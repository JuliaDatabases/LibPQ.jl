using Base: depwarn

const INF_WARN = Ref(false)

function timetype_inf_warning()
    if !INF_WARN[]
        depwarn("`infinity` support for Dates.TimeType is deprecated. Use `InfExtendedTime{T}` instead", :timetype_inf_warning)
        INF_WARN[] = true
    end
end
