# OpenVTC TUI Setup

**Description:** Install and configure the OpenVTC TUI — the interactive text interface for working with your Personal VTA. Used for minting membership DIDs (M-DIDs), managing community contexts, and exchanging credentials.  
**Tested on:** Arch Linux desktop & macOS

**Verified with:**

| OpenVTC Version | VTA Version | Mediator Version | DID Hosting Daemon Version |
| --- | --- | --- | --- |
| 0.11.58 | 0.39.0 | 0.28.36 | 0.8.3 |

## Prerequisites

Complete [01 — Personal VTA](01-personal-vta.md) first. This tutorial connects the OpenVTC TUI to the Personal VTA you set up.

You also need:

- Your **Personal VTA DID**, which you saved in [01 — Personal VTA](01-personal-vta.md). You paste it into the setup wizard in Step 2.
- Access to your **PNM** session from the [01 — Personal VTA](01-personal-vta.md) tutorial — the OpenVTC setup wizard mints an ephemeral DID and asks you to authorise it via PNM. The grant is short-lived (1 hour), so keep PNM at the ready.
- **A VTA that advertises a DID hosting server.** Setup itself does not need one, but you cannot mint a persona without it. If you are using the VTA Farm to host your VTA, this is already done for you.

The following values will be collected during setup. Save each one as prompted.

| ID | What to Save | Used In |
| --- | --- | --- |
| 2a | OpenVTC unlock code | Each TUI launch |

## Setup

### Step 1: Install the OpenVTC TUI

#### Option A: Download pre-built binary (recommended)

Saves the Rust toolchain install and ~2–5 minutes of build time:

```bash
curl -O https://download.firstperson.dev/openvtc/latest/openvtc
chmod +x openvtc && sudo mv openvtc /usr/local/bin/
```

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
> A profile is one OpenVTC account, one set of keys. Plain `openvtc setup` builds the default profile; `openvtc setup -p <name>` builds a named one, and several can live side by side on the same VTA host. That is what you want when testing against multiple VTAs or running separate personas.
>
> The wizard never asks which you are creating, so decide here. Finding out afterwards means running setup again for the profile you actually wanted. File locations are under [Where things live](#where-things-live) at the end of this step.

Launch the wizard:

```bash
openvtc setup
```

(Running `openvtc` with no subcommand also auto-launches the wizard if no profile exists.)

Every page shows a progress breadcrumb.

```text
Section 1/4
  ● Get Started → ○ Key Management → ○ Profile Security → ○ Setup Complete
```

#### 2.1 Get Started

The first page offers two panels side by side: **New profile setup** and **Recover from backup**.

| Page | Action |
| --- | --- |
| New profile setup | Press **Enter** (selected by default) |

#### 2.2 Key Management

You point OpenVTC at your VTA and authorise it through PNM. Only the PNM step needs anything outside the TUI.

| Page | Action |
| --- | --- |
| Connect to your VTA | At **Enter the VTA's DID:**, paste your **Personal VTA DID**, then press **Enter** |

**Authorise the setup DID via PNM.** OpenVTC mints a temporary admin `did:key` for this session and shows it as the **Setup DID**. Below it is a **Context id** field, pre-filled with `openvtc`, and a ready-to-copy `pnm contexts create` command built from both. Leave the context id as it is unless you need a different one; the command updates as you type, and **Esc** resets it to `openvtc`. Press **F2** to copy the command, then run it in the PNM session you set up in [01 — Personal VTA](01-personal-vta.md):

```bash
pnm contexts create --id openvtc --name "OpenVTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h --admin-holder
```

`--admin-holder` also lets OpenVTC manage your own identity (attributes, profiles and disclosures), which sits above any single context. Without it, the **My Identity** panel's Attributes, Profiles and Disclosures tabs are refused.

Switch back to the TUI and press **Enter**. The grant lasts 1 hour — see [Known issues](#known-issues--edge-cases) if you overrun it.

**Bootstrapping with the VTA.** The wizard now works on its own, ticking off each check as it goes: the ephemeral `did:key` authenticates to the VTA, the VTA mints a long-term admin DID for OpenVTC and rotates the ephemeral key out, and the wizard opens a TSP or DIDComm session against the VTA — whichever the VTA advertises in its DID document. When it reports `Bootstrap complete — admin key rotated, ephemeral setup DID retired.`, press **Enter**. If it fails, Enter returns you to the PNM page to check the grant and retry.

**If the context is already in use.** When the context you chose already holds an OpenVTC account (for example, from an earlier setup), the wizard stops at **This Trust Context is already in use** and lists what it contains. Press **R** to recover that account, **B** to go back and use a different context (the existing one is left untouched), or **C** to continue anyway and add a second account to it. A first-time setup never sees this page.

#### 2.3 Profile Security

The unlock code encrypts your keys, configuration and private data.

If your `openvtc` build includes hardware-token support (the default for `cargo install --path openvtc`), this section opens with **Step 1/6: Set up hardware token**. Press **S** to skip it unless you have an OpenPGP-compatible token (NitroKey or YubiKey) plugged in.

| Page | Action |
| --- | --- |
| Step 1/2: Set up unlock code | Press **Enter** to accept **Yes, require unlock code (recommended)** |
| Step 2/2: Enter unlock code | Type your unlock code (2a), press **Tab**, type it again under **Confirm unlock code:**, then press **Enter** |

Choosing **No, do not require unlock code** instead takes you to a **SECURITY WARNING** page and, if you confirm, leaves the config unencrypted.

#### 2.4 Setup Complete

The **Profile configuration** page shows an **Account Summary** with your VTA DID and the context (`openvtc` unless you changed it). Press **Enter** to leave the wizard for the dashboard.

```text
OpenVTC Dashboard                             No active community
┌Menu───────────────────┐┌Content──────────────────────────────────────┐
│ * Communities         ││ Your account is ready. 🎉                   │
│ * Inbox               ││                                             │
│ * My Relationships    ││ You haven't joined any communities yet —    │
│ * My Credentials      ││ that's where the fun begins.                │
│ * Vetting             ││ Find a Verifiable Trust Community and       │
│ * My Identity         ││ choose who it will know you as.             │
│ * Settings            ││                                             │
│ * VTA Service         ││ Press  j  to join your first community.     │
│ * TSP Relationships   ││                                             │
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

There is no `openvtc profiles list` or `openvtc profiles delete`. Inspect with `ls ~/.config/openvtc/`; remove one profile by deleting its `config-<name>.json` and clearing the matching keyring entry (e.g. `secret-tool clear service openvtc account <name>` on libsecret-based systems). Wipe everything with `rm -rf ~/.config/openvtc/` plus the corresponding keyring entries. You will also need to delete the contexts created in the PNM (e.g. `pnm contexts delete openvtc`).

## Verification

From the main menu, open the **VTA Service** panel. Two rows carry the result of Step 2:

- **VTA** — matches your Personal VTA DID.
- **Authenticated** — shows a `did:key`. This is the long-term admin DID the VTA minted for OpenVTC, and its presence is what tells you the PNM grant in 2.2 went through: the ephemeral setup DID has already been rotated out.

Where a **Persona** row would sit, you instead get `Status: Ready — join a community to create your persona`. That is correct at this point — mint a persona in [03 — Joining a Community](03-joining-a-community.md) and the panel replaces the line with the persona itself.

## Known issues / edge cases

- **PNM grant is 1 hour.** If you take longer than that between running `pnm contexts create` and pressing Enter on the wizard's **Authorise the setup DID via PNM** page, provisioning fails. Re-running the wizard mints a fresh setup DID — re-run `pnm contexts create` against the new one.
- **TUI eats stdout.** For tracing output, set `OPENVTC_DEBUG_LOG=/tmp/openvtc.log` before launching: the TUI writes structured logs to that file while you use the UI.

## Next

Mint a persona and submit your first join request: [03 — Joining a Community](03-joining-a-community.md).
