#!/usr/bin/python3
import datetime
import json
import os
import struct
import sys
import traceback
import urllib.request

LOG_PATH = os.environ.get(
    "BRINGIMPORT_LOG_PATH",
    os.path.expanduser("~/Library/Logs/com.manu.bringimport.log"),
)
DEFAULT_OBSIDIAN_VAULT_NAME = "Manu's vault"


def log(message):
    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
        with open(LOG_PATH, "a", encoding="utf-8") as log_file:
            print(f"[{datetime.datetime.now().isoformat(timespec='seconds')}] {message}", file=log_file)
    except Exception:
        # Native messaging stdout must contain only framed JSON messages.
        pass


def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) == 0:
        sys.exit(0)
    length = struct.unpack('<I', raw_length)[0]
    payload = sys.stdin.buffer.read(length)
    return json.loads(payload)


def send_message(payload):
    encoded = json.dumps(payload).encode('utf-8')
    sys.stdout.buffer.write(struct.pack('<I', len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


def get_bring_deeplink(url):
    body = json.dumps({"url": url, "source": "web"}).encode()
    req = urllib.request.Request(
        "https://api.getbring.com/rest/bringrecipes/deeplink",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read())["deeplink"]


def candidate_vault_paths(vault_name):
    configured_path = os.environ.get("OBSIDIAN_VAULT_PATH")
    if configured_path:
        yield os.path.expanduser(configured_path)

    home = os.path.expanduser("~")
    candidates = [
        os.path.join(home, "Documents", vault_name),
        os.path.join(home, "Library", "Mobile Documents", "iCloud~md~obsidian", "Documents", vault_name),
        os.path.join(home, "Library", "Mobile Documents", "com~apple~CloudDocs", vault_name),
        os.path.join(home, "Library", "CloudStorage", "Dropbox", vault_name),
        os.path.join(home, "Library", "CloudStorage", "GoogleDrive", vault_name),
        os.path.join(home, "Dropbox", vault_name),
        os.path.join(home, vault_name),
    ]
    for path in candidates:
        yield path


def find_vault_path(vault_name):
    for path in candidate_vault_paths(vault_name):
        if os.path.isdir(path):
            return path
    raise FileNotFoundError(
        f"Obsidian vault '{vault_name}' not found. Set OBSIDIAN_VAULT_PATH in bring_native_host.sh."
    )


def list_obsidian_folders(vault_name, base_dir):
    vault_path = find_vault_path(vault_name or DEFAULT_OBSIDIAN_VAULT_NAME)
    folder_path = os.path.join(vault_path, base_dir)
    if not os.path.isdir(folder_path):
        raise FileNotFoundError(f"Obsidian folder not found: {folder_path}")

    folders = []
    for name in os.listdir(folder_path):
        if name.startswith("."):
            continue
        full_path = os.path.join(folder_path, name)
        if os.path.isdir(full_path):
            folders.append(name)
    return sorted(folders, key=str.casefold)


log("started")
try:
    msg = read_message()
    log(f"got message: {msg}")

    action = msg.get("action")
    if not action and "url" in msg:
        action = "bringDeeplink"

    if action == "bringDeeplink":
        deeplink = get_bring_deeplink(msg["url"])
        log(f"deeplink: {deeplink}")
        send_message({"deeplink": deeplink})
    elif action == "listObsidianFolders":
        folders = list_obsidian_folders(
            msg.get("vaultName") or DEFAULT_OBSIDIAN_VAULT_NAME,
            msg.get("baseDir") or "",
        )
        log(f"folders: {folders}")
        send_message({"folders": folders})
    else:
        send_message({"error": f"Unknown action: {action}"})
except Exception as e:
    log(f"error: {traceback.format_exc()}")
    send_message({"error": str(e)})
