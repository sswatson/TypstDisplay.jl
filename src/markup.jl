# Displayable Typst markup, and calls into Typst functions.

"""
    TypstMarkup(src)

Typst *markup* that displays as itself: the last value of a chunk renders as
Typst in the document. Every displayable value in this package (tables, plots,
[`typst_call`](@ref)) is one of these underneath.

    TypstMarkup("#table(columns: 2, [a], [b])")

Its plain-text display is the source, so `print(m)` writes the markup, which
also works under a chunk's `results: "typst"` in front ends without MIME
pass-through.
"""
struct TypstMarkup
    src::String
end

Base.show(io::IO, ::TypstMIME, m::TypstMarkup) = print(io, m.src)
Base.show(io::IO, m::TypstMarkup) = print(io, m.src)
Base.show(io::IO, ::MIME"text/plain", m::TypstMarkup) = print(io, m.src)

"""
    typst_markup(x) -> TypstMarkup

The Typst markup `x` displays as. Works for anything with a
`show` method for `MIME"text/x-typst"` or `MIME"text/typst"` (so Typstry.jl
values work too).
"""
function typst_markup(x)
    for m in (MIME"text/x-typst"(), MIME"text/typst"())
        showable(m, x) && return TypstMarkup(sprint(show, m, x))
    end
    throw(ArgumentError("typst_markup: $(typeof(x)) has no Typst representation"))
end
typst_markup(m::TypstMarkup) = m

# Typst identifiers use hyphens, Julia identifiers underscores: `geom_line`,
# `inherit_aes` -> `geom-line`, `inherit-aes`.
typst_name(s) = replace(String(s), '_' => '-')

"""
    TypstCall(name, args, kwargs)

A Typst function call as a value: `name(args..., kwargs...)`, with each
argument converted by [`typst_literal`](@ref) (nested calls are written as
calls). Keyword names have underscores turned into hyphens.
"""
struct TypstCall
    name::String
    args::Vector{Any}
    kwargs::Vector{Pair{Symbol,Any}}
end

TypstCall(name, args...; kwargs...) =
    TypstCall(String(name), collect(Any, args), Pair{Symbol,Any}[k => v for (k, v) in kwargs])

function write_literal(io::IO, c::TypstCall)
    print(io, c.name, '(')
    first = true
    for a in c.args
        first || print(io, ", ")
        write_literal(io, a)
        first = false
    end
    for (k, v) in c.kwargs
        first || print(io, ", ")
        print(io, typst_name(k), ": ")
        write_literal(io, v)
        first = false
    end
    print(io, ')')
end

Base.show(io::IO, c::TypstCall) = print(io, "typst: ", typst_literal(c))

"""
    typst_call(fn, args...; from = :package, kwargs...) -> TypstMarkup

Markup that calls the Typst function `fn` with Julia values as arguments. The
fallback for anything the ready-made displays don't cover: write the function
in a `.typ` file in your project and call it with your data.

`from` says where `fn` comes from:
- `:package` (default): the companion `@local/typst-display` package, which
  re-exports all of Gribouille.
- a path such as `"/plots.typ"`: a file in the Typst project (root-relative).
- `nothing`: already in scope (a Typst built-in).

Keyword names keep their spelling (Typst named arguments are usually hyphenated
already, e.g. `var"inherit-aes"`); underscores are *not* converted here, since
user functions may use them.

    typst_call("convergence-plot", data; from = "/plots.typ")
"""
function typst_call(fn, args...; from = :package, kwargs...)
    io = IOBuffer()
    if from === :package
        ensure_typst_package()
        println(io, "#import ", typst_literal(typst_package_spec()), ": *")
    elseif from !== nothing
        println(io, "#import ", typst_literal(String(from)), ": ", fn)
    end
    print(io, '#', fn, '(')
    parts = String[typst_literal(a) for a in args]
    for (k, v) in kwargs
        push!(parts, string(k, ": ", typst_literal(v)))
    end
    join(io, parts, ", ")
    print(io, ')')
    return TypstMarkup(String(take!(io)))
end
