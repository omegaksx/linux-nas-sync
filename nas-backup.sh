#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/nas-backup.conf"

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config file not found at $CONFIG_FILE" >&2
    exit 1
fi
# shellcheck source=nas-backup.conf
source "$CONFIG_FILE"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# Reachability check — skip silently if NAS is offline
# ---------------------------------------------------------------------------
if ! rsync --list-only \
        --password-file="$PASSWORD_FILE" \
        --port="$NAS_PORT" \
        "${NAS_USER}@${NAS_HOST}::" &>/dev/null; then
    log "NAS not reachable — skipping backup run."
    exit 0
fi

# ---------------------------------------------------------------------------
# Backup each directory pair
# ---------------------------------------------------------------------------
TIMESTAMP="$(date '+%Y-%m-%d_%H%M')"
ERRORS=0

for pair in "${SYNC_DIRS[@]}"; do
    local_dir="${pair%%:*}"
    nas_module_path="${pair##*:}"
    dir_name="$(basename "$nas_module_path")"

    if [[ ! -d "$local_dir" ]]; then
        log "WARN: source directory does not exist, skipping: $local_dir"
        continue
    fi

    log "Syncing  $local_dir  →  ${NAS_USER}@${NAS_HOST}::${nas_module_path}"

    # Versioned backup: files that would be deleted or overwritten are moved
    # into ../.versions/<dir_name>/<timestamp>/ relative to the destination,
    # so they accumulate as <module>/.versions/<dir_name>/<timestamp>/ on the NAS.
    rsync \
        --archive \
        --delete \
        --backup \
        --backup-dir="../.versions/${dir_name}/${TIMESTAMP}" \
        --human-readable \
        --stats \
        --password-file="$PASSWORD_FILE" \
        --port="$NAS_PORT" \
        "${local_dir}/" \
        "${NAS_USER}@${NAS_HOST}::${nas_module_path}/" \
    && log "OK: $local_dir" \
    || { log "ERROR: rsync failed for $local_dir"; ERRORS=$((ERRORS + 1)); }
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $ERRORS -gt 0 ]]; then
    log "Backup finished with $ERRORS error(s)."
    exit 1
else
    log "Backup finished successfully."
fi
