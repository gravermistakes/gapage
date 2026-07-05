# cta-v1 :: scripts/r/inverse_mc.R
# Modality II: Inverse Monte Carlo (⊝)
# Functional form: ⊝(X) = −X ⊕ ∫_Σ ψ* ψ
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
in_path  <- cta_arg_str(args, "in",    "")
shift_v  <- cta_arg_num(args, "shift", 0)
out_path <- cta_arg_str(args, "out",   "")

if (!nzchar(in_path)) cta_die("--in required")
x <- cta_read_samples(in_path)

# ⊝(X) = −X ⊕ shift  (additive coupling to the integrated probability mass)
y <- -x + shift_v

if (nzchar(out_path)) cta_write_samples(y, out_path)

cta_emit(list(
    modality = "inverse_mc",
    symbol = "⊝",
    equation = "⊝(X) = −X ⊕ ∫_Σ ψ* ψ",
    shift_integral = shift_v,
    input_stats = cta_stats(x),
    output_stats = cta_stats(y),
    output_file = if (nzchar(out_path)) out_path else NULL
))
