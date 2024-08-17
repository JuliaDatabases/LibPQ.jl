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
