# cta-v1 :: scripts/r/diverse_mc.R
# Modality VII: Diverse Monte Carlo (✶)
# Functional form: ✶(X) = ⦙ₓ J(X) ⊕ H(X)
# Semantics: maximize heterogeneity while preserving marginal structure.
#   J(X): empirical copula + maximally-dispersed permutation (Latin hypercube on ranks)
#   H(X): KDE-fit + entropy-max noise that preserves mean and variance
#   ⊕   : direct sum (concatenate)
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path  <- cta_arg_str(args, "in", "")
out_path <- cta_arg_str(args, "out", "")
seed     <- cta_seed(args)
if (!nzchar(in_path)) cta_die("--in required")

set.seed(seed)
x <- cta_read_samples(in_path)
n <- length(x)
if (n < 4) cta_die("Diverse requires n >= 4 samples")

mu <- mean(x); sigma <- sd(x)

# --- J(X): copula dispersion ---
# Step 1: rank-transform x to uniform copula on (0,1].
u <- (rank(x, ties.method = "average") - 0.5) / n
# Step 2: build a Latin hypercube on n points and assign by sorting u-order
#         to the LH cells. This is maximally dispersed in marginal distribution.
lh_cells <- (sample.int(n) - 0.5) / n      # one point per stratum, random within
# Step 3: invert copula via quantile of the empirical distribution of x.
qfun <- function(p) quantile(x, probs = p, names = FALSE, type = 7)
J <- qfun(lh_cells)

# --- H(X): entropy-max noise convolved with KDE ---
# Fit a Gaussian KDE; bandwidth via Silverman's rule of thumb (density() default nrd0).
kde <- density(x)
# Sample from the KDE: pick a random data point, add Gaussian noise with sd=kde$bw.
idx <- sample.int(n, n, replace = TRUE)
H_raw <- x[idx] + rnorm(n, mean = 0, sd = kde$bw)
# Project H_raw to preserve original mean and variance (max-entropy constraint).
H <- (H_raw - mean(H_raw)) / sd(H_raw) * sigma + mu

# --- Direct sum ---
divergent <- c(J, H)   # length 2n

# Diversity score: ratio of divergent sample range to original range
range_pre  <- diff(range(x))
range_post <- diff(range(divergent))
diversity_score <- if (range_pre > 0) range_post / range_pre else 0

if (nzchar(out_path)) cta_write_samples(divergent, out_path)

cta_emit(list(
    modality = "diverse_mc",
    symbol = "✶",
    equation = "✶(X) = ⦙ₓ J(X) ⊕ H(X)",
    n_input = n,
    n_output = length(divergent),
    kde_bandwidth = kde$bw,
    diversity_score = diversity_score,
    input_stats = cta_stats(x),
    copula_stats = cta_stats(J),
    entropy_stats = cta_stats(H),
    output_stats = cta_stats(divergent),
    output_file = if (nzchar(out_path)) out_path else NULL
))
