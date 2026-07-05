# cta-v1 :: scripts/r/introverse_mc.R
# Modality XIV: Introverse Monte Carlo (⬖)
# Functional form: ⬖(X) = ⨂ᵢ Xᵢ ⊗ δₖ
# Semantics: internal cross-validation via jackknife. n leave-one-out subsets,
#            measure estimator stability, output distribution of deltas.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path   <- cta_arg_str(args, "in", "")
out_path  <- cta_arg_str(args, "out", "")
statistic <- cta_arg_str(args, "statistic", "mean")
if (!nzchar(in_path)) cta_die("--in required")

x <- cta_read_samples(in_path)
n <- length(x)
if (n < 4) cta_die("Introverse requires n >= 4 samples")

stat_fn <- switch(statistic,
    mean     = mean,
    variance = var,
    median   = median,
    p95      = function(z) quantile(z, 0.95, names = FALSE),
    p05      = function(z) quantile(z, 0.05, names = FALSE),
    cta_die(paste("unknown statistic:", statistic))
)

full_stat <- stat_fn(x)

# Vectorized leave-one-out using R's index-out trick.
# For mean specifically, we can compute analytically: jack_i = (n*mean - x_i)/(n-1)
# but we use the general loop for arbitrary statistics. Still O(n) calls inside R.
jack_stats <- vapply(seq_len(n), function(i) stat_fn(x[-i]), numeric(1))
deltas <- jack_stats - full_stat

# Jackknife estimate of standard error:
# SE_jack = sqrt( (n-1)/n * sum( (jack_i - mean(jack))^2 ) )
jack_mean <- mean(jack_stats)
se_jack <- sqrt((n - 1) / n * sum((jack_stats - jack_mean)^2))

# Bias estimate: (n-1) * (jack_mean - full_stat)
bias_estimate <- (n - 1) * (jack_mean - full_stat)
bias_corrected <- full_stat - bias_estimate

# Stability score: 1 / (1 + se_jack / |full_stat|), clipped to [0,1]
denom <- max(abs(full_stat), 1e-9)
stability_score <- 1 / (1 + se_jack / denom)

if (nzchar(out_path)) cta_write_samples(deltas, out_path)

cta_emit(list(
    modality = "introverse_mc",
    symbol = "⬖",
    equation = "⬖(X) = ⨂ᵢ Xᵢ ⊗ δₖ",
    statistic = statistic,
    n = n,
    full_sample_statistic = full_stat,
    jackknife_mean = jack_mean,
    jackknife_se = se_jack,
    bias_estimate = bias_estimate,
    bias_corrected = bias_corrected,
    stability_score = stability_score,
    input_stats = cta_stats(x),
    delta_stats = cta_stats(deltas),
    output_file = if (nzchar(out_path)) out_path else NULL
))
