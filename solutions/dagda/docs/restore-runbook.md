# Dagda Restore Runbook

> Use this when things go wrong. The automated script handles most of it — read this first to understand what it does.

## Quick reference

| Scenario | Command |
|----------|---------|
| List snapshots | `docker exec dagda_restic restic snapshots` |
| Restore latest | `bash scripts/restore.sh` |
| Restore specific snapshot | `bash scripts/restore.sh abc12345` |
| Restore single file/dir | See "Partial restore" below |

## Scenario 1: Partial restore (specific photos or config)

Restore just what you need without touching the running system:

```bash
# Find the right snapshot
docker exec dagda_restic restic snapshots

# Restore a specific path from a snapshot to a temp dir
docker exec dagda_restic restic restore <snapshot-id> \
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
docker exec dagda_restic restic snapshots | wc -l
```

## Repository integrity check

Run occasionally to verify backup data isn't corrupted:
```bash
docker exec dagda_restic restic check
```

## Encryption

All snapshots are encrypted with the `RESTIC_PASSWORD` from `.env`.
If you lose this password, the backup is unrecoverable.
It is stored in your password manager under `Dagda — Hetzner backup S3 credentials`.

## Future: Immich moves to Hetzner VPS

When Immich migrates to a Hetzner VPS, the restic container moves with it.
The `dagda-backup` bucket and credentials stay the same.
Update this runbook to reflect the new machine's paths.
