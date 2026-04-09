# Dagda — Planning Document

> **Status:** Phase 1 complete. Stack running, fully wired, end-to-end tested.
> **Last updated:** 2026-04-05
> **Next action:** Phase 2 — Home Assistant + cameras.

---

## What Dagda Is

Dagda is a self-hosted home media and automation platform running on the user's primary Windows machine (WSL2/Docker), replacing the fragmented experience of commercial streaming platforms. Named after the Irish god of abundance — a cauldron that never empties.

**I (Claude Code, this session) am Dagda** — I manage the platform, plan enhancements, and execute changes via the existing Telegram/Discord → homelabber → Claude Code pipeline.

---

## Hardware Context

- **Machine:** Dell laptop/desktop, ~2018 vintage
- **OS:** Windows 11, WSL2 (Ubuntu 24.04)
- **RAM:** 16GB total, ~12GB used by Windows. WSL2 allocated 7.7GB.
- **GPU:** NVIDIA GeForce GTX 1060 Max-Q, 6GB VRAM — CUDA capable, WSL2 supported. Sufficient for Frigate AI detection.
- **Storage:**
  - C:\ — 220GB, 89% full (26GB free) — OS drive, keep clear
  - D:\ — 932GB, 70% used (283GB free)
  - E:\ — 932GB, 100% full — external, not for services
  - F:\ — 1.9TB, 12% used (1.7TB free) — **primary media storage**
- **Docker:** Already running in WSL2 (containerd + dockerd confirmed)
- **Tailscale:** Already installed and running (both Windows + WSL)

### Hardware Realism

This machine works for Phase 1. It will get tight. Within ~6 months, plan for a dedicated mini PC (used Dell OptiPlex or Beelink N100, ~£100-150) to offload the media stack. Flag this at Phase 2 planning.

---

## Services — Planned Stack

| Service | Purpose | Weight | Notes |
|---------|---------|--------|-------|
| **Sonarr** | TV show automation | Light | Already installed on Windows — migrate to Docker |
| **Radarr** | Movie automation | Light | Not yet installed |
| **Prowlarr** | Indexer management (feeds Sonarr+Radarr) | Light | Not yet installed |
| **Overseerr** | Request UI ("download Dune") | Light | Web UI + mobile app |
| **Deluge** | Torrent client | Light | Already installed on Windows — migrate to Docker |
| **Audiobookshelf** | Audiobook hosting + streaming | Light-medium | Handles .aax, .mp3, .m4b etc. Family sharing built in |
| **Immich** | Photo/video hosting | Medium | Already partially set up in talon/homelabber/immich |
| **Home Assistant** | Smart home hub | Light-medium | Central control for all smart devices |
| **Frigate** | NVR + AI camera detection | **Heavy** | Needs GPU (NVIDIA via CUDA in WSL2) |
| **Nginx Proxy Manager** | Reverse proxy + SSL | Light | GUI-based |
| **Authelia** | SSO / auth layer | Light | In front of all services |

### Download Bot Flow (no LLM needed)
Telegram/Discord message "download Dune" → parse intent → call Radarr API directly → Radarr queues in Deluge → on completion, moves to Plex library. Fast, cheap, no Claude invocation needed for this path.

---

## Integrations — Existing Patterns to Reuse

The homelabber Telegram/Discord bot stack at `talon/homelabber/` is mature and battle-tested:

- **Engine:** `talon/homelabber/bot/` — executor, router, context, security, reflect
- **Telegram bot:** `talon/telegram-bot/` — running as systemd service
- **Discord bot:** `talon/discord-bot/` — same engine, discord.py adapter
- **Routing:** Add `dagda` → `/home/lowflying/homeclaw/solutions/dagda` to `bot/router.py`

Dagda tasks (e.g. "download X", "show camera feeds", "turn off living room lights") will route through this same pipeline.

**Possible restructure:** User considering moving Dagda under `lowflying/homelabber` directory to co-locate with bot patterns. Decision pending.

---

## Devices

### Cameras

| Camera | Model | RTSP? | Notes |
|--------|-------|-------|-------|
| Eufy Doorbell | T8210 | Possible — enable in app under "Local Share" | Uses Homebase 1 |
| Eufy Indoor Pan&Tilt | (model TBD) | Likely yes | May work without Homebase |
| Eufy Solo Cam S40 | S40 | Possible — enable in app | Solar, uses Homebase 1 |
| Tapo cameras | (models TBD) | **Yes, natively** | Full Frigate compatible |
| VTech baby monitors | (models TBD) | **No** — proprietary | Likely not integrable without capture card |

**Action required:** Check Eufy app → each camera → "Local Share" to enable RTSP. Test stream URL format: `rtsp://<homebase-ip>/<camera-id>`.

### Smart Home

| Device | Protocol | Home Assistant support |
|--------|----------|----------------------|
| TCP Smart plugs | Tuya-based (local or cloud) | Yes — via Local Tuya integration |
| Philips Hue | Zigbee / Hue Bridge | Excellent — native HA integration |
| Future TRVs | TBD — recommend Zigbee-based (e.g. SONOFF, Tuya) | Best to buy Zigbee-compatible |
| Future thermostat | TBD — recommend Hive, Tado, or Zigbee | All have HA integrations |

**Recommendation for future purchases:** Buy Zigbee-based TRVs/thermostat. Add a Zigbee USB stick (ConBee II or SONOFF Zigbee 3.0) to the machine — Home Assistant's Zigbee2MQTT integration handles everything locally with no cloud dependency.

### Audio Books

Formats in use: .aax (Audible DRM), ripped CDs (.mp3/.flac), downloaded files.
Audiobookshelf handles all of these. For .aax: one-time extraction of Audible activation bytes → ABS converts locally.

---

## Users & Access

| User | Access level | Notes |
|------|-------------|-------|
| Primary (you) | Full admin | Telegram/Discord bot control |
| Partner | Media + smart home | Overseerr, Immich, ABS, Home Assistant |
| Kids (future) | Restricted | Parental control layer via Home Assistant + network filtering |

**Parental controls:** Home Assistant can enforce device schedules (e.g. cut WiFi to kids' devices at bedtime via router integration). Phase 2+ for mobile/remote access via Tailscale.

---

## Open Questions

- [ ] Which specific Eufy Indoor Pan&Tilt model?
- [ ] Tapo camera models?
- [ ] Smart home: any existing Zigbee hub/stick, or all cloud-based currently?
- [x] NVIDIA GPU model — GTX 1060 Max-Q, 6GB VRAM, CUDA capable in WSL2
- [x] Audiobook UX — phone app (Audiobookshelf mobile)
- [x] Plex kept alongside new stack — stays on Windows, not Dockerised

---

## Phased Roadmap

### Phase 1 — Core media stack ✅ COMPLETE (2026-04-05)

**Running at `docker/docker-compose.yml`:**

| Service | Port | Status |
|---------|------|--------|
| Prowlarr | 9696 | Running — 4 public indexers (YTS, TPB, LimeTorrents, Torrent Downloads) |
| Deluge | 8112 | Running — downloads to `/mnt/d/Media/Downloads/complete` |
| Sonarr | 8989 | Running — root `/media/TV Shows`, wired to Deluge + Prowlarr |
| Radarr | 7878 | Running — root `/media/Movie`, wired to Deluge + Prowlarr |
| Overseerr | 5055 | Running — connected to Plex + Sonarr + Radarr, HD-1080p default |
| Audiobookshelf | 13378 | Running — `/media/Audiobooks` library configured |
| Nginx Proxy Manager | 81 | Running — proxy hosts for all services on `*.dagda.local` |

**Decisions made:**
- Plex stays on Windows (not Dockerised) — library at `D:\Media`, 60s auto-scan enabled
- Fresh Sonarr/Radarr install (old Windows installs abandoned)
- Stremio + Torrentio recommended for "watch now" use case (separate app, no Docker needed)
- Overseerr accessed via `http://192.168.1.37:5055` on LAN — wife adds to phone home screen
- TV indexers limited — EZTV geo-blocked in Ireland, 1337x behind Cloudflare. TPB/LimeTorrents cover TV but less reliably. Consider BTN (private) for Phase 2+.
- Media staying on `D:\Media` (D:\ has 283GB free) — migrate to `F:\Media` when needed

**Known gaps / future cleanup:**
- Homelabber bot integration not yet done (wire `dagda` route into `talon/homelabber/bot/router.py`) — **bot torrent status command would be useful here**
- No auth on arr services (LAN-only, acceptable for Phase 1)
- `*.dagda.local` DNS not configured on router (use IP:port for now)
- Port forwarding on Windows 10 requires `C:\Users\Chris\dagda-ports.ps1` run as admin (Task Scheduler entry created for startup). WSL2 mirrored networking not available on Windows 10.

---

### Phase 2 — Smart home + cameras
- Home Assistant
- Frigate (Tapo cameras first, then Eufy if RTSP works via "Local Share" in app)
- TCP Smart plugs (Local Tuya) + Philips Hue integration
- Parental control groundwork
- Flag dedicated hardware if RAM getting tight

### Phase 2b — Immich + Google Photos migration ⚡ IN PROGRESS (2026-04-07)
- Immich added to `docker/docker-compose.yml` (server, ML, redis, postgres)
- Upload library: `/mnt/f/Immich/library`
- External library (read-only): `/mnt/f/GooglePhotosRefugees` → mounted as `/mnt/media/google`
- Google Takeout export requested 2026-04-07 — extract ZIPs to `F:\GooglePhotosRefugees` when ready
- After Takeout import + verify: trash Google Photos to free account space (re-enable email)
- Family photo sharing (partner access via Immich web/mobile)
- Old homelabber rclone pipeline at `talon/homelabber/immich/` can supplement Takeout if needed
- **Backup (Hetzner Object Storage):** Restic container (`dagda_restic`) backs up Immich library + postgres dump + arr configs nightly to `dagda-backup` bucket (`hel1`). 30-day retention. See `docs/restore-runbook.md`. When Immich migrates to a Hetzner VPS, restic moves with it — same bucket, no credential changes needed.

### Phase 4 — Remote access + hardening
- Tailscale subnet router for mobile access (IP already: 100.106.72.41)
- Authelia SSO layer in front of all services
- `*.dagda.local` proper DNS via router
- Move heavy services to dedicated hardware if needed (budget ~£100-150 mini PC)

---

## Directory Structure (planned)

```
homeclaw/solutions/dagda/
├── AGENT.md                  # Read on every invocation
├── docs/
│   ├── planning.md           # This file
│   ├── architecture.md       # ADRs + final decisions (TBD)
│   └── research/             # Per-topic research notes
├── docker/
│   ├── docker-compose.yml    # Full stack
│   └── .env.example          # Required env vars
└── scripts/                  # Maintenance/migration scripts
```
