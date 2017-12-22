using LibPQ
using Compat: Test

import Compat: @__MODULE__
using Compat.Dates
using DataStreams
using Decimals
using Memento
using Missings
using NamedTuples
using OffsetArrays
using TestSetExtensions
using TimeZones


Memento.config("critical")

const TESTSET_TYPE = VERSION < v"0.7-" ? ExtendedTestSet : Test.DefaultTestSet

@testset TESTSET_TYPE "LibPQ" begin

@testset "ConninfoDisplay" begin
    @test parse(LibPQ.ConninfoDisplay, "") == LibPQ.Normal
    @test parse(LibPQ.ConninfoDisplay, "*") == LibPQ.Password
    @test parse(LibPQ.ConninfoDisplay, "D") == LibPQ.Debug
    @test_throws ErrorException parse(LibPQ.ConninfoDisplay, "N")
end

@testset "Version Numbers" begin
    valid_versions = [
        (pqv"11", v"11"),
        (pqv"11.80", v"11.0.80"),
        (pqv"10.1", v"10.0.1"),
        (pqv"9.1.5", v"9.1.5"),
        (pqv"9.2", v"9.2.0"),
        (pqv"8", v"8.0.0"),
    ]

    @testset "Valid Versions" for (pg_version, jl_version) in valid_versions
        @test pg_version == jl_version
    end

    invalid_versions = [
        "10.1.1",
        "10.0.1",
        "10.0.0.1",
        "9.0.0.1",
        "",
    ]

    # can't do cross-version macro testing apparently
    @testset "Invalid Versions" for pg_version_str in invalid_versions
        @test_throws ArgumentError LibPQ._pqv_str(pg_version_str)
    end
end

@testset "Online" begin
    const DATABASE_USER = get(ENV, "LIBPQJL_DATABASE_USER", "postgres")

    @testset "Example SELECT" begin
        conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=false)
        @test conn isa Connection
        @test isopen(conn)
        @test status(conn) == LibPQ.libpq_c.CONNECTION_OK
        @test conn.closed == false

        text_display = sprint(show, conn)
        @test contains(text_display, "dbname = postgres")
        @test contains(text_display, "user = $DATABASE_USER")

        result = execute(
            conn,
            "SELECT typname FROM pg_type WHERE oid = 16";
            throw_error=false,
        )
        @test result isa Result
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test result.cleared == false
        @test LibPQ.num_columns(result) == 1
        @test LibPQ.num_rows(result) == 1
        @test LibPQ.column_name(result, 1) == "typname"
        @test LibPQ.column_number(result, "typname") == 1

        data = Data.stream!(result, NamedTuple)

        @test data[:typname][1] == "bool"

        clear!(result)
        @test result.cleared == true

        # the same but with parameters
        result = execute(
            conn,
            "SELECT typname FROM pg_type WHERE oid = \$1",
            [16];
            throw_error=false,
        )
        @test result isa Result
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test result.cleared == false
        @test LibPQ.num_columns(result) == 1
        @test LibPQ.num_rows(result) == 1
        @test LibPQ.column_name(result, 1) == "typname"

        data = Data.stream!(result, NamedTuple)

        @test data[:typname][1] == "bool"

        clear!(result)
        @test result.cleared == true

        # the same but with fetch
        data = fetch!(NamedTuple, execute(
            conn,
            "SELECT typname FROM pg_type WHERE oid = \$1",
            [16],
        ))

        @test data[:typname][1] == "bool"

        close(conn)
        @test !isopen(conn)
        @test conn.closed == true

        text_display_closed = sprint(show, conn)
        @test contains(text_display_closed, "closed")
    end

    @testset "Example INSERT" begin
        conn = Connection("dbname=postgres user=$DATABASE_USER")

        result = execute(conn, """
            CREATE TEMPORARY TABLE libpqjl_test (
                no_nulls    varchar(10) PRIMARY KEY,
                yes_nulls   varchar(10)
            );
        """)
        @test status(result) == LibPQ.libpq_c.PGRES_COMMAND_OK
        clear!(result)

        # get the data from PostgreSQL and let DataStreams construct my NamedTuple
        result = execute(conn, """
            SELECT no_nulls, yes_nulls FROM (
                VALUES ('foo', 'bar'), ('baz', NULL)
            ) AS temp (no_nulls, yes_nulls)
            ORDER BY no_nulls DESC;
            """;
            throw_error=true,
        )
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test LibPQ.num_rows(result) == 2
        @test LibPQ.num_columns(result) == 2

        data = Data.stream!(result, NamedTuple)

        @test data[:no_nulls] == ["foo", "baz"]
        @test data[:yes_nulls][1] == "bar"
        @test data[:yes_nulls][2] === missing

        clear!(result)

        stmt = Data.stream!(
            data,
            Statement,
            conn,
            "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2);",
        )
        @test num_params(stmt) == 2
        @test num_columns(stmt) == 0  # an insert has no results
        @test column_number(stmt, "no_nulls") == 0
        @test column_names(stmt) == []

        result = execute(
            conn,
            "SELECT no_nulls, yes_nulls FROM libpqjl_test ORDER BY no_nulls DESC;";
            throw_error=true,
        )
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test LibPQ.num_rows(result) == 2
        @test LibPQ.num_columns(result) == 2

        table_data = Data.stream!(result, NamedTuple)
        @test table_data[:no_nulls] == data[:no_nulls]
        @test table_data[:yes_nulls][1] == data[:yes_nulls][1]
        @test table_data[:yes_nulls][2] === missing

        clear!(result)
        close(conn)
    end

    @testset "Connection" begin
        @testset "Version Numbers" begin
            conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            # update this test before PostgreSQL 20.0 ;)
            @test pqv"7" <= server_version(conn) <= pqv"20"
        end

        @testset "Encoding" begin
            conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            @test encoding(conn) == "UTF8"

            set_encoding!(conn, "SQL_ASCII")
            @test encoding(conn) == "SQL_ASCII"
            reset_encoding!(conn)
            @test encoding(conn) == "SQL_ASCII"

            reset!(conn)
            @test encoding(conn) == "SQL_ASCII"
            set_encoding!(conn, "UTF8")
            @test encoding(conn) == "UTF8"
            reset_encoding!(conn)
            @test encoding(conn) == "UTF8"

            conn.encoding = "SQL_ASCII"
            reset_encoding!(conn)
            @test encoding(conn) == "SQL_ASCII"

            @test_throws ErrorException set_encoding!(conn, "NOT A REAL ENCODING")

            close(conn)
        end

        @testset "Bad Connection" begin
            @testset "throw_error=false" begin
                conn = Connection("dbname=123fake"; throw_error=false)
                @test conn isa Connection
                @test status(conn) == LibPQ.libpq_c.CONNECTION_BAD
                @test conn.closed == false

                reset!(conn; throw_error=false)
                @test status(conn) == LibPQ.libpq_c.CONNECTION_BAD
                @test conn.closed == false

                close(conn)
                @test !isopen(conn)
                @test conn.closed == true
                @test_throws ErrorException reset!(conn; throw_error=false)
            end

            @testset "throw_error=true" begin
                @test_throws ErrorException Connection("dbname=123fake"; throw_error=true)

                conn = Connection("dbname=123fake"; throw_error=false)
                @test conn isa Connection
                @test status(conn) == LibPQ.libpq_c.CONNECTION_BAD
                @test conn.closed == false

                @test_throws ErrorException reset!(conn; throw_error=true)
                @test !isopen(conn)
                @test conn.closed == true
                @test_throws ErrorException reset!(conn; throw_error=true)
            end
        end
    end

    @testset "Results" begin
        @testset "Nulls" begin
            conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(conn, "SELECT NULL"; throw_error=true)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1

            data = Data.stream!(result, NamedTuple)

            @test data[1][1] === missing

            clear!(result)

            result = execute(conn, """
                SELECT no_nulls, yes_nulls FROM (
                    VALUES ('foo', 'bar'), ('baz', NULL)
                ) AS temp (no_nulls, yes_nulls)
                ORDER BY no_nulls DESC;
                """;
                throw_error=true,
            )
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_rows(result) == 2
            @test LibPQ.num_columns(result) == 2

            data = Data.stream!(result, NamedTuple)

            @test data[:no_nulls] == ["foo", "baz"]
            @test data[:yes_nulls][1] == "bar"
            @test data[:yes_nulls][2] === missing

            clear!(result)

            # NULL first this time, to check for errors that might come up with lazy
            # initialization of the output data vectors
            result = execute(conn, """
                SELECT no_nulls, yes_nulls FROM (
                    VALUES ('foo', 'bar'), ('baz', NULL)
                ) AS temp (no_nulls, yes_nulls)
                ORDER BY no_nulls ASC;
                """;
                throw_error=true,
            )
            @test result isa Result
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_rows(result) == 2
            @test LibPQ.num_columns(result) == 2

            data = Data.stream!(result, NamedTuple)

            @test data[:no_nulls] == ["baz", "foo"]
            @test data[:yes_nulls][1] === missing
            @test data[:yes_nulls][2] == "bar"

            clear!(result)
            close(conn)
        end

        @testset "Type Conversions" begin
            @testset "Automatic" begin
                conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                result = execute(conn, """
                    SELECT oid, typname, typlen, typbyval, typcategory
                    FROM pg_type
                    WHERE typname IN ('bool', 'int8', 'text')
                    ORDER BY typname;
                    """;
                    throw_error=true,
                )
                @test result isa Result
                @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
                @test LibPQ.num_rows(result) == 3
                @test LibPQ.num_columns(result) == 5
                @test LibPQ.column_types(result) == [LibPQ.Oid, String, Int16, Bool, PQChar]

                data = Data.stream!(result, NamedTuple)

                @test map(eltype, values(data)) == map(T -> Union{T, Missing}, [LibPQ.Oid, String, Int16, Bool, PQChar])
                @test data[:oid] == LibPQ.Oid[LibPQ.PQ_SYSTEM_TYPES[t] for t in (:bool, :int8, :text)]
                @test data[:typname] == ["bool", "int8", "text"]
                @test data[:typlen] == [1, 8, -1]
                @test data[:typbyval] == [true, true, false]
                @test data[:typcategory] == ['B', 'N', 'S']

                clear!(result)
                close(conn)
            end

            @testset "Parsing" begin
                conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                test_data = [
                    ("3", Cint(3)),
                    ("3::int8", Int64(3)),
                    ("3::int4", Int32(3)),
                    ("3::int2", Int16(3)),
                    ("3::float8", Float64(3)),
                    ("3::float4", Float32(3)),
                    ("3::oid", LibPQ.Oid(3)),
                    ("3::numeric", decimal("3")),
                    ("$(BigFloat(pi))::numeric", decimal(BigFloat(pi))),
                    ("$(big"4608230166434464229556241992703")::numeric", parse(Decimal, "4608230166434464229556241992703")),
                    ("E'\\\\xDEADBEEF'::bytea", hex2bytes("DEADBEEF")),
                    ("E'\\\\000'::bytea", UInt8[0o000]),
                    ("E'\\\\047'::bytea", UInt8[0o047]),
                    ("E'\\''::bytea", UInt8[0o047]),
                    ("E'\\\\134'::bytea", UInt8[0o134]),
                    ("E'\\\\\\\\'::bytea", UInt8[0o134]),
                    ("E'\\\\001'::bytea", UInt8[0o001]),
                    ("E'\\\\176'::bytea", UInt8[0o176]),
                    ("'3'::\"char\"", PQChar('3')),
                    ("'t'::bool", true),
                    ("'T'::bool", true),
                    ("'true'::bool", true),
                    ("'TRUE'::bool", true),
                    ("'tRuE'::bool", true),
                    ("'y'::bool", true),
                    ("'YEs'::bool", true),
                    ("'on'::bool", true),
                    ("1::bool", true),
                    ("true", true),
                    ("'f'::bool", false),
                    ("'F'::bool", false),
                    ("'false'::bool", false),
                    ("'FALSE'::bool", false),
                    ("'fAlsE'::bool", false),
                    ("'n'::bool", false),
                    ("'nO'::bool", false),
                    ("'off'::bool", false),
                    ("0::bool", false),
                    ("false", false),
                    ("TIMESTAMP '2004-10-19 10:23:54'", DateTime(2004, 10, 19, 10, 23, 54)),
                    ("'infinity'::timestamp", typemax(DateTime)),
                    ("'-infinity'::timestamp", typemin(DateTime)),
                    ("'epoch'::timestamp", DateTime(1970, 1, 1, 0, 0, 0)),
                    # ("TIMESTAMP WITH TIME ZONE '2004-10-19 10:23:54-00'", ZonedDateTime(2004, 10, 19, 10, 23, 54, tz"UTC")),
                    # ("TIMESTAMP WITH TIME ZONE '2004-10-19 10:23:54-02'", ZonedDateTime(2004, 10, 19, 10, 23, 54, tz"UTC-2")),
                    # ("TIMESTAMP WITH TIME ZONE '2004-10-19 10:23:54+10'", ZonedDateTime(2004, 10, 19, 10, 23, 54, tz"UTC+10")),
                    ("'infinity'::timestamptz", ZonedDateTime(typemax(DateTime), tz"UTC")),
                    ("'-infinity'::timestamptz", ZonedDateTime(typemin(DateTime), tz"UTC")),
                    # ("'epoch'::timestamptz", ZonedDateTime(1970, 1, 1, 0, 0, 0, tz"UTC")),
                    ("'{{{1,2,3},{4,5,6}}}'::int2[]", reshape(Int16[1 2 3; 4 5 6], 1, 2, 3)),
                    ("'{}'::int2[]", Int16[]),
                    ("'{{{1,2,3},{4,5,6}}}'::int4[]", reshape(Int32[1 2 3; 4 5 6], 1, 2, 3)),
                    ("'{{{1,2,3},{4,5,6}}}'::int8[]", reshape(Int64[1 2 3; 4 5 6], 1, 2, 3)),
                    ("'{{{1,2,3},{4,5,6}}}'::float4[]", reshape(Float32[1 2 3; 4 5 6], 1, 2, 3)),
                    ("'{{{1,2,3},{4,5,6}}}'::float8[]", reshape(Float64[1 2 3; 4 5 6], 1, 2, 3)),
                    ("'{{{1,2,3},{4,5,6}}}'::oid[]", reshape(LibPQ.Oid[1 2 3; 4 5 6], 1, 2, 3)),
                    ("'{{{1,2,3},{4,5,6}}}'::numeric[]", reshape(Decimal[1 2 3; 4 5 6], 1, 2, 3)),
                    ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int2[]", copy!(OffsetArray(Int16, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                    ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int4[]", copy!(OffsetArray(Int32, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                    ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int8[]", copy!(OffsetArray(Int64, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                    ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::float4[]", copy!(OffsetArray(Float32, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                    ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::float8[]", copy!(OffsetArray(Float64, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                    ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::oid[]", copy!(OffsetArray(LibPQ.Oid, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                    ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::numeric[]", copy!(OffsetArray(Decimal, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                ]

                for (test_str, data) in test_data
                    result = execute(conn, "SELECT $test_str;")

                    try
                        @test LibPQ.num_rows(result) == 1
                        @test LibPQ.num_columns(result) == 1
                        @test LibPQ.column_types(result)[1] >: typeof(data)

                        oid = LibPQ.column_oids(result)[1]
                        func = result.column_funcs[1]
                        parsed = func(LibPQ.PQValue{oid}(result, 1, 1))
                        @test parsed == data
                        @test typeof(parsed) == typeof(data)
                    finally
                        clear!(result)
                    end
                end

                close(conn)
            end
        end

        @testset "Query Errors" begin
            @testset "Syntax Errors" begin
                conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                result = execute(conn, "SELORCT NUUL;"; throw_error=false)
                @test status(result) == LibPQ.libpq_c.PGRES_FATAL_ERROR
                # We're expecting zeros per "33.3.2. Retrieving Query Result Information"
                # https://www.postgresql.org/docs/10/static/libpq-exec.html#LIBPQ-EXEC-SELECT-INFO
                @test LibPQ.num_rows(result) == 0
                @test LibPQ.num_columns(result) == 0
                clear!(result)
                @test result.cleared == true

                @test_throws ErrorException execute(conn, "SELORCT NUUL;"; throw_error=true)

                close(conn)
                @test !isopen(conn)
            end

            @testset "Wrong No. Parameters" begin
                conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                result = execute(conn, "SELORCT \$1;", String[]; throw_error=false)
                @test status(result) == LibPQ.libpq_c.PGRES_FATAL_ERROR
                # We're expecting zeros per "33.3.2. Retrieving Query Result Information"
                # https://www.postgresql.org/docs/10/static/libpq-exec.html#LIBPQ-EXEC-SELECT-INFO
                @test LibPQ.num_rows(result) == 0
                @test LibPQ.num_columns(result) == 0
                clear!(result)
                @test result.cleared == true

                @test_throws ErrorException execute(
                    conn,
                    "SELORCT \$1;",
                    String[];
                    throw_error=true,
                )

                close(conn)
                @test !isopen(conn)
            end
        end

        @testset "Interface Errors" begin
            conn = Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(
                conn,
                "SELECT typname FROM pg_type WHERE oid = \$1",
                [16],
            )
            clear!(result)
            @test_throws ErrorException fetch!(NamedTuple, result)

            close(conn)
            @test !isopen(conn)
        end
    end
end

end
