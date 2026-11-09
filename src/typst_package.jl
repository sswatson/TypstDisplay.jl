# The companion Typst package lives in this repository (`typst/`) and is copied
# into Typst's local package directory, at the version its `typst.toml`
# declares. Every emitted import names that same version, so the Julia and
# Typst halves can never drift apart.

const TYPST_PACKAGE_NAME = "typst-display"
const TYPST_SOURCE_DIR = normpath(joinpath(@__DIR__, "..", "typst"))

function _read_typst_version()
    for line in eachline(joinpath(TYPST_SOURCE_DIR, "typst.toml"))
        m = match(r"^\s*version\s*=\s*\"([^\"]+)\"", line)
        m === nothing || return String(m.captures[1])
    end
    error("TypstDisplay: no version in $(joinpath(TYPST_SOURCE_DIR, "typst.toml"))")
end

const TYPST_PACKAGE_VERSION = _read_typst_version()

"""The `#import` path for the companion package, e.g. `@local/typst-display:0.1.0`."""
typst_package_spec() = "@local/$(TYPST_PACKAGE_NAME):$(TYPST_PACKAGE_VERSION)"

"""
    typst_packages_dir()

Typst's package directory; `@local` packages live in its
`local/<name>/<version>` subfolder. `TYPST_PACKAGE_PATH` overrides it (the same
variable the `typst` CLI reads).
"""
function typst_packages_dir()
    haskey(ENV, "TYPST_PACKAGE_PATH") && return ENV["TYPST_PACKAGE_PATH"]
    data = if Sys.isapple()
        joinpath(homedir(), "Library", "Application Support")
    elseif Sys.iswindows()
        get(ENV, "APPDATA", joinpath(homedir(), "AppData", "Roaming"))
    else
        get(ENV, "XDG_DATA_HOME", joinpath(homedir(), ".local", "share"))
    end
    return joinpath(data, "typst", "packages")
end

typst_package_target() =
    joinpath(typst_packages_dir(), "local", TYPST_PACKAGE_NAME, TYPST_PACKAGE_VERSION)

function _relative_files(root)
    files = String[]
    for (dir, _, names) in walkdir(root), name in names
        push!(files, relpath(joinpath(dir, name), root))
    end
    return sort!(files)
end

function _same_tree(a, b)
    isdir(b) || return false
    fa = _relative_files(a)
    fa == _relative_files(b) || return false
    return all(f -> read(joinpath(a, f)) == read(joinpath(b, f)), fa)
end

const _installed = Ref(false)

"""
    install_typst_package(; force = false) -> String

Copy the bundled Typst package into Typst's local package directory (see
[`typst_packages_dir`](@ref)), unless an identical copy is already there.
Returns the installed path. Called automatically the first time a value is
rendered in a session; call it yourself to make the package available to an
editor (Tinymist) before any Julia code has run.
"""
function install_typst_package(; force::Bool = false)
    target = typst_package_target()
    if force || !_same_tree(TYPST_SOURCE_DIR, target)
        mkpath(dirname(target))
        # Copy next to the target, then swap, so a concurrent `typst compile`
        # never sees a half-written package.
        staging = target * ".staging-" * string(getpid())
        rm(staging; force = true, recursive = true)
        cp(TYPST_SOURCE_DIR, staging)
        rm(target; force = true, recursive = true)
        mv(staging, target)
    end
    _installed[] = true
    return target
end

ensure_typst_package() = _installed[] || install_typst_package()
