// Gribouille's `plot` with the document's defaults filled in.

#import "@preview/gribouille:0.7.0" as gb
#import "config.typ": default-theme, display-config

/// `plot` from Gribouille, with `theme`, `width` and `height` defaulting to the
/// values set by `configure`. Arguments passed explicitly win.
///
/// The result is wrapped in `context` (to read the settings), so it is plain
/// content rather than a figure: a notebook front end wraps it in the chunk's
/// figure. `as-spec: true` (for `compose`) bypasses the wrapper and the
/// configured theme, since a spec is data, not content.
#let plot(..args) = {
  let named = args.named()
  if named.at("as-spec", default: false) {
    return gb.plot(..args)
  }
  context {
    let cfg = display-config.get()
    let defaults = (width: cfg.plot-width, height: cfg.plot-height)
    if cfg.theme == auto {
      defaults.insert("theme", default-theme(base: text.size))
    } else if cfg.theme != none {
      defaults.insert("theme", cfg.theme)
    }
    gb.plot(..args.pos(), ..defaults, ..named)
  }
}
