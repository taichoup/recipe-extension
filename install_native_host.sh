#!/usr/bin/env bash
# Usage:
#   ./install_native_host.sh --chrome <extension-id>   # Chrome + Brave
#   ./install_native_host.sh --firefox                 # Firefox (fixed extension ID from manifest)
# Find your Chrome/Brave extension ID at chrome://extensions or brave://extensions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_DIR="$HOME/Library/Application Support/com.manu.bringimport"
HOST_PATH="$HOST_DIR/bring_native_host.sh"

# Install host binary (shared by all browsers)
mkdir -p "$HOST_DIR"
cp "$SCRIPT_DIR/bring_native_host.sh" "$SCRIPT_DIR/bring_native_host.py" "$HOST_DIR/"
chmod +x "$HOST_DIR/bring_native_host.sh" "$HOST_DIR/bring_native_host.py"

if [[ "${1:-}" == "--firefox" ]]; then
  : # handled below
elif [[ "${1:-}" == "--chrome" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Usage: ./install_native_host.sh --chrome <extension-id>"
    echo "Find the ID at chrome://extensions or brave://extensions after loading the extension."
    exit 1
  fi
  # fall through to the chrome block below with $2 as the ID
  set -- "$2"  # replace $1 with the extension ID so the else branch works unchanged
fi

if [[ "${1:-}" == "--firefox" ]]; then
  FIREFOX_MANIFEST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
  mkdir -p "$FIREFOX_MANIFEST_DIR"

  sed "s|HOST_PATH_PLACEHOLDER|$HOST_PATH|" \
    "$SCRIPT_DIR/com.manu.bringimport.firefox.json" \
    > "$FIREFOX_MANIFEST_DIR/com.manu.bringimport.json"

  xattr -d com.apple.quarantine "$HOST_PATH" "$HOST_DIR/bring_native_host.py" "$FIREFOX_MANIFEST_DIR/com.manu.bringimport.json" 2>/dev/null || true
  xattr -d com.apple.provenance "$HOST_PATH" "$HOST_DIR/bring_native_host.py" "$FIREFOX_MANIFEST_DIR/com.manu.bringimport.json" 2>/dev/null || true

  echo "✓ Native host installed for Firefox (extension ID: recipe-importer@manu)"
  echo "  Reload the extension in Firefox for it to take effect."
else
  if [[ -z "${1:-}" ]]; then
    echo "Usage:"
    echo "  ./install_native_host.sh --chrome <extension-id>   # Chrome / Brave"
    echo "  ./install_native_host.sh --firefox                 # Firefox"
    echo ""
    echo "For Chrome/Brave: load the extension first, then copy its ID from the extensions page."
    exit 1
  fi

  EXTENSION_ID="$1"
  BRAVE_MANIFEST_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
  CHROME_MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
  mkdir -p "$BRAVE_MANIFEST_DIR" "$CHROME_MANIFEST_DIR"

  for MANIFEST_DIR in "$BRAVE_MANIFEST_DIR" "$CHROME_MANIFEST_DIR"; do
    sed "s|EXTENSION_ID_PLACEHOLDER|$EXTENSION_ID|; s|HOST_PATH_PLACEHOLDER|$HOST_PATH|" \
      "$SCRIPT_DIR/com.manu.bringimport.json" \
      > "$MANIFEST_DIR/com.manu.bringimport.json"
  done

  xattr -d com.apple.quarantine "$HOST_PATH" "$HOST_DIR/bring_native_host.py" "$BRAVE_MANIFEST_DIR/com.manu.bringimport.json" "$CHROME_MANIFEST_DIR/com.manu.bringimport.json" 2>/dev/null || true
  xattr -d com.apple.provenance "$HOST_PATH" "$HOST_DIR/bring_native_host.py" "$BRAVE_MANIFEST_DIR/com.manu.bringimport.json" "$CHROME_MANIFEST_DIR/com.manu.bringimport.json" 2>/dev/null || true

  echo "✓ Native host installed for extension $EXTENSION_ID"
  echo "  Reload the extension in Brave/Chrome for it to take effect."
fi

echo "  Host logs: ~/Library/Logs/com.manu.bringimport.log"
echo "  Wrapper diagnostics: /tmp/com.manu.bringimport.stderr.log"
