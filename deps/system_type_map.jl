using LibPQ
using Tables

function print_types(io::IO, conn::Connection; text_limit=92)
    nt = Tables.columntable(
        execute(conn, "SELECT oid, typname FROM pg_catalog.pg_type ORDER BY oid"),
    )

    println(io, "const PQ_SYSTEM_TYPES = Dict{Symbol, Oid}(")
    print(io, "   ")
    line_count = 3
    for i = 1:length(nt[:oid])
        pair_str = string(" :", Symbol(nt[:typname][i]), " => ", nt[:oid][i], ",")
        pair_length = length(pair_str)

        if line_count != 3 && line_count + pair_length > text_limit
            print(io, "\n   ")
            line_count = 3
        end

        print(io, pair_str)
        line_count += pair_length
    end
    println(io, "\n)")
end

print_types(STDOUT, Connection("dbname=postgres"))
