using Documenter, LibPQ

makedocs(;
    modules=[LibPQ],
    format=:html,
    pages=[
        "Home" => "index.md",
        "API" => "pages/api.md",
    ],
    repo="https://github.com/invenia/LibPQ.jl/blob/{commit}{path}#L{line}",
    sitename="LibPQ.jl",
    authors="Eric Davies",
    assets=[],
)

deploydocs(;
    repo="github.com/invenia/LibPQ.jl",
    target="build",
    julia="0.6",
    deps=nothing,
    make=nothing,
)
