# Deployment: Ubuntu Server

This guide covers deploying the VTI stack on an Ubuntu 26.04 server with Nginx as a reverse proxy and Let's Encrypt SSL certificates.

Two DID Hosting modes are available — choose one before you begin:

- **Standard** _(recommended — if unsure, pick this)_: the DID Hosting Daemon runs as a single integrated service (simpler, fewer subdomains).
- **Standalone DID Hosting**: the DID Hosting components run as separate services on separate ports. Use this if you need each component at its own subdomain or want to scale them independently.

## Service Configuration

### Standard

| Service | Default Port | DNS Record | DID Hosting Path |
| --- | --- | --- | --- |
| Mediator | 7037 | `mediator.yourdomain.com` | `https://dids.yourdomain.com/mediator` |
| Verifiable Trust Agent | 8100 | `vta.yourdomain.com` | `https://dids.yourdomain.com/vta` |
| Verifiable Trust Community | 8200 | `vtc.yourdomain.com` | `https://dids.yourdomain.com/vtc` |
| DID Hosting Service | 8534 | `dids.yourdomain.com` | `https://dids.yourdomain.com` |

### Standalone DID Hosting

| Service | Default Port | DNS Record | DID Hosting Path |
| --- | --- | --- | --- |
| Mediator | 7037 | `mediator.yourdomain.com` | `https://dids.yourdomain.com/mediator` |
| Verifiable Trust Agent | 8100 | `vta.yourdomain.com` | `https://dids.yourdomain.com/vta` |
| Verifiable Trust Community | 8200 | `vtc.yourdomain.com` | `https://dids.yourdomain.com/vtc` |
| DID Hosting Server | 8530 | `dids.yourdomain.com` | `https://dids.yourdomain.com` |
| WebVH Witness | 8531 | `witness.yourdomain.com` | `https://dids.yourdomain.com/services/witness` |
| WebVH Control | 8532 | `control.yourdomain.com` | `https://dids.yourdomain.com/services/control` |
| WebVH Watcher | 8533 | `watcher.yourdomain.com` | `https://dids.yourdomain.com/services/watcher` |

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

If using **standalone DID Hosting**, also add:

| Type | Name | Content (IPv4) | Notes |
| --- | --- | --- | --- |
| A | `witness` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `control` | `<SERVER_PUBLIC_IP>` | DNS only |
| A | `watcher` | `<SERVER_PUBLIC_IP>` | DNS only |

> **Cloudflare users:** Set these records to **DNS only** (grey cloud, proxy disabled). The setup script uses Let's Encrypt for SSL, which requires direct access to port 80.

## Step 3: Bootstrap a Non-Root Operator User

SSH into your server as `root` and run the bootstrap script. It creates a `vti` user with sudo, copies your SSH key over, then disables root SSH and password authentication.

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/bootstrap-user.sh | bash
```

The script will:

1. Create the `vti` user and add it to the `sudo` group
2. Drop `/etc/sudoers.d/90-vti-nopasswd` so `vti` can sudo without a password (the user has no password set, and SSH password auth is disabled — so this is the standard cloud-VM admin pattern, not a downgrade)
3. Copy `/root/.ssh/authorized_keys` → `/home/vti/.ssh/authorized_keys`
4. Drop `/etc/ssh/sshd_config.d/01-vti-hardening.conf` with `PermitRootLogin no` and `PasswordAuthentication no`
5. Reload `sshd`

**Then disconnect and reconnect as `vti@<host>`.** Subsequent steps run as `vti`.

## Step 4: Run the Setup Script

By default the script runs in **live** mode — it installs only what's needed to host pre-built binaries behind nginx (no compilers, no Docker). Pass `--dev` if this box will build the binaries from source (Option B in Step 5).

**Standard (live):**

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain>
# or with email (used for Let's Encrypt expiry notifications):
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- <domain> <email>
```

**Standalone DID Hosting (live):**

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- --standalone <domain> <email>
```

**Dev (installs Rust, Node.js, and the C/C++ build toolchain too):**

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/ubuntu-server-setup.sh | bash -s -- --dev <domain> <email>
```

The script will:

1. Update system packages
2. Install runtime dependencies (`ufw`, `ca-certificates`, `curl`; plus build toolchain in `--dev`)
3. Configure UFW firewall (allow ports 22, 80, 443)
4. *(--dev only)* Install Rust
5. *(--dev only)* Install Node.js v22
6. Install Nginx and Certbot (via snap)
7. Create Nginx reverse proxy configs (4 services standard; 7 services standalone)
8. Obtain SSL certificates via Certbot
9. Verify each HTTPS URL responds

> **Expected result:** `502 Bad Gateway` on the HTTPS URLs is normal at this stage — the backend services are not running yet.

> **Note:** if you ran with `--dev`, Rust and Cargo were installed in the script's subshell. To use `cargo` in your current session, run `source $HOME/.cargo/env`, or log out and SSH back in.

## Step 5: Install Services

### Option A: Download Pre-Built Binaries (Recommended)

Saves 15–40 minutes of build time depending on your hardware.

**Both modes — common binaries:**

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

**Standalone DID Hosting:**

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

### Option B: Build from Source

> **Requires `--dev`:** the build toolchain (Rust, Node.js, gcc/clang/cmake, libssl/libdbus headers) is only installed if you ran Step 4 with `--dev`. Re-run with `--dev` if you skipped it.

#### VTA, CNM, and PNM

```bash
cd ~
mkdir fpp && cd fpp
git clone https://github.com/OpenVTC/verifiable-trust-infrastructure.git
cd verifiable-trust-infrastructure
```

> **Branch selection:** Note the git fetch/checkout commands for the current development branches. You can ignore these and just use the `main` branch unless you are testing.

```bash
# FOR TESTING ONLY
git fetch origin feat/runtime-services-P6
git checkout feat/runtime-services-P6
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
```

```bash
# FOR TESTING ONLY
git fetch origin chore/mediator-setup-cosmetics
git checkout chore/mediator-setup-cosmetics
```

```bash
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

```bash
# FOR TESTING ONLY
git fetch origin release/0.6.0
git checkout release/0.6.0
```

**Standard:**

```bash
cd webvh-ui && npm install && npm run build:web && cd ..
cargo install --path did-hosting-daemon --no-default-features --features "store-fjall,ui,did-methods"
```

**Standalone DID Hosting** — build the UI first (`did-hosting-control` embeds it at compile time):

```bash
cd did-hosting-ui && npm install && npm run build:web && cd ..
cargo install --path did-hosting-control --no-default-features --features "store-fjall,ui"
cargo install --path did-hosting-server --no-default-features --features "store-fjall,method-webvh,method-web"
cargo install --path webvh-witness --no-default-features --features "store-fjall"
cargo install --path webvh-watcher
```

## Resulting URL Map

**Standard:**

| URL | Backend |
| --- | --- |
| `https://mediator.yourdomain.com` | `localhost:7037` |
| `https://vta.yourdomain.com` | `localhost:8100` |
| `https://vtc.yourdomain.com` | `localhost:8200` |
| `https://dids.yourdomain.com` | `localhost:8534` |

**Standalone DID Hosting:**

| URL | Backend |
| --- | --- |
| `https://mediator.yourdomain.com` | `localhost:7037` |
| `https://vta.yourdomain.com` | `localhost:8100` |
| `https://vtc.yourdomain.com` | `localhost:8200` |
| `https://dids.yourdomain.com` | `localhost:8530` |
| `https://witness.yourdomain.com` | `localhost:8531` |
| `https://control.yourdomain.com` | `localhost:8532` |
| `https://watcher.yourdomain.com` | `localhost:8533` |

## Next: set up VTI

With the host provisioned, pick how you want to drive the VTI setup:

| How you want to drive it | Guide |
| --- | --- |
| Step through the wizards interactively | [Interactive setup](interactive-setup.md) |
| Drive from TOML recipes / CLI flags | [Automated setup](automated-setup.md) |
