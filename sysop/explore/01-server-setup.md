# Explore 01: Server Setup

Provision an Ubuntu 26.04 host for the explore stream. Single DID Hosting topology; everything runs as root. For a hardened production deployment, see the [Deploy stream](../deploy/) (a VTA Farm on hardened Kubernetes).

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
| VPS or cloud account | We use [Hetzner](https://www.hetzner.com). Create an Ubuntu 26.04 instance (2vCPU, 4gb RAM recommended). |
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

SSH into your server as **root**. Download the setup script from this repository's `main` branch, read it, then run it. Download it to a file rather than piping it into `bash`, so you can read what you are about to run as root and so the script's prompts stay attached to your terminal.

```bash
curl -fsSLO https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-explore.sh
less setup-explore.sh
```

Run the script:

```bash
sudo bash setup-explore.sh <domain>
# or with email (used for Let's Encrypt expiry notifications):
sudo bash setup-explore.sh <domain> <email>
```

Example:

```bash
sudo bash setup-explore.sh example.com
```

The script checks that `<domain>` is a plain hostname and `<email>` a plain address, and stops before changing anything if either is not. The whole script is one function called on its last line, so an incomplete download runs nothing.

The script will:

1. Update system packages
2. Install build and runtime dependencies (Git, OpenSSL, build toolchain, Valkey)
3. Configure UFW firewall (allow ports 22, 80, 443)
4. Install Rust (Ubuntu's `rustup` package, then the stable toolchain)
5. Install Nginx and Certbot (via snap)
6. Create Nginx reverse proxy configs (4 services)
7. Obtain SSL certificates via Certbot
8. Verify each HTTPS URL responds

Node.js is not installed here: the one step that needs it, the optional DID Hosting UI build in [Option B](#option-b-build-from-source), installs it. Docker is not used anywhere in this guide and is not installed.

> **Expected result:** `502 Bad Gateway` on the HTTPS URLs is normal at this stage — the backend services are not running yet.

### If the script stops on a blue configuration dialog

Older copies of the script, which this page used to pipe straight into `bash`, can stop at a full-screen `Configuring keyboard-configuration` dialog during Step 1, or at a `needrestart` "which services should be restarted" list later on. With the script piped in, stdin was the download rather than your terminal, so the dialog may not accept keystrokes at all.

To get past it, `Ctrl-C` out and run a downloaded copy as shown above. It sets the apt frontend on every call and runs from a file, so stdin stays attached to your terminal. On a host with pre-seeded debconf answers, you can also pre-seed the answers as root before re-running:

```bash
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | debconf-set-selections
```

Re-running the whole script is safe, so it does not matter how far in you got before interrupting. The Rust and Certbot steps each skip themselves if the tool is already present, the UFW rules and `systemctl enable` calls are idempotent, and the Nginx vhosts are rewritten from scratch and re-certified on every run. The one thing to watch is Let's Encrypt's rate limit — five duplicate certificates per week — so avoid re-running it many times in a row once certificates have been issued.

> **Note:** `export DEBIAN_FRONTEND=noninteractive` in your own shell will not help — the script's apt calls go through `sudo`, whose default `env_reset` strips the variable before apt sees it. Seeding the debconf database persists the setting instead, so it applies regardless of environment. The current script sets the frontend on each apt invocation itself, so a fresh copy should never prompt.

## Step 4: Reload shell environment

`cargo install` puts the binaries it builds in `~/.cargo/bin`. The script adds that directory to `PATH` for new login shells. To use it in your current session, run:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

Or simply log out and SSH back in — the environment will be loaded automatically on the next login.

## Step 5: Install service binaries

### Option A: Download pre-built binaries (recommended)

Saves 15–40 minutes of build time depending on your hardware.

> **Not integrity-checked.** `download.firstperson.dev` does not publish checksums or signatures yet, so nothing below verifies these binaries beyond HTTPS. That is acceptable only on a throwaway explore host: do not copy them to a machine that holds real keys.

#### Latest tagged release: VTI-Dogwood

```bash
curl -O https://download.firstperson.dev/vta/latest/vta
chmod +x vta && sudo mv vta /usr/local/bin/

curl -O https://download.firstperson.dev/vtc/latest/vtc
chmod +x vtc && sudo mv vtc /usr/local/bin/

# pnm-server: the server build of PNM — secrets live in plaintext config
# rather than an OS keyring, which a headless host has no access to.
# Do not "correct" this back to the pnm/ path.
curl -O https://download.firstperson.dev/pnm-server/latest/pnm
chmod +x pnm && sudo mv pnm /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/latest/mediator
chmod +x mediator && sudo mv mediator /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/latest/mediator-setup
chmod +x mediator-setup && sudo mv mediator-setup /usr/local/bin/

curl -O https://download.firstperson.dev/did-hosting-daemon/latest/did-hosting-daemon
chmod +x did-hosting-daemon && sudo mv did-hosting-daemon /usr/local/bin/
```

#### Last compiled commit from main branches (unverified)

Unverified builds of whatever was last merged, published without checksums or signatures. Use them only on a throwaway host, to try a change that is not in a tagged release yet.

```bash
curl -O https://download.firstperson.dev/vta/main/vta
chmod +x vta && sudo mv vta /usr/local/bin/

curl -O https://download.firstperson.dev/vtc/main/vtc
chmod +x vtc && sudo mv vtc /usr/local/bin/

# pnm-server: the server build of PNM — secrets live in plaintext config
# rather than an OS keyring, which a headless host has no access to.
# Do not "correct" this back to the pnm/ path.
curl -O https://download.firstperson.dev/pnm-server/main/pnm
chmod +x pnm && sudo mv pnm /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/main/mediator
chmod +x mediator && sudo mv mediator /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/main/mediator-setup
chmod +x mediator-setup && sudo mv mediator-setup /usr/local/bin/

curl -O https://download.firstperson.dev/did-hosting-daemon/main/did-hosting-daemon
chmod +x did-hosting-daemon && sudo mv did-hosting-daemon /usr/local/bin/
```

### Option B: Build from source

The setup script installed Rust and the C/C++ build toolchain, so you can also build the binaries yourself. The DID Hosting UI build also needs Node.js, which that step installs.

#### VTA, CNM, and PNM

```bash
cd ~
mkdir fpp && cd fpp
git clone https://github.com/OpenVTC/verifiable-trust-infrastructure.git
cd verifiable-trust-infrastructure
git checkout VTI-Dogwood # latest tagged release, or just stay on main
```

```bash
cargo install --path vta-service --no-default-features --features "setup,config-seed,didcomm,rest,cli-synthesis"
cargo install --path vtc-service --no-default-features --features "setup,config-secret,website,admin-ui"
cargo install --path pnm-cli --no-default-features --features "config-session,tsp"
```

#### Mediator

```bash
cd ~
mkdir affinidi && cd affinidi
git clone https://github.com/affinidi/affinidi-tdk-rs.git
cd affinidi-tdk-rs/crates/messaging
git checkout VTI-Dogwood # latest tagged release, or just stay on main
```

```bash
cargo install --path affinidi-messaging-mediator --no-default-features --features "didcomm,redis-backend,fjall-backend"
cargo install --path affinidi-messaging-mediator-setup
```

#### DID Hosting Daemon

```bash
cd ~/affinidi
git clone https://github.com/affinidi/affinidi-webvh-service.git
cd affinidi-webvh-service
git checkout VTI-Dogwood # latest tagged release, or just stay on main
```

```bash
# Node.js and npm are needed only for the UI build. apt verifies Ubuntu's
# packages against the Ubuntu archive signing key.
sudo apt-get install -y nodejs npm
cd did-hosting-ui && npm install && npm run build:web && cd ..
cargo install --path did-hosting-daemon --no-default-features --features "store-fjall,ui,did-methods"
```

> **Node.js version:** `did-hosting-ui` declares Node.js `>=24.3.0` in its `package.json`, and Ubuntu 26.04 ships Node.js 22. If the UI build fails on Node.js 22, install the pre-built `did-hosting-daemon` from Option A instead.

## Resulting URL map

| URL | Backend |
| --- | --- |
| `https://mediator.yourdomain.com` | `localhost:7037` |
| `https://vta.yourdomain.com` | `localhost:8100` |
| `https://vtc.yourdomain.com` | `localhost:8200` |
| `https://dids.yourdomain.com` | `localhost:8534` |

## Next

Provision and start the stack: [02 — Walkthrough](02-walkthrough.md).
