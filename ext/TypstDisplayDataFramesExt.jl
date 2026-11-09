module TypstDisplayDataFramesExt

using DataFrames: AbstractDataFrame
using TypstDisplay: TypstDisplay, TypstMIME, typst_table

# A DataFrame as the last value of a chunk renders as a Typst table.
Base.show(io::IO, m::TypstMIME, df::AbstractDataFrame) = show(io, m, typst_table(df))

end
