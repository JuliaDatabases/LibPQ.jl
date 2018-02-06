# LibPQ API

```@meta
DocTestSetup = quote
    using LibPQ
end
```

## Public

### Connections

```@docs
LibPQ.Connection
execute
prepare
status(::Connection)
Base.close(::Connection)
Base.isopen(::Connection)
reset!(::Connection)
Base.show(::IO, ::Connection)
```

### Results

```@docs
LibPQ.Result
status(::Result)
clear!(::Result)
num_rows(::Result)
num_columns(::Result)
Base.show(::IO, ::Result)
```

### Statements

```@docs
LibPQ.Statement
num_columns(::Statement)
num_params(::Statement)
Base.show(::IO, ::Statement)
```

### DataStreams Integration

```@docs
LibPQ.Statement(::LibPQ.DataStreams.Data.Schema, ::Type{LibPQ.DataStreams.Data.Row}, ::Bool, ::Connection, ::AbstractString)
LibPQ.fetch!
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
LibPQ.error_message(::Connection)
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
LibPQ.num_params(::Result)
LibPQ.error_message(::Result)
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
