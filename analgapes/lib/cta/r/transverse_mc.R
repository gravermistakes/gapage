# cta-v1 :: scripts/r/transverse_mc.R
# Modality VI: Transverse Monte Carlo (⊥)
# Functional form: ⊥(X) = X ⊗ ⊥
# Semantics: orthogonal projection. Remove correlation between X and a nuisance
#            variable; output the residuals (the component of X orthogonal to
#            the nuisance direction). If no nuisance file is given, generate one
#            from the empirical mean-drift direction and project that out.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path       <- cta_arg_str(args, "in", "")
nuisance_path <- cta_arg_str(args, "nuisance", "")
out_path      <- cta_arg_str(args, "out", "")
seed          <- cta_seed(args)
if (!nzchar(in_path)) cta_die("--in required")

x <- cta_read_samples(in_path)
n <- length(x)

if (nzchar(nuisance_path)) {
    z <- cta_read_samples(nuisance_path)
    if (length(z) != n) cta_die(paste("nuisance length", length(z), "!= signal length", n))
    nuisance_source <- "file"
} else {
    # Generate a structured nuisance: a smoothed random walk correlated with x's
    # natural ordering. This gives Gram-Schmidt something non-trivial to project out.
    set.seed(seed)
    z <- cumsum(rnorm(n)) / sqrt(seq_len(n))
    nuisance_source <- "synthetic_random_walk"
}

# Linear regression of x on z (with intercept). Residuals are the orthogonal component.
fit <- lm(x ~ z)
residuals_x <- as.numeric(residuals(fit))
beta <- as.numeric(coef(fit)[2])

# Pearson correlation pre/post — should be ~0 post-projection
corr_pre  <- cor(x, z)
corr_post <- cor(residuals_x, z)

if (nzchar(out_path)) cta_write_samples(residuals_x, out_path)

cta_emit(list(
    modality = "transverse_mc",
    symbol = "⊥",
    equation = "⊥(X) = X ⊗ ⊥",
    nuisance_source = nuisance_source,
    regression_slope = beta,
    correlation_pre = corr_pre,
    correlation_post = corr_post,
    r_squared = summary(fit)$r.squared,
    input_stats = cta_stats(x),
    nuisance_stats = cta_stats(z),
    residual_stats = cta_stats(residuals_x),
    output_file = if (nzchar(out_path)) out_path else NULL
))
