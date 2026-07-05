#!/usr/bin/env bash
# cta-v1 :: scripts/cta_setup.sh
# Idempotent installer for R + jsonlite. Run once per fresh environment.
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

set -euo pipefail

need_install=0
if ! command -v Rscript >/dev/null 2>&1; then
    need_install=1
fi

if [[ $need_install -eq 0 ]] && ! Rscript -e 'quit(status=as.integer(!requireNamespace("jsonlite", quietly=TRUE)))' 2>/dev/null; then
    need_install=1
fi

if [[ $need_install -eq 0 ]]; then
    echo "[cta:setup] R + jsonlite already present ($(Rscript --version 2>&1))"
    exit 0
fi

# Detect package manager
if command -v apt-get >/dev/null 2>&1; then
    echo "[cta:setup] installing r-base-core + r-cran-jsonlite via apt"
    apt-get update >/dev/null 2>&1 || true
    apt-get install -y r-base-core r-cran-jsonlite >/dev/null 2>&1
elif command -v pkg >/dev/null 2>&1; then
    # Termux
    echo "[cta:setup] installing R via pkg (Termux)"
    pkg install -y r-base
    Rscript -e 'install.packages("jsonlite", repos="https://cloud.r-project.org")'
elif command -v brew >/dev/null 2>&1; then
    brew install r
    Rscript -e 'install.packages("jsonlite", repos="https://cloud.r-project.org")'
else
    echo "[cta:setup] ERROR: no apt-get / pkg / brew. Install R and jsonlite manually." >&2
    exit 1
fi

echo "[cta:setup] ready: $(Rscript --version 2>&1)"
