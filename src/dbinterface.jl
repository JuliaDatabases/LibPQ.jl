DBInterface.connect(::Type{Connection}, args...; kws...) =
    LibPQ.Connection(args...; kws...)

DBInterface.prepare(conn::Connection, args...; kws...) =
    LibPQ.prepare(conn, args...; kws...)

DBInterface.execute(conn::Union{Connection, Statement}, args...; kws...) =
    LibPQ.execute(conn, args...; kws...)

DBInterface.close!(conn::Connection) = LibPQ.close(conn)
