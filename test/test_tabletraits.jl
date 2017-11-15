using LibPQ
using IteratorInterfaceExtensions
using TableTraits
using DataValues
using NamedTuples
using Base.Test

@testset "TableTraits" begin
    const DATABASE_USER = get(ENV, "LIBPQJL_DATABASE_USER", "postgres")

    conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=false)
    result = execute(conn, "SELECT typname FROM pg_type WHERE oid = 16")

    @test IteratorInterfaceExtensions.isiterable(result) == true
    @test TableTraits.isiterabletable(result) == true

    it = IteratorInterfaceExtensions.getiterator(result)

    @test length(it) == 1

    as_array = collect(it)
    @test length(as_array) == 1
    @test as_array[1] == @NT(typname = DataValue("bool"))

    clear(result)
    close(conn)
end