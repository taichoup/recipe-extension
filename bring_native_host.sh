#!/bin/bash
HOST_DIR="$(cd "$(dirname "$0")" && pwd)"
{
  echo "wrapper started at $(date)"
  echo "argv0=$0"
  echo "host_dir=$HOST_DIR"
} >>"/tmp/com.manu.bringimport.stderr.log" 2>/dev/null || true
export BRINGIMPORT_LOG_PATH="$HOME/Library/Logs/com.manu.bringimport.log"
exec /usr/bin/python3 "$HOST_DIR/bring_native_host.py"
