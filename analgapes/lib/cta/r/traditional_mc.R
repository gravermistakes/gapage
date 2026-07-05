# cta-v1 :: scripts/r/traditional_mc.R
# Modality I: Traditional Monte Carlo (△)
# Functional form: Δ(X) ~ P(X)
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
dist <- cta_arg_str(args, "distribution", "normal:0:1")
n    <- cta_arg_int(args, "n", 5000)
seed <- cta_seed(args)
out  <- cta_arg_str(args, "out", "")

x <- cta_sample_distribution(dist, n, seed)

if (nzchar(out)) cta_write_samples(x, out)

cta_emit(list(
    modality = "traditional_mc",
    symbol = "△",
    equation = "Δ(X) ~ P(X)",
    n_samples = n,
    distribution = dist,
    seed = seed,
    output_stats = cta_stats(x),
    output_file = if (nzchar(out)) out else NULL
))
