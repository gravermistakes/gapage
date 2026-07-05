#!/usr/bin/env bash
# apk-unpack.sh - GPL APK unpacker
set -euo pipefail
APK="$1"; OUT="${2:-.}"; mkdir -p "$OUT"
unzip -q "$APK" -d "$OUT" 2>/dev/null || { echo "APK unpack failed"; exit 1; }
echo "Unpacked: $APK -> $OUT"
find "$OUT" -name "*.dex" | wc -l | xargs echo "DEX files:"
find "$OUT" -name "*.so" | wc -l | xargs echo "Native libs:"
[ -f "$OUT/AndroidManifest.xml" ] && echo "Manifest: present"
