#!/usr/bin/env bash
set -euo pipefail

# ---------- inputs & guards ----------
SOURCE_DIR="${1:?usage: backup.sh <source-dir> [backup-root]}"
BACKUP_ROOT="${2:-/tmp/backups}"          # ${2:-default} = use $2 if given, else default
LOGFILE="$BACKUP_ROOT/backup.log"
KEEP=5                                     # how many archives to retain

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "error: '$SOURCE_DIR' is not a directory" >&2
  exit 1
fi

mkdir -p "$BACKUP_ROOT"

# ---------- logging ----------
log() { echo "[$(date -Is)] $*" | tee -a "$LOGFILE"; }

# ---------- failure alerting ----------
trap 'log "ERROR: backup FAILED at line $LINENO"; exit 1' ERR

# ---------- create the archive ----------
STAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE="$BACKUP_ROOT/backup-$STAMP.tar.gz"

log "starting backup of $SOURCE_DIR"

# YOUR CODE 1: create the tar.gz.
tar czf "$ARCHIVE" -C "$SOURCE_DIR" .   # ( -C changes into the dir first, so the archive holds relative paths, not /home/... )

# ---------- verify it ----------
tar tzf "$ARCHIVE" > /dev/null || { log "ERROR: verification failed"; exit 1; }

SIZE=$(du -h "$ARCHIVE" | cut -f1)
log "created $ARCHIVE ($SIZE)"

# ---------- rotation: keep only the newest $KEEP archives ----------
find "$BACKUP_ROOT" -maxdepth 1 -name 'backup-*.tar.gz' -printf '%T@ %p\n' \
  | sort -rn | tail -n +$((KEEP+1)) | cut -d' ' -f2- | xargs -r rm -f

log "rotation complete; retaining newest $KEEP"
log "backup finished successfully"
