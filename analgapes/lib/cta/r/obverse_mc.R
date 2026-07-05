# cta-v1 :: scripts/r/obverse_mc.R
# Modality III: Obverse Monte Carlo (☿)
# Functional form: ☿(X) = X ⨀ ⬡    (reflection across median axis)
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path  <- cta_arg_str(args, "in",  "")
out_path <- cta_arg_str(args, "out", "")

if (!nzchar(in_path)) cta_die("--in required")
x <- cta_read_samples(in_path)

axis <- median(x)
y <- axis - (x - axis)        # = 2*axis - x

sym_div <- abs(mean(x) - mean(y))

if (nzchar(out_path)) cta_write_samples(y, out_path)

cta_emit(list(
    modality = "obverse_mc",
    symbol = "☿",
    equation = "☿(X) = X ⨀ ⬡",
    reflection_axis = axis,
    symmetry_divergence = sym_div,
    input_stats = cta_stats(x),
    output_stats = cta_stats(y),
    output_file = if (nzchar(out_path)) out_path else NULL
))
