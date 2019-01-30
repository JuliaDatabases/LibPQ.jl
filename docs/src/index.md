# LibPQ

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://invenia.github.io/LibPQ.jl/stable)
[![Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://invenia.github.io/LibPQ.jl/latest)
[![Build Status](https://travis-ci.org/invenia/LibPQ.jl.svg?branch=master)](https://travis-ci.org/invenia/LibPQ.jl)
[![CodeCov](https://codecov.io/gh/invenia/LibPQ.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/invenia/LibPQ.jl)

## Examples

### Selection

```julia
using LibPQ, DataStreams

conn = LibPQ.Connection("dbname=postgres")
result = execute(conn, "SELECT typname FROM pg_type WHERE oid = 16")
data = Data.stream!(result, NamedTuple)

# the same but with parameters
result = execute(conn, "SELECT typname FROM pg_type WHERE oid = \$1", ["16"])
data = Data.stream!(result, NamedTuple)

# the same but using `fetch!` to handle streaming and clearing
data = fetch!(NamedTuple, execute(conn, "SELECT typname FROM pg_type WHERE oid = \$1", ["16"]))

close(conn)
```

### Insertion

```julia
using LibPQ, DataStreams

conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")

result = execute(conn, """
    CREATE TEMPORARY TABLE libpqjl_test (
        no_nulls    varchar(10) PRIMARY KEY,
        yes_nulls   varchar(10)
    );
""")

Data.stream!(
    (no_nulls = ["foo", "baz"], yes_nulls = ["bar", missing]),
    LibPQ.Statement,
    conn,
    "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2);",
)

close(conn)
```

#### A Note on Bulk Insertion

When inserting a large number of rows, wrapping your insert queries in a transaction will greatly increase performance.
See the PostgreSQL documentation [14.4.1. Disable Autocommit](https://www.postgresql.org/docs/10/static/populate.html#DISABLE-AUTOCOMMIT) for more information.

Concretely, this means surrounding your query like this:

```julia
execute(conn, "BEGIN;")

Data.stream!(
    (no_nulls = ["foo", "baz"], yes_nulls = ["bar", missing]),
    LibPQ.Statement,
    conn,
    "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2);",
)

execute(conn, "COMMIT;")
```

### `COPY`

An alternative to repeated `INSERT` queries is the PostgreSQL `COPY` query.
`LibPQ.CopyIn` makes it easier to stream data to the server using a `COPY FROM STDIN` query.

```julia
using LibPQ, DataFrames

conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")

row_strings = imap(eachrow(df)) do row
    if ismissing(row[:yes_nulls])
        "$(row[:no_nulls]),\n"
    else
        "$(row[:no_nulls]),$(row[:yes_nulls])\n"
    end
end

copyin = LibPQ.CopyIn("COPY libpqjl_test FROM STDIN (FORMAT CSV);", row_strings)

execute(conn, copyin)

close(conn)
```
