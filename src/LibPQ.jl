module LibPQ

export Connection, Result, Statement
export status, reset!, execute, clear,
    encoding, set_encoding!, reset_encoding!,
    num_columns, num_rows, num_params,
    column_name, column_names, column_number

using DocStringExtensions, DataStreams, Nulls

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
    function __init__()
        const global LIBPQ_HANDLE = :libpq
    end

    include(joinpath(@__DIR__, "headers", "libpq-fe.jl"))
end

### CONNECTIONS BEGIN

"A connection to a PostgreSQL database."
mutable struct Connection
    "A pointer to a libpq PGconn object (C_NULL if closed)"
    conn::Ptr{libpq_c.PGconn}

    "True if the connection is closed and the PGconn object has been cleaned up"
    closed::Bool

    "libpq client encoding (string encoding of returned data)"
    encoding::String

    "Integer counter for generating connection-level unique identifiers"
    uid_counter::UInt

    Connection(conn::Ptr, closed=false) = new(conn, closed, "UTF8", 0)
end

"""
    handle_new_connection(jl_conn::Connection; throw_error=true) -> Connection

Check status and handle errors for newly-created connections.
Also set the client encoding ([23.3. Character Set Support](https://www.postgresql.org/docs/10/static/multibyte.html))
to `jl_conn.encoding`.

If `throw_error` is `true`, an error will be thrown if the connection's status is
`CONNECTION_BAD` and the PGconn object will be cleaned up.
Otherwise, a warning will be shown and the user should call `close` or `reset!` on the
returned `Connection`.
"""
function handle_new_connection(jl_conn::Connection; throw_error=true)
    if status(jl_conn) == libpq_c.CONNECTION_BAD
        err = error_message(jl_conn)

        if throw_error
            close(jl_conn)
            error(err)
        else
            warn(err)
        end
    else
        # if connection is successful, set client_encoding
        reset_encoding!(jl_conn)
    end

    return jl_conn
end

"""
    Connection(str::AbstractString; throw_error=true) -> Connection

Create a `Connection` from a connection string as specified in the PostgreSQL
documentation ([33.1.1. Connection Strings](https://www.postgresql.org/docs/10/static/libpq-connect.html#LIBPQ-CONNSTRING)).

See [`handle_new_connection`](@ref) for information on the `throw_error` argument.
"""
function Connection(str::AbstractString; throw_error=true)
    return handle_new_connection(
        Connection(libpq_c.PQconnectdb(str));
        throw_error=throw_error,
    )
end

"""
    encoding(jl_conn::Connection) -> String

Return the client encoding name for the current connection (see
[Table 23.1. PostgreSQL Character Sets](https://www.postgresql.org/docs/10/static/multibyte.html#CHARSET-TABLE)
for possible values).

Currently all Julia connections are set to use `UTF8` as this makes conversion to and from
`String` straighforward.

See also: [`set_encoding!`](@ref), [`reset_encoding!`](@ref)
"""
function encoding(jl_conn::Connection)
    encoding_id::Cint = libpq_c.PQclientEncoding(jl_conn.conn)

    if encoding_id == -1
        error("libpq could not retrieve the connection's client encoding")
    end

    return unsafe_string(libpq_c.pg_encoding_to_char(encoding_id))
end

"""
    set_encoding!(jl_conn::Connection, encoding::String)

Set the client encoding for the current connection (see
[Table 23.1. PostgreSQL Character Sets](https://www.postgresql.org/docs/10/static/multibyte.html#CHARSET-TABLE)
for possible values).

Currently all Julia connections are set to use `UTF8` as this makes conversion to and from
`String` straighforward.
Other encodings are not explicitly handled by this package and will probably be very buggy.

See also: [`encoding`](@ref), [`reset_encoding!`](@ref)
"""
function set_encoding!(jl_conn::Connection, encoding::String)
    status = libpq_c.PQsetClientEncoding(jl_conn.conn, encoding)

    if status == -1
        error("libpq could not set the connection's client encoding to $encoding")
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
See [](https://www.postgresql.org/docs/10/static/libpq-status.html#LIBPQ-PQTRANSACTIONSTATUS)
for information on the meaning of the possible return values.
"""
transaction_status(jl_conn::Connection) = libpq_c.PQtransactionStatus(jl_conn.conn)

"""
    close(jl_conn::Connection)

Close the PostgreSQL database connection and free the memory used by the `PGconn` object.
This function calls [`PQfinish`](https://www.postgresql.org/docs/10/static/libpq-connect.html#LIBPQ-PQFINISH),
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

Check whether a connection is open
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
function reset!(jl_conn::Connection; throw_error=true)
    if jl_conn.closed
        error("Cannot reset a connection that has been closed")
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
        error("Unexpected dispchar in PQconninfoOption")
    end
end

"A Julia representation of a PostgreSQL connection option (`PQconninfoOption`)."
struct ConnectionOption
    "The name of the option"
    keyword::String

    "The name of the fallback environment variable for this option"
    envvar::Union{String, Null}

    "The PostgreSQL compiled-in default for this option"
    compiled::Union{String, Null}

    "The value of the option if set"
    val::Union{String, Null}

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
    ci_array = Vector{ConnectionOption}()

    ci_ptr = libpq_c.PQconninfo(jl_conn.conn)
    if ci_ptr == C_NULL
        error("libpq could not allocate memory for connection info")
    end

    # ci_ptr is an array of PQconninfoOptions terminated by a PQconninfoOption with the
    # keyword field set to C_NULL
    ci_opt_idx = 1
    ci_opt = unsafe_load(ci_ptr, ci_opt_idx)
    while ci_opt.keyword != C_NULL
        push!(ci_array, ConnectionOption(ci_opt))

        ci_opt_idx += 1
        ci_opt = unsafe_load(ci_ptr, ci_opt_idx)
    end

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
        if !isnull(ci_opt.val) && ci_opt.disptype != Debug
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
mutable struct Result <: Data.Source
    "A pointer to a libpq PGresult object (C_NULL if cleared)"
    result::Ptr{libpq_c.PGresult}

    "True if the PGresult object has been cleaned up"
    cleared::Bool

    # TODO: attach encoding per https://wiki.postgresql.org/wiki/Driver_development#Result_object_and_client_encoding
end

"""
    show(io::IO, jl_result::Result)

Show a PostgreSQL result and whether it has been cleared.
"""
function Base.show(io::IO, jl_result::Result)
    print(io, "PostgreSQL result")

    if jl_result.cleared
        print(io, " (cleared)")
    end
end

"""
    Result(result::Ptr{libpq_c.PGresult}) -> Result

Construct a `Result` from a `libpg_c.PGresult`
"""
Result(result::Ptr{libpq_c.PGresult}) = Result(result, false)

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
    clear!(jl_result::Result)

Clean up the memory used by the `PGresult` object.
The `Result` will no longer be usable.
"""
function Base.clear!(jl_result::Result)
    if !jl_result.cleared
        libpq_c.PQclear(jl_result.result)
    end

    jl_result.cleared = true
    jl_result.result = C_NULL
    return nothing
end

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
            libpq_c.PQclear(jl_result.result)
            error(err_msg)
        else
            warn(err_msg)
        end
    else
        if result_status == libpq_c.PGRES_NONFATAL_ERROR
            warn(err_msg)
        end

        info(unsafe_string(libpq_c.PQcmdStatus(jl_result.result)))
    end

    return jl_result
end

"""
    execute(jl_conn::Connection, query::AbstractString; throw_error=true) -> Result

Run a query on the PostgreSQL database and return a Result.
If `throw_error` is `true`, throw an error and clear the result if the query results in a
fatal error or unreadable response.
"""
function execute(jl_conn::Connection, query::AbstractString; throw_error=true)
    return handle_result(
        Result(libpq_c.PQexec(jl_conn.conn, query));
        throw_error=throw_error,
    )
end

"""
    execute(jl_conn::Connection, query::AbstractString, parameters::Vector{<:AbstractString}; throw_error=true) -> Result

Run a query on the PostgreSQL database and return a Result.
If `throw_error` is `true`, throw an error and clear the result if the query results in a
fatal error or unreadable response.
"""
function execute(
    jl_conn::Connection,
    query::AbstractString,
    parameters::AbstractVector{<:Union{String, Nullable{String}, Null}};
    throw_error=true,
)
    num_params = length(parameters)

    return handle_result(
        Result(libpq_c.PQexecParams(
            jl_conn.conn,
            query,
            num_params,
            C_NULL,  # set paramTypes to C_NULL to have the server infer a type
            parameter_pointers(parameters),
            C_NULL,  # paramLengths is ignored for text format parameters
            zeros(Cint, num_params),  # all parameters in text format
            zero(Cint),  # return result in text format
        ));
        throw_error=throw_error,
    )
end

function parameter_pointers(
    parameters::AbstractVector{<:Union{String, Nullable{String}, Null}},
)
    pointers = Vector{Ptr{UInt8}}(length(parameters))

    map!(pointers, parameters) do parameter
        isnull(parameter) ? C_NULL : pointer(unsafe_get(parameter))
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
    column_names(jl_result::Result, column_number::Integer) -> Vector{String}

Return the names of all the columns in the query result.
"""
function column_names(jl_result::Result)
    [column_name(jl_result, i) for i in 1:num_columns(jl_result)]
end

"""
    column_number(jl_result::Result, column_name::AbstractString) -> Int

Return the index (1-based) of the column named `column_name`.
"""
function column_number(jl_result::Result, column_name::AbstractString)::Int
    # todo: check cleared?
    libpq_c.PQfnumber(jl_result.result, String(column_name)) + 1
end

### RESULTS END

### PREPARE BEGIN

struct Statement
    jl_conn::Connection
    name::String
    description::Result
    num_params::Int
end

# currently no deallocation happens; they're deallocated at the end of the session per https://www.postgresql.org/docs/10/static/sql-deallocate.html
function prepare(jl_conn::Connection, query::AbstractString)
    uid = unique_id(jl_conn, "stmt")

    jl_result = handle_result(
        Result(libpq_c.PQprepare(
            jl_conn.conn,
            uid,
            query,
            0,  # infer all parameters from the query string
            C_NULL,
        ));
        throw_error=true,
    )

    clear!(jl_result)

    description = handle_result(
        Result(libpq_c.PQdescribePrepared(
            jl_conn.conn,
            uid,
        ));
        throw_error=true,
    )

    Statement(jl_conn, uid, description, num_params(description))
end

num_params(stmt::Statement) = num_params(stmt.description)
num_columns(stmt::Statement) = num_columns(stmt.description)

function column_name(stmt::Statement, column_number::Integer)
    column_name(stmt.description, column_number)
end

column_names(stmt::Statement) = column_names(stmt.description)

function column_number(stmt::Statement, column_name::AbstractString)
    column_number(stmt.description, column_name)
end

"""
    execute(stmt::Statement, parameters::Vector{<:AbstractString}; throw_error=true) -> Result

Execute a prepared statement on the PostgreSQL database and return a Result.
If `throw_error` is `true`, throw an error and clear the result if the query results in a
fatal error or unreadable response.
"""
function execute(
    stmt::Statement,
    parameters::AbstractVector{<:Union{String, Nullable{String}, Null}};
    throw_error=true,
)
    num_params = length(parameters)

    return handle_result(
        Result(libpq_c.PQexecPrepared(
            stmt.jl_conn.conn,
            stmt.name,
            num_params,
            parameter_pointers(parameters),
            C_NULL,  # paramLengths is ignored for text format parameters
            zeros(Cint, num_params),  # all parameters in text format
            zero(Cint),  # return result in text format
        ));
        throw_error=throw_error,
    )
end

### PREPARE END

include("datastreams.jl")

end
