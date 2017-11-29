using BinDeps
using Compat

@BinDeps.setup

libpq = library_dependency("libpq")

# package managers
provides(AptGet, "libpq5", libpq)

provides(Yum, "postgresql-libs", libpq)
provides(Yum, "postgresql96-libs", libpq)
provides(Yum, "postgresql95-libs", libpq)
provides(Yum, "postgresql94-libs", libpq)

if is_apple()
    if Pkg.installed("Homebrew") === nothing
        error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")
    end
    using Homebrew
    provides(Homebrew.HB, "libpq", libpq, os = :Darwin; installed_libpath="/usr/local/opt/libpq/lib")
    provides(Homebrew.HB, "postgresql", libpq, os = :Darwin)
    provides(Homebrew.HB, "postgresql@9.6", libpq, os = :Darwin; installed_libpath="/usr/local/opt/postgresql@9.6/lib")
    provides(Homebrew.HB, "postgresql@9.5", libpq, os = :Darwin; installed_libpath="/usr/local/opt/postgresql@9.5/lib")
    provides(Homebrew.HB, "postgresql@9.4", libpq, os = :Darwin; installed_libpath="/usr/local/opt/postgresql@9.4/lib")
end

@BinDeps.install
