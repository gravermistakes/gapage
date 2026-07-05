#!/usr/bin/env bash
# resource-extractor.sh - GPL resource extractor
set -euo pipefail
APK="$1"; OUT="${2:-resources}"
mkdir -p "$OUT"
unzip -q "$APK" 'res/*' resources.arsc -d "$OUT" 2>/dev/null || true
echo "Extracted resources to: $OUT"
find "$OUT" -name "*.xml" | wc -l | xargs echo "XML files:"
find "$OUT" -name "*.png" | wc -l | xargs echo "Images:"
