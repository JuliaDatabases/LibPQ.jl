Tables.istable(::Type{<:Result}) = true
Tables.rowaccess(::Type{<:Result}) = true
Tables.rows(r::Result) = r

Base.eltype(r::Result) = Row
Base.length(r::Result) = num_rows(r)

function Tables.schema(r::Result)
    types = map(r.not_null, column_types(r)) do not_null, col_type
        not_null ? col_type : Union{col_type, Missing}
    end
    return Tables.Schema(types, map(Symbol, column_names(r)))
end

function Base.iterate(r::Result, (len, row)=(length(r), 1))
    row > len && return nothing
    return Row(result, row), (len, row + 1)
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
