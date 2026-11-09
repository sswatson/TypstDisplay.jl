module TypstDisplayIJuliaExt

using IJulia: IJulia
using TypstDisplay: TYPST_MIME_NAMES

# IJulia only publishes MIME types it has been told about. Registering the Typst
# types makes every value with a Typst `show` method carry Typst markup in its
# display bundle, next to the usual text/plain, text/html, ... Both names are
# registered: `text/x-typst` for this package's values, and `text/typst` so
# Typstry.jl values are published too.
function __init__()
    for name in TYPST_MIME_NAMES
        m = MIME(name)
        m in IJulia.ijulia_mime_types || IJulia.register_mime(m)
    end
end

end
