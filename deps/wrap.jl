ENV["PATH"] = "/usr/local/opt/llvm/bin:$(ENV["PATH"])"

using Clang

cd(Pkg.dir("LibPQ", "src", "headers"))

context = wrap_c.init(;
    clang_includes=["/usr/local/opt/libpq/include"],
    common_file="libpq_common.jl",
)

context.headers = [
    "/usr/local/opt/libpq/include/libpq-fe.h",
]

run(context)
