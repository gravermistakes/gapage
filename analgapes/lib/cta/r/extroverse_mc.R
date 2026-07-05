# cta-v1 :: scripts/r/extroverse_mc.R
# Modality XV: Extroverse Monte Carlo (⬗)
# Functional form: ⬗(X) = X ⨂ ⊗ⱼ
# Semantics: mixture with external reference distributions. Sample with prob α
#            from X and (1-α)/j from each external reference.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path     <- cta_arg_str(args, "in", "")
refs_csv    <- cta_arg_str(args, "refs", "")      # comma-separated paths
out_path    <- cta_arg_str(args, "out", "")
alpha       <- cta_arg_num(args, "alpha", -1)     # -1 sentinel => auto
n_out       <- cta_arg_int(args, "n", 5000)
seed        <- cta_seed(args)
if (!nzchar(in_path))  cta_die("--in required")
if (!nzchar(refs_csv)) cta_die("--refs required (comma-separated file paths)")

set.seed(seed)
x <- cta_read_samples(in_path)
ref_paths <- strsplit(refs_csv, ",", fixed = TRUE)[[1]]
refs <- lapply(ref_paths, cta_read_samples)
j <- length(refs)

# Auto-alpha: minimize KL(X_marginal || mixture) approximated via bin discretization.
# Coarse search over alpha in {0.1, 0.2, ..., 0.9}.
if (alpha < 0) {
    bin_lo <- min(c(x, unlist(refs)))
    bin_hi <- max(c(x, unlist(refs)))
    breaks <- seq(bin_lo, bin_hi, length.out = 31L)
    x_freq <- tabulate(cut(x, breaks, include.lowest = TRUE, labels = FALSE), nbins = 30L) + 1
    x_p <- x_freq / sum(x_freq)
    ref_ps <- lapply(refs, function(r) {
        rf <- tabulate(cut(r, breaks, include.lowest = TRUE, labels = FALSE), nbins = 30L) + 1
        rf / sum(rf)
    })
    candidates <- seq(0.1, 0.9, by = 0.1)
    kls <- vapply(candidates, function(a) {
        mix <- a * x_p + ((1 - a) / j) * Reduce("+", ref_ps)
        sum(x_p * log(x_p / mix))
    }, numeric(1))
    alpha <- candidates[which.min(kls)]
    alpha_source <- "auto_kl_min"
} else {
    alpha_source <- "user"
}

# Draw mixture samples.
# Each output sample: with prob alpha draw from x, else with prob (1-alpha)/j draw from ref_k.
component <- sample.int(j + 1L, n_out, replace = TRUE,
                        prob = c(alpha, rep((1 - alpha) / j, j)))
mixture <- numeric(n_out)
for (k in seq_along(component)) {
    c <- component[k]
    if (c == 1L) {
        mixture[k] <- x[sample.int(length(x), 1L)]
    } else {
        ref <- refs[[c - 1L]]
        mixture[k] <- ref[sample.int(length(ref), 1L)]
    }
}

if (nzchar(out_path)) cta_write_samples(mixture, out_path)

ref_stats_list <- lapply(refs, cta_stats)
names(ref_stats_list) <- basename(ref_paths)

cta_emit(list(
    modality = "extroverse_mc",
    symbol = "⬗",
    equation = "⬗(X) = X ⨂ ⊗ⱼ",
    n_references = j,
    n_output = n_out,
    alpha = alpha,
    alpha_source = alpha_source,
    component_weights = c(alpha, rep((1 - alpha) / j, j)),
    input_stats = cta_stats(x),
    reference_stats = ref_stats_list,
    mixture_stats = cta_stats(mixture),
    output_file = if (nzchar(out_path)) out_path else NULL
))
