# LibPQ

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://invenia.github.io/LibPQ.jl/stable)
[![Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://invenia.github.io/LibPQ.jl/latest)
[![Build Status](https://travis-ci.org/invenia/LibPQ.jl.svg?branch=master)](https://travis-ci.org/invenia/LibPQ.jl)
[![CodeCov](https://codecov.io/gh/invenia/LibPQ.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/invenia/LibPQ.jl)

## Examples

### Selection

```julia
conn = Connection("dbname=postgres")
result = execute(conn, "SELECT typname FROM pg_type WHERE oid = 16")
data = Data.stream!(result, NamedTuple)
clear!(result)

# the same but with parameters
result = execute(conn, "SELECT typname FROM pg_type WHERE oid = \$1", ["16"])
data = Data.stream!(result, NamedTuple)
clear!(result)

close(conn)
```

### Insertion

```julia
conn = Connection("dbname=postgres user=$DATABASE_USER")

result = execute(conn, """
    CREATE TEMPORARY TABLE libpqjl_test (
        no_nulls    varchar(10) PRIMARY KEY,
        yes_nulls   varchar(10)
    );
""")
clear!(result)

Data.stream!(
    data,
    Statement,
    conn,
    "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\$1, \$2);",
)

close(conn)
```
