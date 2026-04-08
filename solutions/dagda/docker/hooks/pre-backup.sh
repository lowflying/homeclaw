#!/bin/sh
# Pre-backup hook — runs inside restic container before each backup.
# Dumps Immich postgres to /backups/db/immich.sql via docker exec (Docker socket required).
set -eu

mkdir -p /backups/db

DUMP_FILE=/backups/db/immich.sql
DUMP_TMP=/backups/db/immich.sql.tmp

echo "[pre-backup] Dumping Immich postgres (dagda_immich_postgres)..."
docker exec \
  -e PGPASSWORD="${DB_PASSWORD}" \
  dagda_immich_postgres \
  pg_dump --clean --if-exists -U "${DB_USERNAME}" "${DB_DATABASE_NAME}" > "${DUMP_TMP}"

# Sanity check: dump must be at least 10KB
DUMP_BYTES=$(wc -c < "${DUMP_TMP}")
if [ "${DUMP_BYTES}" -lt 10240 ]; then
  echo "[pre-backup] ERROR: dump is suspiciously small (${DUMP_BYTES} bytes) — aborting"
  rm -f "${DUMP_TMP}"
  exit 1
fi

mv "${DUMP_TMP}" "${DUMP_FILE}"

DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)
echo "[pre-backup] pg_dump complete — ${DUMP_SIZE}"
