Tables.istable(::Type{<:Result}) = true

# Rows

Tables.rowaccess(::Type{<:Result}) = true
Tables.rows(jl_result::Result) = jl_result

Base.eltype(jl_result::Result) = Row
Base.length(jl_result::Result) = num_rows(jl_result)

function Base.iterate(jl_result::Result, (len, row)=(length(jl_result), 1))
    row > len && return nothing
    return Row(jl_result, row), (len, row + 1)
end

function Tables.schema(jl_result::Result)
    types = map(jl_result.not_null, column_types(jl_result)) do not_null, col_type
        not_null ? col_type : Union{col_type, Missing}
    end
    return Tables.Schema(map(Symbol, column_names(jl_result)), types)
end

struct Row
    result::Result
    row::Int
end

result(pqrow::Row) = getfield(pqrow, :result)
row_number(pqrow::Row) = getfield(pqrow, :row)

Base.propertynames(pqrow::Row) = map(Symbol, column_names(result(pqrow)))

function Base.getproperty(pqrow::Row, name::Symbol)
    jl_result = result(pqrow)
    row = row_number(pqrow)
    col = column_number(jl_result, name)
    return jl_result[row, col]
end

function Base.getindex(pqrow::Row, col::Integer)
    row = row_number(pqrow)
    return result(pqrow)[row, col]
end

Base.length(pqrow::Row) = num_columns(result(pqrow))

function Base.iterate(pqrow::Row, (len, col)=(length(pqrow), 1))
    col > len && return nothing
    return (result(pqrow)[row_number(pqrow), col], (len, col + 1))
end

# Columns

struct Column{T} <: AbstractVector{T}
    result::Result
    col::Int
    col_name::Symbol
    oid::Oid
    not_null::Bool
    typ::Type
    func::Base.Callable
end

struct Columns <: AbstractVector{Column}
    result::Result
end

result(cs::Columns) = getfield(cs, :result)

Base.propertynames(cs::Columns) = map(Symbol, column_names(result(cs)))

Base.getproperty(cs::Columns, name::Symbol) = Column(result(cs), name)
Base.getindex(cs::Columns, col::Integer) = Column(result(cs), col)
Base.IndexStyle(::Type{Columns}) = IndexLinear()
Base.length(cs::Columns) = num_columns(result(cs))
Base.size(cs::Columns) = (length(cs),)

Tables.columnaccess(::Type{<:Result}) = true
Tables.columns(jl_result::Result) = Columns(jl_result)

function Tables.schema(cs::Columns)
    jl_result = result(cs)
    types = map(jl_result.not_null, column_types(jl_result)) do not_null, col_type
        not_null ? col_type : Union{col_type, Missing}
    end
    return Tables.Schema(map(Symbol, column_names(jl_result)), types)
end

function Column(jl_result::Result, col::Integer, name=Symbol(column_name(jl_result, col)))
    @boundscheck if !checkindex(Bool, Base.OneTo(num_columns(jl_result)), col)
        throw(BoundsError(Columns(jl_result), col))
    end

    oid = column_oids(jl_result)[col]
    typ = column_types(jl_result)[col]
    func = jl_result.column_funcs[col]
    not_null = jl_result.not_null[col]
    element_type = not_null ? typ : Union{typ, Missing}
    return Column{element_type}(jl_result, col, name, oid, not_null, typ, func)
end

function Column(jl_result::Result, name::Symbol, col=column_number(jl_result, name))
    return Column(jl_result, col, name)
end

result(c::Column) = getfield(c, :result)
column_number(c::Column) = getfield(c, :col)
column_name(c::Column) = getfield(c, :col_name)

function Base.getindex(c::Column{T}, row::Integer)::T where T
    jl_result = result(c)
    col = column_number(c)
    if isnull(jl_result, row, col)
        return missing
    else
        return c.func(PQValue{c.oid}(jl_result, row, col))::c.typ
    end
end

Base.IndexStyle(::Type{<:Column}) = IndexLinear()
Base.length(c::Column) = num_rows(result(c))
Base.size(c::Column) = (length(c),)


"""
    LibPQ.load!(table, connection::LibPQ.Connection, query) -> LibPQ.Statement

Insert the data from `table` using `query`.
`query` will be prepared as a [`LibPQ.Statement`](@ref) and then [`execute`](@ref) is run
on every row of `table`.

For best performance, wrap the call to this function in a PostgreSQL transaction:

```jldoctest; setup = :(execute(conn, "CREATE TEMPORARY TABLE libpqjl_test (no_nulls varchar(10) PRIMARY KEY, yes_nulls varchar(10));"))
julia> execute(conn, "BEGIN;");

julia> LibPQ.load!(
           (no_nulls = ["foo", "baz"], yes_nulls = ["bar", missing]),
           conn,
           "INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\\\$1, \\\$2);",
       );

julia> execute(conn, "COMMIT;");
```
"""
function load!(table::T, connection::Connection, query::AbstractString) where {T}
    rows = Tables.rows(table)
    stmt = prepare(connection, query)
    state = iterate(rows)
    state === nothing && return stmt
    row, st = state
    names = propertynames(row)
    sch = Tables.Schema(names, nothing)
    parameters = Vector{Parameter}(undef, length(names))
    while state !== nothing
        row, st = state
        Tables.eachcolumn(sch, row) do val, col, nm
            parameters[col] = if ismissing(val)
                missing
            elseif val isa AbstractString
                convert(String, val)
            else
                string_parameter(val)
            end
        end
        close(execute_params(stmt, parameters; throw_error=true))
        state = iterate(rows, st)
    end
    return stmt
end
