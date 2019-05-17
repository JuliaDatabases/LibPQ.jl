"A wrapper for one value in a PostgreSQL result."
struct PQValue{OID}
    "PostgreSQL result"
    jl_result::Result

    "Row index of the result (0-indexed)"
    row::Cint

    "Column index of the result (0-indexed)"
    col::Cint

    function PQValue{OID}(jl_result::Result, row::Integer, col::Integer) where OID
        return new{OID}(jl_result, row - 1, col - 1)
    end
end

"""
    PQValue(jl_result::Result, row::Integer, col::Integer) -> PQValue
    PQValue{OID}(jl_result::Result, row::Integer, col::Integer) -> PQValue{OID}

Construct a `PQValue` wrapping one value in a PostgreSQL result.
Row and column positions are provided 1-indexed.
If the `OID` type parameter is not provided, the Oid of the field will be retrieved from
the result.
"""
function PQValue(jl_result::Result, row::Integer, col::Integer)
    oid = libpq_c.PQftype(jl_result.result, col - 1)

    return PQValue{oid}(jl_result, row, col)
end

"""
    isnull(jl_result::Result, row::Integer, col::Integer) -> Bool

Return whether the result value at the specified row and column (1-indexed) is `NULL`.
"""
function isnull(jl_result::Result, row::Integer, col::Integer)
    return libpq_c.PQgetisnull(jl_result.result, row - 1, col - 1) == 1
end

"""
    num_bytes(pqv::PQValue) -> Cint

The length in bytes of the `PQValue`'s corresponding data.
LibPQ.jl currently always uses text format, so this is equivalent to C's `strlen`.

See also: [`data_pointer`](@ref)
"""
num_bytes(pqv::PQValue) = libpq_c.PQgetlength(pqv.jl_result.result, pqv.row, pqv.col)

"""
    data_pointer(pqv::PQValue) -> Ptr{UInt8}

Get a raw pointer to the data for one value in a PostgreSQL result.
This data will be freed by libpq when the result is cleared, and should only be used
temporarily.
"""
data_pointer(pqv::PQValue) = libpq_c.PQgetvalue(pqv.jl_result.result, pqv.row, pqv.col)

"""
    unsafe_string(pqv::PQValue) -> String

Construct a `String` from a `PQValue` by copying the data.
"""
function Base.unsafe_string(pqv::PQValue)
    return unsafe_string(data_pointer(pqv), num_bytes(pqv))
end

"""
    string_view(pqv::PQValue) -> String

Wrap a `PQValue`'s underlying data in a `String`.
This function uses [`data_pointer`](@ref) and [`num_bytes`](@ref) and does not copy.

!!! note

    The underlying data will be freed by libpq when the result is cleared, and should only
    be used temporarily.

See also: [`bytes_view`](@ref)
"""
function string_view(pqv::PQValue)
    return String(unsafe_wrap(Vector{UInt8}, data_pointer(pqv), num_bytes(pqv)))
end

"""
    bytes_view(pqv::PQValue) -> Vector{UInt8}

Wrap a `PQValue`'s underlying data in a vector of bytes.
This function uses [`data_pointer`](@ref) and [`num_bytes`](@ref) and does not copy.

This function differs from [`string_view`](@ref) as it keeps the `\0` byte at the end.
`PQValue` parsing functions should use `bytes_view` when the data returned by PostgreSQL
is not in UTF-8.

!!! note

    The underlying data will be freed by libpq when the result is cleared, and should only
    be used temporarily.
"""
bytes_view(pqv::PQValue) = unsafe_wrap(Vector{UInt8}, data_pointer(pqv), num_bytes(pqv) + 1)

Base.String(pqv::PQValue) = unsafe_string(pqv)
Base.parse(::Type{String}, pqv::PQValue) = unsafe_string(pqv)
Base.convert(::Type{String}, pqv::PQValue) = String(pqv)
Base.length(pqv::PQValue) = length(string_view(pqv))
Base.lastindex(pqv::PQValue) = lastindex(string_view(pqv))

# Fallback, because Base requires string iteration state to be indices into the string.
# In an ideal world, PQValue would be an AbstractString and this particular method would
# not be necessary.
"""
    parse(::Type{T}, pqv::PQValue) -> T

Parse a value of type `T` from a `PQValue`.
By default, this uses any existing `parse` method for parsing a value of type `T` from a
`String`.
"""
Base.parse(::Type{T}, pqv::PQValue) where {T} = parse(T, string_view(pqv))

# allow parsing as a Symbol anything which works as a String
Base.parse(::Type{Symbol}, pqv::PQValue) = Symbol(string_view(pqv))

function Base.iterate(pqv::PQValue)
    sv = string_view(pqv)
    iterate(pqv, (sv, ()))
end
function Base.iterate(pqv::PQValue, state)
    sv, i = state
    iter = iterate(sv, i...)
    iter === nothing && return nothing
    c, new_sv_state = iter
    return (c, (sv, (new_sv_state,)))
end

## integers
_DEFAULT_TYPE_MAP[:int2] = Int16
_DEFAULT_TYPE_MAP[:int4] = Int32
_DEFAULT_TYPE_MAP[:int8] = Int64

## floating point
_DEFAULT_TYPE_MAP[:float4] = Float32
_DEFAULT_TYPE_MAP[:float8] = Float64

## oid
_DEFAULT_TYPE_MAP[:oid] = Oid

## numeric
_DEFAULT_TYPE_MAP[:numeric] = Decimal

# no default for monetary; needs lconv and lc_monetary from result/connection

## character
# bpchar is char(n)
function Base.parse(::Type{String}, pqv::PQValue{PQ_SYSTEM_TYPES[:bpchar]})
    return String(rstrip(string_view(pqv), ' '))
end
# char is "char"
_DEFAULT_TYPE_MAP[:char] = PQChar
Base.parse(::Type{PQChar}, pqv::PQValue{PQ_SYSTEM_TYPES[:char]}) = PQChar(first(pqv))
Base.parse(::Type{Char}, pqv::PQValue{PQ_SYSTEM_TYPES[:char]}) = Char(parse(PQChar, pqv))
# varchar, text, and name are all String

## binary data

_DEFAULT_TYPE_MAP[:bytea] = Vector{UInt8}
function Base.parse(::Type{Vector{UInt8}}, pqv::PQValue{PQ_SYSTEM_TYPES[:bytea]})
    byte_length = Ref{Csize_t}(0)
    bytes = bytes_view(pqv)

    unescaped_ptr = libpq_c.PQunescapeBytea(bytes, byte_length)

    if unescaped_ptr == C_NULL
        error("Could not unescape byte sequence $(String(bytes))")
    end

    unescaped_vec = copy(unsafe_wrap(Vector{UInt8}, unescaped_ptr, byte_length[]))

    libpq_c.PQfreemem(unescaped_ptr)

    return unescaped_vec
end

## bool
# TODO: check whether we ever need this or if PostgreSQL always gives t or f
_DEFAULT_TYPE_MAP[:bool] = Bool
const BOOL_TRUE = r"^\s*(t|true|y|yes|on|1)\s*$"i
const BOOL_FALSE = r"^\s*(f|false|n|no|off|0)\s*$"i
function Base.parse(::Type{Bool}, pqv::PQValue{PQ_SYSTEM_TYPES[:bool]})
    str = string_view(pqv)

    if occursin(BOOL_TRUE, str)
        return true
    elseif occursin(BOOL_FALSE, str)
        return false
    else
        error("\"$str\" is not a valid boolean")
    end
end

## dates and times
# ISO, YMD
_DEFAULT_TYPE_MAP[:timestamp] = DateTime
const TIMESTAMP_FORMAT = dateformat"y-m-d HH:MM:SS.s"  # .s is optional here
function Base.parse(::Type{DateTime}, pqv::PQValue{PQ_SYSTEM_TYPES[:timestamp]})
    str = string_view(pqv)

    if str == "infinity"
        return typemax(DateTime)
    elseif str == "-infinity"
        return typemin(DateTime)
    end

    # Cut off digits after the third after the decimal point,
    # since DateTime in Julia currently handles only milliseconds, see Issue #33
    str = replace(str, r"(\.[\d]{3})\d+" => s"\g<1>")
    return parse(DateTime, str, TIMESTAMP_FORMAT)
end

# ISO, YMD
_DEFAULT_TYPE_MAP[:timestamptz] = ZonedDateTime
const TIMESTAMPTZ_FORMATS = (
    dateformat"y-m-d HH:MM:SSz",
    dateformat"y-m-d HH:MM:SS.sz",
    dateformat"y-m-d HH:MM:SS.ssz",
    dateformat"y-m-d HH:MM:SS.sssz",
)
function Base.parse(::Type{ZonedDateTime}, pqv::PQValue{PQ_SYSTEM_TYPES[:timestamptz]})
    str = string_view(pqv)

    if str == "infinity"
        return ZonedDateTime(typemax(DateTime), tz"UTC")
    elseif str == "-infinity"
        return ZonedDateTime(typemin(DateTime), tz"UTC")
    end

    for fmt in TIMESTAMPTZ_FORMATS[1:end-1]
        try
            return parse(ZonedDateTime, str, fmt)
        catch
            continue
        end
    end
    # Cut off digits after the third after the decimal point,
    # since DateTime in Julia currently handles only milliseconds, see Issue #33
    str = replace(str, r"(\.[\d]{3})\d+" => s"\g<1>")
    return parse(ZonedDateTime, str, TIMESTAMPTZ_FORMATS[end])
end

# UNIX timestamps
function Base.parse(::Type{DateTime}, pqv::PQValue{PQ_SYSTEM_TYPES[:int8]})
    unix2datetime(parse(Int64, pqv))
end

function Base.parse(::Type{ZonedDateTime}, pqv::PQValue{PQ_SYSTEM_TYPES[:int8]})
    TimeZones.unix2zdt(parse(Int64, pqv))
end

## arrays
# numeric arrays never have double quotes and always use ',' as a separator
parse_numeric_element(::Type{T}, str) where T = parse(T, str)

parse_numeric_element(::Type{Union{T, Missing}}, str) where T =
    str == "NULL" ? missing : parse(T, str)

function parse_numeric_array(eltype::Type{T}, str::AbstractString) where T
    eq_ind = findfirst(isequal('='), str)

    if eq_ind !== nothing
        offset_str = str[1:eq_ind-1]
        range_strs = split(str[1:eq_ind-1], ['[',']']; keepempty=false)

        ranges = map(range_strs) do range_str
            lower, upper = split(range_str, ':'; limit=2)
            return parse(Int, lower):parse(Int, upper)
        end

        arr = OffsetArray{T}(undef, ranges...)
        el_iter = eachmatch(r"[^\}\{,]+", str[eq_ind+1:end])
    else
        arr = Array{T}(undef, array_size(str)...)
        el_iter = eachmatch(r"[^\}\{,]+", str)
    end

    idx_iter = imap(reverse, product(reverse(axes(arr))...))
    for (idx, num_match) in zip(idx_iter, el_iter)
        arr[idx...] = parse_numeric_element(T, num_match.match)
    end

    return arr
end

function array_size(str)
    ndims = something(findfirst(c -> c != '{', str), 0) - 1
    dims = zeros(Int, ndims)

    curr_dim = ndims
    curr_pos = ndims
    open_braces = ndims
    last_ind = lastindex(str)
    el_count = 0
    while curr_dim > 0 && curr_pos < last_ind
        curr_pos = nextind(str, curr_pos)

        if str[curr_pos] == '}'
            open_braces -= 1

            if open_braces < curr_dim
                dims[curr_dim] = el_count
                curr_dim -= 1
                el_count = 1
            end
        elseif str[curr_pos] == '{'
            open_braces += 1
        elseif str[curr_pos] == ','
            if open_braces == curr_dim
                el_count += 1
            end
        else
            if open_braces == curr_dim && el_count == 0
                el_count = 1
            end
        end
    end

    return dims
end

for pq_eltype in ("int2", "int4", "int8", "float4", "float8", "oid", "numeric")
    array_oid = PQ_SYSTEM_TYPES[Symbol("_$pq_eltype")]
    jl_type = _DEFAULT_TYPE_MAP[Symbol(pq_eltype)]
    jl_missingtype = Union{jl_type, Missing}

    # could be an OffsetArray or Array of any dimensionality
    _DEFAULT_TYPE_MAP[array_oid] = AbstractArray{jl_missingtype}

    for jl_eltype in (jl_type, jl_missingtype)
        @eval function Base.parse(
            ::Type{A}, pqv::PQValue{$array_oid}
        ) where A <: AbstractArray{$jl_eltype}
            parse_numeric_array($jl_eltype, string_view(pqv))::A
        end
    end
end

struct FallbackConversion <: AbstractDict{Tuple{Oid, Type}, Base.Callable}
end

function Base.getindex(cmap::FallbackConversion, oid_typ::Tuple{Integer, Type})
    _, typ = oid_typ

    return function parse_type(pqv::PQValue)
        parse(typ, pqv)
    end
end

Base.haskey(cmap::FallbackConversion, oid_typ::Tuple{Integer, Type}) = true

"""
A fallback conversion mapping (like [`PQConversions`](@ref) which holds a single function
for converting PostgreSQL data of a given Oid to a given Julia type, using the [`parse`](@ref)
function.
"""
const _FALLBACK_CONVERSION = FallbackConversion()
