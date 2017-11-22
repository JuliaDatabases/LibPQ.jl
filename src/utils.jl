"""
    unsafe_string_or_null(ptr::Cstring) -> Union{String, Null}

Convert a `Cstring` to a `Union{String, Null}`, returning `null` if the pointer is `C_NULL`.
"""
function unsafe_string_or_null(ptr::Cstring)::Union{String, Null}
    ptr == C_NULL ? null : unsafe_string(ptr)
end
