"""
    TypstDisplay

Render Julia values as Typst: tables become Typst tables and plots become
Gribouille plots, drawn by Typst in the document's own fonts.

Values display through the Typst MIME types, `text/x-typst` (Calepin's name)
and `text/typst` (Typstry.jl's), with identical content. A Jupyter kernel
publishes it in its display bundle, and a front end that understands it
(Calepin, with Typst pass-through for Jupyter kernels) renders the markup in
place. No chunk options or glue code needed:

    df                                     # a DataFrame -> a Typst table
    G.plot(df; mapping = G.aes(x = :n, y = :sd), layers = [G.geom_line()])

The markup imports the companion Typst package `@local/typst-display`, which
ships inside this Julia package (`typst/`) and is installed into Typst's local
package directory automatically, at the version matching this package.

For full control, write the Typst yourself and call it with [`typst_call`](@ref),
or display any markup with [`TypstMarkup`](@ref).
"""
module TypstDisplay

using Dates: Dates, Date, DateTime
using Tables: Tables

export TypstCode, @tcode_str, TypstMarkup, typst_markup, typst_literal, typst_call
export rows, pivot_longer, typst_table, G, GPlot, install_typst_package

const TYPST_MIME = MIME"text/x-typst"
# Both names are in use: `text/x-typst` by Calepin, `text/typst` by Typstry.jl.
# Every value here shows the same markup under either.
const TypstMIME = Union{MIME"text/x-typst", MIME"text/typst"}
const TYPST_MIME_NAMES = ("text/x-typst", "text/typst")

include("literal.jl")
include("typst_package.jl")
include("markup.jl")
include("tables.jl")
include("gribouille.jl")

end # module
