"""
    CopyIn(query, data_itr) -> CopyIn

Create a `CopyIn` query instance which can be executed to send data to PostgreSQL via a
`COPY <table_name> FROM STDIN` query.

`query` must be a `COPY FROM STDIN` query as described in the [PostgreSQL documentation](https://www.postgresql.org/docs/10/sql-copy.html).
`COPY FROM` queries which use a file or `PROGRAM` source can instead use the standard
[`execute`](@ref) query interface.

`data_itr` is an iterable containing chunks of data to send to PostgreSQL.
The data can be divided up into arbitrary buffers as it will be reconstituted on the server.
The iterated items must be `AbstractString`s or `Array{UInt8}`s.
"""
struct CopyIn
    query::String
    data_itr
end

function put_copy_data(jl_conn::Connection, data::Union{Array{UInt8}, AbstractString})
    libpq_c.PQputCopyData(jl_conn.conn, data, sizeof(data))
end

function put_copy_end(jl_conn::Connection)
    libpq_c.PQputCopyEnd(jl_conn.conn, C_NULL)
end

"""
    execute(jl_conn::Connection, copyin::CopyIn, args...;
        throw_error::Bool=true, kwargs...
    ) -> Result

Runs [`execute`](@ref execute(::Connection, ::String)) on `copyin`'s query, then sends
`copyin`'s data to the server.

All other arguments are passed through to the `execute` call for the initial query.
"""
function execute(
    jl_conn::Connection,
    copy::CopyIn,
    parameters=nothing;
    throw_error=true,
    kwargs...,
)
    level = throw_error ? error : warn
    if parameters !== nothing
        string_params = string_parameters(parameters)
        pointer_params = parameter_pointers(string_params)
    end

    copy_end_result = lock(jl_conn) do
        if parameters === nothing
            result = _execute(jl_conn.conn, copy.query)
        else
            result = _execute(jl_conn.conn, copy.query, pointer_params)
        end
        result_status = libpq_c.PQresultStatus(result)

        if result_status != libpq_c.PGRES_COPY_IN
            if !(result_status in (libpq_c.PGRES_BAD_RESPONSE, libpq_c.PGRES_FATAL_ERROR))
                level(LOGGER, Errors.JLResultError(
                    "Expected PGRES_COPY_IN after COPY query, got $result_status"
                ))
            end
            return result
        end

        for chunk in copy.data_itr
            put_copy_data(jl_conn, chunk)
        end

        status_code = put_copy_end(jl_conn)
        if status_code == -1
            level(LOGGER, Errors.PQConnectionError(jl_conn))
        end

        libpq_c.PQgetResult(jl_conn.conn)
    end

    return handle_result(
        Result(copy_end_result, jl_conn, kwargs...); throw_error=throw_error
    )
end

"""
    CopyOut!(data, query) -> CopyOut!

Create a `CopyOut!` query instance which can be executed to receive data from PostgreSQL via a
`COPY <table_name> TO STDIN` query.

`query` must be a `COPY TO STDIN` query as described in the [PostgreSQL documentation](https://www.postgresql.org/docs/10/sql-copy.html).
`COPY TO` queries which use a file or `PROGRAM` source can instead use the standard
[`execute`](@ref) query interface.

`data` is an IOBuffer where strings of data received from PostgreSQL are written to.
The data is received as text in CSV format.
"""
struct CopyOut!
    data::IOBuffer
    query::String
end

"""
    execute(jl_conn::Connection, copyout::CopyOut!, args...;
        throw_error::Bool=true, kwargs...
    ) -> Result

Runs [`execute`](@ref execute(::Connection, ::String)) on `copyout`'s query, then fills
`copyout`'s data from the server.

All other arguments are passed through to the `execute` call for the initial query.
"""
function execute(
    jl_conn::Connection,
    copy::CopyOut!,
    parameters=nothing;
    throw_error=true,
    kwargs...,
)
    level = throw_error ? error : warn
    if parameters !== nothing
        # https://postgrespro.com/list/thread-id/1893680
        throw(ArgumentError("COPY can't take any parameter"))
    end

    copy_end_result = lock(jl_conn) do
        result = _execute(jl_conn.conn, copy.query)
        result_status = libpq_c.PQresultStatus(result)

        if result_status != libpq_c.PGRES_COPY_OUT
            level(LOGGER, Errors.JLResultError(
                "Expected PGRES_COPY_OUT after COPY query, got $result_status"
            ))
            return result
        end

        io = copy.data  # store csv string
        async::Cint = 0  # blocking call
        rowRef = Ref{Cstring}()
        status_code = Cint(0)
        while (status_code = libpq_c.PQgetCopyData(jl_conn.conn, rowRef, async)) > 0
            rowPtr = rowRef[]
            write(io, unsafe_string(rowPtr))
            if rowPtr != C_NULL
                libpq_c.PQfreemem(convert(Ptr{Cvoid}, rowPtr))
            end
        end
        seekstart(io)  # rewind iobuffer so future user read will begin from start
        -2 == status_code && level(LOGGER, Errors.JLResultError("PQgetCopyData error: $(error_message(jl_conn))"))

        libpq_c.PQgetResult(jl_conn.conn)
    end

    return handle_result(
        Result(copy_end_result, jl_conn, kwargs...); throw_error=throw_error
    )
end
