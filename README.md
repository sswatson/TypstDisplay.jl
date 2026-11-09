# TypstDisplay.jl

Render Julia values as native Typst in a literate Typst notebook: a DataFrame
becomes a Typst table, and a plot described in Julia becomes a
[Gribouille](https://m.canouil.dev/gribouille) plot. Typst draws both, in the
document's own fonts, sizes and math. There are no image files and no glue code:
the value at the end of a chunk is what appears.

````typ
#calepin.chunk(label: "fig-spread", fig-caption: [Spread of the estimator.])[
```julia
G.plot(df;
    mapping = G.aes(x = :n, y = :sd, colour = :source),
    layers = [G.geom_line(), G.geom_point()],
    scales = G.scales(x = G.scale_log10(), y = G.scale_log10()),
    labels = G.labels(x = tcode"[sample size $n$]", y = "sd"))
```
]

#calepin.chunk(label: "tbl-spread", tbl-caption: [The same numbers.])[
```julia
df
```
]
````

There is a MATLAB twin, [typst-display-matlab](../typst-display-matlab), with
the same API in MATLAB spelling. It vendors this repository's `typst/` package,
which stays canonical here: edit it here, bump its version, and run that
repository's `scripts/sync-typst-package.sh`.

The repository holds both halves:

```
Project.toml, src/, ext/   the Julia package (ext/: DataFrames, IJulia, REPL, Typstry)
typst/                     the Typst package `@local/typst-display`
test/                      tests, including compiling the output with real typst
```

## How it works

1. **Julia side.** Values with a Typst `show` method display as Typst markup.
   Two MIME names are in use: `text/x-typst` (Calepin's) and `text/typst`
   ([Typstry.jl](https://github.com/jakobjpeters/Typstry.jl)'s). This package
   shows the same markup under both, for its plot and table types and, through
   a package extension, for DataFrames. A second extension registers both
   names with IJulia, so a kernel publishes the markup in its display bundles
   next to `text/plain`.
2. **Front end.** A notebook tool that understands either name renders the
   markup in place. Automatic display requires Calepin with Typst MIME
   pass-through support (see [Calepin](#calepin) below).
3. **Typst side.** The markup imports `@local/typst-display:<version>`, which
   re-exports Gribouille (pinned) with a `plot` that applies the document's
   defaults, and provides `data-table` for tables. The Typst package ships
   inside the Julia package, and the Julia package copies it into Typst's local
   package directory the first time it renders anything (or when you call
   `TypstDisplay.install_typst_package()`). The emitted import names the
   version read from `typst/typst.toml`, so the two halves cannot drift apart.

## Julia API

| | |
|---|---|
| `G.name(args...; kw...)` | The Gribouille function `name`, with underscores turned into hyphens (`G.geom_line` is `geom-line`, `inherit_aes` is `inherit-aes`). Every Gribouille function works, and Gribouille's docs are the reference. `G.plot(...)` returns a `GPlot`, which displays as the plot. A table passed first, or as any `data` keyword, is sent as rows |
| `tcode"..."` / `TypstCode` | Typst code spliced in verbatim: `tcode"0.9pt"`, `tcode"rgb(\"#1f5f8b\")"`, `tcode"[sample size $n$]"`. It does not interpolate, so `$` is literal |
| Typstry.jl values | Interoperate when both packages are loaded. As an argument, a Typstry value (e.g. Typstry's own `typst"sample size $n$"`) is passed as a content block. Displayed, it renders through Calepin like any other Typst value. Ours is `tcode"..."` so the two string macros don't collide |
| a DataFrame | Displays as a table (booktabs rules, numbers right-aligned, floats rounded per column) |
| `typst_table(t; digits, align, max_rows)` | Any Tables.jl table as a table, with per-column overrides: `digits = (sd = 5,)` |
| `typst_call(fn, args...; from, kw...)` | **The fallback.** Calls a Typst function with Julia data. `from = "/plots.typ"` imports it from a project file; the default imports from this package; `from = nothing` means it is already in scope |
| `TypstMarkup(src)` | Any Typst markup, displayed as is |
| `rows(t)`, `rows(; cols...)` | Any table as a vector of row `NamedTuple`s, the shape Gribouille's `data` takes |
| `pivot_longer(t, cols; names_to, values_to)` | Wide to long, so several series share one `colour` mapping |
| `typst_literal(x)` | The Typst source for a Julia value (numbers, strings, symbols, `nothing`/`missing`, dates, arrays, `NamedTuple`/`Dict`, nested) |
| `typst_markup(x)` | The markup `x` displays as, for inspection |
| `typst_show(x; output, open, width, margin)` | Render a standalone PDF and open it; returns its path. See below |

A `GPlot`'s plain-text display is a short summary. Use `typst_markup(p)` to
see the generated Typst.

## Outside a notebook: standalone PDFs

At an interactive REPL, a plot opens as a PDF in your default viewer. So
sending a chunk from a document to the REPL (vim-slime and the like) shows its
plot, as the notebook would. Tables still print as text there; open one with
`typst_show`:

```julia
typst_show(df)
typst_show(typst_table(df; digits = (sd = 5,)))
typst_show(p)                                       # p = G.plot(...)
pdf = typst_show(p; output = "spread.pdf", open = false)
```

`typst_show(x; output, open = true, width = "16cm", margin = "0.5cm")` takes a
`GPlot`, any table, or anything with a Typst display, and returns the PDF's
absolute path. The page is `width` wide, with a height that fits the content.
Without `output`, the PDF goes in a fresh temporary directory, which is kept so
the viewer can go on reading it; the source and compiler log are removed. An
`output` must end in `.pdf` and its directory must exist. A successful render
replaces that file; a failed one leaves it alone. It needs the Typst CLI on
`PATH`, or its path in `TYPST_BIN`.

The REPL behaviour comes from a package extension on the `REPL` standard
library, and it overrides only the REPL's own display, so notebooks (IJulia,
Calepin) are unaffected. `TypstDisplay.AUTO_SHOW[] = false` turns it off. A
project whose `Manifest.toml` predates this needs `Pkg.resolve()` once, so
Julia sees the extension. [typst-display-matlab](../typst-display-matlab) has
the same `typst_show`.

## Typst API (`@local/typst-display`)

Everything Gribouille exports, plus:

| | |
|---|---|
| `configure(..)` | Defaults for every table and plot after this point: `theme` (`auto`: `default-theme` at the current text size; `none`: leave it to Gribouille's `theme-set`), `plot-width` (`auto`, the text width), `plot-height` (6.5cm), `digits` (significant digits for a float column's largest value; 4), `max-rows` (50), `missing`, `header-weight`, `table-size` |
| `plot(..)` | Gribouille's `plot` with the configured defaults; explicit arguments win. `as-spec: true` (for `compose`) bypasses it |
| `default-theme(base:)` | The default theme, sized relative to `base` |
| `data-table(spec)` | The table renderer the Julia side calls |

Hand-written plots in a project (`plots.typ`) should import this package rather
than Gribouille directly, so they share the theme:

```typ
#import "@local/typst-display:0.1.0": *
#let ratio-plot(data) = plot(data: data, mapping: aes(x: "n", y: "ratio"), layers: (geom-line(),))
```

## Using it in a project

Requires Julia 1.10 or later and Typst 0.15 or later on `PATH`. The first
Typst compile downloads Gribouille and its dependencies from Typst Universe.

**Julia.** Install from GitHub (the package is not yet in the General registry):

```julia
using Pkg
Pkg.add(url = "https://github.com/sswatson/TypstDisplay.jl")
```

For local development, use `Pkg.develop(path = "/path/to/TypstDisplay.jl")`.

`Pkg.add(url = ...)` pins the exact commit in the project's `Manifest.toml`,
so a project keeps working when this repository moves on. If you end up with
several such packages, a personal registry
([LocalRegistry.jl](https://github.com/GunnarFarneback/LocalRegistry.jl)) gives
version numbers and `Pkg.add("TypstDisplay")` instead of URLs.

**Typst.** Nothing to install: the Julia package installs its Typst half. One
exception: if the document itself imports `@local/typst-display` (for
`configure`), install it before the first compile, because a front end may
compile the document before any Julia runs. Add this to the project's setup
step:

```julia
using TypstDisplay; TypstDisplay.install_typst_package()
```

## Calepin

Automatic display of the last value in a Julia chunk requires a Calepin build
with Typst MIME pass-through support. The integration was developed with a
local patch to [Calepin](https://github.com/vincentarelbundock/calepin); that
patch is not included in this repository. It forwards `text/x-typst` or
`text/typst` display bundles and wraps figure output with its caption and label.

With a Calepin build without that support, use `results: "typst"` and print the
markup explicitly:

````typ
#calepin.chunk(results: "typst")[
```julia
using TypstDisplay
print(typst_table((; n = [100, 1000], sd = [0.1762, 0.05157])))
```
]
````

For plots, use `print(typst_markup(p))`. For DataFrames, use
`print(typst_markup(df))` or `print(typst_table(df))`.

## Why it is built this way

- **MIME display, not printing.** A value that knows how to render itself is
  what makes "the last value is the output" work. Printing needs a chunk
  option and breaks when output is split across several writes.
- **Data crosses the boundary; drawing stays in Typst.** Julia sends values,
  and Typst decides fonts, number formatting and theme, so tables and plots
  follow the document and `configure`.
- **`G` mirrors Gribouille generically** instead of wrapping each function, so
  the Julia side never falls behind Gribouille's API.
- **The Typst package ships inside the Julia package,** so one install gives
  both, at matching versions. There is no separate install script.

## Development

```sh
julia --project=. -e 'using Pkg; Pkg.test()'   # needs `typst` on PATH for the compile tests
```

To release a change to the Typst side, bump `version` in `typst/typst.toml`
(and in `Project.toml`) together. Documents that import the package directly
name a version, so keep old versions installed or update those imports.

## License

MIT; see [LICENSE](LICENSE).
