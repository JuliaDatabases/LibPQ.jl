# LibPQ

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://invenia.github.io/LibPQ.jl/stable/)
[![In Development](https://img.shields.io/badge/docs-dev-blue.svg)](https://invenia.github.io/LibPQ.jl/dev/)
[![Build Status](https://travis-ci.com/invenia/LibPQ.jl.svg?branch=master)](https://travis-ci.com/invenia/LibPQ.jl)
[![CodeCov](https://codecov.io/gh/invenia/LibPQ.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/invenia/LibPQ.jl)

## Examples

### Selection

```julia
using LibPQ, Tables

conn = LibPQ.Connection("dbname=postgres")
result = execute(conn, "SELECT typname FROM pg_type WHERE oid = 16")
data = columntable(result)

# the same but with parameters
result = execute(conn, "SELECT typname FROM pg_type WHERE oid = \$1", ["16"])
data = columntable(result)

# the same but asynchronously
async_result = async_execute(conn, "SELECT typname FROM pg_type WHERE oid = \$1", ["16"])
# do other things
result = fetch(async_result)
data = columntable(result)

close(conn)
```

### Insertion

```julia
using LibPQ

conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")

result = execute(conn, """
    CREATE TEMPORARY TABLE libpqjl_test (
        no_nulls    varchar(10) PRIMARY KEY,
        yes_nulls   varchar(10)
    );
""")

LibPQ.load!(
    (no_nulls = ["foo", "baz"], yes_nulls = ["bar", missing]),
    conn,
    "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2);",
)

close(conn)
```

#### A Note on Bulk Insertion

When inserting a large number of rows, wrapping your insert queries in a transaction will greatly increase performance.
See the PostgreSQL documentation [14.4.1. Disable Autocommit](https://www.postgresql.org/docs/10/populate.html#DISABLE-AUTOCOMMIT) for more information.

Concretely, this means surrounding your query like this:

```julia
execute(conn, "BEGIN;")

LibPQ.load!(
    (no_nulls = ["foo", "baz"], yes_nulls = ["bar", missing]),
    conn,
    "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2);",
)

execute(conn, "COMMIT;")
```

### `COPY`

An alternative to repeated `INSERT` queries is the PostgreSQL `COPY` query.
`LibPQ.CopyIn` makes it easier to stream data to the server using a `COPY FROM STDIN` query.

```julia
using LibPQ, DataFrames, CSV

conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")

result = execute(conn, """
    CREATE TEMPORARY TABLE libpqjl_test (
        no_nulls    varchar(10) PRIMARY KEY,
        yes_nulls   varchar(10)
    );
""")

no_nulls = map(string, 'a':'z')
yes_nulls = Union{String, Missing}[isodd(Int(c)) ? string(c) : missing for c in 'a':'z']
data = DataFrame(no_nulls=no_nulls, yes_nulls=yes_nulls)

"""
Function for upload of a Tables.jl compatible data structure (e.g. DataFrames.jl) into the db.
"""
function load_by_copy!(table, conn:: LibPQ.Connection, tablename:: AbstractString)
    iter = CSV.RowWriter(table)
    column_names = first(iter)
    copyin = LibPQ.CopyIn("COPY $tablename ($column_names) FROM STDIN (FORMAT CSV, HEADER);", iter)
    execute(conn, copyin)
end

load_by_copy!(data, conn, "libpqjl_test")

close(conn)
```
