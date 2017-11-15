using LibPQ
using Base.Test

using DataFrames
using DataStreams

@testset "LibPQ" begin

@testset "ConninfoDisplay" begin
    @test parse(LibPQ.ConninfoDisplay, "") == LibPQ.Normal
    @test parse(LibPQ.ConninfoDisplay, "*") == LibPQ.Password
    @test parse(LibPQ.ConninfoDisplay, "D") == LibPQ.Debug
    @test_throws ErrorException parse(LibPQ.ConninfoDisplay, "N")
end

@testset "Online" begin
    const DATABASE_USER = get(ENV, "LIBPQJL_DATABASE_USER", "postgres")

    @testset "Example" begin
        conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=false)
        @test conn isa Connection
        @test status(conn) == LibPQ.libpq_c.CONNECTION_OK
        @test conn.closed == false

        text_display = sprint(show, conn)
        @test contains(text_display, "dbname = postgres")
        @test contains(text_display, "user = $DATABASE_USER")

        result = execute(conn, "SELECT typname FROM pg_type WHERE oid = 16")
        @test result isa Result
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test result.cleared == false
        @test LibPQ.num_columns(result) == 1
        @test LibPQ.num_rows(result) == 1
        @test LibPQ.column_name(result, 1) == "typname"

        data = Data.stream!(result, DataFrame)

        @test get(data[:typname][1]) == "bool"

        clear(result)
        @test result.cleared == true
        close(conn)
        @test conn.closed == true
    end
end

include("test_tabletraits.jl")

end
