# cta-v1 :: scripts/r/subverse_mc.R
# Modality VIII: Subverse Monte Carlo (♆)
# Functional form: ♆(X) = ⧜Ɐ X ⊗ γₖ δXₖ
# Semantics: subsample sensitivity. Draw a fraction of X, compute the delta
#            between full-sample and subsample for a chosen statistic, scale by γ.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path   <- cta_arg_str(args, "in", "")
out_path  <- cta_arg_str(args, "out", "")
seed      <- cta_seed(args)
fraction  <- cta_arg_num(args, "fraction", -1)   # -1 sentinel => use 1/sqrt(n)
statistic <- cta_arg_str(args, "statistic", "mean")   # mean|variance|median|p95|p05
gamma     <- cta_arg_num(args, "gamma", 1.0)
n_reps    <- cta_arg_int(args, "reps", 200)
if (!nzchar(in_path)) cta_die("--in required")

set.seed(seed)
x <- cta_read_samples(in_path)
n <- length(x)
if (n < 4) cta_die("Subverse requires n >= 4 samples")

if (fraction < 0) fraction <- 1 / sqrt(n)
k <- max(2L, as.integer(round(n * fraction)))

stat_fn <- switch(statistic,
    mean     = function(z) mean(z),
    variance = function(z) var(z),
    median   = function(z) median(z),
    p95      = function(z) quantile(z, 0.95, names = FALSE),
    p05      = function(z) quantile(z, 0.05, names = FALSE),
    cta_die(paste("unknown statistic:", statistic))
)

full_stat <- stat_fn(x)
deltas <- replicate(n_reps, {
    s <- sample.int(n, k, replace = FALSE)
    gamma * (stat_fn(x[s]) - full_stat)
})

if (nzchar(out_path)) cta_write_samples(deltas, out_path)

cta_emit(list(
    modality = "subverse_mc",
    symbol = "♆",
    equation = "♆(X) = ⧜Ɐ X ⊗ γₖ δXₖ",
    statistic = statistic,
    fraction = fraction,
    subsample_size = k,
    gamma = gamma,
    n_reps = n_reps,
    full_sample_statistic = full_stat,
    input_stats = cta_stats(x),
    delta_stats = cta_stats(deltas),
    stability_score = if (sd(deltas) > 0) 1 / (1 + sd(deltas) / max(abs(full_stat), 1e-9)) else 1,
    output_file = if (nzchar(out_path)) out_path else NULL
))
