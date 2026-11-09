module TypstDisplayTypstryExt

using Typstry: Typst, TypstString, TypstText
import TypstDisplay: write_literal

# Typstry values are Typst markup, so as an argument they are passed as a
# content block: `G.labels(x = typst"sample size $n$")` with Typstry's macro.
function write_literal(io::IO, x::Union{Typst, TypstString, TypstText})
    print(io, '[')
    show(io, MIME"text/typst"(), x)
    print(io, ']')
end

end
