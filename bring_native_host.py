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


log("started")
try:
    msg = read_message()
    log(f"got message: {msg}")
    body = json.dumps({"url": msg["url"], "source": "web"}).encode()
    req = urllib.request.Request(
        "https://api.getbring.com/rest/bringrecipes/deeplink",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        deeplink = json.loads(resp.read())["deeplink"]
    log(f"deeplink: {deeplink}")
    send_message({"deeplink": deeplink})
except Exception as e:
    log(f"error: {traceback.format_exc()}")
    send_message({"error": str(e)})
