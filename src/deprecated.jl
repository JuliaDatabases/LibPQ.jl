using Base: depwarn

const INF_WARN = Ref(false)

function depwarn_timetype_inf()
    if !INF_WARN[]
        depwarn(
            "`infinity` support for $(Dates.TimeType) is deprecated. Use `$InfExtendedTime` instead",
            :depwarn_timetype_inf,
        )
        INF_WARN[] = true
    end
end
