#!/usr/bin/env bash
# cta-v1 :: scripts/provenance_seal.sh
#
# ESL Seal of Inherited Provenance generator.
#
# Hashing primitive: SHAKE256 with 512-bit output (NIST FIPS 202; we use
# SHAKE256-xoflen=64 because "SHAKE512" is not a standard primitive — the only
# NIST XOFs are SHAKE128 and SHAKE256. Output length is configurable; 512 bits
# matches the ESL requirement for the seal length.).
#
# Salt construction: Epoch Rule30 Salt Stream.
#   seed = (unix_epoch XOR floor(temperature * 1e6) XOR additional_entropy_int)
#   stream = Rule30 cellular automaton, width 257, 512 bits emitted from
#            the center column, packed as 64 hex bytes.
# The stream is mixed into the input via XOR-prepend before hashing.
#
# Usage:
#   ./provenance_seal.sh --input path/to/artifact [--input ...] \
#       [--temperature 1.0] [--entropy "any string"] [--out seal.json]
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -f "$AVRS_ROOT/lib/cta/common.sh" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
source "$AVRS_ROOT/lib/cta/common.sh"
cta_require openssl awk

INPUTS=()
TEMPERATURE="1.0"
ENTROPY=""
OUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input) INPUTS+=("$2"); shift 2 ;;
        --temperature) TEMPERATURE="$2"; shift 2 ;;
        --entropy) ENTROPY="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) cta_die "unknown arg: $1" ;;
    esac
done

[[ ${#INPUTS[@]} -eq 0 ]] && cta_die "at least one --input required"

# ---------- seed construction ----------
EPOCH=$(cta_epoch)
# Temperature -> integer micro-units
TEMP_INT=$(awk -v t="$TEMPERATURE" 'BEGIN { printf "%d", t * 1000000 }')
# Entropy string -> integer hash (sum of bytes mod 2^31)
ENTROPY_INT=0
if [[ -n "$ENTROPY" ]]; then
    ENTROPY_INT=$(printf '%s' "$ENTROPY" | od -An -tu1 -w65536 | awk '{ for(i=1;i<=NF;i++) s+=$i } END { print s % 2147483647 }')
fi
SEED=$(( EPOCH ^ TEMP_INT ^ ENTROPY_INT ))
[[ $SEED -lt 0 ]] && SEED=$(( -SEED ))

# ---------- generate Rule30 salt stream ----------
SALT_HEX=$(cta_rule30 "$SEED" 64)

# ---------- per-input hashes ----------
declare -a HASHES=()
declare -a NAMES=()
declare -a SIZES=()
for path in "${INPUTS[@]}"; do
    [[ -f "$path" ]] || cta_die "input not found: $path"
    size=$(wc -c < "$path")
    # Mix: prepend salt bytes to file content before SHAKE256
    # We feed (salt_bytes || file_content) to openssl shake256
    mixed_hash=$( { perl -e 'print pack("H*", $ARGV[0])' "$SALT_HEX"; cat "$path"; } | cta_shake256_512 )
    HASHES+=("$mixed_hash")
    NAMES+=("$(basename "$path")")
    SIZES+=("$size")
done

# ---------- composite seal ----------
# A combined hash over all the individual hashes, salted again with the same salt.
COMPOSITE=$( { perl -e 'print pack("H*", $ARGV[0])' "$SALT_HEX"; printf '%s\n' "${HASHES[@]}"; } | cta_shake256_512 )

# ---------- emit JSON ----------
files_json="["
for i in "${!INPUTS[@]}"; do
    [[ $i -gt 0 ]] && files_json+=","
    files_json+=$(cta_json \
        path="${INPUTS[$i]}" \
        name="${NAMES[$i]}" \
        size_bytes="${SIZES[$i]}" \
        hash_shake256_512="${HASHES[$i]}")
done
files_json+="]"

SEAL_JSON=$(cta_json \
    schema="ESL-Seal-of-Inherited-Provenance-v1.0" \
    hash_primitive="SHAKE256-xoflen-64-bit-output" \
    salt_construction="Epoch-Rule30-Salt-Stream" \
    salt_width_bits=257 \
    salt_output_bytes=64 \
    salt_hex="$SALT_HEX" \
    seed_components="$(cta_json epoch="$EPOCH" temperature_micro="$TEMP_INT" entropy_int="$ENTROPY_INT")" \
    seed_xor="$SEED" \
    files="$files_json" \
    composite_seal_shake256_512="$COMPOSITE" \
    license="ESL-ANCSA-MRA-IndiModSHA v1.0" \
    original_creator="Anja Evermoor" \
    handle="@161evermoorFAFO / @gravermistakes" \
    sealed_epoch="$EPOCH")

if [[ -n "$OUT" ]]; then
    printf '%s\n' "$SEAL_JSON" > "$OUT"
    cta_info "seal written to $OUT"
fi
printf '%s\n' "$SEAL_JSON"
