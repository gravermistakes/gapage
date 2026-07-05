# cta-v1 :: scripts/r/retroverse_mc.R
# Modality XIII: Retroverse Monte Carlo (⤺)
# Functional form: ⤺(X) = ⧜ X ⨂ ⬡
# Semantics: retrospective reweighting toward a target (typically Obverse).
#            Censor a fraction of X, then importance-reweight non-censored
#            via bin-frequency ratio (KL-min under censoring).
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path     <- cta_arg_str(args, "in", "")
target_path <- cta_arg_str(args, "target", "")
out_path    <- cta_arg_str(args, "out", "")
censor_frac <- cta_arg_num(args, "censor-fraction", 0.3)
n_bins      <- cta_arg_int(args, "bins", 30)
seed        <- cta_seed(args)
if (!nzchar(in_path))     cta_die("--in required")
if (!nzchar(target_path)) cta_die("--target required (typically Obverse output)")

set.seed(seed)
x <- cta_read_samples(in_path)
target <- cta_read_samples(target_path)
n <- length(x)

# Step 1: censor.
n_censor <- as.integer(round(n * censor_frac))
censor_idx <- sample.int(n, n_censor, replace = FALSE)
observed <- x[-censor_idx]
n_obs <- length(observed)

# Step 2: build common bins spanning both distributions.
bin_lo <- min(c(observed, target))
bin_hi <- max(c(observed, target))
breaks <- seq(bin_lo, bin_hi, length.out = n_bins + 1L)

obs_bins    <- cut(observed, breaks = breaks, include.lowest = TRUE, labels = FALSE)
target_bins <- cut(target,   breaks = breaks, include.lowest = TRUE, labels = FALSE)

obs_freq    <- tabulate(obs_bins,    nbins = n_bins) + 1   # +1 Laplace smoothing
target_freq <- tabulate(target_bins, nbins = n_bins) + 1
obs_p    <- obs_freq    / sum(obs_freq)
target_p <- target_freq / sum(target_freq)

# Step 3: importance weights = target_p / obs_p, evaluated at each observed point's bin.
weights_per_bin <- target_p / obs_p
sample_weights <- weights_per_bin[obs_bins]

# Step 4: resample with replacement using weights to produce a reweighted distribution
# whose empirical density approximates target.
reweighted_idx <- sample.int(n_obs, n_obs, replace = TRUE, prob = sample_weights)
reweighted <- observed[reweighted_idx]

# KL divergence from reweighted-empirical to target (bin-discretized).
rw_bins <- cut(reweighted, breaks = breaks, include.lowest = TRUE, labels = FALSE)
rw_freq <- tabulate(rw_bins, nbins = n_bins) + 1
rw_p <- rw_freq / sum(rw_freq)
kl_pre  <- sum(target_p * log(target_p / obs_p))
kl_post <- sum(target_p * log(target_p / rw_p))

if (nzchar(out_path)) cta_write_samples(reweighted, out_path)

cta_emit(list(
    modality = "retroverse_mc",
    symbol = "⤺",
    equation = "⤺(X) = ⧜ X ⨂ ⬡",
    censor_fraction = censor_frac,
    n_censored = n_censor,
    n_observed = n_obs,
    n_bins = n_bins,
    kl_divergence_pre = kl_pre,
    kl_divergence_post = kl_post,
    kl_reduction = kl_pre - kl_post,
    input_stats = cta_stats(x),
    target_stats = cta_stats(target),
    reweighted_stats = cta_stats(reweighted),
    output_file = if (nzchar(out_path)) out_path else NULL
))
