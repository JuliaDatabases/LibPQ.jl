using Revise

using
    BenchmarkTools,
    JSON3,
    LibPQ,
    S3DB,
    Tables

function setup_eisdb_credentials()
    eisdb_creds = JSON3.read(read(`aws eisdb-credentials --output json`))
    ENV["AURORA_READER_ENDPOINT"] = eisdb_creds.reader
    ENV["AURORA_DATABASE"] = eisdb_creds.dbname
    ENV["AURORA_PORT"] = eisdb_creds.port
    ENV["AURORA_USER"] = eisdb_creds.username
    return nothing
end

function get_data()
    setup_eisdb_credentials()
    db = S3DB.Client()
    conn = S3DB.AuroraClients.establish_connection(db.dsn)
    result = execute(conn, "SELECT s.data::float8 FROM generate_series(0,10000,0.1) AS s(data);"; binary_format=true)
    data = columntable(result)
    close(conn)
    return data.data
end

function my_getindex(c::LibPQ.Column{T}, row::Integer, col::Integer) where {T}
    jl_result = LibPQ.result(c)
    if LibPQ.isnull(jl_result, row, col)
        return missing
    else
        data_ptr = LibPQ.libpq_c.PQgetvalue(jl_result.result, row - 1, col - 1)
        return convert(Float64, LibPQ.pqparse(Float64, data_ptr))
    end
end

my_collect(c) = map(n -> my_getindex(c, n, 1), 1:length(c))

function foo!(y, x)
    for n in eachindex(x)
        y[n] = x[n]
    end
    return y
end

function main()
    println("Grabbing data");
    lmp_column = get_data();

    println("Current LibPQ performance");
    display(@benchmark collect($lmp_column));
    println();

    y = Vector{Float64}(undef, length(lmp_column));
    println("foo")
    display(@benchmark foo!($y, $lmp_column));
    println();

    println("Peformance with hack");
    display(@benchmark my_collect($lmp_column));
    println();
end

# function profile_allocs(lmp_column)
#     Profile.Allocs.clear()
#     Profile.Allocs.@profile sample_rate=1 collect(lmp_column)
#     PProf.Allocs.pprof(from_c=false)
# end

Revise.track(@__FILE__)
