# OpenVTC TUI Setup

**Description:** Install and configure the OpenVTC TUI — the interactive text interface for working with your Personal VTA. Used for minting membership DIDs (M-DIDs), managing community contexts, and exchanging credentials.  
**Tested on:** Arch Linux desktop

**Verified with:**

| OpenVTC Version | VTA Version | Mediator Version | DID Hosting Daemon Version |
| --- | --- | --- | --- |
| 0.2.1 | 0.12.46 | 0.17.12 | 0.8.2 |

## Prerequisites

Complete [01 — Personal VTA](01-personal-vta.md) first. This tutorial connects the OpenVTC TUI to the Personal VTA you set up.

You also need:

- Access to your **PNM** session from the [01 — Personal VTA](01-personal-vta.md) tutorial — the OpenVTC setup wizard mints an ephemeral DID and asks you to authorise it via PNM. The grant is short-lived (1 hour), so keep PNM at the ready.
- **A VTA that advertises a DID hosting server.** Setup itself does not need one, but you cannot mint a persona without it.

The following values will be collected during setup. Save each one as prompted.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1b | Personal VTA DID (from the Personal VTA tutorial) | Step 2 |
| 2a | OpenVTC unlock passphrase | Each TUI launch |

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

> **ℹ️ NOTE: Decide on the profile before you start**
>
> A profile is one OpenVTC account — one VTA, one set of keys. Plain `openvtc setup` builds the default profile; `openvtc setup -p <name>` builds a named one, and several can live side by side on the same host. That is what you want when testing against multiple VTAs or running separate personas.
>
> The wizard never asks which you are creating, so decide here. Finding out afterwards means running setup again for the profile you actually wanted. File locations are under [Where things live](#where-things-live) at the end of this step.

Launch the wizard:

```bash
openvtc setup
```

(Running `openvtc` with no subcommand also auto-launches the wizard if no profile exists.)

Every page shows a progress breadcrumb. It still lists **Digital Identity**, but that section no longer exists — setup only bootstraps your account, and minting a persona moved to the dashboard (see [03 — Joining a Community](03-joining-a-community.md)). The label is a leftover and will be removed; until then the counter runs 1/5 → 2/5 → 3/5 → 5/5, skipping the fourth.

```text
Section 1/5
  ● Get Started → ○ Key Management → ○ Profile Security → ○ Digital Identity → ○ Setup Complete
```

#### 2.1 Get Started

| Page | Action |
| --- | --- |
| New profile setup | Press **Enter** (use default) |

#### 2.2 Key Management

You point OpenVTC at your VTA and authorise it through PNM. Only the PNM step needs anything outside the TUI.

| Page | Action |
| --- | --- |
| Connect to your VTA | Paste the **Personal VTA DID** (1b), then press **Enter** |

**Authorise the setup DID.** OpenVTC mints an ephemeral admin `did:key` for this session and shows it alongside a ready-to-copy `pnm contexts create` command. Press **F2** to copy the command, then run it in the PNM session you set up in [01 — Personal VTA](01-personal-vta.md):

```bash
pnm contexts create --id openvtc --name "OpenVTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h
```

Switch back to the TUI and press **Enter**. The grant lasts 1 hour — see [Known issues](#known-issues--edge-cases) if you overrun it.

**Bootstrapping with the VTA.** The wizard now works on its own: the ephemeral `did:key` authenticates to the VTA, the VTA mints a long-term admin DID for OpenVTC and rotates the ephemeral key out, and the wizard opens a REST or DIDComm session against the VTA — whichever the VTA advertises in its DID document. Press **Enter** when it reports success. If it fails, Enter returns you to the PNM page to check the grant and retry.

#### 2.3 Profile Security

The unlock code encrypts your secured config.

| Page | Action |
| --- | --- |
| Set up unlock code | Press **Enter**, then type your unlock code twice (2a) |

Choosing to skip instead takes you through a warning page and leaves the config unprotected.

#### 2.4 Setup Complete

Press **Enter** to leave the wizard for the dashboard.

```text
OpenVTC Dashboard                             No active community
┌Menu───────────────────┐┌Content──────────────────────────────────────┐
│ * Communities         ││ Your account is ready. 🎉                   │
│ * Inbox               ││                                             │
│ * My Relationships    ││ You haven't joined any communities yet —    │
│ * My Credentials      ││ that's where the fun begins.                │
│ * Settings            ││                                             │
│ * VTA Service         ││ Press  j  to join your first community.     │
│ * Create Persona DID  ││                                             │
│ * Logs                ││                                             │
│ * Help / Status       ││                                             │
│ * Quit                ││                                             │
└───────────────────────┘└─────────────────────────────────────────────┘
```

**Menu** on the left, **Content** on the right — `<TAB>` switches panels, `<F10>` quits. Relaunch the TUI any time with `openvtc`.

#### Where things live

The public config is written to `~/.config/openvtc/config.json`. Keys and the secured config blob (BIP32 seed, ESK) are stored in your OS keyring under service `openvtc`, account = the profile name. On a headless Linux server the keyring falls back automatically to kernel keyutils — no `gnome-keyring-daemon` required.

A named profile gets its own config file and its own keyring entry — the default profile's `config.json` becomes `config-alice.json`:

```bash
openvtc setup -p alice
openvtc -p alice
```

There is no `openvtc profiles list` or `openvtc profiles delete`. Inspect with `ls ~/.config/openvtc/`; remove one profile by deleting its `config-<name>.json` and clearing the matching keyring entry (e.g. `secret-tool clear service openvtc account <name>` on libsecret-based systems). Wipe everything with `rm -rf ~/.config/openvtc/` plus the corresponding keyring entries.

## Verification

From the main menu, open the **VTA Service** panel. Two rows carry the result of Step 2:

- **VTA** — matches your Personal VTA DID (1b).
- **Authenticated** — shows a `did:key`. This is the long-term admin DID the VTA minted for OpenVTC, and its presence is what tells you the PNM grant in 2.2 went through: the ephemeral setup DID has already been rotated out.

Where a **Persona** row would sit, you instead get `Status: Ready — join a community to create your persona`. That is correct at this point — mint a persona in [03 — Joining a Community](03-joining-a-community.md) and the panel replaces the line with the persona itself.

## Known issues / edge cases

- **PNM grant is 1 hour.** If you take longer than that between running `pnm contexts create` and pressing Enter on the wizard's ACL page, provisioning fails. Re-running the wizard mints a fresh setup DID — re-run `pnm contexts create` against the new one.
- **TUI eats stdout.** For tracing output, set `OPENVTC_DEBUG_LOG=/tmp/openvtc.log` before launching: the TUI writes structured logs to that file while you use the UI.

## Deployment notes

> _To be documented._
