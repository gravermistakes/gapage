# cta-v1 :: scripts/r/microversal_mc.R
# Modality IX: Microversal Monte Carlo (∴)
# Functional form: ∴(X) = ⧄_{Δ→0} (X ⊕ δX)
# Semantics: limit behavior of an estimator under vanishing perturbation.
#            Loop over shrinking Δ, record the statistic, regress on (Δ, stat),
#            extrapolate to Δ=0; classify as stable (continuous) or singular.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path   <- cta_arg_str(args, "in", "")
out_path  <- cta_arg_str(args, "out", "")
seed      <- cta_seed(args)
statistic <- cta_arg_str(args, "statistic", "mean")
n_levels  <- cta_arg_int(args, "levels", 12)
delta0    <- cta_arg_num(args, "delta-start", 1.0)
if (!nzchar(in_path)) cta_die("--in required")

set.seed(seed)
x <- cta_read_samples(in_path)
n <- length(x)
if (n < 4) cta_die("Microversal requires n >= 4 samples")

stat_fn <- switch(statistic,
    mean     = function(z) mean(z),
    variance = function(z) var(z),
    median   = function(z) median(z),
    p95      = function(z) quantile(z, 0.95, names = FALSE),
    cta_die(paste("unknown statistic:", statistic))
)

deltas <- delta0 * (0.5 ^ (0:(n_levels - 1)))   # geometric: 1, 0.5, 0.25, ..., ~2.4e-4
stats <- numeric(n_levels)
for (i in seq_along(deltas)) {
    noise <- rnorm(n, mean = 0, sd = deltas[i])
    stats[i] <- stat_fn(x + noise)
}

# Linear regression on (delta, stat) using the last 6 (smallest-delta) points.
tail_n <- min(6L, n_levels)
last_d <- tail(deltas, tail_n)
last_s <- tail(stats, tail_n)
fit <- lm(last_s ~ last_d)
limit_estimate <- as.numeric(coef(fit)[1])      # intercept = stat at Δ=0
slope <- as.numeric(coef(fit)[2])
r2 <- summary(fit)$r.squared

# Singularity heuristic:
#   - "continuous_stable" if |slope| << |limit| (slope/limit ratio < 0.1) regardless of r²;
#     low r² in this regime means "no detectable change as Δ→0" which is the textbook
#     signature of continuity.
#   - "singular" if |slope| is large relative to |limit| AND r² is high (real divergent trend).
#   - "noisy_inconclusive" otherwise.
abs_slope <- abs(slope)
abs_limit <- max(abs(limit_estimate), 1e-9)
slope_ratio <- abs_slope / abs_limit
continuity <- if (slope_ratio < 0.1) {
    "continuous_stable"
} else if (slope_ratio > 1.0 && r2 > 0.5) {
    "singular"
} else {
    "noisy_inconclusive"
}

# Convergence rate: log-ratio of consecutive deltas to consecutive stats
deltas_diff <- abs(diff(stats))
delta_step  <- abs(diff(deltas))
nonzero <- delta_step > 0 & deltas_diff > 0
conv_rate <- if (any(nonzero))
    mean(log(deltas_diff[nonzero]) / log(delta_step[nonzero])) else NA

if (nzchar(out_path)) {
    df <- data.frame(delta = deltas, stat = stats)
    write.table(df, out_path, row.names = FALSE, col.names = FALSE, sep = "\t")
}

cta_emit(list(
    modality = "microversal_mc",
    symbol = "∴",
    equation = "∴(X) = ⧄_{Δ→0} (X ⊕ δX)",
    statistic = statistic,
    n_levels = n_levels,
    deltas = deltas,
    statistic_trajectory = stats,
    limit_estimate = limit_estimate,
    extrapolation_slope = slope,
    extrapolation_r_squared = r2,
    convergence_rate = conv_rate,
    continuity_classification = continuity,
    input_stats = cta_stats(x),
    output_file = if (nzchar(out_path)) out_path else NULL
))
