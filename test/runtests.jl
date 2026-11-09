using Test
using Dates
using DataFrames
using TypstDisplay
using TypstDisplay: TYPST_MIME
using Typstry: Typstry
using IJulia: IJulia
using REPL: REPL

# Install into a throwaway package directory, never the user's.
const PKGDIR = mktempdir()
ENV["TYPST_PACKAGE_PATH"] = PKGDIR

typst_source(x) = sprint(show, TYPST_MIME(), x)

@testset "literals" begin
    @test typst_literal(1) == "1"
    @test typst_literal(2.5) == "2.5"
    @test typst_literal(1.0) == "1.0"
    @test typst_literal(Float32(0.1)) == "0.1"
    @test typst_literal(Inf) == "float.inf"
    @test typst_literal(nothing) == "none"
    @test typst_literal(missing) == "none"
    @test typst_literal(:a) == "\"a\""
    @test typst_literal("q\"\\\n") == "\"q\\\"\\\\\\n\""
    @test typst_literal([1]) == "(1,)"
    @test typst_literal(()) == "()"
    @test typst_literal(Dict()) == "(:)"
    @test typst_literal((; a = 1, b = [true])) == "(\"a\": 1, \"b\": (true,))"
    @test typst_literal(Date(2026, 1, 2)) == "datetime(year: 2026, month: 1, day: 2)"
    @test typst_literal(tcode"12cm") == "12cm"
    @test typst_literal(tcode"[$n$]") == "[\$n\$]"
    @test sprint(show, tcode"1pt") == "tcode\"1pt\""
    @test_throws ArgumentError typst_literal(1 + 2im)
end

@testset "reshaping" begin
    r = rows(; n = [1, 2], sd = [0.5, 0.25])
    @test r == [(n = 1, sd = 0.5), (n = 2, sd = 0.25)]
    @test rows(DataFrame(n = [1, 2], sd = [0.5, 0.25])) == r
    long = pivot_longer((; n = [1, 2], a = [10, 20], b = [30, 40]), [:a, :b])
    @test length(long) == 4
    @test long[3] == (n = 1, series = "b", value = 30)
end

@testset "Gribouille calls" begin
    p = G.plot(DataFrame(x = [1, 2], y = [3.0, 4.0]);
        mapping = G.aes(x = :x, y = :y),
        layers = [G.geom_line(stroke = tcode"1pt")],
        scales = G.scales(x = G.scale_log10()),
        guides = G.guides(colour = G.guide_legend(inherit_aes = false)))
    src = typst_source(p)
    @test p isa GPlot
    @test occursin(TypstDisplay.typst_package_spec(), src)
    @test occursin("plot(data: ((\"x\": 1, \"y\": 3.0), (\"x\": 2, \"y\": 4.0)),", src)
    @test occursin("layers: (geom-line(stroke: 1pt),)", src)
    @test occursin("scale-log10()", src)
    @test occursin("guide-legend(inherit-aes: false)", src)
    @test_throws ArgumentError G.plot(DataFrame(x = [1]); data = DataFrame(x = [1]))
    # Layer data is converted to rows too.
    layer = G.geom_point(data = (; x = [1], y = [2]))
    @test occursin("data: ((\"x\": 1, \"y\": 2),)", typst_literal(layer))
end

@testset "markup" begin
    m = typst_call("my-fn", [1, 2]; from = "/plots.typ", height = tcode"8cm")
    @test typst_source(m) == "#import \"/plots.typ\": my-fn\n#my-fn((1, 2), height: 8cm)"
    @test sprint(print, m) == typst_source(m)
    @test typst_source(typst_call("rect"; from = nothing)) == "#rect()"
    @test showable(TYPST_MIME(), DataFrame(a = [1]))
    @test !showable(TYPST_MIME(), 1)
    # Both MIME names show the same markup.
    for x in (DataFrame(a = [1]), G.plot((; a = [1]); mapping = G.aes(x = :a, y = :a)), m)
        @test sprint(show, MIME"text/typst"(), x) == typst_source(x)
    end
end

@testset "table limits" begin
    @test_throws ArgumentError typst_table((; a = [1]); max_rows = -1)
    @test occursin("\"rows\": ()", typst_source(typst_table((; a = [1]); max_rows = 0)))
end

@testset "IJulia MIME registration" begin
    @test Base.get_extension(TypstDisplay, :TypstDisplayIJuliaExt) !== nothing
    for name in TypstDisplay.TYPST_MIME_NAMES
        @test MIME(name) in IJulia.ijulia_mime_types
    end
end

@testset "Typstry interop" begin
    # Only Typstry defines `typst"..."`; ours is `tcode"..."`, so the two can be loaded together.
    @test !isdefined(TypstDisplay, Symbol("@typst_str"))
    # A Typstry string passed as an argument becomes a content block.
    @test typst_literal(Typstry.TypstString(Typstry.TypstText("sample size \$n\$"))) == "[sample size \$n\$]"
    # A Typstry value displays through typst_markup.
    @test typst_markup(Typstry.Typst(1 // 2)) isa TypstMarkup
end

@testset "Typst package install" begin
    target = TypstDisplay.install_typst_package()
    @test startswith(target, PKGDIR)
    @test isfile(joinpath(target, "typst.toml"))
    # Idempotent, and repairs a modified copy.
    write(joinpath(target, "lib.typ"), "// tampered")
    TypstDisplay.install_typst_package()
    @test read(joinpath(target, "lib.typ")) == read(joinpath(TypstDisplay.TYPST_SOURCE_DIR, "lib.typ"))
end

# End to end: the generated markup compiles with the real typst, when present.
typst = Sys.which("typst")
if typst === nothing
    @warn "typst not on PATH; skipping compile tests"
else
    @testset "compiles with typst" begin
        df = DataFrame(
            n = [100, 1000, 10_000],
            sd = [0.1762, 0.05157, 0.00152],
            label = ["a*b", "#not-markup", missing],
            ok = [true, false, true],
        )
        plotdata = pivot_longer((; n = df.n, empirical = df.sd, theory = df.sd .* 1.05),
            [:empirical, :theory]; names_to = :source, values_to = :sd)
        p = G.plot(plotdata;
            mapping = G.aes(x = :n, y = :sd, colour = :source),
            layers = [G.geom_line(), G.geom_point()],
            scales = G.scales(x = G.scale_log10(), y = G.scale_log10()),
            labels = G.labels(x = tcode"[sample size $n$]", y = "sd"))
        dir = mktempdir()
        doc = joinpath(dir, "doc.typ")
        write(doc, """
            #set page(width: 16cm, height: auto, margin: 1cm)
            #import "$(TypstDisplay.typst_package_spec())": configure
            #configure(digits: 3)
            $(typst_source(typst_table(DataFrame())))
            $(typst_source(typst_table(DataFrame(a = Int[]))))
            $(typst_source(typst_table(df; max_rows = 0)))
            $(typst_source(df))

            #eval($(typst_literal(typst_source(p))), mode: "markup")

            $(typst_source(typst_table(df; digits = (sd = 5,))))
            """)
        cmd = `$typst compile --package-path $PKGDIR $doc $(joinpath(dir, "doc.pdf"))`
        out = IOBuffer()
        ok = success(pipeline(cmd; stdout = out, stderr = out))
        ok || println(String(take!(out)))
        @test ok
        txt = Sys.which("pdftotext") === nothing ? nothing :
              read(`pdftotext $(joinpath(dir, "doc.pdf")) -`, String)
        if txt !== nothing
            @test occursin("0.176", txt)          # 3 significant digits
            @test occursin("0.17620", txt)        # per-column override
            @test occursin("#not-markup", txt)    # strings are text, not markup
        end
    end

    @testset "standalone PDFs" begin
        dir = mktempdir()
        df = DataFrame(x = [1, 2], y = [3.5, 4.0])
        p = G.plot(df; mapping = G.aes(x = :x, y = :y), layers = [G.geom_point()])
        values = Any[df, (; x = [1, 2], y = [3, 4]), p, typst_table(df; digits = (y = 3,)),
                     TypstMarkup("Hello \$x^2\$")]
        for (k, v) in enumerate(values)
            # Shell metacharacters and Unicode must survive unchanged.
            target = joinpath(dir, "résumé ' \$ ` $k.pdf")
            pdf = typst_show(v; output = target, open = false)
            @test pdf == target
            @test read(pdf, 5) == b"%PDF-"
        end
        pdf = typst_show(df; open = false, width = "20cm", margin = tcode"1cm")
        @test isabspath(pdf) && isfile(pdf) && readdir(dirname(pdf)) == ["display.pdf"]
        rm(dirname(pdf); recursive = true)
        # Relative output resolves against the working directory.
        cd(dir) do
            @test typst_show(df; output = "rel.pdf", open = false) == joinpath(realpath(dir), "rel.pdf")
        end
        # A failed compile leaves an existing output intact.
        target = joinpath(dir, "keep.pdf")
        write(target, "original")
        @test_throws ErrorException typst_show(TypstMarkup("#unknown-function()"); output = target, open = false)
        @test read(target, String) == "original"
        @test_throws ArgumentError typst_show(df; output = joinpath(dir, "bad.txt"), open = false)
        @test_throws ArgumentError typst_show(df; output = joinpath(dir, "missing", "x.pdf"), open = false)
        @test_throws ArgumentError typst_show(42; open = false)
        withenv("TYPST_BIN" => joinpath(dir, "nonexistent-typst")) do
            @test_throws ErrorException typst_show(df; open = false)
        end
    end

    @testset "plots open at the REPL" begin
        opened = String[]
        TypstDisplay.PDF_OPENER[] = pdf -> push!(opened, pdf)
        try
            p = G.plot((; x = [1, 2], y = [3, 4]); mapping = G.aes(x = :x, y = :y), layers = [G.geom_point()])
            @test typst_show(p) == only(opened)
            # The REPL's display, as when a chunk is sent to the REPL.
            out = IOBuffer()
            term = REPL.Terminals.TTYTerminal("dumb", devnull, out, devnull)
            display(REPL.REPLDisplay(REPL.BasicREPL(term)), p)
            text = String(take!(out))
            @test length(opened) == 2
            @test occursin("GPlot", text) && occursin("Opened $(opened[2])", text)
            TypstDisplay.AUTO_SHOW[] = false
            display(REPL.REPLDisplay(REPL.BasicREPL(term)), p)
            @test length(opened) == 2 && !occursin("Opened", String(take!(out)))
            # Tables at the REPL stay text.
            display(REPL.REPLDisplay(REPL.BasicREPL(term)), DataFrame(a = [1]))
            @test length(opened) == 2
        finally
            TypstDisplay.PDF_OPENER[] = nothing
            TypstDisplay.AUTO_SHOW[] = true
            foreach(pdf -> rm(dirname(pdf); recursive = true), opened)
        end
    end
end
