# Recipe Importer

A small Chromium extension for turning recipe pages into Obsidian notes and sending recipe ingredients to Bring!.

## What It Does

When you open the extension popup on a recipe page, it:

1. Looks for a `schema.org/Recipe` JSON-LD block in the current page.
2. Extracts the recipe name, ingredients, instructions, and image.
3. Asks the native host for the current subfolders under `Cuisine` in the Obsidian vault.
4. Offers two actions:
   - **Obsidian**: creates a new note through an `obsidian://new` URL.
   - **Bring!**: asks Bring! to generate a recipe deeplink, then opens it so Bring! can import addable ingredients.

The Obsidian note includes:

- YAML frontmatter with the source URL.
- The recipe image, when one is available.
- Ingredients as a Markdown list.
- Instructions as numbered steps.

## Why There Is A Native Host

The Bring! recipe deeplink endpoint rejects direct browser-extension requests with HTTP `403`, because the browser sends extension-origin request headers. To avoid that CORS/origin issue, the extension uses Chrome/Brave native messaging:

```text
extension popup -> native host -> Bring! API -> deeplink -> extension popup
```

The native host is a small Python script:

- `bring_native_host.py` reads one native-messaging request from stdin.
- It sends a POST request to `https://api.getbring.com/rest/bringrecipes/deeplink`.
- It lists Obsidian subfolders under the configured recipe directory.
- It returns the generated deeplink to the extension.

The shell wrapper `bring_native_host.sh` launches the Python script and writes diagnostics to `/tmp/com.manu.bringimport.stderr.log`.

## Files

- `manifest.json`: Chromium extension manifest.
- `popup.html`: popup UI.
- `popup.js`: recipe extraction, Obsidian note generation, Bring! integration.
- `bring_native_host.py`: native messaging host that calls Bring!.
- `bring_native_host.sh`: executable wrapper used by Chromium.
- `com.manu.bringimport.json`: native host manifest template.
- `install_native_host.sh`: installs the native host for the current extension ID.
- `icon-chefs-kiss.png`: source icon.
- `icons/`: resized extension icons.

## Initial Setup On A New Mac

### 1. Clone Or Copy This Folder

Put the folder somewhere stable. The unpacked extension ID is tied to the extension path, so moving the folder can change the extension ID.

### 2. Load The Extension

In Brave:

1. Open `brave://extensions`.
2. Enable **Developer mode**.
3. Click **Load unpacked**.
4. Select this folder.
5. Copy the generated extension ID.

In Chrome:

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Click **Load unpacked**.
4. Select this folder.
5. Copy the generated extension ID.

Other Chromium browsers use the same general flow, usually at one of:

- `edge://extensions`
- `opera://extensions`
- `vivaldi://extensions`
- `chrome://extensions`

### 3. Install The Native Host

Run this from the project folder, replacing the ID with the one shown by the browser:

```sh
./install_native_host.sh YOUR_EXTENSION_ID
```

The script currently installs native host manifests for macOS Brave and Chrome:

```text
~/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.manu.bringimport.json
~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.manu.bringimport.json
```

The native host files themselves are copied to:

```text
~/Library/Application Support/com.manu.bringimport/
```

After installing, fully quit and reopen the browser. Reloading the extension is often not enough for native messaging manifest changes.

## Other Chromium Browsers

Native messaging host manifests are browser-specific. If you use another Chromium browser, copy the generated `com.manu.bringimport.json` into that browser's `NativeMessagingHosts` directory.

Common macOS locations:

```text
~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/
~/Library/Application Support/Vivaldi/NativeMessagingHosts/
~/Library/Application Support/Chromium/NativeMessagingHosts/
~/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/
~/Library/Application Support/Google/Chrome/NativeMessagingHosts/
```

The manifest must contain the exact extension ID:

```json
"allowed_origins": [
  "chrome-extension://YOUR_EXTENSION_ID/"
]
```

If the browser shows a new extension ID after moving/reloading the folder, rerun:

```sh
./install_native_host.sh NEW_EXTENSION_ID
```

## Troubleshooting

If Bring! fails with `Native host has exited`, check whether the browser actually launched the wrapper:

```sh
tail -n 50 /tmp/com.manu.bringimport.stderr.log
```

Then check the Python host log:

```sh
tail -n 50 ~/Library/Logs/com.manu.bringimport.log
```

Useful signals:

- If neither log changes, the browser did not find or authorize the native host manifest.
- If only the `/tmp` wrapper log changes, Python failed before app logging.
- If the Python log changes and shows an error, the native host launched and the issue is inside the Bring! request.

Also verify:

- The extension has the `nativeMessaging` permission in `manifest.json`.
- `allowed_origins` exactly matches the current extension ID.
- The native host manifest path points to an executable file.
- You fully quit and reopen the browser after changing native host manifests.

## Obsidian Notes

The Obsidian action uses an `obsidian://new` URL. The current vault and recipe folder settings are at the top of `popup.js`:

```js
const VAULT = "Manu's vault";
const CUISINE_DIR = 'Cuisine';
```

The popup asks the native host for the current subfolders inside:

```text
<vault>/Cuisine/
```

If the native host cannot read the vault, the popup falls back to a small built-in list so the extension remains usable.

By default, the host looks for the vault in common macOS locations, including:

```text
~/Documents/Manu's vault
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Manu's vault
~/Library/Mobile Documents/com~apple~CloudDocs/Manu's vault
~/Library/CloudStorage/Dropbox/Manu's vault
```

If the vault lives somewhere else, set `OBSIDIAN_VAULT_PATH` in `bring_native_host.sh` before reinstalling the native host. Example:

```sh
export OBSIDIAN_VAULT_PATH="$HOME/Somewhere/Manu's vault"
```

Then rerun:

```sh
./install_native_host.sh YOUR_EXTENSION_ID
```
