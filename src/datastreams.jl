### SOURCE BEGIN

function Data.schema(jl_result::Result)
    Data.schema(jl_result, Data.Field)
end

function Data.schema(jl_result::Result, ::Type{Data.Field})
    types = map(jl_result.not_null, column_types(jl_result)) do not_null, col_type
        not_null ? col_type : Union{col_type, Missing}
    end

    return Data.Schema(
        types,
        column_names(jl_result),
        num_rows(jl_result),
    )
end

function Data.isdone(jl_result::Result, row, col)
    Data.isdone(jl_result, row, col, num_rows(jl_result), num_columns(jl_result))
end

function Data.isdone(jl_result::Result, row, col, rows, cols)
    row > rows || col > cols
end

Data.streamtype(::Type{Result}, ::Type{Data.Field}) = true
Data.accesspattern(jl_result::Result) = RandomAccess()

# function Data.streamfrom(
#     jl_result::Result,
#     ::Type{Data.Field},
#     ::Type{Union{T, Missing}},
#     row::Int,
#     col::Int,
# )::Union{T, Missing} where T
#     if libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
#         return missing
#     else
#         oid = jl_result.column_oids[col]
#         return jl_result.column_funcs[col](PQValue{oid}(jl_result, row, col))::T
#     end
# end

# allow types that aren't just unions to handle nulls
function Data.streamfrom(
    jl_result::Result,
    ::Type{Data.Field},
    ::Type{T},
    row::Int,
    col::Int,
)::T where T>:Missing
    if libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
        return missing
    else
        oid = jl_result.column_oids[col]
        return jl_result.column_funcs[col](PQValue{oid}(jl_result, row, col))::Base.nonmissingtype(T)
    end
end

# if a user says they don't want Missing, error on NULL
function Data.streamfrom(
    jl_result::Result,
    ::Type{Data.Field},
    ::Type{T},
    row::Int,
    col::Int,
)::T where T
    if libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
        error("Unexpected NULL at column $col row $row")
    end

    oid = jl_result.column_oids[col]
    return jl_result.column_funcs[col](PQValue{oid}(jl_result, row, col))
end

### SOURCE END

### SINK BEGIN

"""
    Statement(sch::Data.Schema, ::Type{Data.Row}, append, connection::Connection, query::AbstractString) -> Statement

Construct a `Statement` for use in streaming with DataStreams.
This function is called by `Data.stream!(source, Statement, connection, query)`.
"""
function Statement(
    sch::Data.Schema,
    ::Type{Data.Row},
    append::Bool,  # ignored
    connection::Connection,
    query::AbstractString,
)
    return prepare(connection, query)
end

Data.weakrefstrings(::Type{<:Statement}) = false
Data.streamtypes(::Type{<:Statement}) = [Data.Row]

function Data.streamto!(sink::Statement, ::Type{Data.Row}, row, row_num, col_num)
    parameters = Vector{Parameter}(undef, length(row))

    # this should change to be whatever custom pgtype conversion function we invent
    @inbounds for (i, val) in enumerate(values(row))
        parameters[i] = if ismissing(val)
            missing
        elseif val isa AbstractString
            convert(String, val)
        else
            string(val)
        end
    end

    close(execute(sink, parameters; throw_error=true))
end

### SINK END

### FETCH BEGIN

# fetch! is not part of the DataSreams API

"""
    fetch!(sink::Union{T, Type{T}}, result::Result, args...; kwargs...) where {T} -> T

Stream data to `sink` or a new structure of type T using [`Data.stream!`](https://juliadata.github.io/DataStreams.jl/stable/#Data.stream!-1).
Any trailing `args` or `kwargs` are passed to `Data.stream!`.
`result` is cleared upon completion.
"""
function fetch!(sink, result::Result, args...; kwargs...)
    if !isopen(result)
        error(LOGGER, "Cannot fetch a cleared Result")
    end

    data = Data.stream!(result, sink, args...; kwargs...)
    close(result)
    return Data.close!(data)
end

### FETCH END
