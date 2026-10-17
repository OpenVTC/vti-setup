# Explore 01: Server Setup

Provision an Ubuntu 26.04 host for the explore stream. Single DID Hosting topology; everything runs as root. For a hardened production deployment, see the [Deploy stream](../deploy/) (a VTA Farm on hardened Kubernetes).

## Why root?

Every command in the explore stream runs as root, with no `sudo` anywhere. That is a deliberate choice for a box that exists only to learn on:

- **It's throwaway.** The host holds no real keys or data and gets deleted when you're done, so per-user isolation buys nothing here.
- **Fewer commands.** No `sudo` prefixes, no service users, no `chown` or `chmod` steps to get files where each service can read them.
- **No permission problems to debug.** If you're new to the stack, you can focus on how the VTA, Mediator, DID Hosting Daemon and VTC fit together, not on why one of them can't read its own config.
- **One home directory.** The setup script installs Rust into `/root/.cargo`, and the walkthrough keeps each service's files under `/root/<svc>/`. Every step expects to find them there.

A production host should never be run this way. The [Deploy stream](../deploy/) covers the hardened setup.

If you disable root SSH logins, as many people do, log in as your normal user and run `sudo -i` before Step 3, then do the rest of both explore pages from that root shell. Don't put `sudo` in front of individual commands instead: `sudo bash setup-explore.sh` would install Rust into `/root/.cargo`, leaving your own shell without the tools on its `PATH` and unable to reach the `/root/<svc>/` files the walkthrough uses.

## Service configuration

| Service | Default Port | DNS Record | DID Hosting Path |
| --- | --- | --- | --- |
| Mediator | 7037 | `mediator.yourdomain.com` | `https://dids.yourdomain.com/mediator` |
| Verifiable Trust Agent | 8100 | `vta.yourdomain.com` | `https://dids.yourdomain.com/vta` |
| Verifiable Trust Community | 8200 | `vtc.yourdomain.com` | `https://dids.yourdomain.com/vtc` |
| DID Hosting Service | 8534 | `dids.yourdomain.com` | `https://dids.yourdomain.com` |
| Trust Registry | 3232 (loopback only) | none | `https://dids.yourdomain.com/trust-registry` |

The Trust Registry gets no DNS record or Nginx vhost on the explore box. Clients reach it through its DID and the mediator over DIDComm and TSP; its REST API is bound to loopback for health checks only.

## Prerequisites

| Requirement | Details |
| --- | --- |
| Registered domain + DNS access | We use [Cloudflare](https://www.cloudflare.com) for DNS management. |
| VPS or cloud account | We use [Hetzner](https://www.hetzner.com). Create an Ubuntu 26.04 instance (2vCPU, 4gb RAM recommended). |
| SSH key pair | Used to connect to the server. |
| `curl` on the server | Hetzner Ubuntu image already includes it. If not using Hetzner: `apt install curl` |

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

SSH into your server as **root** (see [Why root?](#why-root) if your host doesn't allow root logins). Download the setup script from this repository's `main` branch, read it, then run it. Download it to a file rather than piping it into `bash`, so you can read what you are about to run as root and so the script's prompts stay attached to your terminal.

```bash
curl -fsSLO https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/setup-explore.sh
less setup-explore.sh
```

Run the script:

```bash
bash setup-explore.sh <domain>
# or with email (used for Let's Encrypt expiry notifications):
bash setup-explore.sh <domain> <email>
```

Example:

```bash
bash setup-explore.sh example.com
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

> **Note:** Seeding the debconf database persists the setting, so it applies however the script is started. The current script sets the frontend on each apt invocation itself, so a fresh copy should never prompt.

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

#### Latest tagged release: VTI-Eucalyptus

```bash
curl -O https://download.firstperson.dev/vta/latest/vta
chmod +x vta && mv vta /usr/local/bin/

curl -O https://download.firstperson.dev/vtc/latest/vtc
chmod +x vtc && mv vtc /usr/local/bin/

# pnm-server: the server build of PNM — secrets live in plaintext config
# rather than an OS keyring, which a headless host has no access to.
# Do not "correct" this back to the pnm/ path.
curl -O https://download.firstperson.dev/pnm-server/latest/pnm
chmod +x pnm && mv pnm /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/latest/mediator
chmod +x mediator && mv mediator /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/latest/mediator-setup
chmod +x mediator-setup && mv mediator-setup /usr/local/bin/

curl -O https://download.firstperson.dev/did-hosting-daemon/latest/did-hosting-daemon
chmod +x did-hosting-daemon && mv did-hosting-daemon /usr/local/bin/

# trust-registry: built with the VTA, TSP and fjall features the walkthrough
# needs (see Option B for the exact feature list).
curl -O https://download.firstperson.dev/trust-registry/latest/trust-registry
chmod +x trust-registry && mv trust-registry /usr/local/bin/
```

#### Nightly builds (unverified)

Unverified builds from each project's `nightly` branch, published without checksums or signatures. Use them only on a throwaway host, to try a change that is not in a tagged release yet. The Trust Registry has no `nightly` branch, so its line below fetches the last build from `main` instead.

```bash
curl -O https://download.firstperson.dev/vta/nightly/vta
chmod +x vta && mv vta /usr/local/bin/

curl -O https://download.firstperson.dev/vtc/nightly/vtc
chmod +x vtc && mv vtc /usr/local/bin/

# pnm-server: the server build of PNM — secrets live in plaintext config
# rather than an OS keyring, which a headless host has no access to.
# Do not "correct" this back to the pnm/ path.
curl -O https://download.firstperson.dev/pnm-server/nightly/pnm
chmod +x pnm && mv pnm /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/nightly/mediator
chmod +x mediator && mv mediator /usr/local/bin/

curl -O https://download.firstperson.dev/mediator/nightly/mediator-setup
chmod +x mediator-setup && mv mediator-setup /usr/local/bin/

curl -O https://download.firstperson.dev/did-hosting-daemon/nightly/did-hosting-daemon
chmod +x did-hosting-daemon && mv did-hosting-daemon /usr/local/bin/

curl -O https://download.firstperson.dev/trust-registry/main/trust-registry
chmod +x trust-registry && mv trust-registry /usr/local/bin/
```

### Option B: Build from source

The setup script installed Rust and the C/C++ build toolchain, so you can also build the binaries yourself. The DID Hosting UI build also needs Node.js, which that step installs.

#### VTA, CNM, and PNM

```bash
cd ~
mkdir fpp && cd fpp
git clone https://github.com/OpenVTC/verifiable-trust-infrastructure.git
cd verifiable-trust-infrastructure
git checkout VTI-Eucalyptus # latest tagged release, or 'git checkout nightly' for the nightly branch
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
git clone https://github.com/affinidi/affinidi-messaging-mediator.git
cd affinidi-messaging-mediator
git checkout v0.42.0 # latest tagged release, or 'git checkout nightly' for the nightly branch
```

```bash
cargo install --path crates/affinidi-messaging-mediator --no-default-features --features "didcomm,redis-backend,fjall-backend"
cargo install --path crates/affinidi-messaging-mediator/tools/mediator-setup
```

The mediator moved out of `affinidi-tdk-rs` into its own repository, which has no `VTI-Eucalyptus` tag; `v0.42.0` is its first release.

#### DID Hosting Daemon

```bash
cd ~/affinidi
git clone https://github.com/affinidi/affinidi-webvh-service.git
cd affinidi-webvh-service
git checkout VTI-Eucalyptus # latest tagged release, or 'git checkout nightly' for the nightly branch
```

```bash
# Node.js and npm are needed only for the UI build. apt verifies Ubuntu's
# packages against the Ubuntu archive signing key.
apt-get install -y nodejs npm
cd did-hosting-ui && npm install && npm run build:web && cd ..
cargo install --path did-hosting-daemon --no-default-features --features "store-fjall,ui,did-methods"
```

> **Node.js version:** `did-hosting-ui` declares Node.js `>=24.3.0` in its `package.json`, and Ubuntu 26.04 ships Node.js 22. If the UI build fails on Node.js 22, install the pre-built `did-hosting-daemon` from Option A instead.

#### Trust Registry

The default build of the registry has no VTA integration, so the feature list matters. The explore walkthrough needs `vta` to take its identity from the VTA, `tsp` to answer the VTC's default TSP transport, `storage-fjall` for an embedded trust-record store with no external database, `secrets-config` for the on-disk bundle cache, and `standalone` for the `trust-registry` binary itself. The pre-built binaries in Option A are built with this same list.

```bash
cd ~/affinidi
git clone https://github.com/affinidi/affinidi-trust-registry-rs.git
cd affinidi-trust-registry-rs
git checkout trust-registry-v0.26.0 # latest tagged release, or just stay on main (this repo has no nightly branch)
```

```bash
cargo install --path trust-registry --no-default-features --features "tsp,secrets-config,storage-fjall,vta,standalone"
```

If `~/affinidi` does not exist yet because you built nothing else, create it first with `mkdir ~/affinidi`.

Whichever way you installed it, confirm the binary has the `vta` feature before moving on. A registry built without it ignores every `TR_VTA_*` setting and refuses to start with `Required environment variable 'PROFILE_CONFIG' is not set`:

```bash
grep -ac TR_VTA_CREDENTIAL "$(command -v trust-registry)"
```

Any number above zero is fine. Zero means the feature is missing: rebuild with the command above, or fetch a binary that was built with it.

## Resulting URL map

| URL | Backend |
| --- | --- |
| `https://mediator.yourdomain.com` | `localhost:7037` |
| `https://vta.yourdomain.com` | `localhost:8100` |
| `https://vtc.yourdomain.com` | `localhost:8200` |
| `https://dids.yourdomain.com` | `localhost:8534` |

The Trust Registry has no public URL on the explore box; it listens on `127.0.0.1:3232` and is reached through its DID (`https://dids.yourdomain.com/trust-registry`).

## Next

Provision and start the stack: [02 — Walkthrough](02-walkthrough.md).
