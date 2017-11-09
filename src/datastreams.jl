function Data.schema(jl_result::Result)
    Data.schema(jl_result, Data.Field)
end

function Data.schema(jl_result::Result, ::Type{Data.Field})
    nrows = num_rows(jl_result)
    ncols = num_columns(jl_result)

    Data.Schema(
        column_names(jl_result),
        fill(Nullable{String}, ncols),  # types
        nrows,
    )
end

function Data.schema(jl_result::Result, ::Type{Data.Column})
    nrows = num_rows(jl_result)
    ncols = num_columns(jl_result)

    Data.Schema(
        column_names(jl_result),
        fill(NullableVector{String}, ncols),  # types
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

if isdefined(Data, :accesspattern)
    Data.accesspattern(jl_result::Result) = RandomAccess()
end

function Data.streamfrom(
    jl_result::Result,
    ::Type{Data.Field},
    ::Type{Nullable{String}},
    row::Int,
    col::Int,
)::Nullable{String}
    if libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
        return Nullable()
    else
        return Nullable(
            unsafe_string(libpq_c.PQgetvalue(jl_result.result, row - 1, col - 1))
        )
    end
end

function Data.streamfrom(
    jl_result::Result,
    ::Type{Data.Field},
    ::Type{Union{String, Null}},
    row::Int,
    col::Int,
)::Union{String, Null}
    if libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
        return null
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
