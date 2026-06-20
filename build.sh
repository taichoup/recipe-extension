#!/usr/bin/env bash
# Produces dist/firefox/ ready to load via about:debugging → Load Temporary Add-on.
# Chrome loads directly from the repo root (manifest.json).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/dist/firefox"

rm -rf "$OUT"
mkdir -p "$OUT"

cp -r "$SCRIPT_DIR/icons" "$SCRIPT_DIR/popup.html" "$SCRIPT_DIR/popup.js" "$OUT/"
cp "$SCRIPT_DIR/com.manu.bringimport.firefox.json" "$OUT/com.manu.bringimport.firefox.json"

# The Firefox manifest lives at root under a different name to avoid conflicts.
cp "$SCRIPT_DIR/manifest.firefox.json" "$OUT/manifest.json"

echo "✓ Firefox build ready at dist/firefox/"
echo "  In Firefox: about:debugging → This Firefox → Load Temporary Add-on → select dist/firefox/manifest.json"
