# Interactive VTI Setup (Standalone DID Hosting)

Stand up the full VTI stack with the DID Hosting services running in standalone mode — VTA, Mediator, and DID Hosting Control, Server, Witness, and Watcher as separate services. Uses the offline sealed-bundle bootstrap flow over DIDComm.

If you're looking for the standard integrated DID Hosting Daemon setup, see [Interactive setup](interactive-setup.md).

**Tested on:** [Ubuntu Server (Standalone DID Hosting)](ubuntu-server-standalone-dids.md)

**Verified with:**

| VTA Version | Mediator Version | DID Hosting Version |
| --- | --- | --- |
| 0.7.0 | 0.15.5 | 0.7.0 |

## Prerequisites

Complete the [Ubuntu Server (Standalone DID Hosting)](ubuntu-server-standalone-dids.md) deployment before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | VTA mnemonic phrase | Recovery |
| 1b | VTA DID | Step 2 |
| 1c | Mediator DID | Step 4.1, Step 4.2 |
| 3a | SHA-256 digest (mediator bundle) | Step 3 |
| 3b | Admin DID | Later |
| 4a | Control Admin DID | Step 4.3 |
| 4b | Control Admin private key | Later |
| 4c | SHA-256 digest (Control bundle) | Step 4.1 |
| 4d | Control DID | Step 4.2 |
| 4e | SHA-256 digest (server bundle) | Step 4.2 |
| 4f | Server DID | Step 4.3 |

## Steps

### Step 1: Set up VTA

Create a directory for the VTA and run the setup wizard:

```bash
cd ~
mkdir vta
cd ~/vta
vta setup
```

When prompted, use the values below. Replace `yourdomain.com` with your actual domain.

| Prompt | Action |
| --- | --- |
| Config file path [config.toml]: | Press **Enter** (use default) |
| VTA name (leave empty to skip): | Enter a name for this VTA |
| Services to enable (select at least one): | Press **Enter** (default: **REST API** and **DIDComm Messaging**) |
| Server host: | Press **Enter** (default: `0.0.0.0`) |
| Server port: | Press **Enter** (default: `8100`) |
| VTA REST URL [http://localhost:8100]: | `https://vta.yourdomain.com` |
| Log level: | Press **Enter** (default: `info`) |
| Log format: | Press **Enter** (default: `text`) |
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

**DIDComm Messaging:**

| Prompt | Action |
| --- | --- |
| DIDComm messaging: | Choose **Create a new mediator DID (did:webvh)** |
| Trust context for the mediator DID [mediator]: | Press **Enter** (use default) |
| Mediator URL: | `https://mediator.yourdomain.com/mediator/v1` |
| Mediator hostname for vsock-bridged TEE deployments (leave empty to skip): | Press **Enter** (leave empty) |
| Upstream routing-key DIDs for this mediator (comma-separated, leave empty to skip): | Press **Enter** (leave empty) |
| mediator DID URL [http://localhost:8000/]: | `https://dids.yourdomain.com/mediator` |
| Is this correct? [Y/n]: | Press **Enter** → **Y** |
| DID creation mode: | Press **Enter** (default: **Simple — VTA creates keys and document**) |
| Make this DID portable (can move to a different domain later)? [Y/n]: | Press **Enter** → **Y** |
| Number of pre-rotation keys [1]: | Press **Enter** (use default) |
| Save DID log to file [mediator-did.jsonl]: | Press **Enter** (use default) |

**VTA DID:**

| Prompt | Action |
| --- | --- |
| VTA DID: | Choose **Create a new did:webvh DID** |
| VTA DID URL [http://localhost:8000/]: | `https://dids.yourdomain.com/vta` |
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
  VTA REST URL: https://vta.yourdomain.com
  VTA DID: did:webvh:...:dids.yourdomain.com:vta
  Services: REST, DIDComm
  Server: 0.0.0.0:8100
  Mediator DID: did:webvh:...:dids.yourdomain.com:mediator
  Mediator URL: https://mediator.yourdomain.com/mediator/v1
  Contexts: vta (m/26'/2'/0')
```

> **⚠️ SAVE THESE** (1b, 1c)
>
> From the summary above:
>
> - **VTA DID** (1b): the `VTA DID:` line
> - **Mediator DID** (1c): the `Mediator DID:` line

### Step 2: Connect PNM to VTA

```bash
cd ~/vta
pnm setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| What would you like to do?: | Choose **Connect to an existing non-TEE VTA** |
| Name for this VTA: | Enter a name for this VTA |
| VTA DID: | Paste the **VTA DID** from 1b |

PNM will output a `vta import-did` command. Note it down — it contains a generated temp DID unique to this session:

```text
vta import-did --did did:key:z6Mk... --role admin
```

Run that command in the `~/vta` directory:

```bash
cd ~/vta
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
| Decide whether the VTA should...: | Choose **Pick up pre-provisioned mediator (offline export)** |
| Which VTA context should the admin credential live in?: | `mediator` |

The wizard outputs:

```text
Ship this bootstrap request to your VTA admin out-of-band.

Hotkeys:  [c] copy JSON   [v] copy vta cmd   [p] copy pnm-cli cmd
```

**Open a new terminal window** to the server.

**→ VTA session** — mediator-setup automatically generates the JSON; move it to the VTA directory:

```bash
mv ~/mediator/bootstrap-request.json ~/vta
```

Run:

```bash
cd ~/vta
vta contexts reprovision --id mediator --recipient bootstrap-request.json --out bundle.armor
```

The command outputs the bundle details:

```text
╔══════════════════════════════════════════════════════════════╗
║  Context provision bundle (sealed — hand off armored output) ║
╚══════════════════════════════════════════════════════════════╝

  Context:   mediator (DIDComm Messaging Mediator)
  Admin DID: did:key:z6Mk...
  DID:       did:webvh:...:dids.yourdomain.com:mediator
  Recipient: mediator/conf/mediator.toml

Armored bundle written to bundle.armor

  Bundle-Id:       <id>
  Producer DID:    did:key:z6Mk...
  SHA-256 digest:  <hex>
```

> **⚠️ SAVE THIS** (3a)
>
> Save the **SHA-256 digest** — you will paste it in the Mediator session for OOB verification.

Move the bundle to the mediator directory:

```bash
mv ~/vta/bundle.armor ~/mediator/
```

**Switch back** to the in process Mediator Setup window.

**→ Mediator session** — press **Enter** to continue. When prompted:

| Prompt | Action |
| --- | --- |
| Enter a path to bundle.armor, or paste its contents. | `/root/mediator/bundle.armor` |
| Type the SHA-256 digest your VTA admin showed you. Leave blank to skip the OOB check. | Paste the **SHA-256 digest** (3a) |

The wizard completes the VTA integration and displays:

```text
Bundle opened successfully — sealed handoff complete.

  Mediator DID  [m]
    did:webvh:...:dids.yourdomain.com:mediator

  Admin DID  [a]
    did:key:z6Mk...

  VTA DID  [v]
    did:webvh:...:dids.yourdomain.com:vta

  ── Bundle contents ─────────────────────────────────────────
  Keys:          3 signing + 1 key-agreement
  DID document:  included (matches exported DID)
  did.jsonl:     included (will be written next to mediator.toml)

  Hotkeys:  [m] copy mediator DID   [a] copy admin DID   [v] copy VTA DID

  Press Enter — the wizard will skip the Did step (already provisioned) and continue
  to Protocol. Private key bytes are written to your secret backend at the end of
  the flow without passing through the TUI.
```

> **⚠️ SAVE THIS** (3b)
>
> Press **[a]** to copy the **Admin DID** (3b) and save it to your notes.

Press **Enter** to continue to Protocol.

**Protocol:**

| Prompt | Action |
| --- | --- |
| Toggle protocols with Enter: | Select **DIDComm v2 (recommended)** |

**Security:**

| Prompt | Action |
| --- | --- |
| Configure transport security: | Choose **No SSL (use TLS-terminating proxy)** |
| Configure authentication tokens: | Choose **Generate a fresh JWT signing key (recommended)** |
| Network access posture: | Press **Enter** (default: **Open network**) |
| Cross-origin requests: | Press **Enter** (default: **Deny all cross-origin**) |

**Database:**

| Prompt | Action |
| --- | --- |
| Choose between Redis (multi-mediator) and Fjall (embedded single-node): | Choose **Fjall** |
| Use an absolute path on a persistent volume in production | Press **Enter** (default: `./data/mediator`) |
| Fjall directory `./data/mediator` does not exist. Create it now?: | Choose **Yes — create the directory now** |

**Admin Account:**

| Prompt | Action |
| --- | --- |
| Configure the admin DID for mediator management: | Choose **Generate a new admin did:key** |
| Where should the wizard write mediator.toml?: | Press **Enter** (default: `conf/mediator.toml`) |

The wizard shows a **Summary — Review Configuration** screen. Press **Enter** to write the configuration.

### Step 4: Set up DID Hosting (Standalone Mode)

#### Step 4.1: Set up DID Hosting Control

```bash
cd ~
mkdir control
cd ~/control
did-hosting-control setup
```

**Offline bootstrap (phase 1):**

| Prompt | Action |
| --- | --- |
| How will the control plane reach its VTA?: | Choose **Offline — start a new sealed-bundle bootstrap (phase 1)** |
| Bootstrap request file path [bootstrap-request.json]: | Press **Enter** (use default) |
| Pending state file path [setup-offline-state.toml]: | Press **Enter** (use default) |
| Config file output path [config.toml]: | Press **Enter** (use default) |
| DID hosting URL (e.g. https://did.example.com): | `https://dids.yourdomain.com` |
| DID path on the server: | `services/control` |
| VTA context ID: | `control` |
| Mediator DID (leave empty to skip): | Paste the **Mediator DID** (1c) |
| DID log output file (written in step 2) [control-did.jsonl]: | Press **Enter** (use default) |
| Public URL: | `https://control.yourdomain.com` |
| Listen host: | Press **Enter** (default: `0.0.0.0`) |
| Listen port: | Press **Enter** (default: `8532`) |
| Log level: | Press **Enter** (default: `info`) |
| Log format: | Press **Enter** (default: `text`) |
| Data directory [data/did-hosting-control]: | Press **Enter** (use default) |
| Continue with plaintext secrets storage?: | **yes** |
| Admin ACL entry: | Choose **Generate a new did:key identity for the operator** |

The wizard prints:

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

Move the bootstrap request to the VTA directory and create the control context:

```bash
mv ~/control/bootstrap-request.json ~/vta/
cd ~/vta
```

```bash
vta contexts create --id control --admin-did <Consumer DID> --admin-expires 1h
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
  Integration DID: did:webvh:...:dids.yourdomain.com
  Template:        did-hosting-control (did-hosting-control)
  Secrets:         1
  Outputs:         1
  SHA-256 digest:  <hex>
```

> **⚠️ SAVE THIS** (4c)
>
> Save the **SHA-256 digest** — you will pass it to `--expect-digest` in the next step.

Move the bundle to the control directory:

```bash
mv ~/vta/bundle.armor ~/control/
```

Complete offline setup (phase 2):

```bash
cd ~/control
did-hosting-control setup
```

| Prompt | Action |
| --- | --- |
| How will the control plane reach its VTA?: | Choose **Offline — complete a pending sealed-bundle bootstrap (phase 2)** |
| ASCII-armored sealed bundle path: | `/root/control/bundle.armor` |
| Expected SHA-256 digest (lowercase hex): | Paste the **SHA-256 digest** (4c) |
| Pending state file path (from phase 1) [setup-offline-state.toml]: | Press **Enter** (use default) |

The wizard prints the completed setup:

```text
  Sealed response opened.
  DID:          did:webvh:...:dids.yourdomain.com
  VTA DID:      did:webvh:...:dids.yourdomain.com:vta
  VTA URL:      https://vta.yourdomain.com

  DID log entry written to control-did.jsonl
  Generated JWT signing key.
  Configuration written to config.toml
  Secrets stored.
  Admin ACL entry added for did:key:z6Mk...

  Setup complete!

  Control DID: did:webvh:...:dids.yourdomain.com

  Next steps:
    1. Set up did-hosting-server (if not already done)
    2. Import this DID on the server:
       did-hosting-server bootstrap-did --path services/control --did-log control-did.jsonl
    3. Start the control plane:
       did-hosting-control --config config.toml
```

> **⚠️ SAVE THIS** (4d)
>
> Save the **Control DID** (4d) (the `Control DID:` line)

#### Step 4.2: Set up DID Hosting Server

```bash
cd ~
mkdir server
cd ~/server
did-hosting-server setup
```

**Offline bootstrap (phase 1):**

| Prompt | Action |
| --- | --- |
| How will the server reach its VTA?: | Choose **Offline — start a new sealed-bundle bootstrap (phase 1)** |
| Bootstrap request file path [bootstrap-request.json]: | Press **Enter** (use default) |
| Pending state file path [setup-offline-state.toml]: | Press **Enter** (use default) |
| Configuration file path [config.toml]: | Press **Enter** (use default) |
| Server URL (e.g. https://server1.example.com): | `https://dids.yourdomain.com` |
| VTA context ID: | `server` |
| Mediator DID (leave empty to skip) []: | Paste the **Mediator DID** (1c) |
| Control plane DID (leave empty to set later) []: | Paste the **Control DID** (4d) |
| Listen host: | Press **Enter** (default: `0.0.0.0`) |
| Listen port: | Press **Enter** (default: `8530`) |
| Log level: | Press **Enter** (default: `info`) |
| Log format: | Press **Enter** (default: `text`) |
| Data directory [data/did-hosting-server]: | Press **Enter** (use default) |
| Continue with plaintext secrets storage?: | **yes** |

The wizard prints:

```text
  Offline setup step 1/2 complete.

  Request file:   bootstrap-request.json
  State file:     setup-offline-state.toml
  Bootstrap seed: stored in the configured secrets backend

  Consumer DID:   did:key:z6Mk...
  Nonce:          <nonce>
```

Move the bootstrap request to the VTA directory and create the server context:

```bash
mv ~/server/bootstrap-request.json ~/vta/
cd ~/vta
```

```bash
vta contexts create --id server --admin-did <Consumer DID> --admin-expires 1h
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
  Integration DID: did:webvh:...:dids.yourdomain.com
  Template:        did-hosting-daemon (did-hosting-daemon)
  Secrets:         1
  Outputs:         1
  SHA-256 digest:  <hex>
```

> **⚠️ SAVE THIS** (4e)
>
> Save the **SHA-256 digest** — you will pass it to `--expect-digest` in the next step.

Move the bundle to the server directory:

```bash
mv ~/vta/bundle.armor ~/server/
```

Complete offline setup (phase 2):

```bash
cd ~/server
did-hosting-server setup
```

> **Note:** Run this command from `~/server`. Running it from any other directory will cause a "No such file or directory" error because the wizard looks for `setup-offline-state.toml` in the current directory.

| Prompt | Action |
| --- | --- |
| How will the server reach its VTA?: | Choose **Offline — complete a pending sealed-bundle bootstrap (phase 2)** |
| ASCII-armored sealed bundle path: | `/root/server/bundle.armor` |
| Expected SHA-256 digest (lowercase hex): | Paste the **SHA-256 digest** (4e) |
| Pending state file path (from phase 1) [setup-offline-state.toml]: | Press **Enter** (use default) |

The wizard prints the completed setup:

```text
  Sealed response opened.
  DID:          did:webvh:...:dids.yourdomain.com
  VTA DID:      did:webvh:...:dids.yourdomain.com:vta
  VTA URL:      https://vta.yourdomain.com

  Generated JWT signing key.
  Configuration written to config.toml
  Secrets stored in secret store.

  Importing server DID into store at path '.well-known'...
  Server DID imported!
  DID:  did:webvh:...:dids.yourdomain.com
  SCID: <scid>
  server_did updated in config.toml

  Setup complete!

  Server DID: did:webvh:...:dids.yourdomain.com

  Next steps:
    1. Add this server's DID to the control plane ACL:
       did-hosting-control add-acl --did did:webvh:...:dids.yourdomain.com --role service
    2. Start the server:
       did-hosting-server --config config.toml
```

> **⚠️ SAVE THIS** (4f)
>
> Save the **Server DID** (4f) (the `Server DID:` line)

#### Step 4.3: Wire Control and Server Together

Import the control DID log into the server store:

```bash
mv ~/control/control-did.jsonl ~/server/
cd ~/server
did-hosting-server bootstrap-did --path services/control --did-log control-did.jsonl
```

Add the server DID to the control plane ACL:

```bash
cd ~/control
did-hosting-control add-acl --did <Server DID (4f)> --role service
```

Create an enrollment invite for the admin DID so it can authenticate to the control plane over DIDComm:

```bash
did-hosting-control invite --role admin --did <Admin DID (4a)>
```

The command outputs an enrollment URL:

```text
  Enrollment invite created!

  DID:     did:key:z6Mk...
  Role:    admin
  Expires: in 24h (epoch ...)

  Enrollment URL:
  https://control.yourdomain.com/enroll?token=...
```

#### Step 4.4: Load VTA and Mediator DIDs

Import the DID logs generated during VTA setup so the hosting server can resolve them:

```bash
cd ~/server
did-hosting-server load-did --path mediator --did-log ~/vta/mediator-did.jsonl
did-hosting-server load-did --path vta --did-log ~/vta/VTA-did.jsonl
```

#### Step 4.5: Start DID Hosting Services

```bash
cd ~/control
nohup did-hosting-control > log.txt 2>&1 &
```

```bash
cd ~/server
nohup did-hosting-server > log.txt 2>&1 &
```

#### Step 4.6: Register Admin Passkey

Visit the **Enrollment URL** from Step 4.3 in a browser (`https://control.yourdomain.com/enroll?token=...`), then save a passkey when prompted.

## Verification

> _To be documented._

## Known Issues / Edge Cases

> _To be documented._

## Deployment Notes

> _To be documented._
