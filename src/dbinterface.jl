DBInterface.connect(::Type{Connection}, args...; kws...) = Connection(args...; kws...)

DBInterface.prepare(conn::Connection, args...; kws...) = prepare(conn, args...; kws...)

function DBInterface.execute(conn::Union{Connection,Statement}, args...; kws...)
    return execute(conn, args...; kws...)
end

DBInterface.close!(conn::Connection) = close(conn)
