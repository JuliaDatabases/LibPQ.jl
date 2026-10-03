struct DBConnection <: DBInterface.Connection
    conn::Connection
end

function DBInterface.connect(::Type{Connection}, args...; kwargs...)
    return DBConnection(Connection(args...; kwargs...))
end

function DBInterface.prepare(conn::DBConnection, args...; kwargs...)
    return prepare(conn.conn, args...; kwargs...)
end

function DBInterface.execute(conn::DBConnection, args...; kwargs...)
    return execute(conn.conn, args...; kwargs...)
end

function DBInterface.execute(conn::DBConnection, str::AbstractString; kwargs...)
    return execute(conn.conn, str; kwargs...)
end

function DBInterface.execute(conn::DBConnection, str::AbstractString, params; kwargs...)
    return execute(conn.conn, str, params; kwargs...)
end

function DBInterface.execute(stmt::Statement, args...; kwargs...)
    return execute(stmt, args...; kwargs...)
end

DBInterface.close!(conn::DBConnection) = close(conn.conn)

# DBInterface 2.0 does not provide transactions.
if isdefined(DBInterface, :transaction)
    # Use direct SQL so transaction control does not create session-long prepared statements.
    function DBInterface.transaction(f, conn::DBConnection)
        close(execute(conn.conn, "BEGIN TRANSACTION;"))
        try
            ret = f()
            close(execute(conn.conn, "COMMIT;"))
            return ret
        catch transaction_error
            transaction_backtrace = catch_backtrace()
            try
                close(execute(conn.conn, "ROLLBACK;"))
            catch rollback_error
                rollback_backtrace = catch_backtrace()
                throw(CompositeException([
                    CapturedException(transaction_error, transaction_backtrace),
                    CapturedException(rollback_error, rollback_backtrace),
                ]))
            end
            rethrow()
        end
    end
end
