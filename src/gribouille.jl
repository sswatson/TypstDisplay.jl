# Gribouille from Julia: `G.<function>(...)` builds the Typst call of the same
# name, so the whole Gribouille API is available without a Julia wrapper per
# function, and a plot displays as a Gribouille plot drawn by Typst.

"""
    G

Gribouille, from Julia. Any `G.name(args...; kwargs...)` becomes the Typst call
`name(args..., kwargs...)`, with underscores in names turned into hyphens
(`G.geom_line` is `geom-line`, `inherit_aes` is `inherit-aes`). Gribouille's
documentation is therefore the reference: <https://m.canouil.dev/gribouille>.

`G.plot(...)` returns a [`GPlot`](@ref), which displays as the plot. A table
passed as the first argument (or as any `data` keyword, e.g. a layer's) is
sent as rows; columns are named with symbols or strings.

    G.plot(df;
        mapping = G.aes(x = :n, y = :sd, colour = :source),
        layers = [G.geom_line(), G.geom_point()],
        scales = G.scales(x = G.scale_log10(), y = G.scale_log10()),
        labels = G.labels(x = tcode"[sample size \$n\$]", y = "sd"))

Defaults (theme, width, height) come from the companion package and can be
changed per document with `#configure(...)`; anything passed explicitly wins.
"""
struct GribouilleNamespace end
const G = GribouilleNamespace()

struct GFunction
    name::String
end

Base.getproperty(::GribouilleNamespace, name::Symbol) = GFunction(typst_name(name))
Base.show(io::IO, ::GribouilleNamespace) = print(io, "G (Gribouille, rendered by Typst)")
Base.show(io::IO, f::GFunction) = print(io, "G.", replace(f.name, '-' => '_'))

"""A Gribouille plot as a Julia value; displays as the plot. See [`G`](@ref)."""
struct GPlot
    call::TypstCall
end

_as_data(x) = Tables.istable(x) ? rows(x) : x

function (f::GFunction)(args...; kwargs...)
    args = collect(Any, args)
    kw = Pair{Symbol,Any}[k => (k === :data ? _as_data(v) : v) for (k, v) in kwargs]
    if f.name == "plot"
        # `plot(df; ...)`: Gribouille takes the data as `data:`.
        if !isempty(args) && Tables.istable(args[1])
            any(p -> first(p) === :data, kw) &&
                throw(ArgumentError("G.plot: data given both positionally and as `data`"))
            pushfirst!(kw, :data => _as_data(popfirst!(args)))
        end
        return GPlot(TypstCall(f.name, args, kw))
    end
    return TypstCall(f.name, args, kw)
end

write_literal(io::IO, p::GPlot) = write_literal(io, p.call)

function typst_markup(p::GPlot)
    ensure_typst_package()
    return TypstMarkup(string(
        "#import ", typst_literal(typst_package_spec()), ": *\n#", typst_literal(p.call),
    ))
end

Base.show(io::IO, m::TypstMIME, p::GPlot) = show(io, m, typst_markup(p))

function Base.show(io::IO, ::MIME"text/plain", p::GPlot)
    data = something(findfirst(kv -> first(kv) === :data, p.call.kwargs), 0)
    n = data == 0 ? 0 : length(last(p.call.kwargs[data]))
    print(io, "GPlot (Gribouille, $n rows of data); displays as a plot in Typst.\n",
          "Typst source: typst_markup(plot)")
end
Base.show(io::IO, p::GPlot) = print(io, "GPlot(", length(p.call.kwargs), " arguments)")
