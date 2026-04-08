# Hetzner Cloud Backup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automated nightly encrypted backups of Immich photos + service configs to Hetzner Object Storage, with a tested restore script.

**Architecture:** `mazzolino/restic` container in docker-compose runs nightly at 02:00, dumps Immich postgres via pre-backup hook, then pushes encrypted incremental snapshots to a dedicated `dagda-backup` Hetzner Object Storage bucket. 30-day retention enforced automatically. A `scripts/restore.sh` handles full disaster recovery.

**Tech Stack:** restic 0.17+, mazzolino/restic Docker image, Hetzner Object Storage (S3-compatible, `hel1`), bash, docker compose.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `docker/docker-compose.yml` | Modify | Add restic service + `restic-backups` named volume |
| `docker/.env.example` | Modify | Document restic env vars |
| `docker/.env` | Modify (manual) | Add actual restic secrets |
| `docker/hooks/pre-backup.sh` | Create | pg_dump Immich postgres before each backup |
| `scripts/restore.sh` | Create | Full disaster recovery: restore files + reimport postgres |
| `docs/restore-runbook.md` | Create | Human-readable restore guide |
| `docs/planning.md` | Modify | Add Hetzner VPS migration note |

---

## Task 1: Create Hetzner bucket and S3 credentials

**Files:** None (manual console steps)

- [ ] **Step 1: Create the bucket**

  In the [Hetzner Cloud Console](https://console.hetzner.cloud):
  - Navigate to **Object Storage** in the left sidebar
  - Click **Create Bucket**
  - Name: `dagda-backup`
  - Location: `Falkenstein (eu-central)` — same region as `homeclaw` bucket
  - Click **Create**

- [ ] **Step 2: Generate dedicated S3 credentials**

  Still in the Object Storage section:
  - Click **Access Keys** (top right of Object Storage section)
  - Click **Generate credentials**
  - Description: `dagda-backup`
  - **Copy both the Access Key ID and Secret Access Key immediately** — the secret is only shown once
  - Store in your password manager under `Dagda — Hetzner backup S3 credentials`

- [ ] **Step 3: Verify bucket is reachable**

  From your WSL2 terminal, substitute your real key values:
  ```bash
  docker run --rm \
    -e AWS_ACCESS_KEY_ID=<your-key-id> \
    -e AWS_SECRET_ACCESS_KEY=<your-secret> \
    amazon/aws-cli \
    --endpoint-url https://hel1.your-objectstorage.com \
    s3 ls
  ```
  Expected: `dagda-backup` appears in the bucket list.

---

## Task 2: Add restic env vars to .env files

**Files:**
- Modify: `docker/.env.example`
- Modify: `docker/.env`

- [ ] **Step 1: Add vars to .env.example**

  Append to `docker/.env.example`:
  ```bash
  # ── Restic backup ────────────────────────────────────────────────────────────
  # Hetzner Object Storage bucket for encrypted offsite backups
  RESTIC_REPOSITORY=s3:https://hel1.your-objectstorage.com/dagda-backup

  # Encryption passphrase — store in password manager. If lost, backup is unrecoverable.
  RESTIC_PASSWORD=changeme_strong_passphrase_here

  # Dedicated S3 credentials for dagda-backup bucket (separate from Terraform creds)
  RESTIC_S3_KEY=your_hetzner_s3_access_key_id
  RESTIC_S3_SECRET=your_hetzner_s3_secret_access_key
  ```

- [ ] **Step 2: Add actual values to .env**

  Edit `docker/.env` and append the same block with your real values filled in:
  ```bash
  # ── Restic backup ────────────────────────────────────────────────────────────
  RESTIC_REPOSITORY=s3:https://hel1.your-objectstorage.com/dagda-backup
  RESTIC_PASSWORD=<your-strong-passphrase>
  RESTIC_S3_KEY=<access-key-id-from-task-1>
  RESTIC_S3_SECRET=<secret-from-task-1>
  ```

- [ ] **Step 3: Verify .env is gitignored**

  ```bash
  cd /home/lowflying/homeclaw
  git check-ignore -v solutions/dagda/docker/.env
  ```
  Expected: a line confirming `.env` is ignored. If nothing is returned, add `docker/.env` to `.gitignore`.

---

## Task 3: Create pre-backup hook script

**Files:**
- Create: `docker/hooks/pre-backup.sh`

- [ ] **Step 1: Create hooks directory and script**

  ```bash
  mkdir -p /home/lowflying/homeclaw/solutions/dagda/docker/hooks
  ```

  Create `docker/hooks/pre-backup.sh`:
  ```bash
  #!/bin/sh
  # Pre-backup hook — runs inside restic container before each backup.
  # Dumps Immich postgres to /backups/db/immich.sql via docker exec (Docker socket required).
  set -e

  mkdir -p /backups/db

  echo "[pre-backup] Dumping Immich postgres (dagda_immich_postgres)..."
  docker exec \
    -e PGPASSWORD="${DB_PASSWORD}" \
    dagda_immich_postgres \
    pg_dump -U "${DB_USERNAME}" "${DB_DATABASE_NAME}" > /backups/db/immich.sql

  DUMP_SIZE=$(du -sh /backups/db/immich.sql | cut -f1)
  echo "[pre-backup] pg_dump complete — ${DUMP_SIZE}"
  ```

- [ ] **Step 2: Make executable**

  ```bash
  chmod +x /home/lowflying/homeclaw/solutions/dagda/docker/hooks/pre-backup.sh
  ```

- [ ] **Step 3: Verify script is syntactically valid**

  ```bash
  sh -n /home/lowflying/homeclaw/solutions/dagda/docker/hooks/pre-backup.sh
  ```
  Expected: no output (no syntax errors).

- [ ] **Step 4: Commit**

  ```bash
  cd /home/lowflying/homeclaw
  git add solutions/dagda/docker/hooks/pre-backup.sh solutions/dagda/docker/.env.example
  git commit -m "feat(backup): add restic pre-backup pg_dump hook and env vars"
  ```

---

## Task 4: Add restic service to docker-compose

**Files:**
- Modify: `docker/docker-compose.yml`

- [ ] **Step 1: Add restic-backups named volume**

  In `docker/docker-compose.yml`, find the `volumes:` block near the bottom (currently has `immich-model-cache:`). Add `restic-backups:`:
  ```yaml
  volumes:
    immich-model-cache:
    restic-backups:
  ```

- [ ] **Step 2: Add restic service**

  In `docker/docker-compose.yml`, add the following service block in the `# ─── PHOTOS ───` section, after the `immich-postgres` service:
  ```yaml
    # ─── BACKUP ────────────────────────────────────────────────────────────────
    # Restic: encrypted nightly backup to Hetzner Object Storage.
    # Backs up: Immich library + postgres dump + service configs.
    # Schedule: 02:00 daily. Retention: 30 days.
    # Repo: s3:https://hel1.your-objectstorage.com/dagda-backup
    restic:
      image: mazzolino/restic:latest
      container_name: dagda-restic
      hostname: dagda
      restart: unless-stopped
      env_file: .env
      environment:
        RESTIC_REPOSITORY: ${RESTIC_REPOSITORY}
        RESTIC_PASSWORD: ${RESTIC_PASSWORD}
        AWS_ACCESS_KEY_ID: ${RESTIC_S3_KEY}
        AWS_SECRET_ACCESS_KEY: ${RESTIC_S3_SECRET}
        BACKUP_CRON: "0 2 * * *"
        RESTIC_BACKUP_SOURCES: /data/immich-library /data/service-configs /backups/db
        RESTIC_BACKUP_ARGS: "--verbose"
        RESTIC_FORGET_ARGS: "--keep-daily 30 --prune"
        RUN_BEFORE_BACKUP: /hooks/pre-backup.sh
      volumes:
        - ${IMMICH_UPLOAD_LOCATION}:/data/immich-library:ro
        - ${CONFIG_ROOT}:/data/service-configs:ro
        - ./hooks:/hooks:ro
        - restic-backups:/backups
        - /var/run/docker.sock:/var/run/docker.sock
      depends_on:
        - immich-postgres
      networks:
        - dagda
  ```

- [ ] **Step 3: Validate docker-compose syntax**

  ```bash
  cd /home/lowflying/homeclaw/solutions/dagda/docker
  docker compose config --quiet
  ```
  Expected: no errors, exits 0.

- [ ] **Step 4: Commit**

  ```bash
  cd /home/lowflying/homeclaw
  git add solutions/dagda/docker/docker-compose.yml
  git commit -m "feat(backup): add mazzolino/restic service to docker-compose"
  ```

---

## Task 5: Initialise restic repository

**Files:** None (one-time runtime step)

- [ ] **Step 1: Initialise the repository**

  Run from `docker/` directory:
  ```bash
  cd /home/lowflying/homeclaw/solutions/dagda/docker
  docker compose run --rm restic restic init
  ```
  Expected output:
  ```
  created restic repository xxxxxxxx at s3:https://hel1.your-objectstorage.com/dagda-backup
  Please note that knowledge of your password is required to access the repository.
  Losing your password means that your data is irrecoverably lost.
  ```

- [ ] **Step 2: Verify repository is accessible**

  ```bash
  docker compose run --rm restic restic snapshots
  ```
  Expected: `no matching snapshots` (empty repo, no error).

---

## Task 6: Trigger a manual backup and verify

**Files:** None (runtime verification)

- [ ] **Step 1: Start the restic container**

  ```bash
  cd /home/lowflying/homeclaw/solutions/dagda/docker
  docker compose up -d restic
  docker compose ps restic
  ```
  Expected: `dagda-restic` is `running`.

- [ ] **Step 2: Trigger a manual backup now (don't wait for 02:00)**

  ```bash
  docker exec dagda-restic /bin/backup
  ```
  Expected: output includes lines like:
  ```
  [pre-backup] Dumping Immich postgres (dagda_immich_postgres)...
  [pre-backup] pg_dump complete — 2.5M
  Files:         1234 new, 0 changed, 0 unmodified
  snapshot abcd1234 saved
  ```

- [ ] **Step 3: Verify snapshot exists in repository**

  ```bash
  docker exec dagda-restic restic snapshots
  ```
  Expected: one snapshot listed with today's date and hostname `dagda`.

- [ ] **Step 4: Spot-check backup contents**

  ```bash
  docker exec dagda-restic restic ls latest --long | head -30
  ```
  Expected: file listing showing `/data/immich-library/`, `/data/service-configs/`, and `/backups/db/immich.sql`.

---

## Task 7: Create restore script

**Files:**
- Create: `scripts/restore.sh`

- [ ] **Step 1: Write the restore script**

  Create `scripts/restore.sh`:
  ```bash
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
  ```

- [ ] **Step 2: Make executable**

  ```bash
  chmod +x /home/lowflying/homeclaw/solutions/dagda/scripts/restore.sh
  ```

- [ ] **Step 3: Validate syntax**

  ```bash
  bash -n /home/lowflying/homeclaw/solutions/dagda/scripts/restore.sh
  ```
  Expected: no output (no syntax errors).

- [ ] **Step 4: Commit**

  ```bash
  cd /home/lowflying/homeclaw
  git add solutions/dagda/scripts/restore.sh
  git commit -m "feat(backup): add disaster recovery restore script"
  ```

---

## Task 8: Test restore to temp directory

**Files:** None (runtime verification)

- [ ] **Step 1: Run restore script against latest snapshot**

  ```bash
  cd /home/lowflying/homeclaw/solutions/dagda
  bash scripts/restore.sh latest
  ```
  Expected:
  - Download completes without error
  - "Postgres reimport complete" line appears
  - Asset count matches what Immich shows in its UI
  - Photo file count is non-zero
  - Manual steps printed at end

- [ ] **Step 2: Spot-check restored files**

  ```bash
  RESTORE_DIR=$(ls -td /tmp/dagda-restore-* | head -1)
  ls "$RESTORE_DIR/data/immich-library/" | head -10
  ls "$RESTORE_DIR/data/service-configs/" | head -10
  ls -lh "$RESTORE_DIR/backups/db/immich.sql"
  ```
  Expected: photo directories visible, config subdirs visible, dump file has non-zero size.

- [ ] **Step 3: Clean up temp dir**

  ```bash
  RESTORE_DIR=$(ls -td /tmp/dagda-restore-* | head -1)
  rm -rf "$RESTORE_DIR"
  ```

---

## Task 9: Write restore runbook

**Files:**
- Create: `docs/restore-runbook.md`

- [ ] **Step 1: Write the runbook**

  Create `docs/restore-runbook.md`:
  ```markdown
  # Dagda Restore Runbook

  > Use this when things go wrong. The automated script handles most of it — read this first to understand what it does.

  ## Quick reference

  | Scenario | Command |
  |----------|---------|
  | List snapshots | `docker exec dagda-restic restic snapshots` |
  | Restore latest | `bash scripts/restore.sh` |
  | Restore specific snapshot | `bash scripts/restore.sh abc12345` |
  | Restore single file/dir | See "Partial restore" below |

  ## Scenario 1: Partial restore (specific photos or config)

  Restore just what you need without touching the running system:
  ```bash
  # Find the right snapshot
  docker exec dagda-restic restic snapshots

  # Restore a specific path from a snapshot to a temp dir
  docker exec dagda-restic restic restore <snapshot-id> \
    --target /tmp/restore \
    --include /data/immich-library/2025
  ```
  Then manually copy the files you need from `/tmp/restore/` into place.

  ## Scenario 2: Full disaster recovery (machine replaced or data wiped)

  1. **Get Dagda running again first:**
     ```bash
     cd homeclaw/solutions/dagda/docker
     cp .env.example .env   # fill in all values including RESTIC_* vars
     bash ../scripts/setup.sh
     docker compose up -d
     ```

  2. **Run the restore script:**
     ```bash
     cd homeclaw/solutions/dagda
     bash scripts/restore.sh
     ```
     This will:
     - Pull the latest snapshot from Hetzner
     - Reimport the Immich postgres database
     - Print rsync commands to copy photos and configs back

  3. **Run the printed rsync commands** to move photos and configs into place.

  4. **Restart services:**
     ```bash
     docker compose -f docker/docker-compose.yml restart
     ```

  5. **Verify in Immich:** Open `http://localhost:2283` — your photos should be visible.

  ## Snapshot retention

  30 daily snapshots are kept. To check how many you have:
  ```bash
  docker exec dagda-restic restic snapshots | wc -l
  ```

  ## Encryption

  All snapshots are encrypted with the `RESTIC_PASSWORD` from `.env`.
  If you lose this password, the backup is unrecoverable.
  It is stored in your password manager under `Dagda — Hetzner backup S3 credentials`.

  ## Future: Immich moves to Hetzner VPS

  When Immich migrates to a Hetzner VPS, the restic container moves with it.
  The `dagda-backup` bucket and credentials stay the same.
  Update this runbook to reflect the new machine's paths.
  ```

- [ ] **Step 2: Commit**

  ```bash
  cd /home/lowflying/homeclaw
  git add solutions/dagda/docs/restore-runbook.md
  git commit -m "docs(backup): add restore runbook"
  ```

---

## Task 10: Update planning.md with migration note

**Files:**
- Modify: `docs/planning.md`

- [ ] **Step 1: Add Hetzner VPS migration note to Phase 2b section**

  In `docs/planning.md`, find the `### Phase 2b` section and add after the last bullet:
  ```markdown
  - **Backup (Hetzner Object Storage):** Restic container backs up Immich library + postgres dump + arr configs nightly to `dagda-backup` bucket. When Immich migrates to a Hetzner VPS, restic moves with it — same bucket, no credential changes needed.
  ```

- [ ] **Step 2: Commit**

  ```bash
  cd /home/lowflying/homeclaw
  git add solutions/dagda/docs/planning.md
  git commit -m "docs: note Hetzner backup in Phase 2b, flag VPS migration path"
  ```

---

## Self-Review Checklist

After completing all tasks, verify:

- [ ] `docker exec dagda-restic restic snapshots` shows at least one snapshot
- [ ] `docker exec dagda-restic restic check` passes (repository integrity OK)
- [ ] `bash scripts/restore.sh latest` completes without errors
- [ ] `.env` is confirmed gitignored (`git check-ignore -v docker/.env`)
- [ ] RESTIC_PASSWORD is saved in password manager
