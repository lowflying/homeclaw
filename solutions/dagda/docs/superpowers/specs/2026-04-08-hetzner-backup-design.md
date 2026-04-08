# Hetzner Cloud Backup — Design Spec

**Date:** 2026-04-08
**Phase:** 2b (alongside Immich + Google Photos migration)
**Status:** Approved, pending implementation

---

## Goal

Encrypted, automated offsite backup of Dagda's irreplaceable data to Hetzner Object Storage — daily snapshots, 30-day retention, with a tested restore path.

---

## What Gets Backed Up

| Data | Source Path | Notes |
|------|------------|-------|
| Immich photo/video library | `/mnt/f/Immich/library` | Raw files, backed up directly |
| Immich postgres database | `/backups/db/immich.sql` | pg_dump run as pre-backup hook |
| Arr service configs | `dagda/docker/data/` | Sonarr, Radarr, Prowlarr, Deluge, Overseerr, ABS configs. SQLite DBs safe to backup live (WAL mode). |

**Not included:** Media files (movies, TV, audiobooks). These are re-downloadable; offsite backup of hundreds of GB is not cost-justified.

---

## Architecture

```
[restic container]
  ├── pre-hook: pg_dump → /backups/db/immich.sql
  ├── reads: /mnt/f/Immich/library       (photos)
  ├── reads: /backups/db/immich.sql      (postgres dump)
  └── reads: dagda/docker/data/          (service configs)
        │
        ▼  AES-256 encrypted, deduplicated
[Hetzner Object Storage — bucket: dagda-backup, region: hel1]
```

**Image:** `mazzolino/restic` — wraps restic with cron scheduling, pre/post hooks, and retention via env vars. No separate cron container needed.

**Schedule:** Nightly at 02:00 (low-traffic window).

**Retention:** `--keep-daily 30` — 30 daily snapshots, older ones pruned automatically.

---

## Hetzner Resources

- **Bucket:** `dagda-backup` (new, separate from `homeclaw` Terraform state bucket)
- **Region:** `hel1` (same as existing Object Storage)
- **Credentials:** Dedicated S3 access key scoped to `dagda-backup` only — not shared with Terraform credentials
- **Endpoint:** `https://hel1.your-objectstorage.com`

---

## Credentials & Secrets

All stored in `dagda/docker/.env` (already gitignored):

```
RESTIC_REPOSITORY=s3:https://hel1.your-objectstorage.com/dagda-backup
RESTIC_PASSWORD=<strong-passphrase — store in password manager>
AWS_ACCESS_KEY_ID=<dagda-backup bucket key>
AWS_SECRET_ACCESS_KEY=<dagda-backup bucket secret>
```

**Critical:** The `RESTIC_PASSWORD` is the encryption key. If lost, the backup is unrecoverable. Store in password manager alongside other Dagda secrets.

---

## docker-compose Addition

New service added to `dagda/docker/docker-compose.yml`:

```yaml
restic:
  image: mazzolino/restic:latest
  container_name: dagda-restic
  hostname: dagda
  restart: unless-stopped
  environment:
    RESTIC_REPOSITORY: ${RESTIC_REPOSITORY}
    RESTIC_PASSWORD: ${RESTIC_PASSWORD}
    AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
    AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
    BACKUP_CRON: "0 2 * * *"
    RESTIC_BACKUP_ARGS: "--verbose"
    RESTIC_FORGET_ARGS: "--keep-daily 30 --prune"
    RUN_BEFORE_BACKUP: /hooks/pre-backup.sh
  volumes:
    - /mnt/f/Immich/library:/data/immich-library:ro
    - ./data:/data/service-configs:ro
    - ./hooks:/hooks:ro
    - backups:/backups
    - /var/run/docker.sock:/var/run/docker.sock
  depends_on:
    - immich-postgres
```

---

## Pre-backup Hook

`dagda/docker/hooks/pre-backup.sh` — runs inside the restic container before each backup:

```bash
#!/bin/sh
set -e
echo "[backup] Dumping Immich postgres..."
docker exec dagda_immich_postgres pg_dump -U postgres immich > /backups/db/immich.sql
echo "[backup] pg_dump complete."
```

The restic container needs Docker socket access (or network access to postgres) to run this. Implementation will use `docker exec` via the mounted Docker socket.

---

## Restore Script

`dagda/scripts/restore.sh` — covers the full disaster recovery path:

1. Pull specified snapshot from Hetzner to local restore dir
2. Restore Immich library files to `/mnt/f/Immich/library`
3. Restore service configs to `dagda/docker/data/`
4. Reimport Immich postgres from dump:
   ```bash
   docker exec -i immich-postgres psql -U postgres immich < /restore/db/immich.sql
   ```
5. Validate: check Immich postgres responds, check file counts match snapshot

Script accepts optional `--snapshot <id>` flag; defaults to `latest`.

---

## Restore Runbook

Documented at `dagda/docs/restore-runbook.md`. Covers:
- Listing snapshots: `restic snapshots`
- Partial restore (single file or directory): `restic restore <id> --target /tmp/restore --include /path`
- Full disaster recovery: run `scripts/restore.sh`
- Immich postgres reimport steps
- Expected recovery time: ~15 minutes for configs, plus photo transfer time depending on library size

---

## Monitoring & Alerting

Deferred. To be added when the dagda→homelabber bot integration is wired (`talon/homelabber/bot/router.py`). At that point: Telegram alert on backup success/failure via the existing bot pipeline.

---

## Future: Immich → Hetzner VPS Migration

When Immich moves to a dedicated Hetzner VPS (planned, within a few weeks), the restic container moves there too. The `dagda-backup` bucket, credentials, and retention policy are unchanged — only the runner location changes. No backup gaps during migration as long as restic is initialised on the VPS before the local container is stopped.

---

## Out of Scope

- Media files (movies, TV, audiobooks) — re-downloadable
- Monitoring/alerting — deferred to bot integration phase
- Immich → Hetzner VPS migration — separate phase
