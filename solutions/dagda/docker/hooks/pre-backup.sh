#!/bin/sh
# Pre-backup hook — runs inside restic container before each backup.
# Dumps Immich postgres to /backups/db/immich.sql via docker exec (Docker socket required).
set -e

mkdir -p /backups/db

echo "[pre-backup] Dumping Immich postgres (dagda_immich_postgres)..."
docker exec \
  -e PGPASSWORD="${DB_PASSWORD}" \
  dagda_immich_postgres \
  pg_dump --clean --if-exists -U "${DB_USERNAME}" "${DB_DATABASE_NAME}" > /backups/db/immich.sql

DUMP_SIZE=$(du -sh /backups/db/immich.sql | cut -f1)
echo "[pre-backup] pg_dump complete — ${DUMP_SIZE}"
