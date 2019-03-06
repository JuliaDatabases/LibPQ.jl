using LibPQ
using Test
using Dates
using DataFrames
using DataFrames: eachrow
using DataStreams
using Decimals
using IterTools: imap
using Memento
using OffsetArrays
using TimeZones
using Tables

Memento.config!("critical")

@testset "LibPQ" begin

@testset "ConninfoDisplay" begin
    @test parse(LibPQ.ConninfoDisplay, "") == LibPQ.Normal
    @test parse(LibPQ.ConninfoDisplay, "*") == LibPQ.Password
    @test parse(LibPQ.ConninfoDisplay, "D") == LibPQ.Debug
    @test_throws ErrorException parse(LibPQ.ConninfoDisplay, "N")
end

@testset "Version Numbers" begin
    valid_versions = [
        (LibPQ.pqv"11", v"11"),
        (LibPQ.pqv"11.80", v"11.0.80"),
        (LibPQ.pqv"10.1", v"10.0.1"),
        (LibPQ.pqv"9.1.5", v"9.1.5"),
        (LibPQ.pqv"9.2", v"9.2.0"),
        (LibPQ.pqv"8", v"8.0.0"),
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
    DATABASE_USER = get(ENV, "LIBPQJL_DATABASE_USER", "postgres")

    @testset "Example SELECT" begin
        conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=false)
        @test conn isa LibPQ.Connection
        @test isopen(conn)
        @test status(conn) == LibPQ.libpq_c.CONNECTION_OK
        @test conn.closed == false

        text_display = sprint(show, conn)
        @test occursin("dbname = postgres", text_display)
        @test occursin("user = $DATABASE_USER", text_display)

        result = execute(
            conn,
            "SELECT typname FROM pg_type WHERE oid = 16";
            throw_error=false,
        )
        @test result isa LibPQ.Result
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test isopen(result)
        @test LibPQ.num_columns(result) == 1
        @test LibPQ.num_rows(result) == 1
        @test LibPQ.column_name(result, 1) == "typname"
        @test LibPQ.column_number(result, "typname") == 1

        data = Data.stream!(result, NamedTuple)

        @test data[:typname][1] == "bool"

        close(result)
        @test !isopen(result)

        # the same but with parameters
        result = execute(
            conn,
            "SELECT typname FROM pg_type WHERE oid = \$1",
            [16];
            throw_error=false,
        )
        @test result isa LibPQ.Result
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test isopen(result)
        @test LibPQ.num_columns(result) == 1
        @test LibPQ.num_rows(result) == 1
        @test LibPQ.column_name(result, 1) == "typname"

        data = Data.stream!(result, NamedTuple)

        @test data[:typname][1] == "bool"

        close(result)
        @test !isopen(result)

        # the same but with tuple parameters

        qstr = "SELECT \$1::double precision as foo, typname FROM pg_type WHERE oid = \$2"
        stmt = prepare(conn, qstr)

        result = execute(
            conn,
            qstr,
            (1.0, 16);
            throw_error=false,
        )
        @test result isa LibPQ.Result
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test isopen(result)
        @test LibPQ.num_columns(result) == 2
        @test LibPQ.num_rows(result) == 1
        @test LibPQ.column_name(result, 1) == "foo"
        @test LibPQ.column_name(result, 2) == "typname"

        data = Data.stream!(result, NamedTuple)

        @test data[:foo][1] == 1.0
        @test data[:typname][1] == "bool"

        close(result)
        @test !isopen(result)

        result = execute(
            stmt,
            (1.0, 16);
            throw_error=false,
        )
        @test result isa LibPQ.Result
        @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
        @test isopen(result)
        @test LibPQ.num_columns(result) == 2
        @test LibPQ.num_rows(result) == 1
        @test LibPQ.column_name(result, 1) == "foo"
        @test LibPQ.column_name(result, 2) == "typname"

        data = Data.stream!(result, NamedTuple)

        @test data[:foo][1] == 1.0
        @test data[:typname][1] == "bool"

        close(result)
        @test !isopen(result)


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
        @test occursin("closed", text_display_closed)
    end

    @testset "Example INSERT and DELETE" begin
        conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")

        result = execute(conn, """
            CREATE TEMPORARY TABLE libpqjl_test (
                no_nulls    varchar(10) PRIMARY KEY,
                yes_nulls   varchar(10)
            );
        """)
        @test status(result) == LibPQ.libpq_c.PGRES_COMMAND_OK
        close(result)

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

        close(result)

        stmt = Data.stream!(
            data,
            LibPQ.Statement,
            conn,
            "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2);",
        )
        @test_throws ArgumentError num_affected_rows(stmt.description)
        @test num_params(stmt) == 2
        @test num_columns(stmt) == 0  # an insert has no results
        @test LibPQ.column_number(stmt, "no_nulls") == 0
        @test LibPQ.column_names(stmt) == []

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

        close(result)

        result = execute(
            conn,
            "DELETE FROM libpqjl_test WHERE no_nulls = 'foo';";
            throw_error=true,
        )
        @test status(result) == LibPQ.libpq_c.PGRES_COMMAND_OK
        @test num_rows(result) == 0
        @test num_affected_rows(result) == 1

        close(result)

        result = execute(
            conn,
            "SELECT no_nulls, yes_nulls FROM libpqjl_test ORDER BY no_nulls DESC;";
            throw_error=true,
        )
        table_data_after_delete = Data.stream!(result, NamedTuple)
        @test table_data_after_delete[:no_nulls] == ["baz"]
        @test table_data_after_delete[:yes_nulls][1] === missing

        close(result)

        result = execute(
            conn,
            "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2), (\$3, \$4);",
            Union{String, Missing}["foo", "bar", "quz", missing],

        )
        @test status(result) == LibPQ.libpq_c.PGRES_COMMAND_OK
        @test num_rows(result) == 0
        @test num_affected_rows(result) == 2

        close(result)

        close(conn)
    end

    @testset "Example COPY FROM" begin
        conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")

        result = execute(conn, """
            CREATE TEMPORARY TABLE libpqjl_test (
                no_nulls    varchar(10) PRIMARY KEY,
                yes_nulls   varchar(10)
            );
        """)
        @test status(result) == LibPQ.libpq_c.PGRES_COMMAND_OK
        close(result)

        no_nulls = map(string, 'a':'z')
        yes_nulls = Union{String, Missing}[isodd(Int(c)) ? string(c) : missing for c in 'a':'z']
        data = DataFrame(no_nulls=no_nulls, yes_nulls=yes_nulls)

        row_strings = imap(eachrow(data)) do row
            if ismissing(row[:yes_nulls])
                "$(row[:no_nulls]),\n"
            else
                "$(row[:no_nulls]),$(row[:yes_nulls])\n"
            end
        end

        copyin = LibPQ.CopyIn("COPY libpqjl_test FROM STDIN (FORMAT CSV);", row_strings)

        result = execute(conn, copyin)
        @test isopen(result)
        @test status(result) == LibPQ.libpq_c.PGRES_COMMAND_OK
        @test isempty(LibPQ.error_message(result))
        close(result)

        result = execute(
            conn,
            "SELECT no_nulls, yes_nulls FROM libpqjl_test ORDER BY no_nulls ASC;";
            throw_error=true
        )
        table_data = Data.close!(Data.stream!(result, DataFrame))
        @test isequal(table_data, data)
        close(result)

        close(conn)
    end

    @testset "LibPQ.Connection" begin
        @testset "do" begin
            local saved_conn

            was_open = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true) do jl_conn
                saved_conn = jl_conn
                return isopen(jl_conn)
            end

            @test was_open
            @test !isopen(saved_conn)

            @test_throws ErrorException LibPQ.Connection("dbname=123fake"; throw_error=true) do jl_conn
                @test false
            end
        end

        @testset "Version Numbers" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            # update this test before PostgreSQL 20.0 ;)
            @test LibPQ.pqv"7" <= LibPQ.server_version(conn) <= LibPQ.pqv"20"
        end

        @testset "Encoding" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            @test LibPQ.encoding(conn) == "UTF8"

            LibPQ.set_encoding!(conn, "SQL_ASCII")
            @test LibPQ.encoding(conn) == "SQL_ASCII"
            LibPQ.reset_encoding!(conn)
            @test LibPQ.encoding(conn) == "SQL_ASCII"

            reset!(conn)
            @test LibPQ.encoding(conn) == "SQL_ASCII"
            LibPQ.set_encoding!(conn, "UTF8")
            @test LibPQ.encoding(conn) == "UTF8"
            LibPQ.reset_encoding!(conn)
            @test LibPQ.encoding(conn) == "UTF8"

            conn.encoding = "SQL_ASCII"
            LibPQ.reset_encoding!(conn)
            @test LibPQ.encoding(conn) == "SQL_ASCII"

            @test_throws ErrorException LibPQ.set_encoding!(conn, "NOT A REAL ENCODING")

            close(conn)
        end

        @testset "Options" begin
            conn = LibPQ.Connection(
                "dbname=postgres user=$DATABASE_USER";
                options=Dict("IntervalStyle" => "postgres_verbose"),
                throw_error=true,
            )

            conn_info = LibPQ.conninfo(conn)
            options = first(filter(conn_info) do conn_opt
                conn_opt.keyword == "options"
            end)
            @test occursin("IntervalStyle=postgres_verbose", options.val)

            results = fetch!(NamedTuple, execute(conn, "SELECT '1 12:59:10'::interval;"))
            @test results[1][1] == "@ 1 day 12 hours 59 mins 10 secs"
            close(conn)
        end

        @testset "Bad Connection" begin
            @testset "throw_error=false" begin
                conn = LibPQ.Connection("dbname=123fake"; throw_error=false)
                @test conn isa LibPQ.Connection
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
                @test_throws ErrorException LibPQ.Connection("dbname=123fake"; throw_error=true)

                conn = LibPQ.Connection("dbname=123fake"; throw_error=false)
                @test conn isa LibPQ.Connection
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
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(conn, "SELECT NULL"; throw_error=true)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1

            data = Data.stream!(result, NamedTuple)

            @test data[1][1] === missing

            close(result)

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

            close(result)

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
            @test result isa LibPQ.Result
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_rows(result) == 2
            @test LibPQ.num_columns(result) == 2

            data = Data.stream!(result, NamedTuple)

            @test data[:no_nulls] == ["baz", "foo"]
            @test data[:yes_nulls][1] === missing
            @test data[:yes_nulls][2] == "bar"

            close(result)

             # Verify that Connection is treated as a scalar during broadcast
            commands = [
                """
                SELECT no_nulls, yes_nulls FROM (
                    VALUES ('foo', 'bar'), ('baz', NULL)
                ) AS temp (no_nulls, yes_nulls)
                ORDER BY no_nulls ASC;
                """,
                """
                SELECT no_nulls, yes_nulls FROM (
                    VALUES ('foo', 'bar'), ('baz', NULL)
                ) AS temp (no_nulls, yes_nulls)
                ORDER BY no_nulls DESC;
                """,
            ]
            results = execute.(conn, commands; throw_error=true)
            for result in results
                @test result isa LibPQ.Result
                @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
                @test LibPQ.num_rows(result) == 2
                @test LibPQ.num_columns(result) == 2
                close(result)
            end

            close(conn)
        end

        @testset "Not Nulls" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(conn, "SELECT NULL"; not_null=[false], throw_error=true)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1

            data = Data.stream!(result, NamedTuple)

            @test data[1][1] === missing

            close(result)

            result = execute(conn, "SELECT NULL"; not_null=true, throw_error=true)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1

            @test_throws ErrorException Data.stream!(result, NamedTuple)

            close(result)

            result = execute(conn, "SELECT NULL"; not_null=[true], throw_error=true)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1

            @test_throws ErrorException Data.stream!(result, NamedTuple)

            close(result)

            result = execute(conn, """
                SELECT no_nulls, yes_nulls FROM (
                    VALUES ('foo', 'bar'), ('baz', NULL)
                ) AS temp (no_nulls, yes_nulls)
                ORDER BY no_nulls DESC;
                """;
                not_null=[true, false],
                throw_error=true,
            )
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_rows(result) == 2
            @test LibPQ.num_columns(result) == 2

            data = Data.stream!(result, NamedTuple)

            @test data[:no_nulls] == ["foo", "baz"]
            @test data[:no_nulls] isa Vector{String}
            @test data[:yes_nulls][1] == "bar"
            @test data[:yes_nulls][2] === missing
            @test data[:yes_nulls] isa Vector{Union{String, Missing}}

            close(result)

            result = execute(conn, """
                SELECT no_nulls, yes_nulls FROM (
                    VALUES ('foo', 'bar'), ('baz', NULL)
                ) AS temp (no_nulls, yes_nulls)
                ORDER BY no_nulls DESC;
                """;
                not_null=false,
                throw_error=true,
            )
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_rows(result) == 2
            @test LibPQ.num_columns(result) == 2

            data = Data.stream!(result, NamedTuple)

            @test data[:no_nulls] == ["foo", "baz"]
            @test data[:no_nulls] isa Vector{Union{String, Missing}}
            @test data[:yes_nulls][1] == "bar"
            @test data[:yes_nulls][2] === missing
            @test data[:yes_nulls] isa Vector{Union{String, Missing}}

            close(result)
        end

        @testset "Tables.jl" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(conn, """
                SELECT no_nulls, yes_nulls FROM (
                    VALUES ('foo', 'bar'), ('baz', NULL)
                ) AS temp (no_nulls, yes_nulls)
                ORDER BY no_nulls DESC;
                """;
                not_null=false,
                throw_error=true,
            )

            # rows
            rt = Tables.rows(result)
            data = collect(rt)
            @test data[1].no_nulls == "foo"
            @test data[2].no_nulls == "baz"
            @test data[1].yes_nulls == "bar"
            @test data[2].yes_nulls === missing

            ct = Tables.columns(result)
            no_nulls = collect(ct.no_nulls)
            @test no_nulls == ["foo", "baz"]
            yes_nulls = collect(ct.yes_nulls)
            @test isequal(yes_nulls, ["bar", missing])
        end

        @testset "Type Conversions" begin
            @testset "Automatic" begin
                conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                result = execute(conn, """
                    SELECT oid, typname, typlen, typbyval, typcategory
                    FROM pg_type
                    WHERE typname IN ('bool', 'int8', 'text')
                    ORDER BY typname;
                    """;
                    throw_error=true,
                )
                @test result isa LibPQ.Result
                @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
                @test LibPQ.num_rows(result) == 3
                @test LibPQ.num_columns(result) == 5
                @test LibPQ.column_types(result) == [LibPQ.Oid, String, Int16, Bool, LibPQ.PQChar]

                data = Data.stream!(result, NamedTuple)

                @test map(eltype, collect(values(data))) ==
                    map(T -> Union{T, Missing}, [LibPQ.Oid, String, Int16, Bool, LibPQ.PQChar])
                @test data[:oid] == LibPQ.Oid[LibPQ.PQ_SYSTEM_TYPES[t] for t in (:bool, :int8, :text)]
                @test data[:typname] == ["bool", "int8", "text"]
                @test data[:typlen] == [1, 8, -1]
                @test data[:typbyval] == [true, true, false]
                @test data[:typcategory] == ['B', 'N', 'S']

                close(result)
                close(conn)
            end

            @testset "Parsing" begin
                @testset "Default Types" begin
                    conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

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
                        ("'hello'::char(10)", "hello"),
                        ("'3'::\"char\"", LibPQ.PQChar('3')),
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
                        ("TIMESTAMP '2004-10-19 10:23:54.123'", DateTime(2004, 10, 19, 10, 23, 54,123)),
                        ("TIMESTAMP '2004-10-19 10:23:54.1234'", DateTime(2004, 10, 19, 10, 23, 54,123)),
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
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int2[]", copyto!(OffsetArray{Int16}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int4[]", copyto!(OffsetArray{Int32}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int8[]", copyto!(OffsetArray{Int64}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::float4[]", copyto!(OffsetArray{Float32}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::float8[]", copyto!(OffsetArray{Float64}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::oid[]", copyto!(OffsetArray{LibPQ.Oid}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::numeric[]", copyto!(OffsetArray{Decimal}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
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
                            close(result)
                        end
                    end

                    close(conn)
                end

                @testset "Specified Types" begin
                    conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                    test_data = [
                        ("3", UInt, UInt(3)),
                        ("3::int8", UInt16, UInt16(3)),
                        ("3::int4", Int32, Int32(3)),
                        ("3::int2", UInt8, UInt8(3)),
                        ("3::oid", UInt32, UInt32(3)),
                        ("3::numeric", Float64, 3.0),
                        ("'3'::\"char\"", Char, '3'),
                        ("'foobar'", Symbol, :foobar),
                        ("0::int8", DateTime, DateTime(1970, 1, 1, 0)),
                        ("0::int8", ZonedDateTime, ZonedDateTime(1970, 1, 1, 0, tz"UTC")),
                    ]

                    for (test_str, typ, data) in test_data
                        result = execute(
                            conn,
                            "SELECT $test_str;",
                            column_types=Dict(1 => typ),
                        )

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
                            close(result)
                        end
                    end

                    close(conn)
                end
            end
        end

        @testset "Parameters" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", [["bar", "foo"]])
            @test first(first(Tables.columns(result)))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", (["bar", "foo"],))
            @test first(first(Tables.columns(result)))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", [Any["bar", "foo"]])
            @test first(first(Tables.columns(result)))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", Any[Any["bar", "foo"]])
            @test first(first(Tables.columns(result)))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", [["bar", "foobar"]])
            @test !first(first(Tables.columns(result)))
            close(result)

            result = execute(conn, "SELECT ARRAY[1, 2] = \$1", [[1, 2]])
            @test first(first(Tables.columns(result)))
            close(result)

            result = execute(conn, "SELECT ARRAY[1, 2] = \$1", Any[Any[1, 2]])
            @test first(first(Tables.columns(result)))
            close(result)

            close(conn)
        end

        @testset "Query Errors" begin
            @testset "Syntax Errors" begin
                conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                result = execute(conn, "SELORCT NUUL;"; throw_error=false)
                @test status(result) == LibPQ.libpq_c.PGRES_FATAL_ERROR
                # We're expecting zeros per "33.3.2. Retrieving Query Result Information"
                # https://www.postgresql.org/docs/10/static/libpq-exec.html#LIBPQ-EXEC-SELECT-INFO
                @test LibPQ.num_rows(result) == 0
                @test LibPQ.num_columns(result) == 0
                close(result)
                @test !isopen(result)

                @test_throws ErrorException execute(conn, "SELORCT NUUL;"; throw_error=true)

                close(conn)
                @test !isopen(conn)
            end

            @testset "Wrong No. Parameters" begin
                conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                result = execute(conn, "SELORCT \$1;", String[]; throw_error=false)
                @test status(result) == LibPQ.libpq_c.PGRES_FATAL_ERROR
                # We're expecting zeros per "33.3.2. Retrieving Query Result Information"
                # https://www.postgresql.org/docs/10/static/libpq-exec.html#LIBPQ-EXEC-SELECT-INFO
                @test LibPQ.num_rows(result) == 0
                @test LibPQ.num_columns(result) == 0
                close(result)
                @test !isopen(result)

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
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(
                conn,
                "SELECT typname FROM pg_type WHERE oid = \$1",
                [16],
            )
            close(result)
            @test_throws ErrorException fetch!(NamedTuple, result)

            close(conn)
            @test !isopen(conn)
        end
    end

    @testset "Statements" begin
        @testset "No Params, Output" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            stmt = prepare(conn, "SELECT oid, typname FROM pg_type")

            @test LibPQ.num_columns(stmt) == 2
            @test LibPQ.num_params(stmt) == 0
            @test LibPQ.column_names(stmt) == ["oid", "typname"]

            result = execute(stmt; throw_error=true)

            @test LibPQ.num_columns(result) == 2
            @test LibPQ.column_names(result) == ["oid", "typname"]
            @test LibPQ.column_types(result) == [LibPQ.Oid, String]
            @test LibPQ.num_rows(result) > 0

            close(result)

            close(conn)
        end

        @testset "Params, Output" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            stmt = prepare(conn, "SELECT oid, typname FROM pg_type WHERE oid = \$1")

            @test LibPQ.num_columns(stmt) == 2
            @test LibPQ.num_params(stmt) == 1
            @test LibPQ.column_names(stmt) == ["oid", "typname"]

            result = execute(stmt, [16]; throw_error=true)

            @test LibPQ.num_columns(result) == 2
            @test LibPQ.column_names(result) == ["oid", "typname"]
            @test LibPQ.column_types(result) == [LibPQ.Oid, String]
            @test LibPQ.num_rows(result) == 1

            data = fetch!(NamedTuple, result)
            @test data[:oid][1] == 16
            @test data[:typname][1] == "bool"

            close(result)

            close(conn)
        end
    end
end

end
