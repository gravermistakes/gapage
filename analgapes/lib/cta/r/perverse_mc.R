# cta-v1 :: scripts/r/perverse_mc.R
# Modality XI: Perverse Monte Carlo (♇)
# Functional form: ♇(X) = ⩮ₓ X ⊕ λ ∂ₓ X
# Semantics: skew sampling toward regions where a reference (typically the
#            Obverse reflection) disagrees with X. Resample by mismatch weight,
#            then push along the gradient of the mismatch.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path     <- cta_arg_str(args, "in", "")
ref_path    <- cta_arg_str(args, "reference", "")
out_path    <- cta_arg_str(args, "out", "")
lambda      <- cta_arg_num(args, "lambda", 0.1)
seed        <- cta_seed(args)
if (!nzchar(in_path))  cta_die("--in required")
if (!nzchar(ref_path)) cta_die("--reference required (e.g. Obverse output)")

set.seed(seed)
x <- cta_read_samples(in_path)
r <- cta_read_samples(ref_path)
n <- length(x)
if (length(r) != n) cta_die(paste("reference length", length(r), "!= signal length", n))

# Mismatch per sample point: absolute difference.
mismatch <- abs(x - r)
total_mismatch <- sum(mismatch)
if (total_mismatch == 0) cta_die("zero mismatch — distributions are identical")

# Importance weights: proportional to mismatch.
weights <- mismatch / total_mismatch

# Importance resample (with replacement) according to weights.
resampled_idx <- sample.int(n, n, replace = TRUE, prob = weights)
x_resampled <- x[resampled_idx]

# Gradient of mismatch w.r.t. x: sign(x - r). Finite-difference smoothing
# on sorted x to suppress noise (use rolling mean of width 3).
ord <- order(x_resampled)
grad <- sign(x_resampled - r[resampled_idx])
# Smooth gradient
if (n >= 3) {
    sm <- grad
    sm[ord] <- stats::filter(grad[ord], rep(1/3, 3), sides = 2)
    sm[is.na(sm)] <- grad[is.na(sm)]
    grad <- as.numeric(sm)
}

y <- x_resampled + lambda * grad

# Mismatch reduction
new_mismatch <- mean(abs(y - r[resampled_idx]))
old_mismatch <- mean(abs(x_resampled - r[resampled_idx]))
mismatch_reduction <- if (old_mismatch > 0) 1 - new_mismatch / old_mismatch else 0

if (nzchar(out_path)) cta_write_samples(y, out_path)

cta_emit(list(
    modality = "perverse_mc",
    symbol = "♇",
    equation = "♇(X) = ⩮ₓ X ⊕ λ ∂ₓ X",
    lambda = lambda,
    total_mismatch = total_mismatch,
    mean_mismatch = mean(mismatch),
    mismatch_reduction = mismatch_reduction,
    n = n,
    input_stats = cta_stats(x),
    reference_stats = cta_stats(r),
    output_stats = cta_stats(y),
    output_file = if (nzchar(out_path)) out_path else NULL
))
