# Outside a notebook: render a value to a standalone PDF with the typst CLI and
# open it. `typst_show` is the explicit form; at an interactive REPL a plot
# opens on its own (see ext/TypstDisplayREPLExt.jl), so chunks sent from a
# document to the REPL show their plots. Same behaviour as typst-display-matlab.

"""
    AUTO_SHOW

When `true` (the default), a [`GPlot`](@ref) shown at an interactive Julia REPL
is rendered to a PDF and opened, as by [`typst_show`](@ref). Set
`TypstDisplay.AUTO_SHOW[] = false` to print only its summary. Notebooks
(IJulia, Calepin) are unaffected: there the plot is drawn in the document.
"""
const AUTO_SHOW = Ref(true)

# How a finished PDF is opened; replaceable for tests.
const PDF_OPENER = Ref{Any}(nothing)

function _open_pdf(pdf::AbstractString)
    PDF_OPENER[] === nothing || return PDF_OPENER[](pdf)
    cmd = Sys.isapple() ? `open $pdf` :
          Sys.iswindows() ? `cmd /c start "" $pdf` : `xdg-open $pdf`
    run(pipeline(cmd; stdin = devnull, stdout = devnull, stderr = devnull); wait = false)
    return nothing
end

_typst_executable() = let bin = get(ENV, "TYPST_BIN", "")
    isempty(bin) ? something(Sys.which("typst"), "typst") : bin
end

function _show_markup(x)
    x isa TypstMarkup && return x
    for m in (MIME"text/x-typst"(), MIME"text/typst"())
        showable(m, x) && return typst_markup(x)
    end
    Tables.istable(x) && return typst_table(x)
    throw(ArgumentError("typst_show: $(typeof(x)) has no Typst representation"))
end

_length(x::TypstCode) = x.src
_length(x::AbstractString) = String(x)

"""
    typst_show(x; output = nothing, open = true, width = "16cm", margin = "0.5cm") -> String

Render `x` to a standalone PDF and open it in the default PDF viewer: the way to
see a table or plot outside a notebook. `x` is a [`GPlot`](@ref), a DataFrame or
any other table, or anything with a Typst display ([`TypstMarkup`](@ref),
[`typst_table`](@ref), [`typst_call`](@ref)).

    typst_show(df)
    typst_show(typst_table(df; digits = (sd = 5,)))
    typst_show(p)                                   # p = G.plot(...)
    pdf = typst_show(p; output = "spread.pdf", open = false)

Returns the PDF's absolute path. Without `output`, the PDF is kept in a fresh
temporary directory (so the viewer can go on reading it); the generated source
and compiler log are removed. `output` must end in `.pdf` and its directory
must exist; a successful render replaces the file, a failed one leaves it
alone.

The page is `width` wide (a Typst length) with a height that fits the content.
For table formatting pass `typst_table(df; ...)`; size plots with `G.plot`'s
`width`/`height`. Needs the Typst CLI on `PATH`, or its path in `TYPST_BIN`.
Relative imports in custom markup resolve in the temporary source directory.

At an interactive REPL a plot opens on its own; see [`AUTO_SHOW`](@ref).
"""
function typst_show(x; output::Union{Nothing,AbstractString} = nothing, open::Bool = true,
                    width = "16cm", margin = "0.5cm")
    markup = _show_markup(x)
    if output !== nothing
        lowercase(splitext(output)[2]) == ".pdf" && !isempty(splitext(basename(output))[1]) ||
            throw(ArgumentError("typst_show: output must name a .pdf file, got $(repr(output))"))
        parent = dirname(abspath(output))
        isdir(parent) ||
            throw(ArgumentError("typst_show: output directory does not exist: $parent"))
        output = joinpath(realpath(parent), basename(output))
    end
    install_typst_package()
    pdf = mktempdir() do work
        source = joinpath(work, "display.typ")
        rendered = joinpath(work, "display.pdf")
        write(source, "#set page(width: ", _length(width), ", height: auto, margin: ",
              _length(margin), ")\n", markup.src, "\n")
        # A Cmd runs without a shell, so any path is passed through unchanged.
        typst = _typst_executable()
        log = IOBuffer()
        cmd = `$typst compile --package-path $(typst_packages_dir()) $source $rendered`
        ok = try
            success(pipeline(cmd; stdin = devnull, stdout = log, stderr = log))
        catch err
            error("typst_show: could not run Typst ($typst). Install typst or set TYPST_BIN.\n",
                  sprint(showerror, err))
        end
        ok || error("typst_show: Typst compilation failed:\n", String(take!(log)))
        target = output === nothing ? joinpath(mktempdir(; cleanup = false), "display.pdf") : output
        mv(rendered, target; force = true)
        target
    end
    if open
        try
            _open_pdf(pdf)
        catch err
            @warn "typst_show: PDF saved to $pdf, but the viewer could not be opened" exception = err
        end
    end
    return pdf
end

# The REPL's display of a plot: open it (when AUTO_SHOW is on), then print the
# usual summary and where the PDF is. Called by the REPL extension.
function _repl_show(io::IO, p::GPlot)
    show(io, MIME"text/plain"(), p)
    AUTO_SHOW[] || return nothing
    try
        pdf = typst_show(p)
        print(io, "\nOpened ", pdf)
    catch err
        print(io, "\nCould not render the plot: ", sprint(showerror, err))
    end
    return nothing
end
