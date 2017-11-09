module LibPQ

export Connection
export status, execute, clear

using DataStreams, Nulls, NullableArrays

module libpq_c
    function __init__()
        const global LIBPQ_HANDLE = :libpq
    end

    include(joinpath(@__DIR__, "headers", "libpq-fe.jl"))
end

@enum ConninfoDiplay Normal Password Debug

function Base.parse(::Type{ConninfoDiplay}, str::AbstractString)::ConninfoDiplay
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

function unsafe_nullable_string(ptr::Cstring)::Nullable{String}
    ptr == C_NULL ? Nullable() : unsafe_string(ptr)
end

struct ConnectionOption
    keyword::String
    envvar::Nullable{String}
    compiled::Nullable{String}
    val::Nullable{String}
    label::String
    disptype::ConninfoDiplay
    dispsize::Int
end

function ConnectionOption(pq_opt::libpq_c.PQconninfoOption)
    ConnectionOption(
        unsafe_string(pq_opt.keyword),
        unsafe_nullable_string(pq_opt.envvar),
        unsafe_nullable_string(pq_opt.compiled),
        unsafe_nullable_string(pq_opt.val),
        unsafe_string(pq_opt.label),
        parse(ConninfoDiplay, unsafe_string(pq_opt.dispchar)),
        pq_opt.dispsize,
    )
end

mutable struct Connection
    conn::Ptr{libpq_c.PGconn}
    closed::Bool
end

function Connection(str::AbstractString; throw_error=false)
    jl_conn = Connection(libpq_c.PQconnectdb(str), false)

    if status(jl_conn) == libpq_c.CONNECTION_BAD
        err = error_message(jl_conn)

        if throw_error
            close(jl_conn)
            error(err)
        else
            warn(err)
        end
    end

    return jl_conn
end

status(jl_conn::Connection) = libpq_c.PQstatus(jl_conn.conn)
function Base.close(jl_conn::Connection)
    if !jl_conn.closed
        libpq_c.PQfinish(jl_conn.conn)
    end

    jl_conn.closed = true
    jl_conn.conn = C_NULL
    return nothing
end
function reset!(jl_conn::Connection; throw_error=false)
    if jl_conn.closed
        error("Cannot reset a connection that has been closed")
    end

    libpq_c.PQreset(jl_conn.conn)

    if status(jl_conn) == libpq_c.CONNECTION_BAD
        err = error_message(jl_conn)

        if throw_error
            close(jl_conn)
            error(err)
        else
            warn(err)
        end
    end

    return nothing
end

error_message(jl_conn::Connection) = unsafe_string(libpq_c.PQerrorMessage(jl_conn.conn))

function conninfo(jl_conn::Connection)
    ci_array = Vector{ConnectionOption}()

    ci_ptr = libpq_c.PQconninfo(jl_conn.conn)
    if ci_ptr == C_NULL
        error("libpq could not allocate memory for connection info")
    end

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

function Base.show(io::IO, jl_conn::Connection)
    if jl_conn.closed
        print("PostgreSQL connection (closed)")
        return nothing
    end

    print("PostgreSQL connection ($(status(jl_conn))) with parameters:")
    for ci_opt in conninfo(jl_conn)
        if !isnull(ci_opt.val) && ci_opt.disptype != Debug
            print("\n  ", ci_opt.keyword, " = ")

            if ci_opt.disptype == Password
                print("*" ^ ci_opt.dispsize)
            else
                print(get(ci_opt.val))
            end
        end
    end
end

mutable struct Result <: Data.Source
    result::Ptr{libpq_c.PGresult}
    cleared::Bool
end

function Base.show(io::IO, jl_result::Result)
    print("PostgreSQL result")

    if jl_result.cleared
        print(" (cleared)")
    end
end

Result(result::Ptr{libpq_c.PGresult}) = Result(result, false)

status(jl_result::Result) = libpq_c.PQresultStatus(jl_result.result)
function error_message(jl_result::Result)
    unsafe_string(libpq_c.PQresultErrorMessage(jl_result.result))
end
function clear(jl_result::Result)
    if !jl_result.cleared
        libpq_c.PQclear(jl_result.result)
    end

    jl_result.cleared = true
    jl_result.result = C_NULL
    return nothing
end

function execute(jl_conn::Connection, query::AbstractString; throw_error=false)
    jl_result = Result(libpq_c.PQexec(jl_conn.conn, query), false)
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

function num_rows(jl_result::Result)::Int
    # todo: check cleared?
    libpq_c.PQntuples(jl_result.result)
end

function num_columns(jl_result::Result)::Int
    # todo: check cleared?
    libpq_c.PQnfields(jl_result.result)
end

function column_name(jl_result::Result, column_number::Integer)
    # todo: check cleared?
    unsafe_string(libpq_c.PQfname(jl_result.result, column_number))
end

function column_names(jl_result::Result)
    [column_name(jl_result, i - 1) for i in 1:num_columns(jl_result)]
end

function column_number(jl_result::Result, column_name::AbstractString)::Int
    # todo: check cleared?
    libpq_c.PQfnumber(jl_result.result, String(column_name))
end

include("datastreams.jl")

end
