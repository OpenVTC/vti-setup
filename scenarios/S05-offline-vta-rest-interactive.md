# S05 · Offline VTA · REST · Interactive

**Setup Type:** Offline VTA — VTA unreachable at setup time (air-gapped or bootstrapping order)\
**Transport:** REST\
**Mode:** Interactive
**Tested on:** [Ubuntu Server](../deployments/D02-ubuntu-server.md)

## Prerequisites

Complete [D02 — Ubuntu Server](../deployments/D02-ubuntu-server.md) before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | Personal VTA mnemonic phrase | Recovery |
| 1b | Personal VTA DID | Step 2, Step 3 |
| 3a | Mediator DID | Later |
| 3b | Admin DID | Later |
| 4a | WebVH Daemon DID | Later |
| 4b | WebVH Admin DID | Step 4 |

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

- Choose: **Create a new did:webvh DID**
- VTA DID URL [http://localhost:8534/]: `https://webvh.yourdomain.com/vta-p`
- Is this correct? [Y/n]: → **Y**
- DID creation mode: → **Simple — VTA creates keys and document (recommended)**
- Make this DID portable (can move to a different domain later)? [Y/n]: → **Y**
- Number of pre-rotation keys [1]: → **1**
- > **⚠️ SAVE THIS** (1b)
  > Save the **created DID**
  > (e.g. `Created DID: did:webvh:...:webvh.yourdomain.com:vta-p`)
  > to your notes.
- Save DID log to file [VTA-did.jsonl]: → Press **Enter** (saves to `VTA-did.jsonl`)

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
| VTA DID: | Paste the **Personal VTA DID** from 1b |

PNM will output a `vta import-did` command. Note it down — it contains a generated temp DID unique to this session:

```text
vta import-did --did did:key:z6Mk... --role admin
```

Run that command in the `~/vta-p` directory:

```bash
cd ~/vta-p
vta import-did --did did:key:z6Mk... --role admin
```

### Step 3: Set up Mediator

```bash
cd ~
mkdir mediator
cd mediator
mediator-setup
```

**Deployment Type:**

| Prompt | Action |
| --- | --- |
| What kind of deployment is this?: | Choose **Headless server** |

**Key Storage:**

| Prompt | Action |
| --- | --- |
| Where should cryptographic keys be stored?: | Choose **Local file (file://)** |
| Confirm dev-only warning: | Type `I understand` |
| Storage file path: | `conf/secrets.json` |
| Where should cryptographic keys be stored? (again): | Choose **No encryption (plaintext on disk)** |

**VTA Integration:**

| Prompt | Action |
| --- | --- |
| Decide whether the VTA should...: | Choose **Full setup — VTA mints my mediator DID** |
| Pick online or sealed handoff: | Choose **Sealed handoff (air-gapped)** |
| Which VTA context should the admin credential live in?: | `mediator` |
| URL this mediator will serve at: | `https://mediator.yourdomain.com` |
| Pin a webvh hosting server for this DID's log (optional). | `webvh-prod-1` |

The wizard outputs:

```text
Ship this bootstrap request to your VTA admin out-of-band.

Hotkeys:  [c] copy JSON   [v] copy vta cmd   [p] copy pnm-cli cmd
```

Press **c** to copy the bootstrap request JSON and **v** to copy the `vta` command.

Open a new SSH session and save the JSON to the VTA directory:

```bash
cd ~/vta-p
vim bootstrap-request-vp-mediator.json
```

Paste the copied JSON, save, and run:

```bash
vta bootstrap provision-integration \
  --request bootstrap-request-vp-mediator.json \
  --context mediator \
  --assertion pinned-only \
  --out bundle.armor \
  --create-context
```

> 🚧 Stuck here — command failed. Continued to **Step 4** first, then retried (see [Known Issues](#known-issues--edge-cases)).

### Step 4: Set up WebVH Daemon

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

The wizard completes phase 1 and prints the bootstrap request summary:

```text
  Request file:   bootstrap-request.json
  State file:     setup-offline-state.toml
  Bootstrap seed: stored in the configured secrets backend

  Consumer DID:   did:key:z6Mk...
  Nonce:          <nonce>

  Next steps:
    1. Ferry bootstrap-request.json to your VTA admin.
    2. Ask them to create the VTA context with this DID as admin
       (skip if the context already exists), via either:
         pnm contexts create --context webvh --admin <Consumer DID>
       or, on the VTA host directly:
         vta contexts create --id webvh \
           --admin-did <Consumer DID> --admin-expires 1h
    3. Ask them to seal the response:
         vta bootstrap provision-integration --request <request-file> \
           --out <bundle-file>
    4. They send back an ASCII-armored sealed bundle + SHA-256 digest.
    5. Run:
         webvh-daemon setup-offline-complete \
           --bundle <bundle> --expect-digest <hex> --state setup-offline-state.toml
```

In a new SSH session, create the WebVH context on VTA using the **Consumer DID**:

```bash
cd ~/vta-p
vta contexts create --id webvh \
  --admin-did did:key:z6Mk... \
  --admin-expires 1h
```

Copy the bootstrap request from the webvh directory to the VTA directory, seal the bundle, then copy it back:

```bash
cp ~/webvh/bootstrap-request.json ~/vta-p/bootstrap-request.json
cd ~/vta-p
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
  Template:        webvh-daemon (webvh-daemon)
  Secrets:         1
  Outputs:         1
  SHA-256 digest:  <hex>
```

> **⚠️ NOTE the `SHA-256 digest`** — you will need it in the next step.

Copy the bundle back to the webvh directory:

```bash
cp ~/vta-p/bundle.armor ~/webvh/bundle.armor
```

Complete the offline setup (phase 2) passing the `SHA-256 digest` from above:

```bash
cd ~/webvh
webvh-daemon setup-offline-complete \
  --bundle bundle.armor \
  --expect-digest <hex-digest> \
  --state setup-offline-state.toml
```

The wizard prints the completed setup:

```text
Sealed response opened.
  DID:     did:webvh:...:webvh.yourdomain.com
  VTA DID: did:webvh:...:webvh.yourdomain.com:vta-p
  VTA URL: https://vta-p.yourdomain.com

  Generated JWT signing key.
  Configuration written to config.toml
  Secrets stored in secret store.

  Importing daemon DID into store at path '.well-known'...
  Daemon DID imported!
  DID:  did:webvh:...:webvh.yourdomain.com
  server_did updated in config.toml
  Admin ACL entry added for did:key:z6Mk...

  Setup complete!

  Daemon DID: did:webvh:...:webvh.yourdomain.com
```

> **⚠️ SAVE THESE** (4a, 4b)
>
> - Save the **Daemon DID** (4a) (the `Daemon DID:` line, e.g. `did:webvh:...:webvh.yourdomain.com`)
> - Save the **Admin DID** (4b) (the `Admin ACL entry added for` line, e.g. `did:key:z6Mk...`)

Generate an enrollment token using the **Admin DID** from 4b:

```bash
webvh-daemon invite \
  --did did:key:z6Mk... \
  --role admin
```

The command outputs an **Enrollment URL**, for example:

```text
https://webvh.yourdomain.com/enroll?token=...
```

Start the daemon:

```bash
nohup webvh-daemon > log.txt 2>&1 &
```

Visit the Enrollment URL in a browser to log in to the WebVH admin panel.

## Verification

Visit the WebVH admin panel and confirm you can log in:

```text
https://webvh.yourdomain.com
```

## Known Issues / Edge Cases

### `vta bootstrap provision-integration` fails — missing webvh server endpoint

After completing webvh-daemon setup (Step 4) and retrying `vta bootstrap provision-integration`, the command prompts adding the webvh server to VTA first:

```bash
vta webvh add-server --id webvh-prod-1
```

Running that command returns:

```text
Error: server DID has no WebVHHostingService or DIDCommMessaging service endpoint
```

Resolution TBD.

### `webvh-daemon setup-offline-complete` fails with "bootstrap seed missing"

```text
Setup error: bootstrap seed missing from secret store — phase 1 may not have run
```

**Fix:** Open `~/webvh/config.toml`. The `plaintext_bootstrap_seed` is at the top level. Move it into the `[secrets]` section in `setup-offline-state.toml`:

```toml
[secrets]
plaintext_bootstrap_seed = "..."
```

## Deployment Notes

> _To be documented._
