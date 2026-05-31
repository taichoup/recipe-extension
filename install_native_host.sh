#!/usr/bin/env bash
# Usage: ./install_native_host.sh <extension-id>
# Find your extension ID at brave://extensions after loading the extension.
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: ./install_native_host.sh <extension-id>"
  echo ""
  echo "Load the extension in Brave first, then copy its ID from brave://extensions."
  exit 1
fi

EXTENSION_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRAVE_MANIFEST_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
CHROME_MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
HOST_DIR="$HOME/Library/Application Support/com.manu.bringimport"
HOST_PATH="$HOST_DIR/bring_native_host.sh"

mkdir -p "$BRAVE_MANIFEST_DIR" "$CHROME_MANIFEST_DIR" "$HOST_DIR"

cp "$SCRIPT_DIR/bring_native_host.sh" "$SCRIPT_DIR/bring_native_host.py" "$HOST_DIR/"
chmod +x "$HOST_DIR/bring_native_host.sh" "$HOST_DIR/bring_native_host.py"
chmod +x "$HOST_PATH"

for MANIFEST_DIR in "$BRAVE_MANIFEST_DIR" "$CHROME_MANIFEST_DIR"; do
  sed "s|EXTENSION_ID_PLACEHOLDER|$EXTENSION_ID|; s|HOST_PATH_PLACEHOLDER|$HOST_PATH|" \
    "$SCRIPT_DIR/com.manu.bringimport.json" \
    > "$MANIFEST_DIR/com.manu.bringimport.json"
done

xattr -d com.apple.quarantine "$HOST_PATH" "$HOST_DIR/bring_native_host.py" "$BRAVE_MANIFEST_DIR/com.manu.bringimport.json" "$CHROME_MANIFEST_DIR/com.manu.bringimport.json" 2>/dev/null || true
xattr -d com.apple.provenance "$HOST_PATH" "$HOST_DIR/bring_native_host.py" "$BRAVE_MANIFEST_DIR/com.manu.bringimport.json" "$CHROME_MANIFEST_DIR/com.manu.bringimport.json" 2>/dev/null || true

echo "✓ Native host installed for extension $EXTENSION_ID"
echo "  Reload the extension in Brave (or restart Brave) for it to take effect."
echo "  Host logs: ~/Library/Logs/com.manu.bringimport.log"
echo "  Wrapper diagnostics: /tmp/com.manu.bringimport.stderr.log"
