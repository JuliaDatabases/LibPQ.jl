# [Type Conversions](@id typeconv)

The implementation of type conversions across the LibPQ.jl interface is sufficiently complicated
that it warrants its own section in the documentation.
Luckily, it should be easy to *use* for whichever case you need.

```@meta
DocTestSetup = quote
    using LibPQ
    using DataFrames
    using Tables

    DATABASE_USER = get(ENV, "LIBPQJL_DATABASE_USER", "postgres")
    conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")
end
```

## From Julia to PostgreSQL

Parameters are sent in PostgreSQL text format. Values are converted to their string
representation, with specialized conversion for arrays and intervals. Vectors become
PostgreSQL array literals. You can also provide the PostgreSQL text representation yourself.

```jldoctest
julia> A = collect(12:15);

julia> nt = columntable(execute(conn, "SELECT \$1 = ANY(\$2) AS result", Any[13, string("{", join(A, ","), "}")]));

julia> nt[:result][1]
true
```

For a `bytea` parameter, encode the bytes in PostgreSQL's hexadecimal text format.
A `Vector{UInt8}` is otherwise converted to an array literal such as `{1,2,3,4}`, whose
characters PostgreSQL then stores as bytes. The `binary_format` keyword selects the
result format; parameters still use text format.

```jldoctest
julia> bytes = UInt8[1, 2, 3, 4];

julia> parameter = string(raw"\x", bytes2hex(bytes));

julia> bytes2hex(columntable(execute(conn, "SELECT \$1::bytea AS data", [parameter]))[:data][1])
"01020304"
```

## From PostgreSQL to Julia

The default type conversions applied when fetching PostgreSQL data should be sufficient in many
cases.

```julia
julia> df = DataFrame(execute(conn, "SELECT 1::int4, 'foo'::varchar, '{1.0, 2.1, 3.3}'::float8[], false, TIMESTAMP '2004-10-19 10:23:54'"))
1×5 DataFrames.DataFrame
│ Row │ int4 │ varchar │ float8          │ bool  │ timestamp           │
├─────┼──────┼─────────┼─────────────────┼───────┼─────────────────────┤
│ 1   │ 1    │ foo     │ [1.0, 2.1, 3.3] │ false │ 2004-10-19T10:23:54 │
```

The column types in Julia for the above DataFrame are `Int32`, `String`, `Vector{Float64}`, `Bool`,
and `DateTime`.

Any unknown or unsupported types are parsed as `String`s by default.

### `NULL`

The PostgreSQL `NULL` is handled with `missing`.
By default, data streamed using the Tables interface is `Union{T, Missing}`, and columns are
`Vector{Union{T, Missing}}`.
While `libpq` does not provide an interface for checking whether a result column contains `NULL`,
it's possible to assert that columns do not contain `NULL` using the `not_null` keyword argument to
[`execute`](@ref).
This will result in data retrieved as `T`/`Vector{T}` instead.
`not_null` accepts a list of column names or column positions, or a `Bool` asserting that all
columns do or do not have the possibility of `NULL`.

The type-related interfaces described below only deal with the `T` part of the `Union{T, Missing}`,
and there is currently no way to use an alternate `NULL` representation.

### Overrides

It's possible to override the default type conversion behaviour in several places.
Refer to the [Implementation](@ref) section for more detailed information.

#### Query-level

There are three arguments to [`execute`](@ref) for this:

* `column_types` argument to set the desired types for given columns.
  This is accepted as a dictionary mapping column names (as `Symbol`s or `String`s) and/or positions
  (as `Integer`s) to Julia types.
* `type_map` argument to set the mapping from PostgreSQL types to Julia types.
  This is accepted as a dictionary mapping PostgreSQL oids (as `Integer`s) or [canonical](@ref canon)
  type names (as `Symbol`s or `String`s) to Julia types.
* `conversions` argument to set the *function* used to convert from a given PostgreSQL type to a
  given Julia type.
  This is accepted as a dictionary mapping 2-tuples of PostgreSQL oids or type names (as above) and
  Julia types to callables (functions or type constructors).

#### Connection-level

[`LibPQ.Connection`](@ref) supports `type_map` and `conversions` arguments as well, which will apply
to all queries run with the created connection.
Query-level overrides will override connection-level overrides.

#### Global

To override behaviour for every query everywhere, add mappings to the global constants
[`LibPQ.LIBPQ_TYPE_MAP`](@ref) and [`LibPQ.LIBPQ_CONVERSIONS`](@ref).
Connection-level overrides will override these global overrides.

### UUID values

UUID columns keep the default `String` conversion. To return Julia UUID values,
set `type_map=Dict(:uuid => UUID)` on the connection or query. This works with
both text and binary results.

```jldoctest
julia> using UUIDs: UUID

julia> result = execute(conn, "SELECT '00112233-4455-6677-8899-aabbccddeeff'::uuid AS id"; binary_format=true, type_map=Dict(:uuid => UUID));

julia> first(columntable(result).id)
UUID("00112233-4455-6677-8899-aabbccddeeff")

julia> close(result)
```

For UUID arrays in text results, set
`type_map=Dict(:_uuid => AbstractArray{Union{UUID,Missing}})` to preserve dimensions,
index offsets, and NULL elements. Binary UUID arrays are not currently supported.

### Implementation

#### Flow

When a [`LibPQ.Result`](@ref) is created (as the result of running a query), the Julia types and
conversion functions for each column are precalculated and stored within the `Result`.
The types are chosen using these sources, in decreasing priority:

* `column_types` overrides at `Result` level
* `type_map` overrides at `Result` level
* `type_map` overrides at `Connection` level
* [`LibPQ.LIBPQ_TYPE_MAP`](@ref)
* [`LibPQ._DEFAULT_TYPE_MAP`](@ref)
* fallback to `String`

Using those types, the function for converting from PostgreSQL data to Julia data is selected,
using these sources, in decreasing priority:

* `conversions` overrides at `Result` level
* `conversions` overrides at `Connection` level
* [`LibPQ.LIBPQ_CONVERSIONS`](@ref)
* [`LibPQ._DEFAULT_CONVERSIONS`](@ref),
* fallback to `parse`

When fetching a particular value from a `Result`, that function is used to turn data wrapped by a
`PQValue` to a Julia type.
This operation always copies or parses data and never provides a view into the original `Result`.

#### [Canonical PostgreSQL Type Names](@id canon)

While PostgreSQL allows many aliases for its types (e.g., `double precision` for `float8` and
`character varying` for `varchar`), there is one "canonical" name for the type stored in the
`pg_type` table from PostgreSQL's catalog.
You can find a list of these for all of PostgreSQL's default types in the keys of
[`LibPQ.PQ_SYSTEM_TYPES`](@ref).

```@meta
DocTestSetup = nothing
```
