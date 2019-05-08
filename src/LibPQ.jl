module LibPQ

export status, reset!, execute, prepare,
    num_columns, num_rows, num_params, num_affected_rows

using Dates
using DocStringExtensions
using Decimals
using Tables
using Base.Iterators: zip, product
using IterTools: imap
using LayerDicts
using Memento: Memento, getlogger, warn, info, error, debug
using OffsetArrays
using TimeZones

const Parameter = Union{String, Missing}
const LOGGER = getlogger(@__MODULE__)

function __init__()
    Memento.register(LOGGER)
end

# Docstring template for types using DocStringExtensions
@template TYPES =
    """
        $(TYPEDEF)

    $(DOCSTRING)

    ## Fields:

    $(FIELDS)
    """

include(joinpath(@__DIR__, "utils.jl"))

module libpq_c
    export Oid

    include(joinpath(@__DIR__, "..", "deps", "deps.jl"))

    function __init__()
        check_deps()
    end

    include(joinpath(@__DIR__, "headers", "libpq-fe.jl"))
end

using .libpq_c

include("typemaps.jl")

"""
    const LIBPQ_TYPE_MAP::PQTypeMap

The [`PQTypeMap`](@ref) containing LibPQ-level type mappings for LibPQ.jl.
Adding type mappings to this constant will override the default type mappings for all code
using LibPQ.jl.
"""
const LIBPQ_TYPE_MAP = PQTypeMap()

"""
    const LIBPQ_CONVERSIONS::PQConversions

The [`PQConversions`](@ref) containing LibPQ-level conversion functions for LibPQ.jl.
Adding conversions to this constant will override the default conversions for all code using
LibPQ.jl.
"""
const LIBPQ_CONVERSIONS = PQConversions()

### CONNECTIONS BEGIN
show_option(str::String) = string(replace(str, [' ', '\\'] => s -> "\\$s"))
show_option(bool::Bool) = ifelse(bool, 't', 'f')
show_option(num::Real) = num

# values containing spaces may not work correctly on PostgreSQL versions before 9.6
const CONNECTION_OPTION_DEFAULTS = Dict{String, String}(
    "DateStyle" => "ISO,YMD",
    "IntervalStyle" => "iso_8601",
    "TimeZone" => "UTC",
)

function _connection_parameter_dict(;
    client_encoding::String="UTF8",
    application_name::String="LibPQ.jl",
    connection_options::Dict{String, String}=Dict{String, String}(),
)
    Dict{String, String}(
        "client_encoding" => "UTF8",
        "application_name" => "LibPQ.jl",
        "options" => join(
            ("-c $k=$(show_option(v))" for (k, v) in connection_options),
            " ",
        ),
    )
end

const CONNECTION_PARAMETER_DEFAULTS = _connection_parameter_dict(
    connection_options=CONNECTION_OPTION_DEFAULTS
)

"A connection to a PostgreSQL database."
mutable struct Connection
    "A pointer to a libpq PGconn object (C_NULL if closed)"
    conn::Ptr{libpq_c.PGconn}

    "libpq client encoding (string encoding of returned data)"
    encoding::String

    "Integer counter for generating connection-level unique identifiers"
    uid_counter::UInt

    "Connection-level type correspondence map"
    type_map::PQTypeMap

    "Connection-level conversion functions"
    func_map::PQConversions

    "True if the connection is closed and the PGconn object has been cleaned up"
    closed::Bool

    function Connection(
        conn::Ptr,
        closed=false;
        type_map::AbstractDict=PQTypeMap(),
        conversions::AbstractDict=PQConversions(),
    )
        return new(conn, "UTF8", 0, PQTypeMap(type_map), PQConversions(conversions), closed)
    end
end

Base.broadcastable(c::Connection) = Ref(c)

"""
    handle_new_connection(jl_conn::Connection; throw_error=true) -> Connection

Check status and handle errors for newly-created connections.
Also set the client encoding ([23.3. Character Set Support](https://www.postgresql.org/docs/10/multibyte.html))
to `jl_conn.encoding`.

If `throw_error` is `true`, an error will be thrown if the connection's status is
`CONNECTION_BAD` and the PGconn object will be cleaned up.
Otherwise, a warning will be shown and the user should call `close` or `reset!` on the
returned `Connection`.
"""
function handle_new_connection(jl_conn::Connection; throw_error::Bool=true)
    if status(jl_conn) == libpq_c.CONNECTION_BAD
        err = error_message(jl_conn)

        if throw_error
            close(jl_conn)
            error(LOGGER, err)
        else
            warn(LOGGER, err)
        end
    else
        # if connection is successful, set client_encoding
        reset_encoding!(jl_conn)
    end

    return jl_conn
end

"""
    Connection(
        str::AbstractString;
        throw_error::Bool=true,
        type_map::AbstractDict=LibPQ.PQTypeMap(),
        conversions::AbstractDict=LibPQ.PQConversions(),
        options::Dict{String, String}=$(CONNECTION_OPTION_DEFAULTS),
    ) -> Connection

Create a `Connection` from a connection string as specified in the PostgreSQL
documentation ([33.1.1. Connection Strings](https://www.postgresql.org/docs/10/libpq-connect.html#LIBPQ-CONNSTRING)).

For information on the `type_map` and `conversions` arguments, see [Type Conversions](@ref typeconv).

For a list of available options for the `options` argument, see [Server Configuration](https://www.postgresql.org/docs/10/runtime-config.html).

See [`handle_new_connection`](@ref) for information on the `throw_error` argument.
"""
function Connection(
    str::AbstractString;
    throw_error::Bool=true,
    options::Dict{String, String}=CONNECTION_OPTION_DEFAULTS,
    kwargs...
)
    if options === CONNECTION_OPTION_DEFAULTS
        # avoid allocating another dict in the common case
        connection_parameters = CONNECTION_PARAMETER_DEFAULTS
    else
        connection_parameters = _connection_parameter_dict(connection_options=options)
    end

    ci_array = conninfo(str)

    keywords = String[]
    values = String[]

    for (k, v) in connection_parameters
        push!(keywords, k)
        push!(values, v)
    end

    for ci in ci_array
        if !ismissing(ci.val)
            push!(keywords, ci.keyword)
            push!(values, ci.val)
        end
    end

    # Make the connection
    jl_conn = Connection(libpq_c.PQconnectdbParams(keywords, values, false); kwargs...)

    # If password needed and not entered, prompt the user
    if libpq_c.PQconnectionNeedsPassword(jl_conn.conn) == 1
        push!(keywords, "password")
        user = unsafe_string(libpq_c.PQuser(jl_conn.conn))
        prompt = "Enter password for PostgreSQL user $user:"
        pass = Base.getpass(prompt)
        push!(values, read(pass, String))
        Base.shred!(pass)
        return handle_new_connection(
            Connection(libpq_c.PQconnectdbParams(keywords, values, false); kwargs...);
            throw_error=throw_error,
        )
    else
        return handle_new_connection(
            jl_conn;
            throw_error=throw_error,
        )
    end

end

"""
    Connection(f, args...; kwargs...) -> Connection

A utility method to support `do` syntax.
Constructs the `Connection`, calls `f` on it, then closes it.
"""
function Connection(f::Base.Callable, args...; kwargs...)
    jl_conn = Connection(args...; kwargs...)

    try
        return f(jl_conn)
    finally
        close(jl_conn)
    end
end

"""
    server_version(jl_conn::Connection) -> VersionNumber

Get the PostgreSQL version of the server.

See [33.2. Connection Status Functions](https://www.postgresql.org/docs/10/libpq-status.html#LIBPQ-PQSERVERVERSION)
for information on the integer returned by `PQserverVersion` that is parsed by this
function.

See [`@pqv_str`](@ref) for information on how this packages represents PostgreSQL version
numbers.
"""
function server_version(jl_conn::Connection)
    version_int = libpq_c.PQserverVersion(jl_conn.conn)

    first_major = version_int ÷ 10000
    version = if first_major >= 10
        # new style (only major-minor)
        return VersionNumber(first_major, 0, version_int % 100)
    else
        # old style (major-major-minor)
        return VersionNumber(first_major, (version_int % 10000) ÷ 100, version_int % 100)
    end

    return version
end

"""
    @pqv_str -> VersionNumber

Parse a PostgreSQL version.

!!! note

    As of version 10.0, PostgreSQL moved from a three-part version number (where the first
    two parts represent the major version and the third represents the minor version) to a
    two-part major-minor version number.
    In LibPQ.jl, we represent this using the first two `VersionNumber` components as the
    major version and the third as the minor version.

    ## Examples

    ```jldoctest
    julia> using LibPQ: @pqv_str

    julia> pqv"10.1" == v"10.0.1"
    true

    julia> pqv"9.2.5" == v"9.2.5"
    true
    ```
"""
macro pqv_str(str)
    _pqv_str(str)
end

function _pqv_str(str)
    splitted = map(x -> parse(Int, x)::Int, split(str, '.'))

    if isempty(splitted)
        throw(ArgumentError("PostgreSQL version must contain at least one integer"))
    end

    version = if splitted[1] >= 10
        if length(splitted) == 1
            VersionNumber(splitted[1])
        elseif length(splitted) == 2
            VersionNumber(splitted[1], 0, splitted[2])
        else
            throw(ArgumentError(
                "PostgreSQL versions only have two components starting at version 10"
            ))
        end
    else
        if length(splitted) > 3
            throw(ArgumentError(
                "PostgreSQL versions cannot have more than three components"
            ))
        end

        VersionNumber(splitted...)
    end

    return version
end

"""
    encoding(jl_conn::Connection) -> String

Return the client encoding name for the current connection (see
[Table 23.1. PostgreSQL Character Sets](https://www.postgresql.org/docs/10/multibyte.html#CHARSET-TABLE)
for possible values).

Currently all Julia connections are set to use `UTF8` as this makes conversion to and from
`String` straighforward.

See also: [`set_encoding!`](@ref), [`reset_encoding!`](@ref)
"""
function encoding(jl_conn::Connection)
    encoding_id::Cint = libpq_c.PQclientEncoding(jl_conn.conn)

    if encoding_id == -1
        error(LOGGER, "libpq could not retrieve the connection's client encoding")
    end

    return unsafe_string(libpq_c.pg_encoding_to_char(encoding_id))
end

"""
    set_encoding!(jl_conn::Connection, encoding::String)

Set the client encoding for the current connection (see
[Table 23.1. PostgreSQL Character Sets](https://www.postgresql.org/docs/10/multibyte.html#CHARSET-TABLE)
for possible values).

Currently all Julia connections are set to use `UTF8` as this makes conversion to and from
`String` straighforward.
Other encodings are not explicitly handled by this package and will probably be very buggy.

See also: [`encoding`](@ref), [`reset_encoding!`](@ref)
"""
function set_encoding!(jl_conn::Connection, encoding::String)
    status = libpq_c.PQsetClientEncoding(jl_conn.conn, encoding)

    if status == -1
        error(LOGGER, "libpq could not set the connection's client encoding to $encoding")
    else
        jl_conn.encoding = encoding
    end

    return nothing
end

"""
    reset_encoding!(jl_conn::Connection, encoding::String)

Reset the client encoding for the current connection to `jl_conn.encoding`.

See also: [`encoding`](@ref), [`set_encoding!`](@ref)
"""
function reset_encoding!(jl_conn::Connection)
    set_encoding!(jl_conn, jl_conn.encoding)
end

"""
    unique_id(jl_conn::Connection, prefix::AbstractString="") -> String

Return a valid PostgreSQL identifier that is unique for the current connection.
This is mostly used to create names for prepared statements.
"""
function unique_id(jl_conn::Connection, prefix::AbstractString="")
    id_number, jl_conn.uid_counter = jl_conn.uid_counter, jl_conn.uid_counter + 1

    return "__libpq_$(prefix)_$(id_number)__"
end

"""
    status(jl_conn::Connection) -> libpq_c.ConnStatusType

Return the status of the PostgreSQL database connection according to libpq.
Only `CONNECTION_OK` and `CONNECTION_BAD` are valid for blocking connections, and only
blocking connections are supported right now.

See also: [`error_message`](@ref)
"""
status(jl_conn::Connection) = libpq_c.PQstatus(jl_conn.conn)

"""
    transaction_status(jl_conn::Connection) -> libpq_c.PGTransactionStatusType

Return the PostgreSQL database server's current in-transaction status for the connection.
See [](https://www.postgresql.org/docs/10/libpq-status.html#LIBPQ-PQTRANSACTIONSTATUS)
for information on the meaning of the possible return values.
"""
transaction_status(jl_conn::Connection) = libpq_c.PQtransactionStatus(jl_conn.conn)

"""
    close(jl_conn::Connection)

Close the PostgreSQL database connection and free the memory used by the `PGconn` object.
This function calls [`PQfinish`](https://www.postgresql.org/docs/10/libpq-connect.html#LIBPQ-PQFINISH),
but only if `jl_conn.closed` is `false`, to avoid a double-free.
"""
function Base.close(jl_conn::Connection)
    if !jl_conn.closed
        libpq_c.PQfinish(jl_conn.conn)
    end

    jl_conn.closed = true
    jl_conn.conn = C_NULL
    return nothing
end

"""
    isopen(jl_conn::Connection) -> Bool

Check whether a connection is open.
"""
Base.isopen(jl_conn::Connection) = !jl_conn.closed

"""
    reset!(jl_conn::Connection; throw_error=true)

Reset the communication to the PostgreSQL server.
The `PGconn` object will be recreated using identical connection parameters.

See [`handle_new_connection`](@ref) for information on the `throw_error` argument.

!!! note

    This function can be called on a connection with status `CONNECTION_BAD`, for example,
    but cannot be called on a connection that has been closed.
"""
function reset!(jl_conn::Connection; throw_error::Bool=true)
    if jl_conn.closed
        error(LOGGER, "Cannot reset a connection that has been closed")
    end

    libpq_c.PQreset(jl_conn.conn)
    handle_new_connection(jl_conn; throw_error=throw_error)

    return nothing
end

"""
    error_message(jl_conn::Connection) -> String

Return the error message most recently generated by an operation on the connection.
Includes a trailing newline.
"""
error_message(jl_conn::Connection) = unsafe_string(libpq_c.PQerrorMessage(jl_conn.conn))

"""
Indicator for how to display a PostgreSQL connection option (`PQconninfoOption`).

Possible values are:

* `Normal` (libpq: ""): display as is
* `Password` (libpq: "*"): hide the value of this field
* `Debug` (libpq: "D"): don't show by default
"""
@enum ConninfoDisplay Normal Password Debug

"""
    parse(::Type{ConninfoDisplay}, str::AbstractString) -> ConninfoDisplay

Parse a `ConninfoDisplay` from a string. See [`ConninfoDisplay`](@ref).
"""
function Base.parse(::Type{ConninfoDisplay}, str::AbstractString)::ConninfoDisplay
    if length(str) < 1
        Normal
    elseif first(str) == '*'
        Password
    elseif first(str) == 'D'
        Debug
    else
        error(LOGGER, "Unexpected dispchar '$str' in PQconninfoOption")
    end
end

"A Julia representation of a PostgreSQL connection option (`PQconninfoOption`)."
struct ConnectionOption
    "The name of the option"
    keyword::String

    "The name of the fallback environment variable for this option"
    envvar::Union{String, Missing}

    "The PostgreSQL compiled-in default for this option"
    compiled::Union{String, Missing}

    "The value of the option if set"
    val::Union{String, Missing}

    "The label of the option for display"
    label::String

    "Indicator for how to display the option (see [`ConninfoDisplay`](@ref))"
    disptype::ConninfoDisplay

    "The size of field to provide for entry of the option value (not used here)"
    dispsize::Int
end

"""
    ConnectionOption(pq_opt::libpq_c.PQconninfoOption) -> ConnectionOption

Construct a `ConnectionOption` from a `libpg_c.PQconninfoOption`.
"""
function ConnectionOption(pq_opt::libpq_c.PQconninfoOption)
    ConnectionOption(
        unsafe_string(pq_opt.keyword),
        unsafe_string_or_null(pq_opt.envvar),
        unsafe_string_or_null(pq_opt.compiled),
        unsafe_string_or_null(pq_opt.val),
        unsafe_string(pq_opt.label),
        parse(ConninfoDisplay, unsafe_string(pq_opt.dispchar)),
        pq_opt.dispsize,
    )
end

"""
    conninfo(jl_conn::Connection) -> Vector{ConnectionOption}

Get all connection options for a connection.
"""
function conninfo(jl_conn::Connection)
    ci_ptr = libpq_c.PQconninfo(jl_conn.conn)

    if ci_ptr == C_NULL
        error(LOGGER, "libpq could not allocate memory for connection info")
    end

    ci_array = conninfo(ci_ptr)
    libpq_c.PQconninfoFree(ci_ptr)
    return ci_array
end

function conninfo(ci_ptr::Ptr{libpq_c.PQconninfoOption})
    ci_array = Vector{ConnectionOption}()

    # ci_ptr is an array of PQconninfoOptions terminated by a PQconninfoOption with the
    # keyword field set to C_NULL
    ci_opt_idx = 1
    ci_opt = unsafe_load(ci_ptr, ci_opt_idx)
    while ci_opt.keyword != C_NULL
        push!(ci_array, ConnectionOption(ci_opt))

        ci_opt_idx += 1
        ci_opt = unsafe_load(ci_ptr, ci_opt_idx)
    end

    return ci_array
end

"""
    conninfo(str::AbstractString) -> Vector{ConnectionOption}

Parse connection options from a connection string (either a URI or key-value pairs).
"""
function conninfo(str::AbstractString)
    err_ref = Ref{Ptr{UInt8}}(C_NULL)
    ci_ptr = libpq_c.PQconninfoParse(str, err_ref)

    if ci_ptr == C_NULL && err_ref[] == C_NULL
        error(LOGGER, "libpq could not allocate memory for connection info")
    end

    if err_ref[] != C_NULL
        err_msg = unsafe_string(err_ref[])
        libpq_c.PQfreemem(err_ref[])
        error(err_msg)
    end

    ci_array = conninfo(ci_ptr)
    libpq_c.PQconninfoFree(ci_ptr)
    return ci_array
end

"""
    show(io::IO, jl_conn::Connection)

Display a [`Connection`](@ref) by showing the connection status and each connection option.
"""
function Base.show(io::IO, jl_conn::Connection)
    if jl_conn.closed
        print(io, "PostgreSQL connection (closed)")
        return nothing
    end

    print(io, "PostgreSQL connection ($(status(jl_conn))) with parameters:")
    for ci_opt in conninfo(jl_conn)
        if !ismissing(ci_opt.val) && ci_opt.disptype != Debug
            print(io, "\n  ", ci_opt.keyword, " = ")

            if ci_opt.disptype == Password
                print(io, "*" ^ ci_opt.dispsize)
            else
                print(io, ci_opt.val)
            end
        end
    end
end

### CONNECTIONS END

### RESULTS BEGIN

"A result from a PostgreSQL database query"
mutable struct Result
    "A pointer to a libpq PGresult object (C_NULL if cleared)"
    result::Ptr{libpq_c.PGresult}

    "PostgreSQL Oids for each column in the result"
    column_oids::Vector{Oid}

    "Julia types for each column in the result"
    column_types::Vector{Type}

    "Whether to expect NULL for each column (whether output data can have `missing`)"
    not_null::Vector{Bool}

    "Conversions from PostgreSQL data to Julia types for each column in the result"
    column_funcs::Vector{Base.Callable}

    # TODO: attach encoding per https://wiki.postgresql.org/wiki/Driver_development#Result_object_and_client_encoding
    function Result(
        result::Ptr{libpq_c.PGresult},
        jl_conn::Connection;
        column_types::AbstractDict=ColumnTypeMap(),
        type_map::AbstractDict=PQTypeMap(),
        conversions::AbstractDict=PQConversions(),
        not_null=false,
    )
        jl_result = new(result)

        column_type_map = ColumnTypeMap()
        for (k, v) in column_types
            column_type_map[column_number(jl_result, k)] = v
        end

        type_lookup = LayerDict(
            PQTypeMap(type_map),
            jl_conn.type_map,
            LIBPQ_TYPE_MAP,
            _DEFAULT_TYPE_MAP,
        )

        func_lookup = LayerDict(
            PQConversions(conversions),
            jl_conn.func_map,
            LIBPQ_CONVERSIONS,
            _DEFAULT_CONVERSIONS,
            _FALLBACK_CONVERSION,
        )

        jl_result.column_oids = col_oids = map(1:num_columns(jl_result)) do col_num
            libpq_c.PQftype(jl_result.result, col_num - 1)
        end

        jl_result.column_types = col_types = collect(Type, imap(enumerate(col_oids)) do itr
            col_num, col_oid = itr
            get(column_type_map, col_num) do
                get(type_lookup, col_oid, String)
            end
        end)

        jl_result.column_funcs = collect(Base.Callable, imap(col_oids, col_types) do oid, typ
            func_lookup[(oid, typ)]
        end)

        # figure out which columns the user says may contain nulls
        if not_null isa Bool
            jl_result.not_null = fill(not_null, size(col_types))
        elseif not_null isa AbstractArray
            if eltype(not_null) === Bool
                if length(not_null) != length(col_types)
                    throw(ArgumentError(
                        "The length of keyword argument not_null, when an array, must be equal to the number of columns"
                    ))
                end

                jl_result.not_null = not_null
            else
                # assume array of column names
                jl_result.not_null = fill(false, size(col_types))

                for col_name in not_null
                    col_num = column_number(jl_result, col_name)
                    jl_result.not_null[col_num] = true
                end
            end
        else
            throw(ArgumentError(
                "Unsupported type $(typeof(not_null)) for keyword argument not_null"
            ))
        end

        finalizer(close, jl_result)

        return jl_result
    end
end

"""
    show(io::IO, jl_result::Result)

Show a PostgreSQL result and whether it has been cleared.
"""
function Base.show(io::IO, jl_result::Result)
    print(io, "PostgreSQL result")

    if !isopen(jl_result)
        print(io, " (cleared)")
    end
end

"""
    status(jl_result::Result) -> libpq_c.ExecStatusType

Return the status of a result's corresponding database query according to libpq.
Only `CONNECTION_OK` and `CONNECTION_BAD` are valid for blocking connections, and only
blocking connections are supported right now.

See also: [`error_message`](@ref)
"""
status(jl_result::Result) = libpq_c.PQresultStatus(jl_result.result)

"""
    error_message(jl_result::Result) -> String

Return the error message associated with the result, or an empty string if there was no
error.
Includes a trailing newline.
"""
function error_message(jl_result::Result)
    unsafe_string(libpq_c.PQresultErrorMessage(jl_result.result))
end

"""
    close(jl_result::Result)

Clean up the memory used by the `PGresult` object.
The `Result` will no longer be usable.
"""
function Base.close(jl_result::Result)
    ptr, jl_result.result = jl_result.result, C_NULL
    if ptr != C_NULL
        libpq_c.PQclear(ptr)
    end
    return nothing
end

"""
    isopen(jl_result::Result)

Determine whether the given `Result` has been `close`d, i.e. whether the memory
associated with the underlying `PGresult` object has been cleared.
"""
Base.isopen(jl_result::Result) = jl_result.result != C_NULL

"""
    handle_result(jl_result::Result; throw_error::Bool=true) -> Result

Check status and handle errors for newly-created result objects.

If `throw_error` is `true`, throw an error and clear the result if the query results in a
fatal error or unreadable response.
Otherwise a warning is shown.

Also print an info message about the result.
"""
function handle_result(jl_result::Result; throw_error::Bool=true)
    err_msg = error_message(jl_result)
    result_status = status(jl_result)

    if result_status in (libpq_c.PGRES_BAD_RESPONSE, libpq_c.PGRES_FATAL_ERROR)
        if throw_error
            close(jl_result)
            error(LOGGER, err_msg)
        else
            warn(LOGGER, err_msg)
        end
    else
        if result_status == libpq_c.PGRES_NONFATAL_ERROR
            warn(LOGGER, err_msg)
        end

        debug(LOGGER, unsafe_string(libpq_c.PQcmdStatus(jl_result.result)))
    end

    return jl_result
end

"""
    execute(
        {jl_conn::Connection, query::AbstractString | stmt::Statement},
        [parameters::Union{AbstractVector, Tuple},]
        throw_error::Bool=true,
        column_types::AbstractDict=ColumnTypeMap(),
        type_map::AbstractDict=LibPQ.PQTypeMap(),
        conversions::AbstractDict=LibPQ.PQConversions(),
    ) -> Result

Run a query on the PostgreSQL database and return a `Result`.
If `throw_error` is `true`, throw an error and clear the result if the query results in a
fatal error or unreadable response.

The query may be passed as `Connection` and `AbstractString` (SQL) arguments, or as a
`Statement`.

`execute` optionally takes a `parameters` vector which passes query parameters as strings to
PostgreSQL.

`column_types` accepts type overrides for columns in the result which take priority over
those in `type_map`.
For information on the `column_types`, `type_map`, and `conversions` arguments, see
[Type Conversions](@ref typeconv).
"""
function execute end

function execute(
    jl_conn::Connection,
    query::AbstractString;
    throw_error::Bool=true,
    kwargs...
)
    return handle_result(
        Result(libpq_c.PQexec(jl_conn.conn, query), jl_conn; kwargs...);
        throw_error=throw_error,
    )
end

function execute(
    jl_conn::Connection,
    query::AbstractString,
    parameters::Union{AbstractVector, Tuple};
    throw_error::Bool=true,
    kwargs...
)
    num_params = length(parameters)
    string_params = string_parameters(parameters)

    return handle_result(
        Result(libpq_c.PQexecParams(
            jl_conn.conn,
            query,
            num_params,
            C_NULL,  # set paramTypes to C_NULL to have the server infer a type
            parameter_pointers(string_params),
            C_NULL,  # paramLengths is ignored for text format parameters
            zeros(Cint, num_params),  # all parameters in text format
            zero(Cint),  # return result in text format
        ), jl_conn; kwargs...);
        throw_error=throw_error,
    )
end

"""
    string_parameters(parameters::AbstractVector) -> Vector{Union{String, Missing}}

Convert parameters to strings which can be passed to libpq, propagating `missing`.
"""
function string_parameters end

string_parameters(parameters::AbstractVector{<:Parameter}) = parameters

# Tuples of parameters
string_parameters(parameters::Tuple) = string_parameters(collect(parameters))

# vector which can't contain missing
string_parameters(parameters::AbstractVector) = map(string_parameter, parameters)

# vector which might contain missings
function string_parameters(parameters::AbstractVector{>:Missing})
    collect(
        Union{String, Missing},
        imap(parameters) do parameter
            ismissing(parameter) ? missing : string_parameter(parameter)
        end
    )
end

string_parameter(parameter) = string(parameter)

function string_parameter(parameter::AbstractVector)
    io = IOBuffer()
    print(io, "{")
    join(io, (_array_element(el) for el in parameter), ",")
    print(io, "}")
    String(take!(io))
end

_array_element(el::AbstractString) = "\"$el\""
_array_element(el::Missing) = "NULL"
_array_element(el) = string_parameter(el)

"""
    parameter_pointers(parameters::AbstractVector{<:Parameter}) -> Vector{Ptr{UInt8}}

Given a vector of parameters, returns a vector of pointers to either the string bytes in the
original or `C_NULL` if the element is `missing`.
"""
function parameter_pointers(parameters::AbstractVector{<:Parameter})
    pointers = Vector{Ptr{UInt8}}(undef, length(parameters))

    map!(pointers, parameters) do parameter
        ismissing(parameter) ? C_NULL : pointer(parameter)
    end

    return pointers
end

"""
    num_params(jl_result::Result) -> Int

Return the number of parameters in a prepared statement.
If this result did not come from the description of a prepared statement, return 0.
"""
function num_params(jl_result::Result)::Int
    # todo: check cleared?
    libpq_c.PQnparams(jl_result.result)
end

"""
    num_rows(jl_result::Result) -> Int

Return the number of rows in the query result.
This will be 0 if the query would never return data.
"""
function num_rows(jl_result::Result)::Int
    # todo: check cleared?
    libpq_c.PQntuples(jl_result.result)
end

"""
    num_affected_rows(jl_result::Result) -> Int

Return the number of rows affected by the command returning the result.
This is useful for counting the rows affected by operations such as INSERT,
UPDATE and DELETE that do not return rows but affect them.
This will be 0 if the query does not affect any row.
"""
function num_affected_rows(jl_result::Result)::Int
    # todo: check cleared?
    str = unsafe_string(libpq_c.PQcmdTuples(jl_result.result))
    if isempty(str)
        throw(ArgumentError("Result generated by an incompatible command"))
    else
        return parse(Int, str)
    end
end

"""
    num_columns(jl_result::Result) -> Int

Return the number of columns in the query result.
This will be 0 if the query would never return data.
"""
function num_columns(jl_result::Result)::Int
    # todo: check cleared?
    libpq_c.PQnfields(jl_result.result)
end

"""
    column_name(jl_result::Result, column_number::Integer) -> String

Return the name of the column at index `column_number` (1-based).
"""
function column_name(jl_result::Result, column_number::Integer)
    # todo: check cleared?
    unsafe_string(libpq_c.PQfname(jl_result.result, column_number - 1))
end

"""
    column_names(jl_result::Result) -> Vector{String}

Return the names of all the columns in the query result.
"""
function column_names(jl_result::Result)
    return [column_name(jl_result, i) for i in 1:num_columns(jl_result)]
end

"""
    column_number(jl_result::Result, column_name::Union{AbstractString, Symbol}) -> Int

Return the index (1-based) of the column named `column_name`.
"""
function column_number(jl_result::Result, column_name::Union{AbstractString, Symbol})::Int
    # todo: check cleared?
    return libpq_c.PQfnumber(jl_result.result, String(column_name)) + 1
end

"""
    column_number(jl_result::Result, column_idx::Integer) -> Int

Return the index of the column if it is valid, or error.
"""
function column_number(jl_result::Result, column_idx::Integer)::Int
    if !checkindex(Bool, 1:num_columns(jl_result), column_idx)
        throw(BoundsError(column_names(jl_result), column_idx))
    end

    return column_idx
end

"""
    column_oids(jl_result::Result) -> Vector{LibPQ.Oid}

Return the PostgreSQL oids for each column in the result.
"""
column_oids(jl_result::Result) = jl_result.column_oids

"""
    column_types(jl_result::Result) -> Vector{Type}

Return the corresponding Julia types for each column in the result.
"""
column_types(jl_result::Result) = jl_result.column_types


### RESULTS END

### PREPARE BEGIN

"A PostgreSQL prepared statement"
struct Statement
    """
    A `Connection` for which this statement is valid.
    It may become invalid if the connection is reset.
    """
    jl_conn::Connection

    "An autogenerated neame for the prepared statement (using [`unique_id`](@ref)"
    name::String

    "The query string of the prepared statement"
    query::String

    "A `Result` containing a description of the prepared statement"
    description::Result

    "The number of parameters accepted by this statement according to `description`"
    num_params::Int
end

Base.broadcastable(stmt::Statement) = Ref(stmt)

"""
    prepare(jl_conn::Connection, query::AbstractString) -> Statement

Create a prepared statement on the PostgreSQL server using libpq.
The statement is given an generated unique name using [`unique_id`](@ref).

!!! note

    Currently the statement is not explicitly deallocated, but it is deallocated at the end
    of session per the [PostgreSQL documentation on DEALLOCATE](https://www.postgresql.org/docs/10/sql-deallocate.html).
"""
function prepare(jl_conn::Connection, query::AbstractString)
    uid = unique_id(jl_conn, "stmt")

    jl_result = handle_result(
        Result(libpq_c.PQprepare(
            jl_conn.conn,
            uid,
            query,
            0,  # infer all parameters from the query string
            C_NULL,
        ), jl_conn);
        throw_error=true,
    )

    close(jl_result)

    description = handle_result(
        Result(libpq_c.PQdescribePrepared(
            jl_conn.conn,
            uid,
        ), jl_conn);
        throw_error=true,
    )

    Statement(jl_conn, uid, query, description, num_params(description))
end

"""
    show(io::IO, jl_result::Statement)

Show a PostgreSQL prepared statement and its query.
"""
function Base.show(io::IO, stmt::Statement)
    print(
        io,
        "PostgreSQL prepared statement named ",
        stmt.name,
        " with query ",
        stmt.query,
    )
end

"""
    num_params(stmt::Statement) -> Int

Return the number of parameters in the prepared statement.
"""
num_params(stmt::Statement) = num_params(stmt.description)

"""
    num_columns(stmt::Statement) -> Int

Return the number of columns that would be returned by executing the prepared statement.
"""
num_columns(stmt::Statement) = num_columns(stmt.description)

"""
    column_name(stmt::Statement, column_number::Integer) -> String

Return the name of the column at index `column_number` (1-based) that would be returned by
executing the prepared statement.
"""
function column_name(stmt::Statement, column_number::Integer)
    column_name(stmt.description, column_number)
end

"""
    column_names(stmt::Statement) -> Vector{String}

Return the names of all the columns in the query result that would be returned by executing
the prepared statement.
"""
column_names(stmt::Statement) = column_names(stmt.description)

"""
    column_number(stmt::Statement, column_name::AbstractString) -> Int

Return the index (1-based) of the column named `column_name` that would be returned by
executing the prepared statement.
"""
function column_number(stmt::Statement, column_name::AbstractString)
    column_number(stmt.description, column_name)
end

function execute(
    stmt::Statement,
    parameters::Union{AbstractVector, Tuple};
    throw_error::Bool=true,
    kwargs...
)
    num_params = length(parameters)
    string_params = string_parameters(parameters)

    return handle_result(
        Result(libpq_c.PQexecPrepared(
            stmt.jl_conn.conn,
            stmt.name,
            num_params,
            parameter_pointers(string_params),
            C_NULL,  # paramLengths is ignored for text format parameters
            zeros(Cint, num_params),  # all parameters in text format
            zero(Cint),  # return result in text format
        ), stmt.jl_conn; kwargs...);
        throw_error=throw_error,
    )
end

function execute(
    stmt::Statement;
    throw_error::Bool=true,
    kwargs...
)
    return handle_result(
        Result(libpq_c.PQexecPrepared(
            stmt.jl_conn.conn,
            stmt.name,
            0,  # no parameters
            C_NULL,
            C_NULL,  # paramLengths is ignored for text format parameters
            C_NULL,  # all parameters in text format
            zero(Cint),  # return result in text format
        ), stmt.jl_conn; kwargs...);
        throw_error=throw_error,
    )
end

### PREPARE END

include("parsing.jl")
include("copy.jl")
include("tables.jl")

end
