### SOURCE BEGIN

function Data.schema(jl_result::Result)
    Data.schema(jl_result, Data.Field)
end

function Data.schema(jl_result::Result, ::Type{Data.Field})
    nrows = num_rows(jl_result)
    ncols = num_columns(jl_result)

    Data.Schema(
        fill(Union{String, Missing}, ncols),  # types
        column_names(jl_result),
        nrows,
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

function Data.streamfrom(
    jl_result::Result,
    ::Type{Data.Field},
    ::Type{Union{String, Missing}},
    row::Int,
    col::Int,
)::Union{String, Missing}
    if libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
        return missing
    else
        return unsafe_string(libpq_c.PQgetvalue(jl_result.result, row - 1, col - 1))
    end
end

function Data.streamfrom(
    jl_result::Result,
    ::Type{Data.Field},
    ::Type{String},
    row::Int,
    col::Int,
)::String
    unsafe_string(libpq_c.PQgetvalue(jl_result.result, row - 1, col - 1))
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
    parameters = Vector{Parameter}(length(row))

    # this should change to be whatever custom pgtype conversion function we invent
    map!(parameters, values(row)) do val
        if ismissing(val)
            missing
        elseif val isa AbstractString
            convert(String, val)
        else
            string(val)
        end
    end

    clear!(execute(sink, parameters; throw_error=true))
end

### SINK END
