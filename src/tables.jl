# Tables: reshaping helpers, and tables rendered as Typst tables.

"""
    rows(table) -> Vector{NamedTuple}

Row-oriented copy of any Tables.jl table (a DataFrame, a `NamedTuple` of
column vectors, a vector of `NamedTuple`s, ...), which is the shape Gribouille's
`data:` takes. Also `rows(; n = sizes, sd = spread)`.
"""
rows(table) = Tables.rowtable(table)
rows(; cols...) = rows(NamedTuple(cols))

"""
    pivot_longer(table, cols; names_to = :series, values_to = :value)

Wide to long, like tidyr's `pivot_longer`: each column in `cols` becomes rows
tagged with that column's name in `names_to`. Use it to give several series one
`colour`/`linetype` mapping.

    pivot_longer((; n = sizes, empirical = spread, theory), [:empirical, :theory];
                 names_to = :source, values_to = :sd)
"""
function pivot_longer(table, cols; names_to = :series, values_to = :value)
    cols = Tuple(Symbol.(cols))
    out = NamedTuple[]
    for col in cols, row in rows(table)
        ids = Base.structdiff(NamedTuple(row), NamedTuple{cols})
        push!(out, merge(ids, NamedTuple{(Symbol(names_to), Symbol(values_to))}((String(col), row[col]))))
    end
    return out
end

"""Maximum rows sent to Typst for one table; the rest are only counted."""
const MAX_TABLE_ROWS = Ref(1000)

_column_kind(::Type{Union{}}) = "string"
function _column_kind(T::Type)
    S = nonmissingtype(T)
    S === Nothing && return "string"
    S <: Bool && return "bool"
    S <: Integer && return "int"
    S <: Real && return "float"
    S <: Union{Date,DateTime} && return "date"
    return "string"
end

_cell(x::Union{Nothing,Missing}) = nothing
_cell(x::Union{Real,Date,DateTime}) = x
_cell(x::AbstractString) = String(x)
_cell(x) = string(x)

"""
    typst_table(table; digits = (;), align = (;), max_rows = MAX_TABLE_ROWS[]) -> TypstMarkup

Display any Tables.jl table as a Typst table, formatted by the companion
package's `data-table` (booktabs rules, numbers right-aligned, floats rounded
per column). A DataFrame displays this way on its own; use `typst_table` for
other tables or to override formatting:

- `digits`: decimal places per column, e.g. `(sd = 5,)`. Columns not named
  get the document-wide default (`#configure(digits: ...)`, significant
  digits for the column's largest value).
- `align`: per-column Typst alignment, e.g. `(name = tcode"center",)`.
"""
function typst_table(table; digits = (;), align = (;), max_rows::Integer = MAX_TABLE_ROWS[])
    max_rows >= 0 || throw(ArgumentError("typst_table: max_rows must be nonnegative"))
    Tables.istable(table) || throw(ArgumentError("typst_table: not a Tables.jl table: $(typeof(table))"))
    cols = Tables.columns(table)
    names = collect(Tables.columnnames(cols))
    kinds = [_column_kind(eltype(Tables.getcolumn(cols, n))) for n in names]
    nrows = length(names) == 0 ? 0 : length(Tables.getcolumn(cols, first(names)))
    shown = min(nrows, max_rows)
    body = [[_cell(Tables.getcolumn(cols, n)[i]) for n in names] for i in 1:shown]
    lookup(nt, n) = haskey(nt, Symbol(n)) ? nt[Symbol(n)] : nothing
    spec = (
        columns = [String(n) for n in names],
        kinds = kinds,
        rows = body,
        var"total-rows" = nrows,
        digits = [lookup(digits, n) for n in names],
        align = [lookup(align, n) for n in names],
    )
    ensure_typst_package()
    return TypstMarkup(string(
        "#import ", typst_literal(typst_package_spec()), ": data-table\n",
        "#data-table(", typst_literal(spec), ")",
    ))
end
