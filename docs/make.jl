using Documenter, LibPQ

makedocs(;
    modules=[LibPQ],
    format=:html,
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/iamed2/LibPQ.jl/blob/{commit}{path}#L{line}",
    sitename="LibPQ.jl",
    authors="Eric Davies",
    assets=[],
)

deploydocs(;
    repo="github.com/iamed2/LibPQ.jl",
    target="build",
    julia="0.6",
    deps=nothing,
    make=nothing,
)
