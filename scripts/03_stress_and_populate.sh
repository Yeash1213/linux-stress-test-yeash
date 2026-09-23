#!/bin/bash
# Part 3: Stress the system as the service user.
# Usage: 03_stress_and_populate.sh [--cpu] [--mem] [--disk] [--all]
set -uo pipefail

SVC_NAME="${SVC_NAME:-bgdsvc_yeash}"
MNT="/mnt/${SVC_NAME}_tmp"
DURATION="${DURATION:-30s}"
FILES="${FILES:-20}"   # 20 x 10MB = 200M; set FILES=30 to push past the 256M cap
STRESS_OPTS="--temp-path /tmp"   # stress-ng needs a writable temp dir for the service user

usage() {
    echo "Usage: $0 [--cpu] [--mem] [--disk] [--all]"
    exit 1
}

have_stress_ng() { command -v stress-ng &>/dev/null; }

stress_disk() {
    echo "=== [DISK] Filling $MNT with $FILES x 10MB files (cap is 256M) ==="
    if ! mountpoint -q "$MNT"; then
        echo "[ERROR] $MNT not mounted. Run 02_setup_tmpfs.sh first." >&2
        return 1
    fi
    for i in $(seq 1 "$FILES"); do
        if ! sudo -u "$SVC_NAME" dd if=/dev/urandom of="$MNT/file_$i.dat" bs=1M count=10 status=none; then
            echo "[WARN] Write of file_$i.dat failed (filesystem full?)"
        fi
        df -h "$MNT" | tail -1
    done
}

stress_cpu() {
    echo "=== [CPU] 2 workers for $DURATION ==="
    if have_stress_ng; then
        sudo -u "$SVC_NAME" stress-ng $STRESS_OPTS --cpu 2 --timeout "$DURATION" --metrics-brief
    else
        echo "stress-ng missing, falling back to 'yes > /dev/null'"
        sudo -u "$SVC_NAME" timeout "$DURATION" yes > /dev/null &
        sudo -u "$SVC_NAME" timeout "$DURATION" yes > /dev/null &
        wait
    fi
}

stress_mem() {
    echo "=== [MEM] 1 worker allocating 200M for $DURATION ==="
    if have_stress_ng; then
        sudo -u "$SVC_NAME" stress-ng $STRESS_OPTS --vm 1 --vm-bytes 200M --timeout "$DURATION" --metrics-brief
    else
        echo "[ERROR] stress-ng is required for the memory test (sudo apt install stress-ng -y)" >&2
        return 1
    fi
}

stress_all() {
    echo "=== [ALL] CPU + MEM + DISK at the same time ==="
    stress_cpu  & p1=$!
    stress_mem  & p2=$!
    stress_disk & p3=$!
    wait $p1 $p2 $p3
    echo "=== [ALL] Done. OOM check: ==="
    sudo dmesg 2>/dev/null | grep -i oom || echo "(no OOM killer events)"
}

[ $# -eq 0 ] && usage
if ! id "$SVC_NAME" &>/dev/null; then
    echo "[ERROR] User '$SVC_NAME' does not exist. Run 01_create_user.sh first." >&2
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        --cpu)  stress_cpu ;;
        --mem)  stress_mem ;;
        --disk) stress_disk ;;
        --all)  stress_all ;;
        *) usage ;;
    esac
done
