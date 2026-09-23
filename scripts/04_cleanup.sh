#!/bin/bash
# Part 8: Tear everything down in REVERSE build order.
# Idempotent: every step tolerates "already gone", so it is safe to re-run
# even if a previous run failed partway through.
set -u

SVC_NAME="${SVC_NAME:-bgdsvc_yeash}"
MNT="/mnt/${SVC_NAME}_tmp"

echo "[1/5] Killing processes owned by $SVC_NAME"
if id "$SVC_NAME" &>/dev/null; then
    sudo pkill -u "$SVC_NAME" 2>/dev/null && sleep 1
    sudo pkill -9 -u "$SVC_NAME" 2>/dev/null || true
else
    echo "      user already gone, skipping"
fi

echo "[2/5] Removing automation (crontab, logrotate, helper scripts)"
if id "$SVC_NAME" &>/dev/null; then
    sudo crontab -r -u "$SVC_NAME" 2>/dev/null || echo "      no crontab to remove"
fi
sudo rm -f "/etc/logrotate.d/$SVC_NAME"
sudo rm -f "/usr/local/bin/${SVC_NAME}_monitor.sh"
sudo rm -f "/usr/local/bin/${SVC_NAME}_cleanup_old_files.sh"
# Undo SSH hardening: AllowUsers would point at a deleted account and lock everyone out
if [ -f /etc/ssh/sshd_config.bak ]; then
    sudo mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    # Ubuntu 24.04 uses socket activation: reload so ssh.socket picks the port back up
    sudo systemctl daemon-reload 2>/dev/null
    if systemctl is-active --quiet ssh.socket 2>/dev/null; then
        sudo systemctl restart ssh.socket
    fi
    (sudo systemctl restart ssh 2>/dev/null || sudo service ssh restart) >/dev/null 2>&1
    echo "      restored original sshd_config"
else
    echo "      no sshd_config.bak found (already restored or never backed up)"
fi

echo "[3/5] Unmounting storage"
if mountpoint -q "$MNT" 2>/dev/null; then
    sudo umount "$MNT" || sudo umount -l "$MNT"
else
    echo "      $MNT not mounted, skipping"
fi
[ -d "$MNT" ] && sudo rmdir "$MNT"

echo "[4/5] Removing logs"
sudo rm -rf "/var/log/$SVC_NAME"

echo "[5/5] Removing the service identity"
if id "$SVC_NAME" &>/dev/null; then
    sudo userdel -r "$SVC_NAME" 2>/dev/null || sudo userdel "$SVC_NAME"
else
    echo "      user already removed, skipping"
fi

echo
echo "===== Verification ====="
id "$SVC_NAME" 2>&1                                 || true   # should fail
echo "mount | grep $SVC_NAME:"; mount | grep "$SVC_NAME" || echo "  (nothing mounted)"
echo "ps -u $SVC_NAME:";        ps -u "$SVC_NAME" 2>&1 | head -1 || true
