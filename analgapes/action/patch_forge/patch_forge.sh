#!/usr/bin/env bash
# patch_forge.sh — Copyleft binary patcher
# Takes a source binary + patch spec file, produces patched output
# Patch spec format: OFFSET ORIGINAL_HEX REPLACEMENT_HEX
# Validates original bytes match before patching (safety check)
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

usage() {
    cat <<'EOF'
patch_forge.sh — Binary Patcher for AVRS

USAGE:
    patch_forge.sh <source_binary> <patch_spec> <output_binary>

PATCH SPEC FORMAT (one patch per line):
    OFFSET ORIGINAL_HEX REPLACEMENT_HEX

    Offset is decimal or 0x-prefixed hex.
    Hex values are continuous (no spaces).

EXAMPLE SPEC (NOP out an ARM64 SMC call):
    0x1A3C D4000003 D503201F

EXAMPLE SPEC (NOP out multiple instructions):
    0x1A3C D4000003 D503201F
    0x1A40 D5384200 D503201F
    0x1A44 B9000001 D503201F

NOTES:
    - Original bytes are verified before patching (safety)
    - ARM64 NOP = D503201F (0x1F2003D5 in LE file order)
    - Backup of original is saved as <output>.bak
EOF
    exit 1
}

[[ $# -lt 3 ]] && usage

SRC="$1"
SPEC="$2"
OUT="$3"

[[ ! -f "$SRC" ]] && echo "Source not found: $SRC" && exit 1
[[ ! -f "$SPEC" ]] && echo "Spec not found: $SPEC" && exit 1

# Copy source to output
cp "$SRC" "$OUT"
cp "$SRC" "${OUT}.bak"

echo "[PATCH_FORGE] Source: $SRC ($(stat -c%s "$SRC") bytes)"
echo "[PATCH_FORGE] Spec:   $SPEC"
echo "[PATCH_FORGE] Output: $OUT"

PATCHES=0
FAILURES=0

while IFS=' ' read -r offset original replacement; do
    # Skip comments and blank lines
    [[ -z "$offset" || "$offset" == \#* ]] && continue

    # Convert hex offset to decimal
    if [[ "$offset" == 0x* || "$offset" == 0X* ]]; then
        offset_dec=$((offset))
    else
        offset_dec=$((offset))
    fi

    # Convert hex strings to bytes
    orig_len=$((${#original} / 2))
    repl_len=$((${#replacement} / 2))

    if [[ "$orig_len" -ne "$repl_len" ]]; then
        echo "[PATCH_FORGE] ERROR: length mismatch at offset $offset ($orig_len vs $repl_len)"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    # Read actual bytes at offset and verify
    actual_hex=$(xxd -p -l "$orig_len" -s "$offset_dec" "$OUT" | tr -d '\n' | tr 'a-f' 'A-F')
    original_upper=$(echo "$original" | tr 'a-f' 'A-F')

    if [[ "$actual_hex" != "$original_upper" ]]; then
        echo "[PATCH_FORGE] MISMATCH at 0x$(printf '%X' $offset_dec):"
        echo "  Expected: $original_upper"
        echo "  Found:    $actual_hex"
        echo "  Skipping this patch (safety check failed)"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    # Apply patch using printf + dd
    for ((i=0; i<repl_len; i++)); do
        byte="${replacement:$((i*2)):2}"
        printf "\\x$(echo $byte | tr 'A-F' 'a-f')" | \
            dd of="$OUT" bs=1 seek=$((offset_dec + i)) conv=notrunc 2>/dev/null
    done

    printf "[PATCH_FORGE] PATCHED 0x%08X: %s -> %s (%d bytes)\n" \
        "$offset_dec" "$original" "$replacement" "$orig_len"
    PATCHES=$((PATCHES + 1))

done < "$SPEC"

echo "[PATCH_FORGE] Complete: $PATCHES patches applied, $FAILURES failures"
echo "[PATCH_FORGE] Output: $OUT"
echo "[PATCH_FORGE] Backup: ${OUT}.bak"

# Verify output integrity
if [[ "$PATCHES" -gt 0 && "$FAILURES" -eq 0 ]]; then
    echo "[PATCH_FORGE] SHA256(original): $(sha256sum "$SRC" | cut -d' ' -f1)"
    echo "[PATCH_FORGE] SHA256(patched):  $(sha256sum "$OUT" | cut -d' ' -f1)"
fi
