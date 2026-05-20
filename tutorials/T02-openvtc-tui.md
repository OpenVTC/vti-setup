# T02 · OpenVTC TUI Setup

**Description:** Install and configure the OpenVTC TUI — the interactive text interface for working with your Personal VTA. Used for minting M-DIDs, managing community contexts, and exchanging credentials.
**Tested on:** Arch Linux desktop

**Verified with:**

| OpenVTC Version | VTA Version | Mediator Version | Webvh-daemon Version |
| --- | --- | --- | --- |
| 0.2.0 [prerelease](https://github.com/OpenVTC/openvtc/tree/1f314559b306f4ab450b0e60b76d4705bd52d287) | 0.6.0 | 0.15.3 | 0.7.1 |

## Prerequisites

Complete [T01 — Self-Managed Personal VTA](T01-self-managed-personal-vta.md) first. This tutorial connects the OpenVTC TUI to the Personal VTA you set up.

You also need:

- Access to your **PNM** session from [T01](/tutorials/T01-self-managed-personal-vta.md) — the OpenVTC setup wizard mints an ephemeral DID and asks you to authorise it via PNM. The grant is short-lived (1 hour), so keep PNM at the ready.
- A WebVH host for your persona DID. You can reuse the `webvh-host.com` placeholder from T01 (a different path), or pick a new one — the wizard will tell you whether it needs an externally-hosted URL or will host the DID for you on a VTA-advertised WebVH server.

The following values will be collected during setup. Save each one as prompted.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1b | Personal VTA DID (from T01) | Step 2 |
| 2a | OpenVTC persona DID (P-DID) | Recovery |
| 2b | OpenVTC mnemonic phrase | Recovery |
| 2c | OpenVTC unlock passphrase | Each TUI launch |

## Steps

### Step 1: Install the OpenVTC TUI

#### Option A: Download Pre-Built Binary (Recommended)

Saves the Rust toolchain install and ~2–5 minutes of build time:

```bash
curl -O https://fpp.ic3.dev/openvtc/latest/openvtc
chmod +x openvtc && sudo mv openvtc /usr/local/bin/
```

> **ℹ️ NOTE**
>
> The binary above is installed with `no-default-features`, so you will not have hardware token support. Follow the build instructions below if you want that.

#### Option B: Build from Source

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
> Profile artifacts live under `~/.config/openvtc/` (hardcoded — `XDG_CONFIG_HOME` is not honoured):
>
> - Default profile (no `-p`): `config.json`
> - Named profile (`-p alice`): `config-alice.json`
> - Secured config (BIP32 seed, ESK) lives in the OS keyring under service `openvtc`, account = the profile name.
> - `did.jsonl` (local working copy) is **not** suffixed by profile, so running the wizard under a new profile overwrites it. The authoritative copy is the one you published on the WebVH host.
>
> There is no `openvtc profiles list` or `openvtc profiles delete` command. Inspect with `ls ~/.config/openvtc/`; remove a single profile by deleting its `config-<name>.json` and clearing the matching keyring entry (e.g. `secret-tool clear service openvtc account <name>` on libsecret-based systems). Wipe everything with `rm -rf ~/.config/openvtc/` and clear the corresponding keyring entries.

The wizard walks through a sequence of pages. Where input is required, use the action in the right column.

| Page | Action |
| --- | --- |
| Start | Tab to **New profile setup**, press **Enter** |
| Connect to your VTA | Paste the **Personal VTA DID** from 1b, press **Enter** |

**Authorise the setup DID via PNM:**

OpenVTC mints an ephemeral admin `did:key` for this session and displays it on the **Authorise the setup DID via PNM** page along with a ready-to-copy `pnm contexts create` command. Press **F2** to copy the command.

Switch to your PNM session from T01 and run it:

```bash
pnm contexts create --id openvtc --name "OpenVTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h
```

Switch back to the OpenVTC TUI and press **Enter** to continue. The wizard then auto-bootstraps:

- The ephemeral `did:key` authenticates to the VTA.
- The VTA mints a long-term admin DID for OpenVTC and rotates the ephemeral key out.
- The wizard opens a REST or DIDComm session against the VTA, depending on what the VTA advertises in its DID document.

If the VTA advertises any WebVH hosting servers, the wizard offers to host your persona DID on one of them. Otherwise it skips ahead and prompts for a WebVH URL near the end of the wizard.

| Page | Action |
| --- | --- |
| Select WebVH server (if shown) | Pick a server, or **create manually** to host the persona DID yourself |
| Persona DID + keys | Review the generated **persona DID** (2a) and **24-word mnemonic** (2b) — **save both** |
| Export keys to PGP | Press **Enter** to skip unless you want PGP-formatted key export |
| Install did-git-sign | Press **Enter** to skip unless you want git commit signing through the VTA |
| Set unlock passphrase | Enter a passphrase (min 8 chars) and confirm — **save it as 2c** |
| Mediator DID | Press **Enter** to use the mediator advertised by your VTA |
| Display name | Enter a friendly name for this persona |
| WebVH publish URL (if shown) | Enter the HTTPS URL where you'll host this persona's `did.jsonl` (e.g. `https://webvh-host.com/openvtc-persona`) |
| Final | Press **Enter** to write the config |

> **⚠️ SAVE THESE**
>
> - **Persona DID** (2a): the `did:webvh:...` shown on the keys page.
> - **Mnemonic phrase** (2b): the 24-word phrase. Without it you cannot recover this profile.
> - **Unlock passphrase** (2c): required every time the TUI starts.

When the wizard finishes, the public config is written to `~/.config/openvtc/config.json`. Keys and the secured config blob are stored in your OS keyring (on a headless Linux server this falls back automatically to kernel keyutils — no `gnome-keyring-daemon` required).

### Step 3: Publish the persona DID

If the wizard hosted your persona DID on a VTA-advertised WebVH server, skip this step.

Otherwise, the wizard generated a DID log that you need to publish — follow the same instructions as **T01 Step 2** (HTTPS-only, exact path match, line-delimited JSON), using the URL you entered in the wizard.

Sanity-check from another machine:

```bash
curl -sSf https://webvh-host.com/openvtc-persona/did.jsonl | head -n 1
```

### Step 4: Launch the TUI

```bash
openvtc
```

The TUI prompts for your unlock passphrase (2c), then opens the main UI.

## Verification

From the main menu, open the **VTA Service** panel. It should show:

- **VTA URL** matching your Personal VTA from T01 (e.g. `https://vta-p.yourdomain.com`).
- **VTA DID** matching 1b.
- **Persona DID** matching 2a.
- **Mediator DID** matching the mediator your VTA advertises.
- **Total keys** of 5 (3 persona keys + 2 WebVH update keys).

From the Help/Status panel, hotkey **[1]** copies the persona DID and **[2]** copies the mediator DID — useful spot checks.

The activity log strip at the bottom of every panel shows a periodic mediator keepalive ping with live RTT. A non-zero RTT confirms DIDComm reachability.

## Known Issues / Edge Cases

- **PNM grant is 1 hour.** If you take longer than that between running `pnm contexts create` and pressing Enter on the wizard's ACL page, provisioning fails. Re-running the wizard mints a fresh setup DID — re-run `pnm contexts create` against the new one.
- **No `openvtc status` CLI.** The legacy CLI (`openvtc-cli`) was removed in v0.2.0. All operational views live in TUI panels — there is no headless `openvtc status` or `openvtc health` command.
- **TUI eats stdout.** For tracing output, set `OPENVTC_DEBUG_LOG=/tmp/openvtc.log` before launching: the TUI writes structured logs to that file while you use the UI.

## Deployment Notes

> _To be documented._
