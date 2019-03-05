Tables.istable(::Type{<:Result}) = true
Tables.rowaccess(::Type{<:Result}) = true
Tables.rows(jl_result::Result) = jl_result

Base.eltype(jl_result::Result) = Row
Base.length(jl_result::Result) = num_rows(jl_result)

function Tables.schema(jl_result::Result)
    types = map(jl_result.not_null, column_types(jl_result)) do not_null, col_type
        not_null ? col_type : Union{col_type, Missing}
    end
    return Tables.Schema(map(Symbol, column_names(jl_result)), types)
end

function Base.iterate(jl_result::Result, (len, row)=(length(jl_result), 1))
    row > len && return nothing
    return Row(jl_result, row), (len, row + 1)
end

struct Row
    result::Result
    row::Int
end

Base.propertynames(r::Row) = column_names(getfield(r, :result))

function Base.getproperty(pqrow::Row, name::Symbol)
    jl_result = getfield(pqrow, :result)
    row = getfield(pqrow, :row)
    col = column_number(jl_result, name)
    if libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
        return missing
    else
        oid = jl_result.column_oids[col]
        T = jl_result.column_types[col]
        return jl_result.column_funcs[col](PQValue{oid}(jl_result, row, col))::T
    end
end

# sink
function load!(table::T, connection::Connection, query::AbstractString) where {T}
    Tables.istable(T) || throw(ArgumentError("$T doesn't support the required Tables.jl interface"))
    stmt = prepare(connection, query)
    rows = Tables.rows(table)
    state = iterate(rows)
    state === nothing && return
    st, row = state
    names = propertynames(row)
    sch = Tables.Schema(names, nothing)
    parameters = Vector{Parameter}(undef, length(names))
    while true
        Tables.eachcolumn(sch, row) do val, col, nm
            parameters[col] = if ismissing(val)
                missing
            elseif val isa AbstractString
                convert(String, val)
            else
                string(val)
            end
        end
        close(execute(stmt, parameters; throw_error=true))
        state = iterate(rows, st)
        state === nothing && break
        row, st = state
    end
    return
end
