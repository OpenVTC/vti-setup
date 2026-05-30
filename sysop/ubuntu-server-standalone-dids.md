# Deployment: Ubuntu Server (Standalone DID Hosting)

This guide covers deploying the VTI stack with the DID Hosting Daemon in standalone mode on an Ubuntu 26.04 server with Nginx as a reverse proxy and Let's Encrypt SSL certificates.

In standalone mode the DID Hosting Daemon runs its control, witness, and watcher components as separate services on separate ports, rather than the single integrated port used in the [standard deployment](ubuntu-server.md).

## Service Configuration

| Service | Default Port | DNS Record |
| --- | --- | --- |
| Verifiable Trust Community | 8200 | `vtc.yourdomain.com` |
| Verifiable Trust Agent | 8100 | `vta.yourdomain.com` |
| Mediator | 7037 | `mediator.yourdomain.com` |
| DID Hosting Server | 8530 | `dids.yourdomain.com` |
| WebVH Witness | 8531 | `witness.yourdomain.com` |
| WebVH Watcher | 8533 | `watcher.yourdomain.com` |

## Prerequisites

| Requirement | Details |
| --- | --- |
| Registered domain + DNS access | We use [Cloudflare](https://www.cloudflare.com) for DNS management. |
| VPS or cloud account | We use [Hetzner](https://www.hetzner.com). Create an Ubuntu 26.04 instance. |
| SSH key pair | Used to connect to the server. |
| `curl` on the server | Hetzner Ubuntu image already includes it. If not using Hetzner: `sudo apt install curl` |

## Step 1: Create Ubuntu 26.04 Server

Create a new Ubuntu 26.04 server. Once created, note its **public IP address** — you will need it for DNS configuration in the next step.

## Step 2: Configure DNS Records

Create the following DNS **A records**, all pointing to the public IP from Step 1:

| Type | Name | Content (IPv4) | Notes |
| --- | --- | --- | --- |
| A | `vtc` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `vta` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `dids` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `mediator` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `witness` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `watcher` | `<SERVER_PUBLIC_IP>` | DNS only |

> **Cloudflare users:** Set these records to **DNS only** (grey cloud, proxy disabled). The setup script uses Let's Encrypt for SSL, which requires direct access to port 80.

## Step 3: Run the Setup Script

SSH into your server and run the setup script directly:

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup-standalone-dids.sh | bash -s -- <domain>
# or with email (used for Let's Encrypt expiry notifications):
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup-standalone-dids.sh | bash -s -- <domain> <email>
```

Example:

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup-standalone-dids.sh | bash -s -- example.com
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup-standalone-dids.sh | bash -s -- example.com admin@example.com
```

The script will:

1. Update system packages
2. Install build and runtime dependencies (Git, OpenSSL, etc.)
3. Configure UFW firewall (allow ports 22, 80, 443)
4. Install Rust
5. Install Node.js v22
6. Install Docker
7. Install Nginx and Certbot (via snap)
8. Create Nginx reverse proxy configs for all six services
9. Obtain SSL certificates via Certbot
10. Verify each HTTPS URL responds

> **Expected result:** `502 Bad Gateway` on the HTTPS URLs is normal at this stage — the backend services are not running yet.

## Step 4: Reload Shell Environment

Rust and Cargo were installed inside the script's subshell. To use `cargo` in your current session, run:

```bash
source $HOME/.cargo/env
```

Or simply log out and SSH back in — the environment will be loaded automatically on the next login.

## Step 5: Install Services

### Option A: Download Pre-Built Binaries (Recommended)

Saves 15–40 minutes of build time depending on your hardware:

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

curl -O https://fpp.ic3.dev/did-hosting-control/latest/did-hosting-control
chmod +x did-hosting-control && sudo mv did-hosting-control /usr/local/bin/

curl -O https://fpp.ic3.dev/did-hosting-server/latest/did-hosting-server
chmod +x did-hosting-server && sudo mv did-hosting-server /usr/local/bin/

curl -O https://fpp.ic3.dev/webvh-witness/latest/webvh-witness
chmod +x webvh-witness && sudo mv webvh-witness /usr/local/bin/

curl -O https://fpp.ic3.dev/webvh-watcher/latest/webvh-watcher
chmod +x webvh-watcher && sudo mv webvh-watcher /usr/local/bin/
```

### Option B: Build from Source

#### VTA, CNM, and PNM

```bash
cd ~
mkdir fpp && cd fpp
git clone https://github.com/OpenVTC/verifiable-trust-infrastructure.git
cd verifiable-trust-infrastructure
```

```bash
cargo install --path vta-service --no-default-features --features "setup,config-seed,didcomm,rest,cli-synthesis"
cargo install --path vtc-service --no-default-features --features "setup,config-secret"
cargo install --path cnm-cli --no-default-features --features "config-session"
cargo install --path pnm-cli --no-default-features --features "config-session"
```

#### Mediator

```bash
cd ~
mkdir affinidi && cd affinidi
git clone https://github.com/affinidi/affinidi-tdk-rs.git
cd affinidi-tdk-rs
cd crates/messaging
cargo install --path affinidi-messaging-mediator --no-default-features --features "didcomm,redis-backend,fjall-backend"
cargo install --path affinidi-messaging-mediator/tools/mediator-setup
```

#### DID Hosting Service

```bash
cd ~/affinidi
git clone https://github.com/affinidi/affinidi-webvh-service.git
cd affinidi-webvh-service
```

Build the UI first — `did-hosting-control` embeds it at compile time:

```bash
cd did-hosting-ui && npm install && npm run build:web && cd ..
```

```bash
cargo install --path did-hosting-server --no-default-features --features "store-fjall"
cargo install --path webvh-witness --no-default-features --features "store-fjall"
cargo install --path did-hosting-control --no-default-features --features "store-fjall,ui"
cargo install --path webvh-watcher
```

## Resulting URL Map

| URL | Backend |
| --- | --- |
| `https://vtc.yourdomain.com` | `localhost:8200` |
| `https://vta.yourdomain.com` | `localhost:8100` |
| `https://mediator.yourdomain.com` | `localhost:7037` |
| `https://dids.yourdomain.com` | `localhost:8530` |
| `https://witness.yourdomain.com` | `localhost:8531` |
| `https://watcher.yourdomain.com` | `localhost:8533` |

## Next: set up VTI

With the host provisioned, proceed to the interactive setup:

| How you want to drive it | Guide |
| --- | --- |
| Step through the wizards interactively | [Interactive setup (standalone)](interactive-setup-standalone-dids.md) |
