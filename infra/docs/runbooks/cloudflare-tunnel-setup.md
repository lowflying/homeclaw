# Runbook: Cloudflare Tunnel Setup (one-time, post-VPS-provision)

This is a manual step done once after `terraform apply`. It cannot be automated via Terraform because Cloudflare Tunnel credentials are generated interactively and must be stored on the VPS at a known path before cloudflared will route traffic.

---

## Prerequisites

- VPS provisioned and running (`terraform apply` complete)
- `deploy-infra` workflow run — cloudflared container is up (may be erroring, that's fine)
- `cloudflared` CLI installed locally (or use the VPS — cloudflared is installed by cloud-init)
- You are logged in to the Cloudflare account that owns `obfuscatedbadger.lol`

---

## Step 1 — Authenticate cloudflared

On your local machine (or SSH into the VPS):

```bash
cloudflared tunnel login
```

This opens a browser, asks you to select your zone (`obfuscatedbadger.lol`), and writes `~/.cloudflared/cert.pem`.

---

## Step 2 — Create the tunnel

```bash
cloudflared tunnel create homeclaw
```

This outputs:
```
Created tunnel homeclaw with id <TUNNEL_ID>
```

It also writes a credentials file to `~/.cloudflared/<TUNNEL_ID>.json`. **This file is a secret — do not commit it.**

Note the `<TUNNEL_ID>` — you'll need it in Step 4.

---

## Step 3 — Create DNS CNAME records

For each hostname routed through the tunnel, create a CNAME record pointing to `<TUNNEL_ID>.cfargotunnel.com`:

```bash
cloudflared tunnel route dns homeclaw bot.obfuscatedbadger.lol
cloudflared tunnel route dns homeclaw assistant.obfuscatedbadger.lol
cloudflared tunnel route dns homeclaw procurement.obfuscatedbadger.lol
```

These create `CNAME` records in Cloudflare DNS automatically (proxied, orange-clouded).

---

## Step 4 — Write config and credentials to VPS

SSH into the VPS:

```bash
ssh -i infra/keys/hetzner_deploy -p 2222 deploy@<VPS_IP>
```

Create the cloudflared config directory and write the config:

```bash
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: <TUNNEL_ID>
credentials-file: /etc/cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: bot.obfuscatedbadger.lol
    service: http://clarvis-ai:8001
  - hostname: assistant.obfuscatedbadger.lol
    service: http://personal-assistant:8002
  - hostname: procurement.obfuscatedbadger.lol
    service: http://home-procurement:8003
  - service: http_status:404
EOF
sudo chmod 640 /etc/cloudflared/config.yml
```

Copy the credentials file from your local machine to the VPS (run this locally):

```bash
scp -i infra/keys/hetzner_deploy -P 2222 \
  ~/.cloudflared/<TUNNEL_ID>.json \
  deploy@<VPS_IP>:/tmp/tunnel-creds.json

# Then on VPS:
sudo mv /tmp/tunnel-creds.json /etc/cloudflared/<TUNNEL_ID>.json
sudo chmod 600 /etc/cloudflared/<TUNNEL_ID>.json
```

---

## Step 5 — Restart cloudflared

```bash
cd /opt/homeclaw/shared
docker compose restart cloudflared
docker compose logs cloudflared --tail=20
```

You should see:
```
Registered tunnel connection connIndex=0 ...
```

---

## Step 6 — Add CLOUDFLARE_TUNNEL_TOKEN to GitHub Actions secrets

The tunnel token (alternative to credentials file, usable in the `--token` run mode) can be retrieved with:

```bash
cloudflared tunnel token homeclaw
```

Add this as `CLOUDFLARE_TUNNEL_TOKEN` in GitHub Actions secrets — this allows future automated deploys to reconfigure cloudflared without needing the credentials file on disk.

---

## Verify

```bash
curl -s https://bot.obfuscatedbadger.lol/health
# Should return 502 (no clarvis-ai container yet) — not a connection error
```

A 502 confirms the tunnel is routing. A connection error means the tunnel is not yet working.
