# S05 · Offline VTA · REST · Interactive

**Setup Type:** Offline VTA — VTA unreachable at setup time (air-gapped or bootstrapping order)\
**Transport:** REST\
**Mode:** Interactive\
**Tested on:** [Ubuntu Server](../deployments/D02-ubuntu-server.md)

**Verified with:**

| VTA Version | Mediator Version | Webvh-daemon Version |
| --- | --- | --- |
| 0.6.0 | 0.15.2 | 0.6.0 |
| 0.5.1 | 0.15.1 | 0.6.0 |

## Prerequisites

Complete [D02 — Ubuntu Server](../deployments/D02-ubuntu-server.md) before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | Personal VTA mnemonic phrase | Recovery |
| 1b | Personal VTA DID | Step 2 |
| 3a | WebVH Admin DID | Step 3 |
| 3b | WebVH Admin private key | Step 3 |
| 3c | SHA-256 digest (WebVH bundle) | Step 3 |
| 3d | WebVH Daemon DID | Later |

## Steps

### Step 1: Set up Personal VTA

Create a directory for the personal VTA:

```bash
cd ~
mkdir vta-p
```

Run the setup wizard:

```bash
cd ~/vta-p
vta setup
```

When prompted, use the values below. Replace `yourdomain.com` with your actual domain.

| Prompt | Action |
| --- | --- |
| Config file path [config.toml]: | Press **Enter** (use default) |
| VTA name (leave empty to skip): | Enter your personal VTA name |
| Services to enable (select at least one): | Select **REST API** only |
| Server host: | Press **Enter** (default: `0.0.0.0`) |
| Server port: | **8101** (do not use default) |
| VTA REST URL [http://localhost:8101]: | `https://vta-p.yourdomain.com` |
| Log level: | Press **Enter** (default: `info`) |
| Log format: | Press **Enter** (default: `text`) |
| Remote DID resolver WebSocket URL (leave empty to resolve locally): | Press **Enter** (resolve locally) |
| Audit-log retention (days) [28]: | Press **Enter** (use default) |
| Data directory: | Press **Enter** (default: `data/vta`) |

**BIP-39 mnemonic:**

- Choose: **Generate new 24-word mnemonic**
- > **⚠️ SAVE THIS** (1a)
  > Save the **24-word mnemonic phrase** to your notes.
  > You cannot recover this VTA without it.
- I have saved my mnemonic phrase [y/N]: → **y**

**Seed storage backend:**

- Choose: **Config file (hex-encoded seed in config.toml)**

**VTA DID:**

| Prompt | Action |
| --- | --- |
| VTA DID: | Choose **Create a new did:webvh DID** |
| VTA DID URL [http://localhost:8000/]: | `https://webvh.yourdomain.com/vta-p` |
| Is this correct? [Y/n]: | Press **Enter** → **Y** |
| DID creation mode: | Press **Enter** (default: **Simple — VTA creates keys and document**) |
| Make this DID portable (can move to a different domain later)? [Y/n]: | Press **Enter** → **Y** |
| Number of pre-rotation keys [1]: | Press **Enter** (use default) |
| Save DID log to file [VTA-did.jsonl]: | Press **Enter** (use default) |

When all prompts are complete, the wizard prints:

```text
Setup complete!
  Config saved to: config.toml
  Seed stored in configured backend
  Seed backend: config file (hex-encoded in config.toml)
  VTA Name: <your VTA name>
  VTA REST URL: https://vta-p.yourdomain.com
  VTA DID: did:webvh:...:webvh.yourdomain.com:vta-p
  Services: REST
  Server: 0.0.0.0:8101
  Contexts: vta (m/26'/2'/0')
```

> **⚠️ SAVE THIS** (1b)
>
> From the summary above:
>
> - **Personal VTA DID** (1b): the `VTA DID:` line

### Step 2: Connect PNM to VTA

```bash
cd ~/vta-p
pnm setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| What would you like to do?: | Choose **Connect to an existing non-TEE VTA** |
| Name for this VTA: | Enter a name for this VTA |
| VTA DID: | Paste the **Personal VTA DID** from 1c |

PNM will output a `vta import-did` command. Note it down — it contains a generated temp DID unique to this session:

```text
vta import-did --did did:key:z6Mk... --role admin
```

Run that command in the `~/vta-p` directory:

```bash
cd ~/vta-p
vta import-did --did did:key:z6Mk... --role admin
```

### Step 3: Set up WebVH Daemon

```bash
cd ~
mkdir webvh
cd webvh
webvh-daemon setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| How will the daemon obtain its identity?: | Choose **Offline — start a new sealed-bundle bootstrap (phase 1)** |
| Bootstrap request file path [bootstrap-request.json]: | Press **Enter** (use default) |
| Pending state file path [setup-offline-state.toml]: | Press **Enter** (use default) |
| Configuration file path [config.toml]: | Press **Enter** (use default) |

**Services to enable:**

| Prompt | Action |
| --- | --- |
| Which services should the daemon run?: | Press **Enter** (default: control, server, witness) |

**Connection:**

| Prompt | Action |
| --- | --- |
| Public URL: | `https://webvh.yourdomain.com` |
| Context ID [webvh]: | Press **Enter** (use default) |
| Mediator DID (leave empty to skip): | Press **Enter** |

The wizard prompts for additional configuration:

| Prompt | Action |
| --- | --- |
| Listen host: | Press **Enter** (default: `0.0.0.0`) |
| Listen port: | Press **Enter** (default: `8534`) |
| Log level: | Press **Enter** (default: `info`) |
| Log format: | Press **Enter** (default: `text`) |
| Data directory root [data/daemon]: | Press **Enter** (use default) |
| Continue with plaintext secrets storage? [y/N]: | **y** |
| Admin ACL entry: | Choose **Generate a new did:key identity for the operator** |

The wizard completes phase 1 and prints:

```text
  Generated admin did:key: did:key:z6Mk...
  Private key (save this now — will not be re-shown): z3u2...

  Offline setup step 1/2 complete.

  Request file:   bootstrap-request.json
  State file:     setup-offline-state.toml
  Bootstrap seed: stored in the configured secrets backend

  Consumer DID:   did:key:z6Mk...
  Nonce:          <nonce>
```

> **⚠️ SAVE THESE** (3a, 3b)
>
> - Save the **Admin DID** (3a) (the `Generated admin did:key:` line)
> - Save the **Admin private key** (3b) (the `Private key:` line — shown only once)

Move the bootstrap request to the VTA directory and create the WebVH context:

```bash
mv ~/webvh/bootstrap-request.json ~/vta-p/
cd ~/vta-p
```

```bash
vta contexts create --id webvh --admin-expires 1h --admin-did <Admin DID (3a)>
```

Seal the bundle:

```bash
vta bootstrap provision-integration \
  --request bootstrap-request.json \
  --out bundle.armor
```

The command outputs the bundle details:

```text
Integration provisioned — sealed bundle written to bundle.armor

  Bundle-Id:       <id>
  Client DID:      did:key:z6Mk...
  Admin DID:       did:key:z6Mk... (== client)
  Integration DID: did:webvh:...:webvh.yourdomain.com
  Template:        webvh-control (webvh-control)
  Secrets:         1
  Outputs:         1
  SHA-256 digest:  <hex>
```

> **⚠️ SAVE THIS** (3c)
>
> Save the **SHA-256 digest** — you will pass it to `--expect-digest` in the next command.

Move the bundle to the webvh directory:

```bash
mv ~/vta-p/bundle.armor ~/webvh/
cd ~/webvh
```

Complete offline setup (phase 2):

```bash
cd ~/webvh
webvh-daemon setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| How will the daemon obtain its identity?: | Choose **Offline — complete a pending sealed-bundle bootstrap (phase 2)** |
| ASCII-armored sealed bundle path: | `/root/webvh/bundle.armor` |
| Expected SHA-256 digest (lowercase hex): | Paste the **SHA-256 digest** from 3c |
| Pending state file path (from phase 1): | Press **Enter** (default: `setup-offline-state.toml`) |

The wizard prints the completed setup:

```text
WebVH Daemon — Offline Setup (step 2/2)
========================================

  Sealed response opened.
  DID:          did:webvh:...:webvh.yourdomain.com
  VTA DID:      did:webvh:...:webvh.yourdomain.com:vta-p
  VTA URL:      https://vta-p.yourdomain.com

  Generated JWT signing key.
  Configuration written to config.toml
  Secrets stored in secret store.

  Importing daemon DID into store at path '.well-known'...
  Daemon DID imported!
  DID:  did:webvh:...:webvh.yourdomain.com
  SCID: <scid>
  server_did updated in config.toml
  Admin ACL entry added for did:key:z6Mk...

  Setup complete!

  Daemon DID: did:webvh:...:webvh.yourdomain.com
```

> **⚠️ SAVE THIS** (3d)
>
> Save the **Daemon DID** (3d) (the `Daemon DID:` line, e.g. `did:webvh:...:webvh.yourdomain.com`)

Generate an enrollment token using the **Admin DID** from 3a:

```bash
cd ~/webvh
```

```bash
webvh-daemon invite --role admin --did <Admin DID (3a)>
```

The command outputs an **Enrollment URL**, for example:

```text
https://webvh.yourdomain.com/enroll?token=...
```

Start the WebVH daemon:

```bash
cd ~/webvh
nohup webvh-daemon > log.txt 2>&1 &
```

Visit the Enrollment URL in a browser, then save a passkey when prompted.

> The enrollment URL is **single-use**. If you missed it or the passkey prompt failed, see [Enrollment URL is single-use](#enrollment-url-is-single-use).

**Upload DID logs:**

Go to `https://webvh.yourdomain.com/dids`.

Click **+ New DID** again, enter `vta-p`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta-p/VTA-did.jsonl
```

Start the VTA:

```bash
cd ~/vta-p
nohup vta > log.txt 2>&1 &
```

## Verification

Visit the WebVH admin panel and confirm you can log in:

```text
https://webvh.yourdomain.com
```

Run a health check from the PNM directory:

```bash
cd ~/vta-p
pnm health
```

## Known Issues / Edge Cases

### Enrollment URL is single-use

The enrollment URL generated by `webvh-daemon invite` can only be used once. If you missed saving it, let it expire, or the browser visit failed, you need to regenerate it:

**1.** Stop the running daemon:

```bash
kill -9 $(pgrep -f webvh-daemon)
```

**2.** Regenerate the enrollment token:

```bash
cd ~/webvh
webvh-daemon invite --role admin --did <Admin DID (3a)>
```

**3.** Restart the daemon:

```bash
nohup webvh-daemon > log.txt 2>&1 &
```

Then visit the new Enrollment URL in a browser and save a passkey when prompted.

## Deployment Notes

> _To be documented._
