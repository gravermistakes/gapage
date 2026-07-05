# cta-v1 :: scripts/r/adverse_mc.R
# Modality X: Adverse Monte Carlo (ð)
# Functional form: ð(X) = X ⊕ εₘₐₓ ⊗ ∂_x X
# Semantics: push each sample further from the mean by epsilon_max * (x - mean),
#            i.e. follow the gradient of (x - μ)² outward. Returns systemic
#            fracture ratio (variance amplification).
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path     <- cta_arg_str(args, "in", "")
epsilon_max <- cta_arg_num(args, "epsilon-max", 1.5)
out_path    <- cta_arg_str(args, "out", "")
if (!nzchar(in_path)) cta_die("--in required")

x <- cta_read_samples(in_path)
mu <- mean(x)
adversarial_push <- epsilon_max * (x - mu)   # ∂_x of (x-μ)² is 2(x-μ); we absorb the 2 into ε_max
y <- x + adversarial_push

frac <- if (length(x) >= 2 && var(x) > 0) var(y) / var(x) else 0

if (nzchar(out_path)) cta_write_samples(y, out_path)

cta_emit(list(
    modality = "adverse_mc",
    symbol = "ð",
    equation = "ð(X) = X ⊕ εₘₐₓ ⊗ ∂_x X",
    epsilon_max = epsilon_max,
    systemic_fracture_ratio = frac,
    input_stats = cta_stats(x),
    output_stats = cta_stats(y),
    output_file = if (nzchar(out_path)) out_path else NULL
))
