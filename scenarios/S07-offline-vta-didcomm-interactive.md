# S07 · Offline VTA · DIDComm · Interactive

**Setup Type:** Offline VTA — VTA unreachable at setup time\
**Transport:** DIDComm\
**Mode:** Interactive\
**Tested on:** [Ubuntu Server](../deployments/D02-ubuntu-server.md)

## Prerequisites

Complete [D02 — Ubuntu Server](../deployments/D02-ubuntu-server.md) before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | Personal VTA mnemonic phrase | Recovery |
| 1b | Personal VTA mediator DID (from `mediator-did.jsonl`) | Later |
| 1c | Personal VTA DID | Step 2, Step 3 |
| 3a | SHA-256 digest (mediator bundle) | Step 3 |
| 3b | Mediator DID | Step 4 |
| 3c | Admin DID | Later |
| 4a | WebVH Admin DID | Step 4 |
| 4b | WebVH Admin private key | Step 4 |
| 4c | SHA-256 digest (WebVH bundle) | Step 4 |
| 4d | WebVH Daemon DID | Later |

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
| Services to enable (select at least one): | Press **Enter** (default: **REST API** and **DIDComm Messaging**) |
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

**DIDComm Messaging:**

| Prompt | Action |
| --- | --- |
| DIDComm messaging: | Choose **Create a new mediator DID (did:webvh)** |
| Trust context for the mediator DID [mediator]: | Press **Enter** (use default) |
| Mediator URL: | `https://mediator.yourdomain.com/mediator/v1` |
| mediator DID URL [http://localhost:8000/]: | `https://webvh.yourdomain.com/mediator` |
| Is this correct? [Y/n]: | Press **Enter** → **Y** |
| DID creation mode: | Press **Enter** (default: **Simple — VTA creates keys and document**) |
| Make this DID portable (can move to a different domain later)? [Y/n]: | Press **Enter** → **Y** |
| Number of pre-rotation keys [1]: | Press **Enter** (use default) |
| Save DID log to file [mediator-did.jsonl]: | Press **Enter** (use default) |

> **⚠️ SAVE THIS** (1b)
>
> Save the **created Mediator DID**
> (e.g. `Created DID: did:webvh:...:webvh.yourdomain.com:mediator`)
> to your notes.

**VTA DID:**

| Prompt | Action |
| --- | --- |
| VTA DID: | Choose **Create a new did:webvh DID** |
| VTA DID URL [http://localhost:8534/]: | `https://webvh.yourdomain.com/vta-p` |
| Is this correct? [Y/n]: | Press **Enter** → **Y** |
| DID creation mode: | Press **Enter** (default: **Simple — VTA creates keys and document**) |
| Make this DID portable (can move to a different domain later)? [Y/n]: | Press **Enter** → **Y** |
| Number of pre-rotation keys [1]: | Press **Enter** (use default) |
| Save DID log to file [VTA-did.jsonl]: | Press **Enter** (use default) |

> **⚠️ SAVE THIS** (1c)
>
> Save the **created DID**
> (e.g. `Created DID: did:webvh:...:webvh.yourdomain.com:vta-p`)
> to your notes.

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
| URL this mediator will serve at: | `https://mediator.yourdomain.com/mediator/v1` |
| Pin a webvh hosting server for this DID's log (optional). | Press **Enter** (skip) |

The wizard outputs:

```text
Ship this bootstrap request to your VTA admin out-of-band.

Hotkeys:  [c] copy JSON   [v] copy vta cmd   [p] copy pnm-cli cmd
```

Press **c** to copy the bootstrap request JSON and **v** to copy the `vta` command.

**→ VTA session** — open a new SSH session and save the JSON to the VTA directory:

```bash
cd ~/vta-p
vim bootstrap-request-vp.json
```

Paste the copied JSON, save, and run:

```bash
vta bootstrap provision-integration --request bootstrap-request-vp.json --context mediator --create-context --assertion pinned-only --out bundle.armor
```

The command outputs the bundle details:

```text
Integration provisioned — sealed bundle written to bundle.armor

  Bundle-Id:       <id>
  Client DID:      did:key:z6Mk...
  Admin DID:       did:key:z6Mk... (VTA-minted, rolled over from client)
  Admin template:  vta-admin
  Integration DID: did:webvh:...:mediator.yourdomain.com
  Template:        didcomm-mediator (mediator)
  Secrets:         2
  Outputs:         1
  SHA-256 digest:  <hex>
```

> **⚠️ SAVE THIS** (3a)
>
> Save the **SHA-256 digest** — you will paste it in the Mediator session for OOB verification.

Move the bundle to the mediator directory:

```bash
mv ~/vta-p/bundle.armor ~/mediator/
```

**→ Mediator session** — press **Enter** to continue. When prompted:

| Prompt | Action |
| --- | --- |
| Enter a path to bundle.armor, or paste its contents. | `/root/mediator/bundle.armor` |
| Type the SHA-256 digest your VTA admin showed you. Leave blank to skip the OOB check. | Paste the **SHA-256 digest** (3a) |

The wizard completes the VTA integration:

```text
Bundle opened successfully.
  Admin DID:    did:key:z6Mk... (VTA-minted)
  VTA DID:      did:webvh:...:webvh.yourdomain.com:vta-p
  Mediator DID: did:webvh:...:mediator.yourdomain.com
  Keys:         1 signing + 1 key-agreement
  did.jsonl:    included (will be written next to mediator.toml)
```

> **⚠️ SAVE THESE** (3b, 3c)
>
> - Save the **Mediator DID** (3b) (the `Mediator DID:` line)
> - Save the **Admin DID** (3c) (the `Admin DID:` line)

Press **Enter** to continue to Protocol.

**Protocol:**

| Prompt | Action |
| --- | --- |
| Toggle protocols with Enter: | Select **DIDComm v2 (recommended)** |

**SSL/TLS & JWT:**

| Prompt | Action |
| --- | --- |
| Configure transport security: | Choose **No SSL (use TLS-terminating proxy)** |
| Configure authentication tokens: | Choose **Generate a fresh JWT signing key (recommended)** |

**Database:**

| Prompt | Action |
| --- | --- |
| Choose between Redis (multi-mediator) and Fjall (embedded single-node): | Choose **Fjall** |
| Connection string for the mediator's Redis-compatible database: | Press **Enter** (default: `./data/mediator`) |

**Admin:**

| Prompt | Action |
| --- | --- |
| Configure the admin DID for mediator management: | Choose **Generate admin DID from VTA** |
| Where should the wizard write mediator.toml?: | Press **Enter** (default: `conf/mediator.toml`) |

The wizard shows a **Summary — Review Configuration** screen. Press **Enter** to write the configuration.

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
| Mediator DID (leave empty to skip): | Paste the **Mediator DID** (3b) |

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

> **⚠️ SAVE THESE** (4a, 4b)
>
> - Save the **Admin DID** (4a) (the `Generated admin did:key:` line)
> - Save the **Admin private key** (4b) (the `Private key:` line — shown only once)

In a new SSH session, move the bootstrap request to the VTA directory and create the WebVH context:

```bash
mv ~/webvh/bootstrap-request.json ~/vta-p/
cd ~/vta-p
vta contexts create --id webvh \
  --admin-did did:key:z6Mk... \
  --admin-expires 1h
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

> **⚠️ SAVE THIS** (4c)
>
> Save the **SHA-256 digest** — you will pass it to `--expect-digest` in the next command.

Move the bundle to the webvh directory and complete offline setup (phase 2):

```bash
mv ~/vta-p/bundle.armor ~/webvh/
cd ~/webvh
webvh-daemon setup-offline-complete \
  --bundle bundle.armor \
  --expect-digest <hex-digest>
```

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

> **⚠️ SAVE THIS** (4d)
>
> Save the **Daemon DID** (4d) (the `Daemon DID:` line, e.g. `did:webvh:...:webvh.yourdomain.com`)

Generate an enrollment token using the **Admin DID** from 4a:

```bash
cd ~/webvh
webvh-daemon invite \
  --did did:key:z6Mk... \
  --role admin
```

The command outputs an **Enrollment URL**, for example:

```text
https://webvh.yourdomain.com/enroll?token=...
```

Start all services:

```bash
cd ~/webvh
nohup webvh-daemon > log.txt 2>&1 &

cd ~/mediator
nohup mediator > log.txt 2>&1 &

cd ~/vta-p
nohup vta > log.txt 2>&1 &
```

Visit the Enrollment URL in a browser to log in to the WebVH admin panel.

## Verification

Visit the WebVH admin panel and confirm you can log in:

```text
https://webvh.yourdomain.com
```

## Known Issues / Edge Cases

> _To be documented._

## Deployment Notes

> _To be documented._
