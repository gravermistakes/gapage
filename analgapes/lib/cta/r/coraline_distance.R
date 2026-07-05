# cta-v1 :: scripts/r/coraline_distance.R
# Coraline distance: isometric-but-non-isomorphic detector.
#
# Compares an "origin" sample/state with a "transformed" sample/state across
# two axes:
#   isometric  — does the transform preserve pairwise distances?
#                Measured by L2-norm ratio, std-dev ratio, and KS-statistic.
#   isomorphic — does the transform preserve structure?
#                Measured by Spearman rank correlation and sorted-quantile
#                agreement.
#
# Classification (Coraline Jones rules):
#   home          — high isometric AND high isomorphic (legitimate sameness)
#   other_mother  — high isometric, low isomorphic (uncanny: looks right, isn't)
#   lost          — low isometric, low isomorphic (genuinely different)
#   traveling     — anything in between (in transit / undecided)
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
origin_path <- cta_arg_str(args, "origin", "")
trans_path  <- cta_arg_str(args, "transformed", "")
threshold_iso     <- cta_arg_num(args, "isometric-threshold",   0.85)
threshold_isomorph <- cta_arg_num(args, "isomorphic-threshold", 0.85)
if (!nzchar(origin_path) || !nzchar(trans_path)) cta_die("--origin and --transformed required")

a <- cta_read_samples(origin_path)
b <- cta_read_samples(trans_path)
na <- length(a); nb <- length(b)

# Trim to common length so distance comparisons are well-defined.
n <- min(na, nb)
a <- a[seq_len(n)]
b <- b[seq_len(n)]

# --- isometric measures ---
# L2-norm ratio: 1.0 = identical magnitude.
norm_a <- sqrt(sum(a^2)); norm_b <- sqrt(sum(b^2))
norm_ratio <- if (norm_a > 0) min(norm_a, norm_b) / max(norm_a, norm_b) else 0

# Std-dev ratio.
sd_a <- if (n >= 2) sd(a) else 0
sd_b <- if (n >= 2) sd(b) else 0
sd_ratio <- if (max(sd_a, sd_b) > 0) min(sd_a, sd_b) / max(sd_a, sd_b) else 1

# Two-sample KS statistic (lower = closer distributions, isometric on cdf).
ks_d <- if (n >= 4) suppressWarnings(ks.test(a, b)$statistic) else 1
ks_score <- 1 - as.numeric(ks_d)

isometric_score <- mean(c(norm_ratio, sd_ratio, ks_score))

# --- isomorphic measures ---
# Spearman rank correlation of paired samples (if order matters in input).
spearman_rho <- if (n >= 4) cor(a, b, method = "spearman") else NA
spearman_score <- if (is.na(spearman_rho)) 0 else (spearman_rho + 1) / 2  # [-1,1] -> [0,1]

# Sorted-quantile agreement: if the sorted values align, the marginals are equal,
# which is an isomorphism in the order-theoretic sense.
sorted_a <- sort(a)
sorted_b <- sort(b)
sorted_corr <- if (n >= 4) cor(sorted_a, sorted_b) else NA
sorted_score <- if (is.na(sorted_corr)) 0 else (sorted_corr + 1) / 2

isomorphic_score <- mean(c(spearman_score, sorted_score))

# --- classification ---
iso_hi   <- isometric_score   >= threshold_iso
isom_hi  <- isomorphic_score  >= threshold_isomorph
classification <- if (iso_hi && isom_hi) {
    "home"
} else if (iso_hi && !isom_hi) {
    "other_mother"
} else if (!iso_hi && !isom_hi) {
    "lost"
} else {
    "traveling"
}

cta_emit(list(
    tool = "coraline_distance",
    n = n,
    isometric_measures = list(
        norm_ratio = norm_ratio,
        sd_ratio = sd_ratio,
        ks_statistic = as.numeric(ks_d),
        ks_score = ks_score,
        composite = isometric_score
    ),
    isomorphic_measures = list(
        spearman_rho = spearman_rho,
        spearman_score = spearman_score,
        sorted_corr = sorted_corr,
        sorted_score = sorted_score,
        composite = isomorphic_score
    ),
    thresholds = list(
        isometric = threshold_iso,
        isomorphic = threshold_isomorph
    ),
    classification = classification,
    interpretation = switch(classification,
        home         = "Legitimate sameness. The transformed state preserves both shape and structure.",
        other_mother = "Uncanny match. Distances are preserved but the underlying structure is altered. Be wary; this is the signature of a substitution attack or model collapse.",
        lost         = "Genuinely different. Neither distances nor structure survive the transformation.",
        traveling    = "In transition. One dimension preserved, the other broken. Re-measure after the trajectory settles."
    )
))
