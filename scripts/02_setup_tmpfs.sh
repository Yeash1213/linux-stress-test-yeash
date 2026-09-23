#!/bin/bash
# Part 2: Mount a size-capped tmpfs scratch area owned by the service (idempotent).
set -euo pipefail

SVC_NAME="${SVC_NAME:-bgdsvc_yeash}"
MNT="/mnt/${SVC_NAME}_tmp"
SIZE="256M"   # hard cap so tmpfs can never eat all RAM

if ! id "$SVC_NAME" &>/dev/null; then
    echo "[ERROR] User '$SVC_NAME' does not exist. Run 01_create_user.sh first." >&2
    exit 1
fi

sudo mkdir -p "$MNT"

if mountpoint -q "$MNT"; then
    echo "[SKIP] $MNT is already mounted."
else
    sudo mount -t tmpfs -o size=$SIZE tmpfs "$MNT"
    echo "[OK] Mounted tmpfs (size=$SIZE) at $MNT"
fi

sudo chown "$SVC_NAME:$SVC_NAME" "$MNT"
df -h "$MNT"
