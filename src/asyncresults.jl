"An asynchronous PostgreSQL query"
mutable struct AsyncResult
    "The LibPQ.jl Connection used for the query"
    jl_conn::Connection

    "Keyword arguments to pass to Result on creation"
    result_kwargs::Ref

    "Whether or not the query should be cancelled, if running"
    should_cancel::Bool

    "Task which errors or returns a LibPQ.jl Result which is created once available"
    result_task::Task

    function AsyncResult(jl_conn::Connection, result_kwargs::Ref)
        return new(jl_conn, result_kwargs, false)
    end
end

function AsyncResult(jl_conn::Connection; kwargs...)
    return AsyncResult(jl_conn, Ref(kwargs))
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

"""
    handle_result(async_result::AsyncResult; throw_error=true) -> Result

Executes the query in `async_result` and waits for results.

This implements the loop described in the PostgreSQL documentation for
[Asynchronous Command Processing](https://www.postgresql.org/docs/10/libpq-async.html).

The `throw_error` option only determines whether to throw errors when handling the new
[`Result`](@ref)s; the `Task` may error for other reasons related to processing the
asynchronous loop.

The result returned will be the [`Result`](@ref) of the last query run (the only query if
using parameters).
Any errors produced by the queries will be thrown together in a `CompositeException`.
"""
function handle_result(async_result::AsyncResult; throw_error=true)
    errors = []
    result = nothing
    for result_ptr in _consume(async_result.jl_conn)
        try
            result = handle_result(
                Result(
                    result_ptr,
                    async_result.jl_conn;
                    async_result.result_kwargs[]...
                );
                throw_error=throw_error,
            )
        catch err
            push!(errors, err)
        end
    end

    if throw_error && !isempty(errors)
        throw(CompositeException(errors))
    elseif result === nothing
        error(LOGGER, "Async query did not return result")
    else
        return result
    end
end

function _consume(jl_conn::Connection)
    async_result = jl_conn.async_result
    result_ptrs = Ptr{libpq_c.PGresult}[]
    watcher = FDWatcher(socket(jl_conn), true, false)  # can wait for reads
    try
        while true
            if async_result.should_cancel
                debug(LOGGER, "Received cancel signal for connection $(jl_conn.conn)")
                _cancel(jl_conn)
            end
            debug(LOGGER, "Waiting to read from connection $(jl_conn.conn)")
            wait(watcher)
            debug(LOGGER, "Consuming input from connection $(jl_conn.conn)")
            success = libpq_c.PQconsumeInput(jl_conn.conn) == 1
            !success && error(LOGGER, error_message(jl_conn))

            while libpq_c.PQisBusy(jl_conn.conn) == 0
                debug(LOGGER, "Checking the result from connection $(jl_conn.conn)")
                result_ptr = libpq_c.PQgetResult(jl_conn.conn)
                if result_ptr == C_NULL
                    debug(LOGGER, "Finished reading from connection $(jl_conn.conn)")
                    return result_ptrs
                else
                    result_num = length(result_ptrs) + 1
                    debug(LOGGER,
                        "Saving result $result_num from connection $(jl_conn.conn)"
                    )
                    push!(result_ptrs, result_ptr)
                end
            end
        end
    finally
        close(watcher)
    end
end

"""
    cancel(async_result::AsyncResult)

If this [`AsyncResult`](@ref) represents a currently-executing query, attempt to cancel it.
"""
function cancel(async_result::AsyncResult)
    # just sets the `should_cancel` flag
    # the actual cancellation will be triggered in the main loop of _consume
    # which will call `_cancel` on the `Connection`
    async_result.should_cancel = true
    return
end

function _cancel(jl_conn::Connection)
    cancel_ptr = libpq_c.PQgetCancel(jl_conn.conn)
    try
        # https://www.postgresql.org/docs/10/libpq-cancel.html#LIBPQ-PQCANCEL
        errbuf_size = 256
        errbuf = zeros(UInt8, errbuf_size)
        success = libpq_c.PQcancel(cancel_ptr, pointer(errbuf), errbuf_size) == 1
        if !success
            warn(LOGGER, "Failed cancelling query: $(String(errbuf))")
        else
            debug(LOGGER, "Cancelled query for connection $(jl_conn.conn)")
        end
    finally
        libpq_c.PQfreeCancel(cancel_ptr)
    end
end

iserror(async_result::AsyncResult) = Base.istaskfailed(async_result.result_task)
Base.isready(async_result::AsyncResult) = istaskdone(async_result.result_task)
Base.wait(async_result::AsyncResult) = wait(async_result.result_task)
Base.fetch(async_result::AsyncResult) = fetch(async_result.result_task)
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

Only one `AsyncResult` can be active on a [`Connection`](@ref) at once.
If multiple `AsyncResult`s use the same `Connection`, they will execute serially.

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

function async_execute(jl_conn::Connection, query::AbstractString; kwargs...)
    async_result = _async_execute(jl_conn; kwargs...) do jl_conn
        _async_submit(jl_conn.conn, query)
    end

    return async_result
end

function async_execute(
    jl_conn::Connection,
    query::AbstractString,
    parameters::Union{AbstractVector, Tuple};
    kwargs...
)
    string_params = string_parameters(parameters)
    pointer_params = parameter_pointers(string_params)

    async_result = _async_execute(jl_conn; kwargs...) do jl_conn
        _async_submit(jl_conn.conn, query, pointer_params)
    end

    return async_result
end

function _async_execute(
    submission_fn::Function, jl_conn::Connection; throw_error::Bool=true, kwargs...
)
    async_result = AsyncResult(jl_conn; kwargs...)

    async_result.result_task = @async lock(jl_conn) do
        jl_conn.async_result = async_result

        try
            # error if submission fails
            # does not respect `throw_error` as there's no result to return on this error
            submission_fn(jl_conn) || error(LOGGER, error_message(async_result.jl_conn))

            return handle_result(async_result; throw_error=throw_error)::Result
        finally
            jl_conn.async_result = nothing
        end
    end

    return async_result
end

function _async_submit(conn_ptr::Ptr{libpq_c.PGconn}, query::AbstractString)
    return libpq_c.PQsendQuery(conn_ptr, query) == 1
end

function _async_submit(
    conn_ptr::Ptr{libpq_c.PGconn},
    query::AbstractString,
    parameters::Vector{Ptr{UInt8}},
)
    num_params = length(parameters)

    send_status = libpq_c.PQsendQueryParams(
        conn_ptr,
        query,
        num_params,
        C_NULL,  # set paramTypes to C_NULL to have the server infer a type
        parameters,
        C_NULL,  # paramLengths is ignored for text format parameters
        zeros(Cint, num_params),  # all parameters in text format
        zero(Cint),  # return result in text format
    )

    return send_status == 1
end
