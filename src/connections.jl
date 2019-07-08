show_option(str::String) = string(replace(str, [' ', '\\'] => s -> "\\$s"))
show_option(bool::Bool) = ifelse(bool, 't', 'f')
show_option(num::Real) = num

# values containing spaces may not work correctly on PostgreSQL versions before 9.6
const CONNECTION_OPTION_DEFAULTS = Dict{String, String}(
    "DateStyle" => "ISO,YMD",
    "IntervalStyle" => "iso_8601",
    "TimeZone" => DEFAULT_CLIENT_TIME_ZONE[],
)

function _connection_parameter_dict(;
    client_encoding::String="UTF8",
    application_name::String="LibPQ.jl",
    connection_options::Dict{String, String}=Dict{String, String}(),
)
    keep_option((k, v)) = !(k == "TimeZone" && v == "")

    Dict{String, String}(
        "client_encoding" => client_encoding,
        "application_name" => application_name,
        "options" => join(
            imap(Iterators.filter(keep_option, connection_options)) do (k, v)
                "-c $k=$(show_option(v))"
            end,
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
    closed::Atomic{Bool}

    "Semaphore for thread-safety (not thread-safe until Julia 1.2)"
    semaphore::Semaphore

    "Current AsyncResult, if active"
    async_result  # ::Union{AsyncResult, Nothing}, would be a circular reference

    function Connection(
        conn::Ptr,
        closed=false;
        type_map::AbstractDict=PQTypeMap(),
        conversions::AbstractDict=PQConversions(),
    )
        return new(
            conn,
            "UTF8",
            0,
            PQTypeMap(type_map),
            PQConversions(conversions),
            Atomic{Bool}(closed),
            Semaphore(1),
            nothing,
        )
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
        debug(LOGGER, "Connection established: $(jl_conn.conn)")
        # if connection is successful, set client_encoding
        reset_encoding!(jl_conn)
    end

    # keep a reference to `closed` so it's not cleaned up before the connection is
    let closed = jl_conn.closed, conn_ptr = jl_conn.conn
        finalizer(jl_conn) do _
            # finalizers can't task swtich, but they can schedule tasks
            @async begin
                if !atomic_cas!(closed, false, true)
                    debug(LOGGER, "Closing connection $(conn_ptr) in finalizer")
                    # we don't need to acquire a lock, because if anyone else is holding a
                    # lock on the connection (using lock(::Connection)) then it won't be
                    # cleaned up by the gc yet
                    libpq_c.PQfinish(conn_ptr)
                end
            end

            return
        end
    end

    return jl_conn
end

"""
    Connection(
        str::AbstractString;
        throw_error::Bool=true,
        type_map::AbstractDict=LibPQ.PQTypeMap(),
        conversions::AbstractDict=LibPQ.PQConversions(),
        options::Dict{String, String}=LibPQ.CONNECTION_OPTION_DEFAULTS,
    ) -> Connection

Create a `Connection` from a connection string as specified in the PostgreSQL
documentation ([33.1.1. Connection Strings](https://www.postgresql.org/docs/10/libpq-connect.html#LIBPQ-CONNSTRING)).

For information on the `type_map` and `conversions` arguments, see [Type Conversions](@ref typeconv).

See [`handle_new_connection`](@ref) for information on the `throw_error` argument.

## PostgreSQL Connection Options

For a list of available options for the `options` argument, see [Server Configuration](https://www.postgresql.org/docs/10/runtime-config.html).

The default connection options are:

$(join(map((k, v) for (k, v) in CONNECTION_OPTION_DEFAULTS if k != "TimeZone") do (k, v)
    "* `$(repr(k)) => $(repr(v))`"
end, "\n"))
* `"TimeZone" => $(repr(DEFAULT_CLIENT_TIME_ZONE[]))`, or the `PGTZ` environment variable.
  Will use the server time zone if option is set to `""`.

Note that these default connection options may be different than the defaults used by the
server, which are the defaults used by `psql` and other LibPQ clients.
To use the defaults provided by the server, use
`options = Dict{String, String}("TimeZone" => "")`.
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
    debug(LOGGER, "Connecting to $str")
    jl_conn = Connection(libpq_c.PQconnectdbParams(keywords, values, false); kwargs...)

    # If password needed and not entered, prompt the user
    if libpq_c.PQconnectionNeedsPassword(jl_conn.conn) == 1
        push!(keywords, "password")
        user = unsafe_string(libpq_c.PQuser(jl_conn.conn))
        # close this connection; will open another one below with the user-provided password
        close(jl_conn)
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

# AbstractLock primitives:
# https://github.com/JuliaLang/julia/blob/master/base/condition.jl#L18
Base.lock(conn::Connection) = acquire(conn.semaphore)
Base.unlock(conn::Connection) = release(conn.semaphore)
Base.islocked(conn::Connection) = conn.semaphore.curr_cnt >= conn.semaphore.sem_size

# AbstractLock convention:
function Base.lock(f, conn::Connection)
    lock(conn)
    try
        return f()
    finally
        unlock(conn)
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
    lock(jl_conn) do
        status = libpq_c.PQsetClientEncoding(jl_conn.conn, encoding)

        if status == -1
            error(LOGGER,
                "libpq could not set the connection's client encoding to $encoding"
            )
        else
            jl_conn.encoding = encoding
        end
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
    lock(jl_conn) do
        id_number = jl_conn.uid_counter
        jl_conn.uid_counter += 1

        return "__libpq_$(prefix)_$(id_number)__"
    end
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
    if !atomic_cas!(jl_conn.closed, false, true)
        debug(LOGGER, "Closing connection $(jl_conn.conn)")
        async_result = jl_conn.async_result
        async_result === nothing || cancel(async_result)
        lock(jl_conn) do
            libpq_c.PQfinish(jl_conn.conn)
            jl_conn.conn = C_NULL
        end
    else
        debug(LOGGER, "Tried to close a closed connection; doing nothing")
    end
    return nothing
end

"""
    isopen(jl_conn::Connection) -> Bool

Check whether a connection is open.
"""
Base.isopen(jl_conn::Connection) = !jl_conn.closed[]

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
    if !atomic_cas!(jl_conn.closed, false, true)
        debug(LOGGER, "Closing connection $(jl_conn.conn)")
        async_result = jl_conn.async_result
        async_result === nothing || cancel(async_result)
        lock(jl_conn) do
            jl_conn.closed[] = false
            debug(LOGGER, "Resetting connection $(jl_conn.conn)")
            libpq_c.PQreset(jl_conn.conn)
        end

        handle_new_connection(jl_conn; throw_error=throw_error)
    else
        error(LOGGER, "Cannot reset a connection that has been closed")
    end

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
    return ConnectionOption(
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
        if !isopen(jl_conn)
            error(LOGGER, "Connection is closed")
        else
            error(LOGGER, "libpq could not allocate memory for connection info")
        end
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
    if !isopen(jl_conn)
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

function socket(jl_conn::Connection)
    socket_int = libpq_c.PQsocket(jl_conn.conn)
    @static if Sys.iswindows()
        return Base.WindowsRawSocket(Ptr{Cvoid}(Int(socket_int)))
    else
        return RawFD(socket_int)
    end
end
