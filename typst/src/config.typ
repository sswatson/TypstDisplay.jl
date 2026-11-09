// Document-wide settings for tables and plots rendered from Julia.

#import "@preview/gribouille:0.7.0": element-blank, element-line, element-text, theme-minimal

// The default plot theme, sized relative to the surrounding text so a plot
// matches the document it sits in. Pass `theme:` to `configure` to replace it.
#let default-theme(base: 10pt) = theme-minimal(
  ink: luma(15%),
  axis-title: element-text(size: base * 0.82, colour: luma(15%)),
  axis-text: element-text(size: base * 0.72, colour: luma(40%)),
  legend-text: element-text(size: base * 0.76, colour: luma(15%)),
  plot-title: element-text(size: base, weight: "bold", colour: luma(15%)),
  plot-subtitle: element-text(size: base * 0.82, colour: luma(40%)),
  legend-title: element-blank(),
  legend-position: "top",
  panel-grid: element-line(colour: luma(88%), stroke: 0.4pt),
  panel-grid-minor: element-blank(),
)

#let _defaults = (
  // Plots. `theme: auto` is `default-theme` at the current text size; `none`
  // leaves the theme to Gribouille (and its own `theme-set`).
  theme: auto,
  plot-width: auto,
  plot-height: 6.5cm,
  // Tables. `digits` is the number of significant digits shown for the
  // largest value in a float column, which sets that column's decimal places.
  digits: 4,
  "max-rows": 50,
  missing: text(fill: luma(55%))[–],
  "header-weight": "bold",
  "table-size": auto,
)

#let display-config = state("typst-display-config", _defaults)

/// Change the defaults for every table and plot rendered from Julia after
/// this point in the document. Any of: `theme`, `plot-width`, `plot-height`,
/// `digits`, `max-rows`, `missing`, `header-weight`, `table-size`.
#let configure(..args) = {
  assert(args.pos().len() == 0, message: "typst-display configure: named arguments only")
  for key in args.named().keys() {
    assert(
      key in _defaults,
      message: "typst-display configure: unknown setting `" + key + "`; valid: " + _defaults.keys().join(", "),
    )
  }
  display-config.update(current => current + args.named())
}
