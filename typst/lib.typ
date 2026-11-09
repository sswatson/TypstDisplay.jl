// typst-display: the Typst half of TypstDisplay (TypstDisplay.jl, typst-display-matlab).
//
// Julia or MATLAB emits markup that imports this package and calls `data-table` (for a
// table) or Gribouille functions (for a plot). Everything Gribouille exports
// is re-exported here, with `plot` replaced by a wrapper that applies the
// document-wide defaults set with `configure`.
//
// In a document:
//
//   #import "@local/typst-display:0.1.0": configure, theme-minimal
//   #configure(plot-height: 8cm, digits: 3)

#import "@preview/gribouille:0.7.0": *
#import "src/config.typ": configure, default-theme, display-config
#import "src/plot.typ": plot
#import "src/table.typ": data-table
