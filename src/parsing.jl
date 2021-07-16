"A wrapper for one value in a PostgreSQL result."
struct PQValue{OID,BinaryFormat}
    "PostgreSQL result"
    jl_result::Result

    "Row index of the result (0-indexed)"
    row::Cint

    "Column index of the result (0-indexed)"
    col::Cint

    function PQValue{OID}(
        jl_result::Result{BinaryFormat}, row::Integer, col::Integer
    ) where {OID,BinaryFormat}
        return new{OID,BinaryFormat}(jl_result, row - 1, col - 1)
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

# bytes_view(pqv::PQValue) = bswap(unsafe_load(data_pointer(pq_value_bin)))

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

You can implement default PostgreSQL-specific parsing for a given type by overriding
`pqparse`.
"""
Base.parse(::Type{T}, pqv::PQValue) where {T} = pqparse(T, string_view(pqv))

"""
    LibPQ.pqparse(::Type{T}, str::AbstractString) -> T

Parse a value of type `T` from any `AbstractString`.
This is used to parse PostgreSQL's output format.
"""
function pqparse end

# Fallback method
pqparse(::Type{T}, str::AbstractString) where {T} = parse(T, str)

# allow parsing as a Symbol anything which works as a String
pqparse(::Type{Symbol}, str::AbstractString) = Symbol(str)

## integers
_DEFAULT_TYPE_MAP[:int2] = Int16
_DEFAULT_TYPE_MAP[:int4] = Int32
_DEFAULT_TYPE_MAP[:int8] = Int64

for int_sym in (:int2, :int4, :int8)
    @eval function Base.parse(
        ::Type{T}, pqv::PQValue{$(oid(int_sym)),BINARY}
    ) where {T<:Number}
        return convert(
            T, ntoh(unsafe_load(Ptr{$(_DEFAULT_TYPE_MAP[int_sym])}(data_pointer(pqv))))
        )
    end
end

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
function Base.parse(::Type{String}, pqv::PQValue{PQ_SYSTEM_TYPES[:bpchar],TEXT})
    return String(rstrip(string_view(pqv), ' '))
end
# char is "char"
_DEFAULT_TYPE_MAP[:char] = PQChar
pqparse(::Type{PQChar}, str::AbstractString) = PQChar(first(str))
pqparse(::Type{Char}, str::AbstractString) = Char(pqparse(PQChar, str))
# varchar, text, and name are all String

## binary data

_DEFAULT_TYPE_MAP[:bytea] = Vector{UInt8}

# Needs it's own `parse` method as it uses bytes_view instead of string_view
function Base.parse(::Type{Vector{UInt8}}, pqv::PQValue{PQ_SYSTEM_TYPES[:bytea],TEXT})
    return pqparse(Vector{UInt8}, bytes_view(pqv))
end

function pqparse(::Type{Vector{UInt8}}, bytes::Array{UInt8,1})
    byte_length = Ref{Csize_t}(0)

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
function pqparse(::Type{Bool}, str::AbstractString)
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

# Cut off digits after the third after the decimal point,
# since DateTime in Julia currently handles only milliseconds
# see https://github.com/invenia/LibPQ.jl/issues/33
_trunc_seconds(str) = replace(str, r"(\.[\d]{3})\d+" => s"\g<1>")

_DEFAULT_TYPE_MAP[:timestamp] = DateTime
const TIMESTAMP_FORMAT = dateformat"y-m-d HH:MM:SS.s"  # .s is optional here
function pqparse(::Type{DateTime}, str::AbstractString)
    if str == "infinity"
        depwarn_timetype_inf()
        return typemax(DateTime)
    elseif str == "-infinity"
        depwarn_timetype_inf()
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
function pqparse(::Type{ZonedDateTime}, str::AbstractString)
    if str == "infinity"
        depwarn_timetype_inf()
        return ZonedDateTime(typemax(DateTime), tz"UTC")
    elseif str == "-infinity"
        depwarn_timetype_inf()
        return ZonedDateTime(typemin(DateTime), tz"UTC")
    end

    for fmt in TIMESTAMPTZ_FORMATS[1:(end - 1)]
        parsed = tryparse(ZonedDateTime, str, fmt)
        parsed !== nothing && return parsed
    end

    return parse(ZonedDateTime, _trunc_seconds(str), TIMESTAMPTZ_FORMATS[end])
end

_DEFAULT_TYPE_MAP[:date] = Date
function pqparse(::Type{Date}, str::AbstractString)
    if str == "infinity"
        depwarn_timetype_inf()
        return typemax(Date)
    elseif str == "-infinity"
        depwarn_timetype_inf()
        return typemin(Date)
    end

    return parse(Date, str)
end

_DEFAULT_TYPE_MAP[:time] = Time
function pqparse(::Type{Time}, str::AbstractString)
    try
        return parse(Time, str)
    catch err
        if !(err isa InexactError)
            rethrow(err)
        end
    end

    return parse(Time, _trunc_seconds(str))
end

# InfExtendedTime support for Dates.TimeType
function pqparse(::Type{InfExtendedTime{T}}, str::AbstractString) where {T<:Dates.TimeType}
    if str == "infinity"
        return InfExtendedTime{T}(∞)
    elseif str == "-infinity"
        return InfExtendedTime{T}(-∞)
    end

    return InfExtendedTime{T}(pqparse(T, str))
end

# UNIX timestamps
function Base.parse(::Type{DateTime}, pqv::PQValue{PQ_SYSTEM_TYPES[:int8],TEXT})
    return unix2datetime(parse(Int64, pqv))
end

function Base.parse(::Type{ZonedDateTime}, pqv::PQValue{PQ_SYSTEM_TYPES[:int8],TEXT})
    return TimeZones.unix2zdt(parse(Int64, pqv))
end

## intervals
# iso_8601
_DEFAULT_TYPE_MAP[:interval] = Dates.CompoundPeriod
const INTERVAL_REGEX = Ref{Regex}()  # set at __init__

function _interval_regex()
    function _field_match(period_type, number_match="-?\\d+")
        name = nameof(period_type)
        letter = first(String(name))
        return "(?:(?<$name>$number_match)$letter)?"
    end

    io = IOBuffer()
    print(io, "^P")
    for long_type in (Year, Month, Day)
        print(io, _field_match(long_type))
    end
    print(io, "(?:T")
    for long_type in (Hour, Minute)
        print(io, _field_match(long_type))
    end
    print(
        io,
        _field_match(Second, "(?<whole_seconds>-?\\d+)(?:\\.(?<frac_seconds>\\d{1,9}))?"),
    )
    print(io, ")?\$")

    return Regex(String(take!(io)))
end

# parse the iso_8601 interval output format
# https://www.postgresql.org/docs/10/datatype-datetime.html#DATATYPE-INTERVAL-OUTPUT
function pqparse(::Type{Dates.CompoundPeriod}, str::AbstractString)
    interval_regex = INTERVAL_REGEX[]
    matched = match(interval_regex, str)

    if matched === nothing
        error("Couldn't parse $str as interval using regex $interval_regex")
    end

    periods = Period[]
    sizehint!(periods, 7)
    for period_type in (Year, Month, Day, Hour, Minute)
        period_str = matched[nameof(period_type)]
        if period_str !== nothing
            push!(periods, period_type(parse(Int, period_str)))
        end
    end

    if matched["Second"] !== nothing
        whole_seconds_str = matched["whole_seconds"]
        whole_seconds = parse(Int, whole_seconds_str)
        if whole_seconds != 0
            push!(periods, Second(whole_seconds))
        end

        #=
        We need to parse the fractional seconds as a period.
        Here we try to keep to the largest period type possible for representing the
        fractional seconds.

        For example, 1 is 100 Milliseconds, but 0001 is 100 Microseconds
        =#
        frac_seconds_str = matched["frac_seconds"]
        if frac_seconds_str !== nothing
            len = length(frac_seconds_str)
            frac_periods = [Millisecond, Microsecond, Nanosecond]
            period_coeff = fld1(len, 3)
            period_type = frac_periods[period_coeff]  # field regex prevents BoundsError

            frac_seconds = parse(Int, frac_seconds_str) * 10^(3 * period_coeff - len)
            if frac_seconds != 0
                push!(periods, period_type(frac_seconds))
            end
        end
    end

    return Dates.CompoundPeriod(periods)
end

## ranges
_DEFAULT_TYPE_MAP[:int4range] = Interval{Int32}
_DEFAULT_TYPE_MAP[:int8range] = Interval{Int64}
_DEFAULT_TYPE_MAP[:numrange] = Interval{Decimal}
_DEFAULT_TYPE_MAP[:tsrange] = Interval{DateTime}
_DEFAULT_TYPE_MAP[:tstzrange] = Interval{ZonedDateTime}
_DEFAULT_TYPE_MAP[:daterange] = Interval{Date}

function pqparse(::Type{Interval{T}}, str::AbstractString) where {T}
    str == "empty" && return Interval{T}()
    return parse(Interval{T}, str; element_parser=pqparse)
end

## arrays
# numeric arrays never have double quotes and always use ',' as a separator
parse_numeric_element(::Type{T}, str) where {T} = parse(T, str)

function parse_numeric_element(::Type{Union{T,Missing}}, str) where {T}
    return str == "NULL" ? missing : parse(T, str)
end

function parse_numeric_array(eltype::Type{T}, str::AbstractString) where {T}
    eq_ind = findfirst(isequal('='), str)

    if eq_ind !== nothing
        offset_str = str[1:(eq_ind - 1)]
        range_strs = split(str[1:(eq_ind - 1)], ['[', ']']; keepempty=false)

        ranges = map(range_strs) do range_str
            lower, upper = split(range_str, ':'; limit=2)
            return parse(Int, lower):parse(Int, upper)
        end

        arr = OffsetArray{T}(undef, ranges...)
        el_iter = eachmatch(r"[^\}\{,]+", str[(eq_ind + 1):end])
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
    jl_missingtype = Union{jl_type,Missing}

    # could be an OffsetArray or Array of any dimensionality
    _DEFAULT_TYPE_MAP[array_oid] = AbstractArray{jl_missingtype}

    for jl_eltype in (jl_type, jl_missingtype)
        @eval function pqparse(
            ::Type{A}, str::AbstractString
        ) where {A<:AbstractArray{$jl_eltype}}
            return parse_numeric_array($jl_eltype, str)::A
        end
    end
end

struct FallbackConversion <: AbstractDict{Tuple{Oid,Type},Base.Callable} end

function Base.getindex(cmap::FallbackConversion, oid_typ::Tuple{Integer,Type})
    _, typ = oid_typ

    return function parse_type(pqv::PQValue)
        return parse(typ, pqv)
    end
end

Base.haskey(cmap::FallbackConversion, oid_typ::Tuple{Integer,Type}) = true

"""
A fallback conversion mapping (like [`PQConversions`](@ref) which holds a single function
for converting PostgreSQL data of a given Oid to a given Julia type, using the [`parse`](@ref)
function.
"""
const _FALLBACK_CONVERSION = FallbackConversion()
