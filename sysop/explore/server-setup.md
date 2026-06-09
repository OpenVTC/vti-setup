# Explore: Server Setup

Provision an Ubuntu 26.04 host for the explore stream. Single DID Hosting topology; everything runs as root. For a hardened production deployment with per-service users, use the [Deploy stream](../deploy/) instead.

## Service configuration

| Service | Default Port | DNS Record | DID Hosting Path |
| --- | --- | --- | --- |
| Mediator | 7037 | `mediator.yourdomain.com` | `https://dids.yourdomain.com/mediator` |
| Verifiable Trust Agent | 8100 | `vta.yourdomain.com` | `https://dids.yourdomain.com/vta` |
| Verifiable Trust Community | 8200 | `vtc.yourdomain.com` | `https://dids.yourdomain.com/vtc` |
| DID Hosting Service | 8534 | `dids.yourdomain.com` | `https://dids.yourdomain.com` |

## Prerequisites

| Requirement | Details |
| --- | --- |
| Registered domain + DNS access | We use [Cloudflare](https://www.cloudflare.com) for DNS management. |
| VPS or cloud account | We use [Hetzner](https://www.hetzner.com). Create an Ubuntu 26.04 instance. |
| SSH key pair | Used to connect to the server. |
| `curl` on the server | Hetzner Ubuntu image already includes it. If not using Hetzner: `sudo apt install curl` |

## Step 1: Create Ubuntu 26.04 server

Create a new Ubuntu 26.04 server. Once created, note its **public IP address** — you will need it for DNS configuration in the next step.

## Step 2: Configure DNS records

Create the following DNS **A records**, all pointing to the public IP from Step 1:

| Type | Name | Content (IPv4) | Notes |
| --- | --- | --- | --- |
| A | `mediator` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `vta` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `vtc` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `dids` | `<SERVER_PUBLIC_IP>` | DNS only |

> **Cloudflare users:** Set these records to **DNS only** (grey cloud, proxy disabled). The setup script uses Let's Encrypt for SSL, which requires direct access to port 80.

## Step 3: Run the setup script

SSH into your server as **root** and run the setup script directly:

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-explore.sh | bash -s -- <domain>
# or with email (used for Let's Encrypt expiry notifications):
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-explore.sh | bash -s -- <domain> <email>
```

Example:

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-explore.sh | bash -s -- example.com
```

The script will:

1. Update system packages
2. Install build and runtime dependencies (Git, OpenSSL, build toolchain, Valkey)
3. Configure UFW firewall (allow ports 22, 80, 443)
4. Install Rust
5. Install Node.js v22
6. Install Docker
7. Install Nginx and Certbot (via snap)
8. Create Nginx reverse proxy configs (4 services)
9. Obtain SSL certificates via Certbot
10. Verify each HTTPS URL responds

> **Expected result:** `502 Bad Gateway` on the HTTPS URLs is normal at this stage — the backend services are not running yet.

## Step 4: Reload shell environment

Rust and Cargo were installed inside the script's subshell. To use `cargo` in your current session, run:

```bash
source $HOME/.cargo/env
```

Or simply log out and SSH back in — the environment will be loaded automatically on the next login.

## Step 5: Install service binaries

### Option A: Download pre-built binaries (recommended)

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

curl -O https://fpp.ic3.dev/did-hosting-daemon/latest/did-hosting-daemon
chmod +x did-hosting-daemon && sudo mv did-hosting-daemon /usr/local/bin/
```

### Option B: Build from source

The setup script installed Rust, Node.js, and the C/C++ build toolchain, so you can also build the binaries yourself.

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
cd affinidi-tdk-rs/crates/messaging
```

```bash
cargo install --path affinidi-messaging-mediator --no-default-features --features "didcomm,redis-backend,fjall-backend"
cargo install --path affinidi-messaging-mediator/tools/mediator-setup
```

#### DID Hosting Daemon

```bash
cd ~/affinidi
git clone https://github.com/affinidi/affinidi-webvh-service.git
cd affinidi-webvh-service
```

```bash
cd webvh-ui && npm install && npm run build:web && cd ..
cargo install --path did-hosting-daemon --no-default-features --features "store-fjall,ui,did-methods"
```

## Resulting URL map

| URL | Backend |
| --- | --- |
| `https://mediator.yourdomain.com` | `localhost:7037` |
| `https://vta.yourdomain.com` | `localhost:8100` |
| `https://vtc.yourdomain.com` | `localhost:8200` |
| `https://dids.yourdomain.com` | `localhost:8534` |

## Next

Provision and start the stack: [Walkthrough](walkthrough.md).
