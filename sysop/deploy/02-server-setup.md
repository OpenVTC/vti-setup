# Deploy 02: Server Setup

Configure DNS, install the runtime dependencies, create per-service users and their data directories, install systemd unit files, set up nginx + certbot, and obtain TLS certificates. Run this once, as `vti`, after [01 — Server bootstrap](01-server-bootstrap.md).

## Service configuration

Two DID Hosting modes are available — pick one before you begin. See [04 — DID Hosting topology](04-did-hosting-topology.md) for the decision criteria.

### Standard (recommended — single integrated DID Hosting daemon)

| Service | Default Port | DNS Record | DID Hosting Path |
| --- | --- | --- | --- |
| Mediator | 7037 | `mediator.yourdomain.com` | `https://dids.yourdomain.com/mediator` |
| Verifiable Trust Agent | 8100 | `vta.yourdomain.com` | `https://dids.yourdomain.com/vta` |
| Verifiable Trust Community | 8200 | `vtc.yourdomain.com` | `https://dids.yourdomain.com/vtc` |
| DID Hosting Service | 8534 | `dids.yourdomain.com` | `https://dids.yourdomain.com` |

### Standalone (control + server + witness + watcher split)

| Service | Default Port | DNS Record | DID Hosting Path |
| --- | --- | --- | --- |
| Mediator | 7037 | `mediator.yourdomain.com` | `https://dids.yourdomain.com/mediator` |
| Verifiable Trust Agent | 8100 | `vta.yourdomain.com` | `https://dids.yourdomain.com/vta` |
| Verifiable Trust Community | 8200 | `vtc.yourdomain.com` | `https://dids.yourdomain.com/vtc` |
| DID Hosting Server | 8530 | `dids.yourdomain.com` | `https://dids.yourdomain.com` |
| WebVH Witness | 8531 | `witness.yourdomain.com` | `https://dids.yourdomain.com/services/witness` |
| WebVH Control | 8532 | `control.yourdomain.com` | `https://dids.yourdomain.com/services/control` |
| WebVH Watcher | 8533 | `watcher.yourdomain.com` | `https://dids.yourdomain.com/services/watcher` |

## Step 1: Configure DNS records

Create the following DNS **A records**, all pointing to the public IP from [01 — Server bootstrap](01-server-bootstrap.md) Step 1.

**Standard:**

| Type | Name | Content (IPv4) | Notes |
| --- | --- | --- | --- |
| A | `mediator` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `vta` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `vtc` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `dids` | `<SERVER_PUBLIC_IP>` | DNS only |

**Standalone — additionally:**

| Type | Name | Content (IPv4) | Notes |
| --- | --- | --- | --- |
| A | `witness` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `control` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `watcher` | `<SERVER_PUBLIC_IP>` | DNS only |

> **Cloudflare users:** Set these records to **DNS only** (grey cloud, proxy disabled). The setup script uses Let's Encrypt for SSL, which requires direct access to port 80.

## Step 2: Run the deploy setup script

As `vti`, run:

**Standard:**

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-deploy.sh | bash -s -- <domain> <email>
```

**Standalone DID Hosting:**

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-deploy.sh | bash -s -- --standalone <domain> <email>
```

Domain AND email are both required — the deploy stream needs certbot renewal notifications.

The script will:

1. Update system packages.
2. Install runtime dependencies (`ufw`, `ca-certificates`, `curl`). No build toolchain, no Docker — pre-built binaries only.
3. Configure UFW firewall (allow ports 22, 80, 443).
4. Create per-service system users (`vta-svc`, `mediator-svc`, `dids-svc`, `vtc-svc`; plus `witness-svc`, `control-svc`, `watcher-svc` in `--standalone`), their data directories at `/var/lib/<svc>-svc/`, and the shared `vti-exchange` group + `/var/lib/vti-exchange/`.
5. Install systemd unit files (one per service, with sandboxing) to `/etc/systemd/system/`. Services are **not** enabled or started yet — they have no config.
6. Install Nginx and Certbot (snap).
7. Create Nginx reverse proxy configs (4 vhosts standard; 7 standalone).
8. Obtain SSL certificates via Certbot.
9. Verify each HTTPS URL responds.

> **Expected result:** `502 Bad Gateway` on the HTTPS URLs is normal at this stage — the backend services are not running yet.

## Step 3: Install service binaries

The deploy stream uses pre-built binaries only (no build toolchain is installed). Download them to `/usr/local/bin/` so the systemd units can find them.

**Both topologies — common binaries:**

```bash
curl -O https://fpp.ic3.dev/vta/latest/vta
chmod +x vta && sudo mv vta /usr/local/bin/

curl -O https://fpp.ic3.dev/vtc/latest/vtc
chmod +x vtc && sudo mv vtc /usr/local/bin/

curl -O https://fpp.ic3.dev/cnm/latest/cnm
chmod +x cnm && sudo mv cnm /usr/local/bin/

curl -O https://fpp.ic3.dev/pnm/latest/pnm
chmod +x pnm && sudo mv pnm /usr/local/bin/

curl -O https://fpp.ic3.dev/mediator/latest/mediator
chmod +x mediator && sudo mv mediator /usr/local/bin/

curl -O https://fpp.ic3.dev/mediator/latest/mediator-setup
chmod +x mediator-setup && sudo mv mediator-setup /usr/local/bin/
```

**Standard topology — integrated DID Hosting daemon:**

```bash
curl -O https://fpp.ic3.dev/did-hosting-daemon/latest/did-hosting-daemon
chmod +x did-hosting-daemon && sudo mv did-hosting-daemon /usr/local/bin/
```

**Standalone topology — separate DID Hosting binaries:**

```bash
curl -O https://fpp.ic3.dev/did-hosting-control/latest/did-hosting-control
chmod +x did-hosting-control && sudo mv did-hosting-control /usr/local/bin/

curl -O https://fpp.ic3.dev/did-hosting-server/latest/did-hosting-server
chmod +x did-hosting-server && sudo mv did-hosting-server /usr/local/bin/

curl -O https://fpp.ic3.dev/webvh-witness/latest/webvh-witness
chmod +x webvh-witness && sudo mv webvh-witness /usr/local/bin/

curl -O https://fpp.ic3.dev/webvh-watcher/latest/webvh-watcher
chmod +x webvh-watcher && sudo mv webvh-watcher /usr/local/bin/
```

## Verification

```bash
# Service users with nologin shells
id mediator-svc
getent passwd mediator-svc | cut -d: -f7   # → /usr/sbin/nologin

# vti and all service users are members of vti-exchange
getent group vti-exchange

# Service data dirs exist with correct perms
ls -ld /var/lib/mediator-svc                # 0750 mediator-svc:mediator-svc
ls -ld /var/lib/vti-exchange                # 2770 vti:vti-exchange

# systemd units installed, inactive
systemctl list-unit-files | grep -- '-svc'

# nginx vhosts use $scheme (X-Forwarded-Proto correctness)
sudo grep -R 'X-Forwarded-Proto' /etc/nginx/sites-enabled/

# Negative test — service users cannot escalate or read each other's data
sudo -u mediator-svc -- sudo -n true        # → fails: not in sudoers
sudo -u mediator-svc cat /var/lib/vta-svc/config.toml  # → Permission denied
```

## Resulting URL map

**Standard:**

| URL | Backend |
| --- | --- |
| `https://mediator.yourdomain.com` | `localhost:7037` |
| `https://vta.yourdomain.com` | `localhost:8100` |
| `https://vtc.yourdomain.com` | `localhost:8200` |
| `https://dids.yourdomain.com` | `localhost:8534` |

**Standalone — additionally:**

| URL | Backend |
| --- | --- |
| `https://witness.yourdomain.com` | `localhost:8531` |
| `https://control.yourdomain.com` | `localhost:8532` |
| `https://watcher.yourdomain.com` | `localhost:8533` |

## Next

Provision and start the services:

- Standard topology: [03 — Provisioning](03-provisioning.md).
- Standalone DID Hosting: complete [03 — Provisioning](03-provisioning.md) Steps 1, 2, 4, and 5 (VTA, Mediator, VTC, PNM), then do [04 — DID Hosting topology](04-did-hosting-topology.md) in place of Step 3.
