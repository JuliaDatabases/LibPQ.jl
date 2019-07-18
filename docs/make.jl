using Documenter, LibPQ, Memento

setlevel!(getlogger(LibPQ), "critical")

makedocs(;
    modules=[LibPQ],
    format=Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    pages=[
        "Home" => "index.md",
        "Type Conversions" => "pages/type-conversions.md",
        "API" => "pages/api.md",
        "FAQ" => "pages/faq.md",
    ],
    repo="https://github.com/invenia/LibPQ.jl/blob/{commit}{path}#L{line}",
    sitename="LibPQ.jl",
    checkdocs=:exports,
    linkcheck=true,
    strict=true,
    authors="Eric Davies",
)

deploydocs(;
    repo="github.com/invenia/LibPQ.jl",
)
