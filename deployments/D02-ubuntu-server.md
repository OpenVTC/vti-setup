# Deployment: Ubuntu Server

This guide covers deploying the VTI stack on an Ubuntu 24.04 server with Nginx as a reverse proxy and Let's Encrypt SSL certificates.

## Service Configuration

| Service | Default Port | DNS Record | WebVH Path |
| --- | --- | --- | --- |
| WebVH Service | 8000 | `webvh.yourdomain.com` | `https://webvh.yourdomain.com` |
| Community VTA | 8100 | `vta-c.yourdomain.com` | `https://webvh.yourdomain.com/vta-c` |
| Personal Community VTA | 8101 | `vta-p.yourdomain.com` | `https://webvh.yourdomain.com/vta-p` |
| Mediator | 7037 | `mediator.yourdomain.com` | — |

## Prerequisites

| Requirement | Details |
| --- | --- |
| Registered domain + DNS access | We recommend [Cloudflare](https://www.cloudflare.com) for DNS management. |
| VPS or cloud account | We recommend [Hetzner](https://www.hetzner.com). Create an Ubuntu 24.04 instance. |
| SSH key pair | Used to connect to the server. |
| `curl` on the server | Hetzner Ubuntu image already includes it. If not using Hetzner: `sudo apt install curl` |

## Step 1: Create Ubuntu 24.04 Server

Create a new Ubuntu 24.04 server. Once created, note its **public IP address** — you will need it for DNS configuration in the next step.

## Step 2: Configure DNS Records

Create the following DNS **A records**, all pointing to the public IP from Step 1:

| Type | Name | Content (IPv4) | Notes |
| --- | --- | --- | --- |
| A | `vta-c` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `vta-p` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `webvh` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `mediator` | `<SERVER_PUBLIC_IP>` | DNS only |

> **Cloudflare users:** Set these records to **DNS only** (grey cloud, proxy disabled). The setup script uses Let's Encrypt for SSL, which requires direct access to port 80.

## Step 3: Run the Setup Script

SSH into your server and run the setup script directly:

```bash
curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain>
# or with email (used for Let's Encrypt expiry notifications):
curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain> <email>
```

Example:

```bash
curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- example.com
curl -sSL https://raw.githubusercontent.com/ic3software/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- example.com admin@example.com
```

The script will:

1. Update system packages
2. Install build and runtime dependencies (Git, OpenSSL, etc.)
3. Configure UFW firewall (allow ports 22, 80, 443)
4. Install Rust
5. Install Node.js v22
6. Install Docker
7. Install Nginx and Certbot (via snap)
8. Create Nginx reverse proxy configs for all four services
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

curl -O https://fpp.ic3.dev/cnm/latest/cnm
chmod +x cnm && sudo mv cnm /usr/local/bin/

curl -O https://fpp.ic3.dev/pnm/latest/pnm
chmod +x pnm && sudo mv pnm /usr/local/bin/

curl -O https://fpp.ic3.dev/mediator/latest/mediator
chmod +x mediator && sudo mv mediator /usr/local/bin/

curl -O https://fpp.ic3.dev/mediator/latest/mediator-setup-vta
chmod +x mediator-setup-vta && sudo mv mediator-setup-vta /usr/local/bin/

curl -O https://fpp.ic3.dev/webvh-daemon/latest/webvh-daemon
chmod +x webvh-daemon && sudo mv webvh-daemon /usr/local/bin/
```

### Option B: Build from Source

#### VTA, CNM, and PNM

```bash
cd ~
mkdir fpp && cd fpp
git clone https://github.com/OpenVTC/verifiable-trust-infrastructure.git
cd verifiable-trust-infrastructure
```

Switch to the `sealed-bootstrap` branch:

```bash
git fetch origin sealed-bootstrap
git checkout sealed-bootstrap
```

```bash
cargo install --path vta-service --no-default-features --features "setup,config-seed,didcomm,rest,cli-synthesis"
cargo install --path cnm-cli --no-default-features --features "config-session"
cargo install --path pnm-cli --no-default-features --features "config-session"
```

#### Mediator

```bash
cd ~
mkdir affinidi && cd affinidi
git clone https://github.com/affinidi/affinidi-tdk-rs.git
cd affinidi-tdk-rs
```

Switch to the `fix/mediator-deployment` branch:

```bash
git fetch origin fix/mediator-deployment
git checkout fix/mediator-deployment
```

```bash
cd crates/messaging
cargo install --path affinidi-messaging-mediator
cargo install --path affinidi-messaging-mediator/tools/mediator-setup
```

#### WebVH Service

```bash
cd ~/affinidi
git clone https://github.com/affinidi/affinidi-webvh-service.git
cd affinidi-webvh-service
```

> **Testing phase only:** Switch to the `nightly` branch for the latest changes:

```bash
git fetch origin nightly
git checkout nightly
```

```bash
cd webvh-ui && npm install && npm run build:web && cd ..
cargo install --path webvh-server --no-default-features --features "store-fjall"
```

## Resulting URL Map

| URL | Backend |
| --- | --- |
| `https://vta-c.yourdomain.com` | `localhost:8100` |
| `https://vta-p.yourdomain.com` | `localhost:8101` |
| `https://webvh.yourdomain.com` | `localhost:8000` |
| `https://mediator.yourdomain.com` | `localhost:7037` |

## Next: Run a scenario

Once services are installed, proceed to the scenario file for your setup type:

| Scenario | Link |
| --- | --- |
| Online VTA · REST · Interactive | [S01](../scenarios/S01-online-vta-rest-interactive.md) |
