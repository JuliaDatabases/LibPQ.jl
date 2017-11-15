struct TypedResult{T}
    _result::Result
    _num_rows::Int
end

IteratorInterfaceExtensions.isiterable(x::Result) = true
TableTraits.isiterabletable(x::Result) = true

function IteratorInterfaceExtensions.getiterator(source::Result)
    col_names = Symbol.(column_names(source))
    col_types = fill(DataValue{String}, LibPQ.num_columns(source))

    T = eval(:(@NT($(col_names...)))){col_types...}

    return TypedResult{T}(source, num_rows(source))
end

Base.length(iter::TypedResult) = iter._num_rows

Base.eltype(iter::TypedResult{T}) where T = T

Base.start(iter::TypedResult) = 1

@generated function Base.next(iter::TypedResult{T}, row) where T
    return :(return T($([:(libpq_c.PQgetisnull(iter._result.result, row - 1, $(col - 1)) == 1 ?
        $(T.types[col])() :
        $(T.types[col])(unsafe_string(libpq_c.PQgetvalue(iter._result.result, row - 1, $(col - 1))))) for col=1:length(T.types)]...)), row+1)
end

Base.done(iter::TypedResult, state) = state>iter._num_rows
