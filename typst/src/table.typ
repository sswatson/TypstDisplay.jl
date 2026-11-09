// Tables sent from Julia: column names, kinds and row-major values.

#import "config.typ": display-config

// Fixed-point formatting: `x` with exactly `decimals` digits after the point.
#let _fixed(x, decimals) = {
  if calc.abs(x) >= 1e15 {
    return str(x)
  }
  let scaled = calc.round(calc.abs(x) * calc.pow(10.0, decimals))
  let digits = str(int(scaled))
  if decimals > 0 {
    while digits.len() <= decimals {
      digits = "0" + digits
    }
    digits = digits.slice(0, digits.len() - decimals) + "." + digits.slice(digits.len() - decimals)
  }
  let negative = x < 0 and scaled != 0
  (if negative { "−" } else { "" }) + digits
}

// Decimal places for a float column: enough for `sig` significant digits on
// the column's largest finite value, between 0 and 10.
#let _auto-decimals(values, sig) = {
  let finite = values.filter(v => type(v) == float and v == v and calc.abs(v) < float.inf and v != 0)
  if finite.len() == 0 {
    return 0
  }
  let biggest = calc.max(..finite.map(calc.abs))
  let magnitude = calc.floor(calc.log(biggest, base: 10))
  calc.clamp(sig - 1 - magnitude, 0, 10)
}

#let _format-cell(value, kind, decimals, cfg) = {
  if value == none {
    cfg.missing
  } else if kind == "float" {
    if type(value) == float and value != value {
      [NaN]
    } else if type(value) == float and calc.abs(value) == float.inf {
      if value > 0 { [∞] } else { [−∞] }
    } else {
      _fixed(float(value), decimals)
    }
  } else if kind == "int" {
    if value < 0 { "−" + str(-value) } else { str(value) }
  } else if kind == "bool" {
    if value { "true" } else { "false" }
  } else if kind == "date" and type(value) == datetime {
    value.display()
  } else {
    // Strings are shown as text, never interpreted as markup.
    str(value)
  }
}

/// Render a table sent by TypstDisplay.jl. `spec` has `columns` (names),
/// `kinds` ("int", "float", "bool", "date", "string"), `rows` (arrays of
/// values), `total-rows`, and per-column `digits` / `align` overrides (`none`
/// for the default).
#let data-table(spec) = context {
  let cfg = display-config.get()
  let n = spec.columns.len()
  if n == 0 { return [0 columns] }
  let kinds = spec.kinds
  let numeric = kinds.map(k => k in ("int", "float"))
  let column-values(j) = spec.rows.map(r => r.at(j))
  let decimals = range(n).map(j => {
    let fixed = spec.digits.at(j, default: none)
    if fixed != none { fixed } else if kinds.at(j) == "float" {
      _auto-decimals(column-values(j), cfg.digits)
    } else { 0 }
  })
  let aligns = range(n).map(j => {
    let given = spec.align.at(j, default: none)
    if given != none { given } else if numeric.at(j) { right } else { left }
  })
  let max-rows = cfg.at("max-rows")
  let shown = if max-rows == none { spec.rows } else { spec.rows.slice(0, calc.min(max-rows, spec.rows.len())) }
  let hidden = spec.at("total-rows") - shown.len()

  let body = table(
    columns: n,
    align: (x, y) => aligns.at(x),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header(
      ..spec.columns.map(name => text(weight: cfg.at("header-weight"), name)),
    ),
    table.hline(stroke: 0.5pt),
    ..shown.map(row => range(n).map(j => _format-cell(row.at(j), kinds.at(j), decimals.at(j), cfg))).flatten(),
    ..if hidden > 0 {
      (table.cell(colspan: n, align: left, text(fill: luma(45%), size: 0.9em)[… #hidden more rows]),)
    },
    table.hline(stroke: 0.8pt),
  )
  if cfg.at("table-size") == auto { body } else { text(size: cfg.at("table-size"), body) }
}
