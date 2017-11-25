"""
    unsafe_string_or_null(ptr::Cstring) -> Union{String, Missing}

Convert a `Cstring` to a `Union{String, Missing}`, returning `missing` if the pointer is
`C_NULL`.
"""
function unsafe_string_or_null(ptr::Cstring)::Union{String, Missing}
    ptr == C_NULL ? missing : unsafe_string(ptr)
end
