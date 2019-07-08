using LibPQ
using Test
using Dates
using DataFrames
using DataFrames: eachrow
using Decimals
using IterTools: imap
using Memento
using Memento.TestUtils
using OffsetArrays
using TimeZones
using Tables

Memento.config!("critical")

macro test_broken_on_windows(ex)
    if Sys.iswindows()
        :(@test_broken $(esc(ex)))
    else
        :(@test $(esc(ex)))
    end
end

macro test_nolog_on_windows(ex...)
    if Sys.iswindows()
        :(@test_nolog($(map(esc, ex)...)))
    else
        :(@test_log($(map(esc, ex)...)))
    end
end

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
        @test conn.closed[] == false

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

        data = columntable(result)

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

        data = columntable(result)

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

        data = columntable(result)

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

        data = columntable(result)

        @test data[:foo][1] == 1.0
        @test data[:typname][1] == "bool"

        close(result)
        @test !isopen(result)

        close(conn)
        @test !isopen(conn)
        @test conn.closed[] == true

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

        # get the data from PostgreSQL and let columntable construct my NamedTuple
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

        data = columntable(result)

        @test data[:no_nulls] == ["foo", "baz"]
        @test data[:yes_nulls][1] == "bar"
        @test data[:yes_nulls][2] === missing

        stmt = LibPQ.load!(
            data,
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

        table_data = columntable(result)
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
        table_data_after_delete = columntable(result)
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

    @testset "COPY FROM" begin
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
            table_data = DataFrame(result)
            @test isequal(table_data, data)
            close(result)

            close(conn)
        end

        @testset "Wrong column order" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")

            result = execute(conn, """
                CREATE TEMPORARY TABLE libpqjl_test (
                    pri    bigint PRIMARY KEY,
                    sec    varchar(10)
                );
            """)
            @test status(result) == LibPQ.libpq_c.PGRES_COMMAND_OK
            close(result)

            data = (pri = 1:26, sec = map(string, 'a':'z'))

            row_strings = imap(Tables.rows(data)) do row
                "$(row.sec),$(row.pri)\n"
            end

            copyin = LibPQ.CopyIn("COPY libpqjl_test FROM STDIN (FORMAT CSV);", row_strings)

            result = execute(conn, copyin; throw_error=false)
            @test isopen(result)
            @test status(result) == LibPQ.libpq_c.PGRES_FATAL_ERROR

            err_msg = LibPQ.error_message(result)
            @test occursin("ERROR", err_msg)
            if LibPQ.server_version(conn) >= v"12"
                @test occursin("invalid input syntax for type bigint", err_msg)
            else
                @test occursin("invalid input syntax for integer", err_msg)
            end

            close(result)

            result = execute(
                conn,
                "SELECT pri, sec FROM libpqjl_test ORDER BY pri ASC;";
                throw_error=true
            )
            table_data = columntable(result)
            @test isequal(table_data, (pri = Int[], sec = String[]))
            close(result)

            row_strings = imap(Tables.rows(data)) do row
                "$(row.sec),$(row.pri)\n"
            end

            copyin = LibPQ.CopyIn("COPY libpqjl_test FROM STDIN (FORMAT CSV);", row_strings)
            @test_throws ErrorException execute(conn, copyin; throw_error=true)

            close(conn)
        end
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

            @test_throws ErrorException LibPQ.Connection("dbname=123fake user=$DATABASE_USER"; throw_error=true) do jl_conn
                saved_conn = jl_conn
                @test false
            end

            @test !isopen(saved_conn)
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

            results = columntable(execute(conn, "SELECT '1 12:59:10'::interval;"))
            @test results[1][1] == "@ 1 day 12 hours 59 mins 10 secs"
            close(conn)
        end

        @testset "Time Zone" begin
            function connection_tz(conn::LibPQ.Connection)
                result = execute(conn, "SELECT current_setting('TIMEZONE');")

                tz = columntable(result)[:current_setting][1]
                close(result)
                return tz
            end

            # test with rare time zones to avoid collision with actual server time zones
            # NOTE: do not run tests in Greenland
            default_tz = LibPQ.DEFAULT_CLIENT_TIME_ZONE[]
            try
                LibPQ.DEFAULT_CLIENT_TIME_ZONE[] = "America/Scoresbysund"
                LibPQ.CONNECTION_OPTION_DEFAULTS["TimeZone"] = LibPQ.DEFAULT_CLIENT_TIME_ZONE[]
                merge!(LibPQ.CONNECTION_PARAMETER_DEFAULTS, LibPQ._connection_parameter_dict(connection_options=LibPQ.CONNECTION_OPTION_DEFAULTS))
                withenv("PGTZ" => nothing) do  # unset
                    LibPQ.Connection(
                        "dbname=postgres user=$DATABASE_USER"; throw_error=true
                    ) do conn
                        @test connection_tz(conn) == "America/Scoresbysund"
                    end

                    LibPQ.Connection(
                        "dbname=postgres user=$DATABASE_USER";
                        options=Dict("TimeZone" => "America/Danmarkshavn"),
                        throw_error=true,
                    ) do conn
                        @test connection_tz(conn) == "America/Danmarkshavn"
                    end

                    LibPQ.Connection(
                        "dbname=postgres user=$DATABASE_USER";
                        options=Dict("TimeZone" => ""),
                        throw_error=true,
                    ) do conn
                        @test connection_tz(conn) != "America/Scoresbysund"
                        @test connection_tz(conn) != "America/Danmarkshavn"
                    end
                end

                # For some reason, libpq won't pick up environment variables which are set
                # after it has been loaded. This seems to happen with Julia only; psycopg2
                # does not have this problem. Perhaps we need to set some dlopen option?
                withenv("PGTZ" => "America/Thule") do
                    LibPQ.Connection(
                        "dbname=postgres user=$DATABASE_USER"; throw_error=true
                    ) do conn
                        @test_broken_on_windows connection_tz(conn) == "America/Thule"
                    end

                    LibPQ.Connection(
                        "dbname=postgres user=$DATABASE_USER";
                        options=Dict("TimeZone" => "America/Danmarkshavn"),
                        throw_error=true,
                    ) do conn
                        @test_broken_on_windows connection_tz(conn) == "America/Thule"
                    end

                    LibPQ.Connection(
                        "dbname=postgres user=$DATABASE_USER";
                        options=Dict("TimeZone" => ""),
                        throw_error=true,
                    ) do conn
                        @test_broken_on_windows connection_tz(conn) == "America/Thule"
                    end
                end

                withenv("PGTZ" => "") do
                    @test_nolog_on_windows LibPQ.LOGGER "error" "invalid value for parameter" try
                        LibPQ.Connection(
                            "dbname=postgres user=$DATABASE_USER"; throw_error=true
                        )
                    catch
                    end

                    @test_nolog_on_windows LibPQ.LOGGER "error" "invalid value for parameter" try
                        LibPQ.Connection(
                            "dbname=postgres user=$DATABASE_USER";
                            options=Dict("TimeZone" => "America/Danmarkshavn"),
                            throw_error=true,
                        )
                    catch
                    end

                    @test_nolog_on_windows LibPQ.LOGGER "error" "invalid value for parameter" try
                        LibPQ.Connection(
                            "dbname=postgres user=$DATABASE_USER";
                            options=Dict("TimeZone" => ""),
                            throw_error=true,
                        )
                    catch
                    end
                end
            finally
                LibPQ.DEFAULT_CLIENT_TIME_ZONE[] = default_tz
                LibPQ.CONNECTION_OPTION_DEFAULTS["TimeZone"] = LibPQ.DEFAULT_CLIENT_TIME_ZONE[]
                merge!(LibPQ.CONNECTION_PARAMETER_DEFAULTS, LibPQ._connection_parameter_dict(connection_options=LibPQ.CONNECTION_OPTION_DEFAULTS))
            end
        end

        @testset "Finalizer" begin
            closed_flags = map(1:50) do _
                conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")
                closed = conn.closed
                finalize(conn)
                return closed
            end

            sleep(1)

            @test all(closed -> closed[], closed_flags)

            # with Results, which don't hold a reference to Connection
            results = LibPQ.Result[]

            closed_flags = map(1:50) do _
                conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")
                push!(results, execute(conn, "SELECT 1;"))
                return conn.closed
            end

            GC.gc()
            sleep(1)
            GC.gc()
            sleep(1)

            @test all(closed -> closed[], closed_flags)
            @test all(result -> LibPQ.num_rows(result) == 1, results)

            # with AsyncResults, which hold a reference to Connection
            closed_flags = asyncmap(1:50) do _
                conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")
                wait(async_execute(conn, "SELECT pg_sleep(1);"))
                return conn.closed
            end

            GC.gc()
            sleep(1)
            GC.gc()
            sleep(1)

            @test all(closed -> closed[], closed_flags)
        end

        @testset "Bad Connection" begin
            @testset "throw_error=false" begin
                conn = LibPQ.Connection("dbname=123fake user=$DATABASE_USER"; throw_error=false)
                @test conn isa LibPQ.Connection
                @test status(conn) == LibPQ.libpq_c.CONNECTION_BAD
                @test isopen(conn)

                reset!(conn; throw_error=false)
                @test status(conn) == LibPQ.libpq_c.CONNECTION_BAD
                @test isopen(conn)

                close(conn)
                @test !isopen(conn)
                @test conn.closed[] == true
                @test_throws ErrorException reset!(conn; throw_error=false)
            end

            @testset "throw_error=true" begin
                @test_throws ErrorException LibPQ.Connection("dbname=123fake user=$DATABASE_USER"; throw_error=true)

                conn = LibPQ.Connection("dbname=123fake user=$DATABASE_USER"; throw_error=false)
                @test conn isa LibPQ.Connection
                @test status(conn) == LibPQ.libpq_c.CONNECTION_BAD
                @test isopen(conn)

                @test_throws ErrorException reset!(conn; throw_error=true)
                @test !isopen(conn)
                @test conn.closed[] == true
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

            data = columntable(result)

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

            data = columntable(result)

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

            data = columntable(result)

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

            data = columntable(result)

            @test data[1][1] === missing

            close(result)

            result = execute(conn, "SELECT NULL"; not_null=true, throw_error=true)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1

            @test_throws MethodError columntable(result)[1][1]

            close(result)

            result = execute(conn, "SELECT NULL"; not_null=[true], throw_error=true)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1

            @test_throws MethodError columntable(result)[1][1]

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

            data = columntable(result)

            @test data[:no_nulls] == ["foo", "baz"]
            @test data[:no_nulls] isa AbstractVector{String}
            @test data[:yes_nulls][1] == "bar"
            @test data[:yes_nulls][2] === missing
            @test data[:yes_nulls] isa AbstractVector{Union{String, Missing}}

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

            data = columntable(result)

            @test data[:no_nulls] == ["foo", "baz"]
            @test data[:no_nulls] isa AbstractVector{Union{String, Missing}}
            @test data[:yes_nulls][1] == "bar"
            @test data[:yes_nulls][2] === missing
            @test data[:yes_nulls] isa AbstractVector{Union{String, Missing}}

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
            @test data[1][1] == "foo"
            @test data[2].no_nulls == "baz"
            @test data[2][1] == "baz"
            @test data[1].yes_nulls == "bar"
            @test data[1][2] == "bar"
            @test data[2].yes_nulls === missing
            @test data[2][2] === missing

            # columns
            ct = Tables.columns(result)
            no_nulls = collect(ct.no_nulls)
            @test no_nulls == ["foo", "baz"]
            yes_nulls = collect(ct.yes_nulls)
            @test isequal(yes_nulls, ["bar", missing])

            collected = map(collect, Tables.columns(result))
            @test collected isa AbstractVector{<:AbstractVector{Union{String, Missing}}}
            @test collected isa Vector{Vector{Union{String, Missing}}}
            @test collected[1] == ["foo", "baz"]
            @test isequal(collected[2], ["bar", missing])

            close(result)
            close(conn)
        end

        @testset "Duplicate names" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            result = execute(conn, "SELECT 1 AS col, 2 AS col;", not_null=true, throw_error=true)
            columns = Tables.columns(result)
            @test columns[1] == [1]
            @test columns[2] == [2]

            row = first(Tables.rows(result))
            @test row[1] == 1
            @test row[2] == 2

            close(result)
            close(conn)
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

                data = columntable(result)

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

            @testset "Overrides" begin
                conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

                result = execute(conn, "SELECT 4::bigint;")
                @test first(first(result)) === Int64(4)

                result = execute(conn, "SELECT 4::bigint;", type_map=Dict("int8"=>UInt8))
                @test first(first(result)) === 0x4

                result = execute(conn, "SELECT 'deadbeef';")
                @test first(first(result)) == "deadbeef"

                result = execute(
                    conn,
                    "SELECT 'deadbeef'::text;",  # unknown type on PostgreSQL < 10
                    type_map=Dict(:text=>Vector{UInt8}),
                    conversions=Dict((:text, Vector{UInt8})=>hex2bytes∘LibPQ.string_view),
                )
                @test first(first(result)) == [0xde, 0xad, 0xbe, 0xef]

                result = execute(
                    conn,
                    "SELECT '0xdeadbeef'::text;",
                    type_map=Dict(:text=>String),
                    column_types=[UInt32],
                )
                @test first(first(result)) == 0xdeadbeef

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
                        ("'{{{1,2,3},{4,5,6}}}'::int2[]", Array{Union{Int16, Missing}}(reshape(Int16[1 2 3; 4 5 6], 1, 2, 3))),
                        ("'{}'::int2[]", Union{Missing, Int16}[]),
                        ("'{{{1,2,3},{4,5,6}}}'::int4[]", Array{Union{Int32, Missing}}(reshape(Int32[1 2 3; 4 5 6], 1, 2, 3))),
                        ("'{{{1,2,3},{4,5,6}}}'::int8[]", Array{Union{Int64, Missing}}(reshape(Int64[1 2 3; 4 5 6], 1, 2, 3))),
                        ("'{{{NULL,2,3},{4,NULL,6}}}'::int8[]", Array{Union{Int64, Missing}}(reshape(Union{Int64, Missing}[missing 2 3; 4 missing 6], 1, 2, 3))),
                        ("'{{{1,2,3},{4,5,6}}}'::float4[]", Array{Union{Float32, Missing}}(reshape(Float32[1 2 3; 4 5 6], 1, 2, 3))),
                        ("'{{{1,2,3},{4,5,6}}}'::float8[]", Array{Union{Float64, Missing}}(reshape(Float64[1 2 3; 4 5 6], 1, 2, 3))),
                        ("'{{{NULL,2,3},{4,NULL,6}}}'::float8[]", Array{Union{Float64, Missing}}(reshape(Union{Float64, Missing}[missing 2 3; 4 missing 6], 1, 2, 3))),
                        ("'{{{1,2,3},{4,5,6}}}'::oid[]", Array{Union{LibPQ.Oid, Missing}}(reshape(LibPQ.Oid[1 2 3; 4 5 6], 1, 2, 3))),
                        ("'{{{1,2,3},{4,5,6}}}'::numeric[]", Array{Union{Decimal, Missing}}(reshape(Decimal[1 2 3; 4 5 6], 1, 2, 3))),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int2[]", copyto!(OffsetArray{Union{Missing, Int16}}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int4[]", copyto!(OffsetArray{Union{Missing, Int32}}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::int8[]", copyto!(OffsetArray{Union{Missing, Int64}}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::float4[]", copyto!(OffsetArray{Union{Missing, Float32}}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::float8[]", copyto!(OffsetArray{Union{Missing, Float64}}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::oid[]", copyto!(OffsetArray{Union{Missing, LibPQ.Oid}}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
                        ("'[1:1][-2:-1][3:5]={{{1,2,3},{4,5,6}}}'::numeric[]", copyto!(OffsetArray{Union{Missing, Decimal}}(undef, 1:1, -2:-1, 3:5), [1 2 3; 4 5 6])),
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
                            @test isequal(parsed, data)
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
                        ("'{{{1,2,3},{4,5,6}}}'::int2[]", AbstractArray{Int16}, reshape(Int16[1 2 3; 4 5 6], 1, 2, 3))
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
            @test first(first(result))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", (["bar", "foo"],))
            @test first(first(result))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", [Any["bar", "foo"]])
            @test first(first(result))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", Any[Any["bar", "foo"]])
            @test first(first(result))
            close(result)

            result = execute(conn, "SELECT 'foo' = ANY(\$1)", [["bar", "foobar"]])
            @test !first(first(result))
            close(result)

            result = execute(conn, "SELECT ARRAY[1, 2] = \$1", [[1, 2]])
            @test first(first(result))
            close(result)

            result = execute(conn, "SELECT ARRAY[1, 2] = \$1", Any[Any[1, 2]])
            @test first(first(result))
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
            @test_throws BoundsError columntable(result)

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

            data = columntable(result)
            @test data[:oid][1] == 16
            @test data[:typname][1] == "bool"

            close(result)

            close(conn)
        end
    end

    @testset "AsyncResults" begin
        trywait(ar::LibPQ.AsyncResult) = (try wait(ar) catch end; nothing)

        @testset "Basic" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            ar = async_execute(conn, "SELECT pg_sleep(2);"; throw_error=false)
            yield()
            @test !isready(ar)
            @test !LibPQ.iserror(ar)
            @test conn.async_result === ar

            wait(ar)
            @test isready(ar)
            @test !LibPQ.iserror(ar)
            @test conn.async_result === nothing

            result = fetch(ar)
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test LibPQ.column_name(result, 1) == "pg_sleep"

            close(result)
            close(conn)
        end

        @testset "Parameters" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            ar = async_execute(
                conn,
                "SELECT typname FROM pg_type WHERE oid = \$1",
                [16];
                throw_error=false,
            )

            wait(ar)
            @test isready(ar)
            @test !LibPQ.iserror(ar)
            @test conn.async_result === nothing

            result = fetch(ar)
            @test result isa LibPQ.Result
            @test status(result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test isopen(result)
            @test LibPQ.num_columns(result) == 1
            @test LibPQ.num_rows(result) == 1
            @test LibPQ.column_name(result, 1) == "typname"

            data = columntable(result)

            @test data[:typname][1] == "bool"

            close(result)
            close(conn)
        end

        # Ensures queries wait for previous query completion before starting
        @testset "Wait in line to complete" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            first_ar = async_execute(conn, "SELECT pg_sleep(4);")
            yield()
            second_ar = async_execute(conn, "SELECT pg_sleep(2);")
            @test !isready(first_ar)
            @test !isready(second_ar)

            # wait(first_ar)  # this is needed if I use @par for some reason
            second_result = fetch(second_ar)
            @test isready(first_ar)
            @test isready(second_ar)
            @test !LibPQ.iserror(first_ar)
            @test !LibPQ.iserror(second_ar)
            @test status(second_result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test conn.async_result === nothing

            first_result = fetch(first_ar)
            @test isready(first_ar)
            @test !LibPQ.iserror(first_ar)
            @test status(second_result) == LibPQ.libpq_c.PGRES_TUPLES_OK
            @test conn.async_result === nothing

            close(second_result)
            close(first_result)
            close(conn)
        end

        @testset "Cancel" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            # final query needs to be one that actually does something
            # on Windows, first query also needs to do something
            ar = async_execute(
                conn,
                "SELECT * FROM pg_opclass; SELECT pg_sleep(3); SELECT * FROM pg_type;",
            )
            yield()
            @test !isready(ar)
            @test !LibPQ.iserror(ar)
            @test conn.async_result === ar

            cancel(ar)
            trywait(ar)
            @test isready(ar)
            @test LibPQ.iserror(ar)
            @test conn.async_result === nothing

            local err_msg = ""
            try
                wait(ar)
            catch e
                err_msg = sprint(showerror, e)
            end

            @test occursin("canceling statement due to user request", err_msg)

            close(conn)
        end

        @testset "Canceled by closing connection" begin
            conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER"; throw_error=true)

            # final query needs to be one that actually does something
            # on Windows, first query also needs to do something
            ar = async_execute(
                conn,
                "SELECT * FROM pg_opclass; SELECT pg_sleep(3); SELECT * FROM pg_type;",
            )
            yield()
            @test !isready(ar)
            @test !LibPQ.iserror(ar)
            @test conn.async_result === ar

            close(conn)
            trywait(ar)
            @test isready(ar)
            @test LibPQ.iserror(ar)
            @test conn.async_result === nothing

            local err_msg = ""
            try
                wait(ar)
            catch e
                err_msg = sprint(showerror, e)
            end

            @test occursin("canceling statement due to user request", err_msg)
        end
    end
end

end
