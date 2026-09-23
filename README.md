# Linux SysAdmin Stress Test Lab

A full service lifecycle on Ubuntu (Multipass VM): create a service account, give it RAM-backed scratch space, stress it, secure SSH access, automate monitoring and log rotation, then tear everything down.

**Service account:** `bgdsvc_yeash`

## Structure

```text
scripts/
├── 01_create_user.sh                   # Idempotent service user creation
├── 02_setup_tmpfs.sh                   # 256M-capped tmpfs mount
├── 03_stress_and_populate.sh           # --cpu | --mem | --disk | --all
├── 04_cleanup.sh                       # Reverse-order, idempotent teardown
├── bgdsvc_yeash_monitor.sh             # Cron: snapshot every 5 min
├── bgdsvc_yeash_cleanup_old_files.sh   # Cron: nightly cleanup at 02:00
└── logrotate_bgdsvc_yeash.conf         # Logrotate rule
screenshots/                            # Proof for each part
```

## Usage

```bash
export SVC_NAME=bgdsvc_yeash
./scripts/01_create_user.sh
./scripts/02_setup_tmpfs.sh
./scripts/03_stress_and_populate.sh --all
./scripts/04_cleanup.sh
```

## What Each Part Does

1. **User:** a system account with a `nologin` shell. It checks whether the user already exists, so it is safe to run twice.
2. **tmpfs:** 256M RAM-backed scratch space at `/mnt/bgdsvc_yeash_tmp`. Writes past the cap fail cleanly with "No space left on device".
3. **Stress:** CPU, memory and disk load, run as the service user, one at a time or all together. `dmesg | grep -i oom` checks for OOM kills.
4. **SSH:** ed25519 key-based login for the service account.
5. **Hardening:** `Port 2222`, `PermitRootLogin no`, `PasswordAuthentication no`, `AllowUsers bgdsvc_yeash`.
6. **Cron:** a monitor snapshot every 5 minutes, and old scratch files cleaned out every night.
7. **Logrotate:** daily rotation, 5 copies kept, compressed, 10M size limit.
8. **Cleanup:** removes everything in reverse order (processes → automation → storage → logs → user). It also restores `sshd_config`, so SSH is not left locked to a deleted user.

## Observations

Under combined load the CPU hit 100% but the system stayed stable, and the OOM killer never triggered. The tmpfs cap worked as intended: once it was full, writes failed without affecting the host. tmpfs data also counts as shared RAM in `free -h` until the files are deleted.

**In production I would:**
1. Limit the service with systemd (`MemoryMax`, `CPUQuota`).
2. Open the new SSH port in the firewall before closing port 22.
3. Keep a backup admin account in `AllowUsers`.
4. Send metrics to real monitoring with alerts instead of a log file.
