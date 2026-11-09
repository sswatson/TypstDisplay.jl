# Julia value -> Typst source for the same value.

"""
    TypstCode(src)
    tcode"src"

Typst *code* (an expression) that [`typst_literal`](@ref) splices in verbatim
instead of quoting: lengths, colours, content blocks, function calls.

    G.geom_line(stroke = tcode"0.9pt", colour = tcode"rgb(\"#1f5f8b\")")
    G.labels(x = tcode"[sample size \$n\$]")

`tcode"..."` does not interpolate, so Typst math (`\$n\$`) and backslashes are
written as in Typst; only a `"` inside needs `\\"`.
"""
struct TypstCode
    src::String
end

macro tcode_str(s)
    TypstCode(s)
end

Base.show(io::IO, c::TypstCode) = print(io, "tcode\"", c.src, "\"")

"""
    typst_literal(x) -> String

Typst source for the Julia value `x`: numbers, strings, symbols (as strings),
booleans, `nothing`/`missing` (as `none`), `Date`/`DateTime`, vectors and
tuples (as arrays), `NamedTuple`s and `Dict`s (as dictionaries), nested to any
depth, plus [`TypstCode`](@ref) spliced verbatim.
"""
typst_literal(x) = sprint(write_literal, x)

write_literal(io::IO, x::TypstCode) = print(io, x.src)
write_literal(io::IO, ::Nothing) = print(io, "none")
write_literal(io::IO, ::Missing) = print(io, "none")
write_literal(io::IO, x::Bool) = print(io, x ? "true" : "false")

function write_literal(io::IO, x::Integer)
    # Typst integers are 64-bit; anything wider goes through as a float.
    typemin(Int64) <= x <= typemax(Int64) ? print(io, Int64(x)) : write_literal(io, Float64(x))
end

function write_literal(io::IO, x::AbstractFloat)
    # Float32(0.1) widened to Float64 prints as 0.10000000149011612; go through
    # its own shortest decimal form instead.
    f = x isa Float64 ? x : parse(Float64, string(x))
    if isnan(f)
        print(io, "float.nan")
    elseif isinf(f)
        print(io, f > 0 ? "float.inf" : "-float.inf")
    else
        # `repr` round-trips and always has a `.` or `e`, so Typst reads a float.
        print(io, repr(f))
    end
end

write_literal(io::IO, x::Rational) = write_literal(io, Float64(x))
write_literal(io::IO, x::Real) = write_literal(io, Float64(x))

function write_literal(io::IO, s::AbstractString)
    print(io, '"')
    for c in s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        elseif iscntrl(c)
            print(io, "\\u{", string(UInt32(c); base = 16), "}")
        else
            print(io, c)
        end
    end
    print(io, '"')
end

write_literal(io::IO, x::Symbol) = write_literal(io, String(x))
write_literal(io::IO, x::AbstractChar) = write_literal(io, string(x))

write_literal(io::IO, d::Date) = print(
    io, "datetime(year: ", Dates.year(d), ", month: ", Dates.month(d), ", day: ", Dates.day(d), ")",
)
write_literal(io::IO, t::DateTime) = print(
    io, "datetime(year: ", Dates.year(t), ", month: ", Dates.month(t), ", day: ", Dates.day(t),
    ", hour: ", Dates.hour(t), ", minute: ", Dates.minute(t), ", second: ", Dates.second(t), ")",
)

function write_array(io::IO, items)
    print(io, '(')
    n = 0
    for item in items
        n > 0 && print(io, ", ")
        write_literal(io, item)
        n += 1
    end
    # `(x)` is a parenthesised `x` in Typst; a one-element array needs `(x,)`.
    n == 1 && print(io, ',')
    print(io, ')')
end

write_literal(io::IO, x::AbstractArray) = write_array(io, x)
write_literal(io::IO, x::Tuple) = write_array(io, x)

function write_dict(io::IO, pairs)
    isempty(pairs) && return print(io, "(:)")
    print(io, '(')
    for (i, (k, v)) in enumerate(pairs)
        i > 1 && print(io, ", ")
        # Quoted keys are always valid, including `fig-width` or `1`.
        write_literal(io, string(k))
        print(io, ": ")
        write_literal(io, v)
    end
    print(io, ')')
end

write_literal(io::IO, x::NamedTuple) = write_dict(io, collect(pairs(x)))
write_literal(io::IO, x::AbstractDict) = write_dict(io, collect(x))

write_literal(io::IO, x) = throw(ArgumentError(
    "TypstDisplay: no Typst literal for a value of type $(typeof(x)); " *
    "convert it to a number, string, vector or NamedTuple, " *
    "or pass Typst source as tcode\"...\"",
))
