# cta-v1 :: scripts/r/reverse_mc.R
# Modality IV: Reverse Monte Carlo (▽)
# Functional form: ▽(X) = Σ_t ↺ X_t ⨂ iħ ∂_t X_t
# Semantics: apply an inverse function f(x) elementwise, then reweight by
#            distance-from-mean rank to amplify tail information.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path   <- cta_arg_str(args, "in", "")
inv_expr  <- cta_arg_str(args, "inverse", "x")
reweight  <- cta_arg_str(args, "reweight", "harmonic")
out_path  <- cta_arg_str(args, "out", "")
copy_base <- cta_arg_int(args, "copy-base", 1000)
if (!nzchar(in_path)) cta_die("--in required")

x <- cta_read_samples(in_path)
n <- length(x)

# Evaluate inverse expression with `x` as the vector. Vectorized; no per-element forks.
# The user may write expressions like "log(x)", "x^2", "-x + 1", "exp(x)/2".
inv_fn <- tryCatch(
    eval(parse(text = paste0("function(x) (", inv_expr, ")"))),
    error = function(e) cta_die(paste("bad --inverse expression:", e$message))
)
reversed <- inv_fn(x)

rev_mean <- mean(reversed)
rev_var  <- if (n >= 2) var(reversed) else 0

if (reweight == "harmonic") {
    # Rank by distance from mean (ascending — closest first => rank 1, lowest weight).
    # Weight = 1 / rank; integer copies = round(weight * copy_base), min 1.
    d <- abs(reversed - rev_mean)
    ord <- order(d)
    ranks <- seq_along(d)
    copies <- pmax(as.integer(round((1 / ranks) * copy_base)), 1L)
    reweighted <- rep(reversed[ord], times = copies)
} else if (reweight == "none") {
    reweighted <- reversed
} else {
    cta_die(paste("unknown reweight strategy:", reweight))
}

rw_var <- if (length(reweighted) >= 2) var(reweighted) else 0
tail_amp <- if (rev_var > 0) rw_var / rev_var else 0

if (nzchar(out_path)) cta_write_samples(reweighted, out_path)

cta_emit(list(
    modality = "reverse_mc",
    symbol = "▽",
    equation = "▽(X) = Σ_t ↺ X_t ⨂ iħ ∂_t X_t",
    inverse_function = inv_expr,
    reweight_strategy = reweight,
    tail_amplification = tail_amp,
    input_stats = cta_stats(x),
    reversed_stats = cta_stats(reversed),
    reweighted_stats = cta_stats(reweighted),
    output_file = if (nzchar(out_path)) out_path else NULL
))
