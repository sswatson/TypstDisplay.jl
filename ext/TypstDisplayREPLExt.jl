module TypstDisplayREPLExt

using REPL: REPL
using TypstDisplay: TypstDisplay, GPlot

# At the REPL, a plot opens as a standalone PDF (TypstDisplay.AUTO_SHOW), so a
# chunk sent from a document shows its plot. Only the REPL's own display is
# overridden: notebooks (IJulia, Calepin) keep drawing the plot in place.
function Base.display(d::REPL.REPLDisplay, ::MIME"text/plain", p::GPlot)
    io = REPL.outstream(d.repl)
    TypstDisplay._repl_show(io, p)
    println(io)
    return nothing
end

end
