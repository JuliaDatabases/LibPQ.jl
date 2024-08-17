using Documenter, LibPQ, Memento

setlevel!(getlogger(LibPQ), "critical")

DocMeta.setdocmeta!(LibPQ, :DocTestSetup, quote
    using LibPQ
    DATABASE_USER = get(ENV, "LIBPQJL_DATABASE_USER", "postgres")
    conn = LibPQ.Connection("dbname=postgres user=$DATABASE_USER")
end; recursive=true)

makedocs(;
    modules=[LibPQ],
    pages=[
        "Home" => "index.md",
        "Type Conversions" => "pages/type-conversions.md",
        "API" => "pages/api.md",
        "FAQ" => "pages/faq.md",
    ],
    repo=Remotes.GitHub("JuliaDatabases", "LibPQ.jl"),
    sitename="LibPQ.jl",
    checkdocs=:exports,
    linkcheck=true,
    linkcheck_timeout=60,
    authors="Eric Davies",
)

deploydocs(;
    repo="github.com/iamed2/LibPQ.jl",
)
