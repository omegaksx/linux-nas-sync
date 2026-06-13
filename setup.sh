#!/usr/bin/env bash
# setup.sh — Run once to install the NAS backup system (or re-run on a new machine).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/nas-backup.conf"
BACKUP_SCRIPT="${SCRIPT_DIR}/nas-backup.sh"

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: $CONFIG_FILE not found. Edit it before running setup." >&2
    exit 1
fi
# shellcheck source=nas-backup.conf
source "$CONFIG_FILE"

log() { echo "[setup] $*"; }
die() { echo "[setup] ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Dependencies
# ---------------------------------------------------------------------------
log "Checking dependencies..."
if ! command -v rsync &>/dev/null; then
    log "Installing rsync..."
    sudo apt-get update -qq
    sudo apt-get install -y rsync
fi
log "Dependencies OK."

# ---------------------------------------------------------------------------
# 2. Password file
# ---------------------------------------------------------------------------
if [[ ! -f "$PASSWORD_FILE" ]]; then
    log "Creating password file: $PASSWORD_FILE"
    read -rsp "Enter the rsync password for ${NAS_USER}@${NAS_HOST}: " rsync_pass
    echo
    mkdir -p "$(dirname "$PASSWORD_FILE")"
    echo "$rsync_pass" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    log "Password file created (chmod 600)."
else
    log "Password file already exists: $PASSWORD_FILE"
    # Ensure permissions are correct even if the file was copied over
    chmod 600 "$PASSWORD_FILE"
fi

# ---------------------------------------------------------------------------
# 3. Test connection to NAS rsync daemon
# ---------------------------------------------------------------------------
log "Testing connection to ${NAS_USER}@${NAS_HOST} on port ${NAS_PORT}..."
rsync --list-only \
    --password-file="$PASSWORD_FILE" \
    --port="$NAS_PORT" \
    "${NAS_USER}@${NAS_HOST}::" \
    || die "Cannot reach NAS rsync daemon. Check that:
  - The rsync service is enabled in the DH2300 admin panel
  - User '${NAS_USER}' exists and has the correct password
  - Port ${NAS_PORT} is not blocked by a firewall"
log "Connection OK."

# ---------------------------------------------------------------------------
# 4. Make backup script executable
# ---------------------------------------------------------------------------
chmod +x "$BACKUP_SCRIPT"
log "Backup script is executable: $BACKUP_SCRIPT"

# ---------------------------------------------------------------------------
# 5. Install cron job (idempotent)
# ---------------------------------------------------------------------------
CRON_MARKER="# nas-backup"
CRON_JOB="${CRON_SCHEDULE} ${BACKUP_SCRIPT} ${CRON_MARKER}"

( crontab -l 2>/dev/null | grep -v "$CRON_MARKER"; echo "$CRON_JOB" ) | crontab -
log "Cron job installed: $CRON_JOB"

# ---------------------------------------------------------------------------
# 6. Create log directory
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")"
log "Log directory ready: $(dirname "$LOG_FILE")"

# ---------------------------------------------------------------------------
# 7. Run first backup now
# ---------------------------------------------------------------------------
log "Running initial backup..."
bash "$BACKUP_SCRIPT"

log ""
log "Setup complete."
log "  Config:  $CONFIG_FILE"
log "  Script:  $BACKUP_SCRIPT"
log "  Cron:    $CRON_SCHEDULE"
log "  Log:     $LOG_FILE"
log ""
log "To check the log:    tail -f $LOG_FILE"
log "To run manually:     bash $BACKUP_SCRIPT"
log "To edit directories: \$EDITOR $CONFIG_FILE"
