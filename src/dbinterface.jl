DBInterface.connect(::Type{Connection}, args...; kws...) = Connection(args...; kws...)

DBInterface.prepare(conn::Connection, args...; kws...) = prepare(conn, args...; kws...)

DBInterface.execute(conn::Union{Connection, Statement}, args...; kws...) = execute(conn, args...; kws...)

DBInterface.close!(conn::Connection) = close(conn)
