#!/bin/bash
# Phoenix – Supply Chain Oracle Orchestrator
# Copyright (C) 2026 Anja Evermoor
# GNU GPL v3.0 or later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE="/home/claude/phoenix"
TIMESTAMP="$(date +%s)"

# === Argument parsing ===
TARGET_BINARY="${1:-}"
MAX_DEPTH="${2:-5}"
OUTPUT_FORMAT="${3:-json}"

if [ -z "$TARGET_BINARY" ]; then
    echo "Usage: phoenix_main.sh <target_binary> [max_depth] [output_format]"
    echo "  max_depth: recursion depth for transitive deps (default: 5)"
    echo "  output_format: json|dot|markdown (default: json)"
    exit 1
fi

if [ ! -f "$TARGET_BINARY" ]; then
    echo "[Phoenix] ERROR: target binary not found: $TARGET_BINARY"
    exit 2
fi

# === Workspace setup ===
mkdir -p "$WORKSPACE"/{results,deps,seals,logs}
LOG="$WORKSPACE/logs/phoenix_${TIMESTAMP}.log"
exec > >(tee -a "$LOG") 2>&1

echo "============================================"
echo " Phoenix – Supply Chain Vulnerability Oracle"
echo "============================================"
echo "[*] Target:    $TARGET_BINARY"
echo "[*] Depth:     $MAX_DEPTH"
echo "[*] Format:    $OUTPUT_FORMAT"
echo "[*] Workspace: $WORKSPACE"
echo "[*] Timestamp: $TIMESTAMP"
echo "--------------------------------------------"

# === Tool detection ===
HAS_OCAML=0; command -v ocamlfind >/dev/null 2>&1 && HAS_OCAML=1
HAS_GNAT=0;  command -v gnatmake >/dev/null 2>&1 && HAS_GNAT=1
HAS_PERL=0;  command -v perl >/dev/null 2>&1 && HAS_PERL=1
HAS_JQ=0;    command -v jq >/dev/null 2>&1 && HAS_JQ=1
HAS_READELF=0; command -v readelf >/dev/null 2>&1 && HAS_READELF=1
HAS_NM=0;    command -v nm >/dev/null 2>&1 && HAS_NM=1

echo "[*] Tool availability:"
echo "    OCaml:   $HAS_OCAML"
echo "    GNAT:    $HAS_GNAT"
echo "    Perl:    $HAS_PERL"
echo "    jq:      $HAS_JQ"
echo "    readelf: $HAS_READELF"
echo "    nm:      $HAS_NM"
echo ""

if [ "$HAS_READELF" -eq 0 ]; then
    echo "[Phoenix] FATAL: readelf not available. Cannot parse ELF."
    exit 3
fi

# ===========================================================
# PHASE 1: STRIX – Dependency extraction
# ===========================================================
echo "[Phase 1] STRIX – Extracting dependencies..."

if [ "$HAS_OCAML" -eq 1 ] && [ -f "$SKILL_DIR/strix/strix.ml" ]; then
    echo "[Strix] Compiling OCaml parser..."
    cd "$SKILL_DIR/strix"
    if ocamlfind ocamlopt -package unix -linkpkg strix.ml strix_main.ml -o strix_bin 2>/dev/null; then
        ./strix_bin "$TARGET_BINARY" --depth "$MAX_DEPTH" --output "$WORKSPACE/deps/strix_output.json"
    else
        echo "[Strix] OCaml compilation failed, using readelf fallback"
        HAS_OCAML=0
    fi
    cd "$WORKSPACE"
fi

if [ "$HAS_OCAML" -eq 0 ]; then
    echo "[Strix] Using readelf fallback..."

    # Recursive dependency extraction via readelf
    extract_deps() {
        local bin="$1"
        local depth="$2"
        local prefix="${3:-}"

        [ "$depth" -le 0 ] && return

        local deps
        deps=$(readelf -d "$bin" 2>/dev/null | grep NEEDED | sed 's/.*\[//;s/\]//' || true)

        for lib in $deps; do
            # Resolve path
            local libpath=""
            for searchdir in /usr/lib /usr/lib64 /lib /lib64 \
                             /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu \
                             /lib/x86_64-linux-gnu; do
                if [ -f "$searchdir/$lib" ]; then
                    libpath="$searchdir/$lib"
                    break
                fi
            done

            # Get symbol count
            local symcount=0
            if [ -n "$libpath" ] && [ "$HAS_NM" -eq 1 ]; then
                symcount=$(nm -D "$libpath" 2>/dev/null | wc -l || echo 0)
            fi

            # Get SONAME/version
            local version="null"
            if [ -n "$libpath" ]; then
                local soname
                soname=$(readelf -d "$libpath" 2>/dev/null | grep SONAME | sed 's/.*\[//;s/\]//' || true)
                [ -n "$soname" ] && version="\"$soname\""
            fi

            local pathstr="null"
            [ -n "$libpath" ] && pathstr="\"$libpath\""

            echo "${prefix}{\"name\":\"$lib\",\"path\":$pathstr,\"version\":$version,\"needed_by\":[\"$bin\"],\"symbol_count\":$symcount}"

            # Record lib name for later phases
            echo "$lib" >> "$WORKSPACE/deps/needed.txt"

            # Recurse into library
            if [ -n "$libpath" ]; then
                extract_deps "$libpath" $((depth - 1)) "$prefix"
            fi
        done
    }

    > "$WORKSPACE/deps/needed.txt"
    echo "{" > "$WORKSPACE/deps/strix_output.json"
    echo "  \"target\": \"$TARGET_BINARY\"," >> "$WORKSPACE/deps/strix_output.json"
    echo "  \"depth\": $MAX_DEPTH," >> "$WORKSPACE/deps/strix_output.json"
    echo "  \"libraries\": [" >> "$WORKSPACE/deps/strix_output.json"

    # Collect deps
    DEPS_JSON=$(extract_deps "$TARGET_BINARY" "$MAX_DEPTH" "    ")
    # Deduplicate and comma-separate
    echo "$DEPS_JSON" | sort -u | sed '$ ! s/$/,/' >> "$WORKSPACE/deps/strix_output.json"

    echo "  ]" >> "$WORKSPACE/deps/strix_output.json"
    echo "}" >> "$WORKSPACE/deps/strix_output.json"

    # Deduplicate needed.txt
    sort -u "$WORKSPACE/deps/needed.txt" -o "$WORKSPACE/deps/needed.txt"
fi

LIB_COUNT=$(wc -l < "$WORKSPACE/deps/needed.txt" 2>/dev/null || echo 0)
echo "[Strix] Found $LIB_COUNT unique libraries"
echo ""

# ===========================================================
# PHASE 2: CHIMERA – CVE lookup
# ===========================================================
echo "[Phase 2] CHIMERA – Looking up CVEs..."
TOTAL_CVES=0

if [ "$HAS_PERL" -eq 1 ] && [ -f "$SKILL_DIR/chimera/chimera.pl" ]; then
    while IFS= read -r lib; do
        [ -z "$lib" ] && continue
        safe_lib=$(echo "$lib" | tr '/' '_' | tr '.' '_')
        echo "[Chimera] Querying: $lib"
        if perl "$SKILL_DIR/chimera/chimera.pl" "$lib" --output "$WORKSPACE/deps/${safe_lib}.cves.json" 2>>"$LOG"; then
            if [ "$HAS_JQ" -eq 1 ]; then
                count=$(jq 'length' "$WORKSPACE/deps/${safe_lib}.cves.json" 2>/dev/null || echo 0)
            else
                count=$(grep -o '"id"' "$WORKSPACE/deps/${safe_lib}.cves.json" 2>/dev/null | wc -l || echo 0)
            fi
            TOTAL_CVES=$((TOTAL_CVES + count))
            echo "  -> $count CVEs found"
        else
            echo "  -> Query failed (network or dependency issue)"
            echo "[]" > "$WORKSPACE/deps/${safe_lib}.cves.json"
        fi
    done < "$WORKSPACE/deps/needed.txt"
else
    echo "[Chimera] WARNING: Perl not available, skipping CVE lookup"
    echo "[Chimera] Install perl with JSON and LWP::UserAgent modules"
fi

echo "[Chimera] Total CVEs found: $TOTAL_CVES"
echo ""

# ===========================================================
# PHASE 3: ORACLE – Patch verification
# ===========================================================
echo "[Phase 3] ORACLE – Verifying patch status..."
VERDICTS=0

if [ "$HAS_PERL" -eq 1 ] && [ -f "$SKILL_DIR/oracle/verify_patch.pl" ]; then
    for cve_file in "$WORKSPACE"/deps/*.cves.json; do
        [ -f "$cve_file" ] || continue

        safe_lib=$(basename "$cve_file" .cves.json)

        # Extract CVE IDs and vulnerable functions
        if [ "$HAS_JQ" -eq 1 ]; then
            jq -r '.[] | "\(.id)\t\(.vuln_functions[0] // "")"' "$cve_file" 2>/dev/null | \
            while IFS=$'\t' read -r cve_id vuln_func; do
                [ -z "$cve_id" ] && continue

                # Find the actual library path
                lib_path=""
                lib_name=$(echo "$safe_lib" | tr '_' '.')
                for searchdir in /usr/lib /usr/lib64 /lib /lib64 \
                                 /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu; do
                    if [ -f "$searchdir/$lib_name" ]; then
                        lib_path="$searchdir/$lib_name"
                        break
                    fi
                done

                if [ -n "$lib_path" ]; then
                    echo "[Oracle] Checking $cve_id against $lib_path (func: ${vuln_func:-none})"
                    perl "$SKILL_DIR/oracle/verify_patch.pl" "$lib_path" "$cve_id" "$vuln_func" \
                        --output "$WORKSPACE/deps/${safe_lib}.${cve_id}.verdict.json" 2>>"$LOG" || true
                    VERDICTS=$((VERDICTS + 1))
                fi
            done
        else
            # Fallback: extract CVE IDs with grep
            grep -oP '"id"\s*:\s*"\K[^"]+' "$cve_file" 2>/dev/null | \
            while read -r cve_id; do
                echo "[Oracle] Checking $cve_id (no jq, limited analysis)"
                echo "{\"cve\":\"$cve_id\",\"verdict\":\"INDETERMINATE\",\"confidence\":\"LOW\"}" \
                    > "$WORKSPACE/deps/${safe_lib}.${cve_id}.verdict.json"
                VERDICTS=$((VERDICTS + 1))
            done
        fi
    done
fi

echo "[Oracle] Produced $VERDICTS verdicts"
echo ""

# ===========================================================
# PHASE 4: SPHINX – Build provenance graph
# ===========================================================
echo "[Phase 4] SPHINX – Building provenance graph..."

# Assemble final dependency_graph.json
if [ "$HAS_JQ" -eq 1 ]; then
    # Merge all verdicts into a single report
    VERDICTS_ARRAY="[]"
    for verdict_file in "$WORKSPACE"/deps/*.verdict.json; do
        [ -f "$verdict_file" ] || continue
        VERDICTS_ARRAY=$(echo "$VERDICTS_ARRAY" | jq --slurpfile v "$verdict_file" '. + $v')
    done

    jq -n \
        --arg target "$TARGET_BINARY" \
        --arg timestamp "$(date -Iseconds)" \
        --arg depth "$MAX_DEPTH" \
        --slurpfile deps "$WORKSPACE/deps/strix_output.json" \
        --argjson verdicts "$VERDICTS_ARRAY" \
        '{
            target: $target,
            timestamp: $timestamp,
            max_depth: ($depth | tonumber),
            dependencies: $deps[0].libraries,
            cve_verdicts: $verdicts,
            summary: {
                total_libraries: ($deps[0].libraries | length),
                total_cves_checked: ($verdicts | length),
                vulnerable: ($verdicts | map(select(.verdict == "VULNERABLE")) | length),
                likely_vulnerable: ($verdicts | map(select(.verdict == "LIKELY_VULNERABLE")) | length),
                patched: ($verdicts | map(select(.verdict == "PATCHED")) | length),
                indeterminate: ($verdicts | map(select(.verdict == "INDETERMINATE" or .verdict == "NO_FUNCTION_TO_CHECK")) | length)
            }
        }' > "$WORKSPACE/results/dependency_graph.json"
else
    # Manual assembly without jq
    echo "{" > "$WORKSPACE/results/dependency_graph.json"
    echo "  \"target\": \"$TARGET_BINARY\"," >> "$WORKSPACE/results/dependency_graph.json"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$WORKSPACE/results/dependency_graph.json"
    echo "  \"max_depth\": $MAX_DEPTH," >> "$WORKSPACE/results/dependency_graph.json"
    echo "  \"verdicts\": [" >> "$WORKSPACE/results/dependency_graph.json"
    first=1
    for verdict_file in "$WORKSPACE"/deps/*.verdict.json; do
        [ -f "$verdict_file" ] || continue
        [ "$first" -eq 0 ] && echo "," >> "$WORKSPACE/results/dependency_graph.json"
        cat "$verdict_file" >> "$WORKSPACE/results/dependency_graph.json"
        first=0
    done
    echo "  ]" >> "$WORKSPACE/results/dependency_graph.json"
    echo "}" >> "$WORKSPACE/results/dependency_graph.json"
fi

# === Generate markdown report ===
echo "# Phoenix Supply Chain Audit Report" > "$WORKSPACE/results/phoenix_report.md"
echo "" >> "$WORKSPACE/results/phoenix_report.md"
echo "**Target:** \`$TARGET_BINARY\`" >> "$WORKSPACE/results/phoenix_report.md"
echo "**Timestamp:** $(date -Iseconds)" >> "$WORKSPACE/results/phoenix_report.md"
echo "**Depth:** $MAX_DEPTH" >> "$WORKSPACE/results/phoenix_report.md"
echo "**Libraries found:** $LIB_COUNT" >> "$WORKSPACE/results/phoenix_report.md"
echo "**CVEs checked:** $TOTAL_CVES" >> "$WORKSPACE/results/phoenix_report.md"
echo "" >> "$WORKSPACE/results/phoenix_report.md"
echo "## Dependencies" >> "$WORKSPACE/results/phoenix_report.md"
echo "" >> "$WORKSPACE/results/phoenix_report.md"
cat "$WORKSPACE/deps/needed.txt" | while read -r lib; do
    echo "- \`$lib\`" >> "$WORKSPACE/results/phoenix_report.md"
done
echo "" >> "$WORKSPACE/results/phoenix_report.md"
echo "## Verdicts" >> "$WORKSPACE/results/phoenix_report.md"
echo "" >> "$WORKSPACE/results/phoenix_report.md"
for verdict_file in "$WORKSPACE"/deps/*.verdict.json; do
    [ -f "$verdict_file" ] || continue
    if [ "$HAS_JQ" -eq 1 ]; then
        cve=$(jq -r '.cve' "$verdict_file" 2>/dev/null)
        verd=$(jq -r '.verdict' "$verdict_file" 2>/dev/null)
        conf=$(jq -r '.confidence' "$verdict_file" 2>/dev/null)
        echo "- **$cve**: $verd ($conf)" >> "$WORKSPACE/results/phoenix_report.md"
    fi
done

echo "" >> "$WORKSPACE/results/phoenix_report.md"
echo "---" >> "$WORKSPACE/results/phoenix_report.md"
echo "*Generated by Phoenix Supply Chain Oracle*" >> "$WORKSPACE/results/phoenix_report.md"

echo "[Sphinx] Graph and report written"
echo ""

# ===========================================================
# PHASE 5: KEEL – Seal everything
# ===========================================================
echo "[Phase 5] KEEL – Sealing artifacts..."
make -f "$SKILL_DIR/keel/Makefile" all WORKSPACE="$WORKSPACE" TARGET_BINARY="$TARGET_BINARY"

echo ""
echo "============================================"
echo " Phoenix – Analysis Complete"
echo "============================================"
echo " Results:    $WORKSPACE/results/dependency_graph.json"
echo " Report:     $WORKSPACE/results/phoenix_report.md"
echo " Seals:      $WORKSPACE/seals/"
echo " Provenance: $WORKSPACE/provenance_chain.txt"
echo " Log:        $LOG"
echo "============================================"
