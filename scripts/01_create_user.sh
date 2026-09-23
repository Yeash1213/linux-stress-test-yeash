#!/bin/bash
# Part 1: Create the dedicated service account (idempotent).
set -euo pipefail

SVC_NAME="${SVC_NAME:-bgdsvc_yeash}"

if id "$SVC_NAME" &>/dev/null; then
    echo "[SKIP] User '$SVC_NAME' already exists. Nothing to do."
else
    sudo useradd -r -m -s /usr/sbin/nologin "$SVC_NAME"
    echo "[OK] User '$SVC_NAME' created (system account, nologin shell)."
fi

id "$SVC_NAME"
getent passwd "$SVC_NAME"
