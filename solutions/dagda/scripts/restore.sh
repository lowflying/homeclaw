#!/usr/bin/env bash
# Dagda disaster recovery restore script.
# Usage: bash scripts/restore.sh [snapshot-id]
# Default: restores from 'latest' snapshot.
# Run from: homeclaw/solutions/dagda/
set -euo pipefail

SNAPSHOT="${1:-latest}"
RESTORE_DIR="/tmp/dagda-restore-$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/../docker"

# Load env vars (RESTIC_*, DB_*)
set -a
# shellcheck disable=SC1091
source "$DOCKER_DIR/.env"
set +a

echo "==> Restoring snapshot: $SNAPSHOT"
echo "==> Restore target:     $RESTORE_DIR"
mkdir -p "$RESTORE_DIR"

# ── Step 1: Pull snapshot from Hetzner ───────────────────────────────────────
echo "==> Pulling snapshot from Hetzner Object Storage..."
docker run --rm \
  -e RESTIC_REPOSITORY="$RESTIC_REPOSITORY" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  -e AWS_ACCESS_KEY_ID="$RESTIC_S3_KEY" \
  -e AWS_SECRET_ACCESS_KEY="$RESTIC_S3_SECRET" \
  -v "$RESTORE_DIR:/restore" \
  restic/restic restore "$SNAPSHOT" --target /restore
echo "==> Download complete."

# ── Step 2: Reimport Immich postgres ─────────────────────────────────────────
DUMP_FILE="$RESTORE_DIR/backups/db/immich.sql"
if [[ -f "$DUMP_FILE" ]]; then
  echo "==> Reimporting Immich postgres database..."
  # Terminate active connections then drop+recreate DB
  docker exec \
    -e PGPASSWORD="$DB_PASSWORD" \
    dagda_immich_postgres \
    psql -U "$DB_USERNAME" -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_DATABASE_NAME' AND pid <> pg_backend_pid();" \
    -c "DROP DATABASE IF EXISTS $DB_DATABASE_NAME;" \
    -c "CREATE DATABASE $DB_DATABASE_NAME;"
  # Import dump
  docker exec -i \
    -e PGPASSWORD="$DB_PASSWORD" \
    dagda_immich_postgres \
    psql -U "$DB_USERNAME" "$DB_DATABASE_NAME" < "$DUMP_FILE"
  echo "==> Postgres reimport complete."
else
  echo "==> WARNING: No postgres dump found at $DUMP_FILE — skipping DB restore."
fi

# ── Step 3: Validate ─────────────────────────────────────────────────────────
echo "==> Validating..."
ASSET_COUNT=$(docker exec \
  -e PGPASSWORD="$DB_PASSWORD" \
  dagda_immich_postgres \
  psql -U "$DB_USERNAME" "$DB_DATABASE_NAME" \
  --tuples-only --no-align \
  -c "SELECT COUNT(*) FROM assets;" 2>/dev/null || echo "FAILED")
echo "==> Immich asset count in DB: $ASSET_COUNT"

PHOTO_COUNT=$(find "$RESTORE_DIR/data/immich-library" -type f 2>/dev/null | wc -l)
echo "==> Photo files in snapshot:  $PHOTO_COUNT"

CONFIG_COUNT=$(find "$RESTORE_DIR/data/service-configs" -type f 2>/dev/null | wc -l)
echo "==> Config files in snapshot: $CONFIG_COUNT"

# ── Step 4: Next steps ───────────────────────────────────────────────────────
echo ""
echo "==> MANUAL STEPS REMAINING:"
echo "   # Copy photos back (adjust if restoring to a fresh machine):"
echo "   rsync -av $RESTORE_DIR/data/immich-library/ ${IMMICH_UPLOAD_LOCATION}/"
echo ""
echo "   # Copy service configs back:"
echo "   rsync -av $RESTORE_DIR/data/service-configs/ $DOCKER_DIR/data/"
echo ""
echo "   # Restart all services:"
echo "   docker compose -f $DOCKER_DIR/docker-compose.yml up -d"
echo ""
echo "==> Restore complete. Review output above before running manual steps."
