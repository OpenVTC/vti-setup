# T02 · OpenVTC TUI Setup

**Description:** Install and configure the OpenVTC TUI — the interactive text interface for working with your Personal VTA. Used for minting membership DIDs (M-DIDs), managing community contexts, and exchanging credentials.  
**Tested on:** Arch Linux desktop

**Verified with:**

| OpenVTC Version | VTA Version | Mediator Version | Webvh-daemon Version |
| --- | --- | --- | --- |
| 0.2.0 | 0.6.0 | 0.15.3 | 0.7.1 |

## Prerequisites

Complete [T01 — Self-Managed Personal VTA](/tutorials/T01-self-managed-personal-vta.md) first. This tutorial connects the OpenVTC TUI to the Personal VTA you set up.

You also need:

- Access to your **PNM** session from [T01](/tutorials/T01-self-managed-personal-vta.md) — the OpenVTC setup wizard mints an ephemeral DID and asks you to authorise it via PNM. The grant is short-lived (1 hour), so keep PNM at the ready.
- A WebVH host for your persona DID. You can reuse the `webvh-host.com` placeholder from T01 (with a different path), or pick a new one — the wizard will tell you whether it needs an externally-hosted URL or will host the DID for you on a VTA-advertised WebVH server.

The following values will be collected during setup. Save each one as prompted.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1b | Personal VTA DID (from T01) | Step 2 |
| 2a | OpenVTC unlock passphrase | Each TUI launch |
| 2b | OpenVTC persona DID (P-DID) | Presentation to others |

## Setup

### Step 1: Install the OpenVTC TUI

#### Option A: Download pre-built binary (recommended)

Saves the Rust toolchain install and ~2–5 minutes of build time:

```bash
curl -O https://fpp.ic3.dev/openvtc/latest/openvtc
chmod +x openvtc && sudo mv openvtc /usr/local/bin/
```

> **ℹ️ NOTE**
>
> The binary above is installed with `no-default-features`, so you will not have hardware-token support. Follow the build instructions below if you want that.

#### Option B: Build from source

Requires a Rust toolchain (1.94.0 or newer):

```bash
cd ~
git clone https://github.com/OpenVTC/openvtc.git
cd openvtc
cargo install --path openvtc --no-default-features
```

If you have a hardware token (OpenPGP card / YubiKey) and the PC/SC libraries available on the host, build with default features instead to enable hardware-token support:

```bash
cargo install --path openvtc
```

The binary lands in `~/.cargo/bin/`.

#### Confirm

```bash
openvtc --help
```

### Step 2: Run the setup wizard

Launch the wizard:

```bash
openvtc setup
```

(Running `openvtc` with no subcommand also auto-launches the wizard if no profile exists.)

> **ℹ️ NOTE: Multiple profiles for local testing**
>
> Pass `-p <name>` to maintain separate profiles on the same host — useful for testing against multiple VTAs or running several personas side by side:
>
> ```bash
> openvtc setup -p alice
> openvtc -p alice
> ```
>
> Profile artifacts live under `~/.config/openvtc/`
>
> - Default profile (no `-p`): `config.json`
> - Named profile (`-p alice`): `config-alice.json`
> - Secured config (BIP32 seed, ESK) lives in the OS keyring under service `openvtc`, account = the profile name.
> - `did.jsonl` (local working copy) is **not** suffixed by profile, so running the wizard under a new profile overwrites it. The authoritative copy is the one you published on the WebVH host.
>
> There is no `openvtc profiles list` or `openvtc profiles delete` command. Inspect with `ls ~/.config/openvtc/`; remove a single profile by deleting its `config-<name>.json` and clearing the matching keyring entry (e.g. `secret-tool clear service openvtc account <name>` on libsecret-based systems). Wipe everything with `rm -rf ~/.config/openvtc/` and clear the corresponding keyring entries.

#### 2.1 Get started

The wizard walks through a sequence of pages. Where input is required, use the action in the right column.

Press **Enter** (use default: **New profile setup**).

#### 2.2 Key management

##### 2.2.1 Connect to your VTA

Paste the **Personal VTA DID** from 1b, then press **Enter**.

##### 2.2.2 Authorise the setup DID via PNM

OpenVTC mints an ephemeral admin `did:key` for this session and displays it along with a ready-to-copy `pnm contexts create` command.

Press **F2** to copy the command, then switch to your PNM session from T01 and run it:

```bash
pnm contexts create --id openvtc --name "OpenVTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h
```

Switch back to the OpenVTC TUI and press **Enter** to continue.

##### 2.2.3 Bootstrapping with the VTA

The wizard then auto-bootstraps:

- The ephemeral `did:key` authenticates to the VTA.
- The VTA mints a long-term admin DID for OpenVTC and rotates the ephemeral key out.
- The wizard opens a REST or DIDComm session against the VTA, depending on what the VTA advertises in its DID document.

If the VTA advertises any WebVH hosting servers, the wizard offers to host your persona DID on one of them. Otherwise it skips ahead and prompts for a WebVH URL near the end of the wizard.

Press **Enter** to continue.

##### 2.2.4 Creating keys

The wizard then creates keys for the persona via the VTA along with WebVH update keys.

Press **Enter** to continue.

##### 2.2.5 DID keys

Skip copying the initial keys for now.

Press **Enter** to continue.

##### 2.2.6 Export private keys

Skip copying the private keys for now.

Press **Enter** to continue.

##### 2.2.7 Configure git commit signing

Skip configuring git signing for now.

Select **No, skip git signing setup**, then press **Enter** to continue.

#### 2.3 Profile security

##### 2.3.1 Set up unlock code

Press **Enter** to continue to set up an unlock code.

Enter your unlock code twice. It must be at least 8 characters long.

Press **Enter** to continue.

#### 2.4 Digital identity

##### 2.4.1 Configure messaging mediator

Press **Enter** (Use default VTA mediator) to continue.

##### 2.4.2 Set your display name

Type in your name and press **Enter** to continue.

##### 2.4.3 Persona DID setup

###### 2.4.3.1 Create a new DID

Press **Enter** (Create a new WebVH DID) to continue.

###### 2.4.3.2 Enter persona DID URL

Enter the address of your DID on the web (e.g., `https://webvh-host.com/your-persona`), and press **Enter** to continue.

###### 2.4.3.3 Upload DID document

The wizard now displays the constructed DID — copy it.

Next, upload the DID to your web host (see [step 2 in T01](/tutorials/T01-self-managed-personal-vta.md#step-2-publish-personal-vta-did) for details).

Sanity-check from another machine:

```bash
curl -sSf https://webvh-host.com/your-persona/did.jsonl | head -n 1
```

Press **Enter** to continue.

#### 2.5 Setup complete

Setup is now complete.

Press **Enter** to continue to the dashboard.

When the wizard finishes, the public config is written to `~/.config/openvtc/config.json`. Keys and the secured config blob are stored in your OS keyring (on a headless Linux server this falls back automatically to kernel keyutils — no `gnome-keyring-daemon` required).

After exiting the dashboard, relaunch the TUI any time with `openvtc`.

## Verification

From the main menu, open the **VTA Service** panel. It should show:

- **VTA URL** matching your Personal VTA from T01 (e.g. `https://vta-p.yourdomain.com`)
- **VTA DID** matching 1b
- **Persona DID** matching 2b
- **Mediator DID** matching the mediator your VTA advertises
- **Total keys** of 3 (3 persona keys)

From the Help/Status panel, hotkey **[1]** copies the persona DID and **[2]** copies the mediator DID — useful spot checks.

## Known issues / edge cases

- **PNM grant is 1 hour.** If you take longer than that between running `pnm contexts create` and pressing Enter on the wizard's ACL page, provisioning fails. Re-running the wizard mints a fresh setup DID — re-run `pnm contexts create` against the new one.
- **TUI eats stdout.** For tracing output, set `OPENVTC_DEBUG_LOG=/tmp/openvtc.log` before launching: the TUI writes structured logs to that file while you use the UI.

## Deployment notes

> _To be documented._
