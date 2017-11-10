"""
    unsafe_nullable_string(ptr::Cstring) -> Nullable{String}

Convert a `Cstring` to a `Nullable{String}`, returning `Nullable{String}()` if the pointer
is `C_NULL`.
"""
function unsafe_nullable_string(ptr::Cstring)::Nullable{String}
    ptr == C_NULL ? Nullable() : unsafe_string(ptr)
end
