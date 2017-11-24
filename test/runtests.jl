using LibPQ
using Base.Test
using TestSetExtensions

using DataStreams
using NamedTuples
using Nulls


@testset ExtendedTestSet "LibPQ" begin

@testset "ConninfoDisplay" begin
    @test parse(LibPQ.ConninfoDisplay, "") == LibPQ.Normal
    @test parse(LibPQ.ConninfoDisplay, "*") == LibPQ.Password
    @test parse(LibPQ.ConninfoDisplay, "D") == LibPQ.Debug
    @test_throws ErrorException parse(LibPQ.ConninfoDisplay, "N")
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
            ["16"];
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
        @test data[:yes_nulls][2] === null

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
        @test column_names(stmt) == String[]

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
        @test table_data[:yes_nulls][2] === null

        clear!(result)
        close(conn)
    end

    @testset "Connection" begin
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

            @test isnull(data[1][1])

            clear!(result)
            @test result.cleared == true

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
            @test isnull(data[:yes_nulls][2])

            clear!(result)
            @test result.cleared == true

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
            @test isnull(data[:yes_nulls][1])
            @test data[:yes_nulls][2] == "bar"

            clear!(result)
            @test result.cleared == true

            close(conn)
            @test !isopen(conn)
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
    end
end

end
