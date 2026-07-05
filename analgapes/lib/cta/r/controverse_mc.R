# cta-v1 :: scripts/r/controverse_mc.R
# Modality XII: Controverse Monte Carlo (⚔)
# Functional form: ⚔(X) = ⨀_i Xᵢ ⊗ Xⱼ
# Semantics: test independence by constructing the product space of two
#            conditional samples (typically Transverse residuals and Adverse
#            stressed values). Measure dependence; draw from independent marginals.
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
xi_path <- cta_arg_str(args, "xi", "")    # first sample
xj_path <- cta_arg_str(args, "xj", "")    # second sample
out_path <- cta_arg_str(args, "out", "")
n_product <- cta_arg_int(args, "n-product", 5000)
seed <- cta_seed(args)
if (!nzchar(xi_path)) cta_die("--xi required")
if (!nzchar(xj_path)) cta_die("--xj required")

set.seed(seed)
xi <- cta_read_samples(xi_path)
xj <- cta_read_samples(xj_path)
n <- min(length(xi), length(xj))
xi <- xi[seq_len(n)]
xj <- xj[seq_len(n)]
if (n < 4) cta_die("Controverse requires n >= 4 paired samples")

# Dependence statistics.
spearman_rho <- cor(xi, xj, method = "spearman")
pearson_rho  <- cor(xi, xj, method = "pearson")
# Hoeffding-style D approximation: 1 - mean(|F(xi) - G(xj)|) where F,G are ECDFs.
Fxi <- ecdf(xi)(xi)
Gxj <- ecdf(xj)(xj)
hoeffding_d_proxy <- 1 - mean(abs(Fxi - Gxj))

# Construct product-space draws under independence: draw xi' from marginal of xi,
# draw xj' from marginal of xj, independently. Output the pairs.
i_idx <- sample.int(n, n_product, replace = TRUE)
j_idx <- sample.int(n, n_product, replace = TRUE)
product_xi <- xi[i_idx]
product_xj <- xj[j_idx]

# Also compute the dependence under the null (product space): should be ~0.
null_spearman <- cor(product_xi, product_xj, method = "spearman")

# Output: two-column file (xi, xj) tab-separated.
if (nzchar(out_path)) {
    df <- data.frame(xi = product_xi, xj = product_xj)
    write.table(df, out_path, row.names = FALSE, col.names = FALSE, sep = "\t")
}

# Verdict: if observed Spearman is far from null, samples are not independent.
verdict <- if (abs(spearman_rho) > 3 * abs(null_spearman) && abs(spearman_rho) > 0.05)
    "dependent" else "consistent_with_independence"

cta_emit(list(
    modality = "controverse_mc",
    symbol = "⚔",
    equation = "⚔(X) = ⨀_i Xᵢ ⊗ Xⱼ",
    n_paired = n,
    n_product = n_product,
    observed_spearman = spearman_rho,
    observed_pearson = pearson_rho,
    hoeffding_d_proxy = hoeffding_d_proxy,
    null_spearman = null_spearman,
    independence_verdict = verdict,
    xi_stats = cta_stats(xi),
    xj_stats = cta_stats(xj),
    product_xi_stats = cta_stats(product_xi),
    product_xj_stats = cta_stats(product_xj),
    output_file = if (nzchar(out_path)) out_path else NULL
))
