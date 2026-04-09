#!/bin/sh
# Pre-backup hook — runs inside restic container before each backup.
#
# Postgres is covered by Immich's built-in daily backup, which writes
# compressed SQL dumps to /data/immich-library/backups/ — these are
# picked up by restic as part of the immich-library backup source.
#
# This hook verifies the most recent Immich DB dump exists and is recent
# before proceeding, so the backup aborts rather than silently missing it.
set -eu

IMMICH_BACKUP_DIR=/data/immich-library/backups

echo "[pre-backup] Checking Immich DB backup..."

# Find the most recent dump file
LATEST_DUMP=$(find "${IMMICH_BACKUP_DIR}" -name "immich-db-backup-*.sql.gz" -type f 2>/dev/null | sort | tail -1)

if [ -z "${LATEST_DUMP}" ]; then
  echo "[pre-backup] ERROR: No Immich DB dump found in ${IMMICH_BACKUP_DIR}"
  echo "[pre-backup] Check Immich Settings → Backup to ensure scheduled backups are enabled."
  exit 1
fi

# Check dump is not older than 48 hours (2 days — allows for missed runs)
DUMP_AGE_HOURS=$(( ( $(date +%s) - $(date -r "${LATEST_DUMP}" +%s) ) / 3600 ))
if [ "${DUMP_AGE_HOURS}" -gt 48 ]; then
  echo "[pre-backup] WARNING: Most recent Immich DB dump is ${DUMP_AGE_HOURS}h old: ${LATEST_DUMP}"
  echo "[pre-backup] Proceeding, but check Immich backup settings."
fi

DUMP_SIZE=$(du -sh "${LATEST_DUMP}" | cut -f1)
echo "[pre-backup] DB dump OK: $(basename "${LATEST_DUMP}") (${DUMP_SIZE}, ${DUMP_AGE_HOURS}h old)"
