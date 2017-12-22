# wrapper for value
struct PQValue{OID}
    jl_result::Result

    # 0-indexed
    row::Cint
    col::Cint

    function PQValue{OID}(jl_result::Result, row::Integer, col::Integer) where OID
        return new{OID}(jl_result, row - 1, col - 1)
    end
end

function PQValue(jl_result::Result, row::Integer, col::Integer)
    oid = libpq_c.PQftype(jl_result.result, col - 1)

    return PQValue{oid}(jl_result, row, col)
end

# strlen
num_bytes(pqv::PQValue) = libpq_c.PQgetlength(pqv.jl_result.result, pqv.row, pqv.col)

data_pointer(pqv::PQValue) = libpq_c.PQgetvalue(pqv.jl_result.result, pqv.row, pqv.col)

function Base.unsafe_string(pqv::PQValue)
    return unsafe_string(data_pointer(pqv), num_bytes(pqv))
end

function string_view(pqv::PQValue)
    return String(unsafe_wrap(Vector{UInt8}, data_pointer(pqv), num_bytes(pqv)))
end

# includes null
bytes_view(pqv::PQValue) = unsafe_wrap(Vector{UInt8}, data_pointer(pqv), num_bytes(pqv) + 1)

Base.String(pqv::PQValue) = unsafe_string(pqv)
Base.parse(::Type{String}, pqv::PQValue) = unsafe_string(pqv)
Base.convert(::Type{String}, pqv::PQValue) = String(pqv)
Base.length(pqv::PQValue) = length(string_view(pqv))
Base.endof(pqv::PQValue) = endof(string_view(pqv))

# fallback, because Base is bad with string iteration
Base.parse(::Type{T}, pqv::PQValue) where {T} = parse(T, string_view(pqv))

function Base.start(pqv::PQValue)
    sv = string_view(pqv)
    return (sv, start(sv))
end

function Base.next(pqv::PQValue, state)
    sv, sv_state = state
    c, new_sv_state = next(sv, sv_state)
    return c, (sv, new_sv_state)
end

function Base.done(pqv::PQValue, state)
    sv, sv_state = state
    return done(sv, sv_state)
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
Base.parse(::Type{String}, pqv::PQValue{PQ_SYSTEM_TYPES[:bpchar]}) = rstrip(pqv, ' ')
# char is "char"
_DEFAULT_TYPE_MAP[:char] = PQChar
Base.parse(::Type{PQChar}, pqv::PQValue{PQ_SYSTEM_TYPES[:char]}) = PQChar(first(pqv))
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

    if ismatch(BOOL_TRUE, str)
        return true
    elseif ismatch(BOOL_FALSE, str)
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

    return parse(DateTime, str, TIMESTAMP_FORMAT)
end

# ISO, YMD
_DEFAULT_TYPE_MAP[:timestamptz] = ZonedDateTime
const TIMESTAMPTZ_FORMATS = (
    dateformat"y-m-d HH:MM:SSz",
    dateformat"y-m-d HH:MM:SS.sz",
    dateformat"y-m-d HH:MM:SS.ssz",
    dateformat"y-m-d HH:MM:SS.sssz",
    dateformat"y-m-d HH:MM:SS.ssssz",
    dateformat"y-m-d HH:MM:SS.sssssz",
    dateformat"y-m-d HH:MM:SS.ssssssz",
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

    return parse(ZonedDateTime, str, TIMESTAMPTZ_FORMATS[end])
end

## arrays
# numeric arrays never have double quotes and always use ',' as a separator
function parse_numeric_array(eltype::Type{T}, str::AbstractString) where T
    eq_ind = searchindex(str, '=')

    if eq_ind > 0
        offset_str = str[1:eq_ind-1]
        range_strs = split(str[1:eq_ind-1], ['[',']']; keep=false)

        ranges = map(range_strs) do range_str
            lower, upper = split(range_str, ':'; limit=2)
            return parse(Int, lower):parse(Int, upper)
        end

        arr = OffsetArray(T, ranges...)
    else
        arr = Array{T}(array_size(str)...)
    end

    idx_iter = imap(reverse, product(reverse(indices(arr))...))
    el_iter = eachmatch(r"[^\}\{,]+", str[eq_ind+1:end])
    for (idx, num_match) in zip(idx_iter, el_iter)
        arr[idx...] = parse(T, num_match.match)
    end

    return arr
end

function array_size(str)
    ndims = findfirst(c -> c != '{', str) - 1
    dims = zeros(Int, ndims)

    curr_dim = ndims
    curr_pos = ndims
    open_braces = ndims
    last_ind = endof(str)
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
    jl_eltype = _DEFAULT_TYPE_MAP[Symbol(pq_eltype)]

    # could be an OffsetArray or Array of any dimensionality
    _DEFAULT_TYPE_MAP[array_oid] = AbstractArray{jl_eltype}

    @eval function Base.parse(::Type{AbstractArray{$jl_eltype}}, pqv::PQValue{$array_oid})
        parse_numeric_array($jl_eltype, string_view(pqv))
    end
end


struct FallbackConversion <: Associative{Tuple{Oid, Type}, Base.Callable}
end

function Base.getindex(cmap::FallbackConversion, oid_typ::Tuple{Integer, Type})
    _, typ = oid_typ

    return function parse_type(pqv::PQValue)
        parse(typ, pqv)
    end
end

Base.haskey(cmap::FallbackConversion, oid_typ::Tuple{Integer, Type}) = true

const _FALLBACK_CONVERSION = FallbackConversion()
