# OpenVTC TUI Setup

**Description:** Install and configure the OpenVTC TUI — the interactive text interface for working with your Personal VTA. Used for minting persona DIDs, managing community contexts, and exchanging credentials.  
**Tested on:** Ubuntu Server 26.04

**Verified with:**

| Release | OpenVTC | VTA | PNM | Mediator | DID Hosting |
| --- | --- | --- | --- | --- | --- |
| VTI-Fig | 0.9.0 | 0.87.2 | 0.66.2 | 0.56.0 | 0.12.0 |

**Verified by an automated run** on a fresh Ubuntu 26.04 server, against a Personal VTA set up with [Path B of 01](01-personal-vta.md#path-b--vta-the-hard-way-self-hosted): the wizard was driven through tmux and its screens compared with this page. Secrets were kept with `OPENVTC_SECURE_STORE=file`, as on a headless machine. Not tested on macOS, Windows/WSL, with a desktop OS keyring, or with a hardware security key. See [Versions](../README.md#versions).

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

Saves the Rust toolchain install and ~2–5 minutes of build time. On Linux (x86-64):

```bash
curl -O https://download.firstperson.dev/openvtc/latest/openvtc
chmod +x openvtc && sudo mv openvtc /usr/local/bin/
```

The Linux build includes hardware-token support, so it needs the PC/SC library even if you have no token. Without it, `openvtc` stops with `error while loading shared libraries: libpcsclite.so.1`. On Debian or Ubuntu:

```bash
sudo apt install -y libpcsclite1
```

A [macOS build](https://download.firstperson.dev/releases/latest/macOS/openvtc) is also available.

#### Option B: Build from source

Requires a Rust toolchain (1.95.0 or newer). Build from the `VTI-Fig` tag, which is the release in the table above:

```bash
git clone https://github.com/OpenVTC/openvtc.git
cd openvtc
git checkout VTI-Fig
cargo install --path openvtc --locked --no-default-features
```

If you have a hardware token (OpenPGP card / YubiKey) and the PC/SC libraries available on the host, leave out `--no-default-features` to enable hardware-token support.

OpenVTC is also on crates.io (`cargo install openvtc --version 0.9.0 --locked --no-default-features`), but the crates.io 0.9.0 was published before the release's last fix. Built that way, OpenVTC's activity log shows a harmless `device registration failed: VTA contract mismatch` warning ([openvtc#636](https://github.com/OpenVTC/openvtc/issues/636)).

The binary lands in `~/.cargo/bin/`.

#### Confirm

```bash
openvtc --version
```

It prints `openvtc 0.9.0`.

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

**Run the PNM command.** OpenVTC mints a temporary admin `did:key` for this session and shows it as the **Setup DID**. Below it are a **Context id** field, pre-filled with `openvtc`, and a **Transport** row, `Automatic (TSP → DIDComm → REST)`, which **Tab** changes; leave both as they are unless you need otherwise. The page then lists three ready-to-copy commands built from them, which update as you type:

- **F2**, *New context*: `pnm contexts create`. This is the one for a first setup.
- **F3**, *Context already exists, or re-granting*: `pnm acl create`.
- **F4**, *Re-granting? Delete the old entry first*: `pnm acl delete`.

Press **F2** to copy the command, then run it in the PNM session you set up in [01 — Personal VTA](01-personal-vta.md):

```bash
pnm contexts create --id openvtc --name "OpenVTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h --admin-holder --admin-handoff
```

`--admin-holder` also lets OpenVTC manage your own identity (attributes, profiles and disclosures), which sits above any single context. Without it, the **My Identity** panel's Attributes, Profiles and Disclosures tabs are refused.

`--admin-handoff` lets the one-hour setup DID roll over once to the long-term admin DID the VTA mints at the end of setup. Without it, that last step is refused with `VTI-ACL-058`, and the flag can't be added to the context afterwards. If you already created the context without it, replace the setup DID's grant instead with **F4** and then **F3**:

```bash
pnm acl delete did:key:z6Mk...
pnm acl create --did did:key:z6Mk... --role admin --contexts openvtc \
  --expires 1h --handoff --capabilities persona-holder
```

Wait for PNM to print `Admin ACL entry created`, then switch back to the TUI and press **Enter**. If PNM says the context `already exists … NOT added` instead, nothing was granted; use **F3**. The grant lasts 1 hour and the setup DID can use it once; see [Known issues](#known-issues--edge-cases) if you overrun it.

**Connect to the VTA.** The wizard now works on its own, ticking off each check as it goes: the ephemeral `did:key` authenticates to the VTA, the VTA mints a long-term admin DID for OpenVTC and rotates the ephemeral key out, and the wizard opens a TSP or DIDComm session against the VTA — whichever the VTA advertises in its DID document. When it reports `Bootstrap complete — admin key rotated, ephemeral setup DID retired.`, press **Enter**. If it fails, **R** retries and **B** goes back to the PNM page, which then shows a banner naming the cause and the F-key command that fixes it.

**This Trust Context is already in use.** On VTI-Fig, a first-time setup stops here too. The page reports `Contains 1 persona` and lists a `did:key`: that is the long-term admin DID the VTA has just minted for OpenVTC, not an earlier account. Press **C** to continue. (This is an OpenVTC bug, [openvtc#632](https://github.com/OpenVTC/openvtc/issues/632). It is fixed on `main`, so an OpenVTC newer than 0.9.0 skips this page on a first-time setup and goes straight to **Set up hardware token**.) The page is meant for a context that really does hold an OpenVTC account, for example from an earlier setup; then press **R** to recover that account or **B** to go back and use a different context, which leaves the existing one untouched. **C** adds a second account to it.

#### 2.3 Profile Security

The unlock code encrypts your keys, configuration and private data.

If your `openvtc` build includes hardware-token support (the pre-built download and the default `cargo install` both do), this section opens with **Set up hardware token**. Press **S** to skip it unless you have an OpenPGP-compatible token (NitroKey or YubiKey) plugged in.

| Page | Action |
| --- | --- |
| Set up unlock code | Press **Enter** to accept **Yes, require unlock code (recommended)** |
| Enter unlock code | Type your unlock code (2a), at least 8 characters, press **Tab**, type it again under **Confirm unlock code:**, then press **Enter** |

Use **Tab** to move to the confirm field: **Enter** submits the page, so pressing it after the first field reports `Unlock codes do not match.` **Esc** goes back a page.

Choosing **No, do not require unlock code** instead takes you to a **SECURITY WARNING** page and, if you confirm, leaves the config unencrypted.

#### 2.4 Setup Complete

The **Profile configuration** page shows an **Account Summary** with your VTA DID and the context (`openvtc` unless you changed it). Press **Enter** to leave the wizard. A **Ready** page follows while OpenVTC connects in the background; press **Enter** again for the dashboard.

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
│ * VTA Service         ││ Press  n  to join your first community.     │
│ * TSP Relationships   ││                                             │
│ * Logs                ││                                             │
│ * Help / Status       ││                                             │
│ * Quit                ││                                             │
└───────────────────────┘└─────────────────────────────────────────────┘
```

**Menu** on the left, **Content** on the right — `<TAB>` switches panels, `<F10>` quits. Relaunch the TUI any time with `openvtc`.

#### Where things live

The public config is written to `~/.config/openvtc/config.json`. Keys and the secured config blob (BIP32 seed, ESK) are stored in your OS keyring under service `openvtc`, account = the profile name. If the OS keyring (on Linux, a Secret Service such as GNOME Keyring, KWallet or KeePassXC) can't be opened, OpenVTC stops and explains why rather than falling back to somewhere else. On a headless machine with no keyring, choose encrypted file storage deliberately with `OPENVTC_SECURE_STORE=file openvtc`: secrets then live in `~/.config/openvtc/secrets/`, and the store refuses to hold a profile without an unlock code or hardware token. PNM's equivalent is `VTI_SECURE_STORE=file pnm`, which keeps its secrets in plaintext at mode `0600`.

A named profile gets its own config file and its own keyring entry — the default profile's `config.json` becomes `config-alice.json`:

```bash
openvtc setup -p alice
openvtc -p alice
```

There is no `openvtc profiles list` or `openvtc profiles delete`. Inspect with `ls ~/.config/openvtc/`; remove one profile by deleting its `config-<name>.json` and clearing the matching keyring entry (e.g. `secret-tool clear service openvtc username <name>` on libsecret-based systems), or, with file storage, its file in `~/.config/openvtc/secrets/`. Wipe everything with `rm -rf ~/.config/openvtc/` plus the corresponding keyring entries. You will also need to delete the contexts created in the PNM (e.g. `pnm contexts delete openvtc`).

## Verification

From the main menu, open the **VTA Service** panel. Two rows carry the result of Step 2:

- **VTA** — matches your Personal VTA DID.
- **Authenticated** — shows a `did:key`. This is the long-term admin DID the VTA minted for OpenVTC, and its presence is what tells you the PNM grant in 2.2 went through: the ephemeral setup DID has already been rotated out.

Where a **Persona** row would sit, you instead get `Status: Ready — join a community to create your persona`. That is correct at this point — mint a persona in [03 — Joining a Community](03-joining-a-community.md) and the panel replaces the line with the persona itself.

## Known issues / edge cases

- **PNM grant is 1 hour.** If you take longer than that between running `pnm contexts create` and pressing Enter on the wizard's **Run the PNM command** page, provisioning fails and you are sent back to that page with a banner. Re-grant the same setup DID with **F4** (`pnm acl delete`) and then **F3** (`pnm acl create`). Running `pnm contexts create` again does not work: the context already exists, so PNM grants nothing.
- **TUI eats stdout.** For tracing output, set `OPENVTC_DEBUG_LOG=/tmp/openvtc.log` before launching: the TUI writes structured logs to that file while you use the UI.

## Next

Mint a persona and submit your first join request: [03 — Joining a Community](03-joining-a-community.md).
