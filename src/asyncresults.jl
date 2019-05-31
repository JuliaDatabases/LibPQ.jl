"An asynchronous PostgreSQL query"
mutable struct AsyncResult
    "The LibPQ.jl Connection used for the query"
    jl_conn::Connection

    "Whether this AsyncResult has locked the Connection"
    conn_locked::Atomic{Bool}

    "Keyword arguments to pass to Result on creation"
    result_kwargs::Ref

    "Task which errors or returns a LibPQ.jl Result which is created once available"
    result_task::Task

    function AsyncResult(jl_conn::Connection, conn_locked::Atomic{Bool}, result_kwargs::Ref)
        async_result = new(jl_conn, conn_locked, result_kwargs)
        jl_conn.async_result = async_result
        return async_result
    end
end

function AsyncResult(jl_conn::Connection, conn_locked::Atomic{Bool}; kwargs...)
    AsyncResult(jl_conn, conn_locked, Ref(kwargs))
end

function AsyncResult(jl_conn::Connection; kwargs...)
    AsyncResult(jl_conn, Atomic{Bool}(true); kwargs...)
end

function Base.show(io::IO, async_result::AsyncResult)
    status = if isready(async_result)
        if iserror(async_result)
            "errored"
        else
            "finished"
        end
    else
        "in progress"
    end
    print(io, typeof(async_result), " (", status, ")")
end

function _ensure_unlocked(async_result::AsyncResult)
    was_locked = atomic_xchg!(async_result.conn_locked, false)
    if was_locked
        async_result.jl_conn.async_result = nothing
        unlock(async_result.jl_conn)
    end
    return was_locked
end

function handle_result(async_result::AsyncResult, success::Bool; throw_error=true)
    log_function = throw_error ? error : warn

    if success
        async_result.result_task = consume(async_result; throw_error=throw_error)
    else
        msg = error_message(async_result.jl_conn)
        _ensure_unlocked(async_result)
        log_function(LOGGER, msg)
    end

    return async_result
end

"""
    consume(async_result::AsyncResult; throw_error=true) -> Task

Run a task which executes the query in `async_result` and waits for results.

This implements the loop described in the PostgreSQL documentation for
[Asynchronous Command Processing](https://www.postgresql.org/docs/10/libpq-async.html).

The `throw_error` option only determines whether to throw errors when handling the new
[`Result`](@ref)s; the `Task` may error for other reasons related to processing the
asynchronous loop.

The result returned from the `Task` will be the [`Result`](@ref) of the last query run (the
only query if using parameters).
Any errors produced by the queries will be thrown together in a `CompositeException` by
`@sync`.
"""
function consume(async_result::AsyncResult; throw_error=true)
    @async begin
        try
            debug(LOGGER, "getting the socket fd")
            pqfd = socket(async_result.jl_conn)
            try
                debug(LOGGER, "making an FDWatcher")
                watcher = FDWatcher(pqfd, true, false)  # readable, not writeable
                try
                    last_result = @sync begin
                        result = nothing
                        debug(LOGGER, "beginning the waiting loop")
                        while true
                            debug(LOGGER, "waiting on the fd")
                            wait(watcher)
                            debug(LOGGER, "consuming input")
                            success = libpq_c.PQconsumeInput(async_result.jl_conn.conn) == 1
                            !success && error(error_message(async_result.jl_conn))
                            debug(LOGGER, "checking isbusy")
                            while libpq_c.PQisBusy(async_result.jl_conn.conn) == 0
                                debug(LOGGER, "getting a result")
                                result_ptr = libpq_c.PQgetResult(async_result.jl_conn.conn)
                                result_ptr == C_NULL && @goto finished
                                debug(LOGGER, "handling the non-null result")
                                result = @async handle_result(Result(
                                    result_ptr, async_result.jl_conn;
                                    async_result.result_kwargs[]...
                                ); throw_error=throw_error)
                            end
                        end
                        @label finished
                        debug(LOGGER, "finished the sync block")
                        result
                    end

                    return fetch(last_result)
                finally
                    close(watcher)
                end
            finally
                # I should maybe close pqfd here but I don't think that's possible since
                # it's a file descriptor not a handle and it's not technically open
            end
        finally
            # ensure the connection is unlocked
            _ensure_unlocked(async_result)
            debug(LOGGER, "finished the async block")
        end
    end
end

function cancel(async_result::AsyncResult)
    cancel_ptr = libpq_c.PQgetCancel(async_result.jl_conn.conn)
    try
        # https://www.postgresql.org/docs/10/libpq-cancel.html#LIBPQ-PQCANCEL
        errbuf_size = 256
        errbuf = fill(0x0, errbuf_size)
        success = libpq_c.PQcancel(cancel_ptr, pointer(errbuf), errbuf_size) == 1
        if !success
            error("Failed cancelling query: $(String(errbuf))")
        end

        # in place of _ensure_unlocked, just wait for `consume` to call it
        # this avoids "ERROR: connection pointer is NULL" which happens when conn unlocks
        # itself
        trywait(async_result)
    finally
        libpq_c.PQfreeCancel(cancel_ptr)
    end
end

iserror(async_result::AsyncResult) = Base.istaskfailed(async_result.result_task)
Base.isready(async_result::AsyncResult) = istaskdone(async_result.result_task)
Base.wait(async_result::AsyncResult) = wait(async_result.result_task)
Base.fetch(async_result::AsyncResult) = fetch(async_result.result_task)
trywait(async_result::AsyncResult) = (try wait(async_result) catch end; nothing)
trywait(::Nothing) = nothing
Base.close(async_result::AsyncResult) = cancel(async_result)

"""
    async_execute(
        jl_conn::Connection,
        query::AbstractString,
        [parameters::Union{AbstractVector, Tuple},]
        kwargs...
    ) -> AsyncResult

Run a query on the PostgreSQL database and return an [`AsyncResult`](@ref).

The `AsyncResult` contains a `Task` which processes a query asynchronously.
Calling `fetch` on the `AsyncResult` will return a [`Result`](@ref).

All keyword arguments are the same as [`execute`](@ref) and are passed to the created
`Result`.

`async_execute` does not yet support [`Statement`](@ref)s.

`async_execute` optionally takes a `parameters` vector which passes query parameters as
strings to PostgreSQL.
Queries without parameters can contain multiple SQL statements, and the result of the final
statement is returned.
Any errors which occur during executed statements will be bundled together in a
`CompositeException` and thrown.

As is normal for `Task`s, any exceptions will be thrown when calling `wait` or `fetch`.
"""
function async_execute end

function async_execute(
    jl_conn::Connection,
    query::AbstractString;
    throw_error::Bool=true,
    kwargs...
)
    lock(jl_conn)

    success = _async_execute(jl_conn.conn, query)

    return handle_result(AsyncResult(jl_conn; kwargs...), success; throw_error=throw_error)
end

function async_execute(
    jl_conn::Connection,
    query::AbstractString,
    parameters::Union{AbstractVector, Tuple};
    throw_error::Bool=true,
    kwargs...
)
    string_params = string_parameters(parameters)
    pointer_params = parameter_pointers(string_params)

    lock(jl_conn)

    success = _async_execute(jl_conn.conn, query, pointer_params)

    return handle_result(AsyncResult(jl_conn; kwargs...), success; throw_error=throw_error)
end

function _async_execute(conn_ptr::Ptr{libpq_c.PGconn}, query::AbstractString)
    libpq_c.PQsendQuery(conn_ptr, query) == 1
end

function _async_execute(
    conn_ptr::Ptr{libpq_c.PGconn},
    query::AbstractString,
    parameters::Vector{Ptr{UInt8}},
)
    num_params = length(parameters)

    libpq_c.PQsendQueryParams(
        conn_ptr,
        query,
        num_params,
        C_NULL,  # set paramTypes to C_NULL to have the server infer a type
        parameters,
        C_NULL,  # paramLengths is ignored for text format parameters
        zeros(Cint, num_params),  # all parameters in text format
        zero(Cint),  # return result in text format
    ) == 1
end
