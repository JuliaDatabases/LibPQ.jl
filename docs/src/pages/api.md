# LibPQ API

```@meta
DocTestSetup = quote
    using LibPQ

    DATABASE_USER = get(ENV, "LIBPQJL_DATABASE_USER", "postgres")
    conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")
end
```

## Public

### Connections

```@docs
LibPQ.Connection
execute
prepare
status(::LibPQ.Connection)
Base.close(::LibPQ.Connection)
Base.isopen(::LibPQ.Connection)
reset!(::LibPQ.Connection)
Base.show(::IO, ::LibPQ.Connection)
```

### Results

```@docs
LibPQ.Result
status(::LibPQ.Result)
Base.close(::LibPQ.Result)
Base.isopen(::LibPQ.Result)
num_rows(::LibPQ.Result)
num_columns(::LibPQ.Result)
num_affected_rows(::LibPQ.Result)
Base.show(::IO, ::LibPQ.Result)
```

### Statements

```@docs
LibPQ.Statement
num_columns(::LibPQ.Statement)
num_params(::LibPQ.Statement)
Base.show(::IO, ::LibPQ.Statement)
LibPQ.load!
```

### Copy

```@docs
LibPQ.CopyIn
execute(::LibPQ.Connection, ::LibPQ.CopyIn)
```

### Asynchronous

```@docs
async_execute
LibPQ.AsyncResult
cancel
```

## Internals

### Connections

```@docs
LibPQ.handle_new_connection
LibPQ.server_version
LibPQ.encoding
LibPQ.set_encoding!
LibPQ.reset_encoding!
LibPQ.transaction_status
LibPQ.unique_id
LibPQ.error_message(::LibPQ.Connection)
```

### Connection Info

```@docs
LibPQ.ConnectionOption
LibPQ.conninfo
LibPQ.ConninfoDisplay
Base.parse(::Type{LibPQ.ConninfoDisplay}, ::AbstractString)
```

### Results and Statements

```@docs
LibPQ.handle_result
LibPQ.column_name
LibPQ.column_names
LibPQ.column_number
LibPQ.column_oids
LibPQ.column_types
LibPQ.num_params(::LibPQ.Result)
LibPQ.error_message(::LibPQ.Result)
```

### Type Conversions

```@docs
LibPQ.oid
LibPQ.PQChar
LibPQ.PQ_SYSTEM_TYPES
LibPQ.PQTypeMap
Base.getindex(::LibPQ.PQTypeMap, typ)
Base.setindex!(::LibPQ.PQTypeMap, ::Type, typ)
LibPQ._DEFAULT_TYPE_MAP
LibPQ.LIBPQ_TYPE_MAP
LibPQ.PQConversions
Base.getindex(::LibPQ.PQConversions, oid_typ::Tuple{Any, Type})
Base.setindex!(::LibPQ.PQConversions, ::Base.Callable, oid_typ::Tuple{Any, Type})
LibPQ._DEFAULT_CONVERSIONS
LibPQ.LIBPQ_CONVERSIONS
LibPQ._FALLBACK_CONVERSION
```

### Parsing

```@docs
LibPQ.PQValue
LibPQ.data_pointer
LibPQ.num_bytes
Base.unsafe_string(::LibPQ.PQValue)
LibPQ.string_view
LibPQ.bytes_view
Base.parse(::Type{Any}, pqv::LibPQ.PQValue)
```

### Miscellaneous

```@docs
LibPQ.@pqv_str
LibPQ.string_parameters
LibPQ.parameter_pointers
LibPQ.unsafe_string_or_null
```

```@meta
DocTestSetup = nothing
```
