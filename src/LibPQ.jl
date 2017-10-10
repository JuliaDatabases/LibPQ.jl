module LibPQ

module libpq_c
    function __init__()
        const global LIBPQ_HANDLE = :libpq
    end

    include(joinpath(@__DIR__, "headers", "libpq-fe.jl"))
end

@enum ConninfoDiplay Normal Password Debug

function Base.parse(::Type{ConninfoDiplay}, str::AbstractString)::ConninfoDiplay
    if length(str) < 1
        Normal
    elseif first(str) == '*'
        Password
    elseif first(str) == 'D'
        Debug
    else
        error("Unexpected dispchar in PQconninfoOption")
    end
end

function unsafe_nullable_string(ptr::Cstring)::Nullable{String}
    ptr == C_NULL ? Nullable() : unsafe_string(ptr)
end

struct ConnectionOption
    keyword::String
    envvar::Nullable{String}
    compiled::Nullable{String}
    val::Nullable{String}
    label::String
    disptype::ConninfoDiplay
    dispsize::Int
end

function ConnectionOption(pq_opt::libpq_c.PQconninfoOption)
    ConnectionOption(
        unsafe_string(pq_opt.keyword),
        unsafe_nullable_string(pq_opt.envvar),
        unsafe_nullable_string(pq_opt.compiled),
        unsafe_nullable_string(pq_opt.val),
        unsafe_string(pq_opt.label),
        parse(ConninfoDiplay, unsafe_string(pq_opt.dispchar)),
        pq_opt.dispsize,
    )
end

struct Connection
    conn::Ptr{libpq_c.PGconn}
end

function Connection(str::AbstractString)
    Connection(libpq_c.PQconnectdb(str))
end

function conninfo(jl_conn::Connection)
    ci_array = Vector{ConnectionOption}()

    ci_ptr = libpq_c.PQconninfo(jl_conn.conn)
    ci_ptr == C_NULL && error("libpq could not allocate memory for connection info")

    ci_opt_idx = 1
    ci_opt = unsafe_load(ci_ptr, ci_opt_idx)
    while ci_opt.keyword != C_NULL
        push!(ci_array, ConnectionOption(ci_opt))

        ci_opt_idx += 1
        ci_opt = unsafe_load(ci_ptr, ci_opt_idx)
    end

    libpq_c.PQconninfoFree(ci_ptr)

    return ci_array
end

function Base.show(io::IO, jl_conn::Connection)
    print("PostgreSQL connection with parameters:")
    for ci_opt in conninfo(jl_conn)
        if !isnull(ci_opt.val) && ci_opt.disptype != Debug
            print("\n  ", ci_opt.keyword, " = ")

            if ci_opt.disptype == Password
                print("*" ^ ci_opt.dispsize)
            else
                print(get(ci_opt.val))
            end
        end
    end
end

end
