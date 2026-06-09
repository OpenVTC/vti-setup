# Explore: VTI Walkthrough

Stand up the full VTI stack — VTA, Mediator, DID Hosting Daemon and VTC — by stepping through each tool's interactive wizard. Uses the offline sealed-bundle bootstrap flow over DIDComm.

> **⚠️ Explore stream — do not use for real keys.**
> The box runs everything as root in `/root/<svc>/` with no isolation between services. For a hardened production deployment with per-service users and systemd, see the [Deploy stream](../deploy/) instead.

**Tested on:** [Explore: Server Setup](server-setup.md)

**Verified with:**

| VTA Version | Mediator Version | DID Hosting Daemon Version |
| --- | --- | --- |
| 0.8.0 | 0.15.6 | 0.7.0 |

## Prerequisites

Complete the [Server setup](server-setup.md) first.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | VTA mnemonic phrase | Recovery |
| 1b | VTA DID | Steps 2, 3 & 5 |
| 1c | Mediator DID | Step 4 |
| 3a | SHA-256 digest (mediator bundle) | Step 3 |
| 3b | Admin DID | Later |
| 4a | DID Host Admin DID | Step 4 |
| 4b | DID Host Admin private key | Step 4 |
| 4c | SHA-256 digest (DID Host bundle) | Step 4 |
| 4d | DID Host Daemon DID | Later |
| 5a | VTC DID | |
| 5b | Admin DID | |

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
| Storage file path: [`conf/secrets.json`] | Press **Enter** (use default) |
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
| CORS policy: | Choose **Allow any origin** |

**Database:**

| Prompt | Action |
| --- | --- |
| Choose between Redis (multi-mediator) and Fjall (embedded single-node): | Choose **Redis** |
| Connection string for the mediator's Redis-compatible database. | Press **Enter** (default: `redis://127.0.0.1/`) |

**Admin Account:**

| Prompt | Action |
| --- | --- |
| Configure the admin DID for mediator management: | Choose **Generate a new admin did:key** |
| Where should the wizard write mediator.toml?: | Press **Enter** (default: `conf/mediator.toml`) |

The wizard shows a **Summary — Review Configuration** screen. Press **Enter** to write the configuration.

### Step 4: Set up DID Hosting Daemon

```bash
cd ~
mkdir dids
cd dids
did-hosting-daemon setup
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
| Public URL: | `https://dids.yourdomain.com` |
| DID path on the server [.well-known]: | Press **Enter** (use default) |
| Context ID [webvh]: | Press **Enter** (use default) |
| Mediator DID (leave empty to skip): | Paste the **Mediator DID** (1c) |

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

Move the bootstrap request to the VTA directory and create the WebVH context:

```bash
mv ~/dids/bootstrap-request.json ~/vta/
cd ~/vta
```

```bash
vta contexts create --id webvh --admin-expires 1h --admin-did <Admin DID (4a)>
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
> Save the **SHA-256 digest** — you will pass it to `--expect-digest` in the next command.

Move the bundle to the dids directory:

```bash
mv ~/vta/bundle.armor ~/dids/
cd ~/dids
```

Complete offline setup (phase 2):

```bash
cd ~/dids
did-hosting-daemon setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| How will the daemon obtain its identity?: | Choose **Offline — complete a pending sealed-bundle bootstrap (phase 2)** |
| ASCII-armored sealed bundle path: | `/root/dids/bundle.armor` |
| Expected SHA-256 digest (lowercase hex): | Paste the **SHA-256 digest** from 4c |
| Pending state file path (from phase 1): | Press **Enter** (default: `setup-offline-state.toml`) |

The wizard prints the completed setup:

```text
DID Hosting Daemon — Offline Setup (step 2/2)
========================================

  Sealed response opened.
  DID:          did:webvh:...:dids.yourdomain.com
  VTA DID:      did:webvh:...:dids.yourdomain.com:vta
  VTA URL:      https://vta.yourdomain.com

  Generated JWT signing key.
  Configuration written to config.toml
  Secrets stored in secret store.

  Importing daemon DID into store at path '.well-known'...
  Daemon DID imported!
  DID:  did:webvh:...:dids.yourdomain.com
  SCID: <scid>
  server_did updated in config.toml
  Admin ACL entry added for did:key:z6Mk...

  Setup complete!

  Daemon DID: did:webvh:...:dids.yourdomain.com

  Start the daemon:
    did-hosting-daemon --config config.toml
```

> **⚠️ SAVE THIS** (4d)
>
> Save the **Daemon DID** (4d) (the `Daemon DID:` line, e.g. `did:webvh:...:dids.yourdomain.com`)

Generate an enrollment token using the **Admin DID** from 4a:

```bash
cd ~/dids
```

```bash
did-hosting-daemon invite --role admin --did <Admin DID (4a)>
```

The command outputs an **Enrollment URL**, for example:

```text
https://dids.yourdomain.com/enroll?token=...
```

Start the DID hosting daemon:

```bash
cd ~/dids
nohup did-hosting-daemon > log.txt 2>&1 &
```

Visit the Enrollment URL in a browser, then save a passkey when prompted.

> The enrollment URL is **single-use**. If you missed it or the passkey prompt failed, see [Enrollment URL is single-use](#enrollment-url-is-single-use).

**Upload DID logs:**

Go to `https://dids.yourdomain.com/dids`.

Click **+ New DID** (top right), enter `mediator`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/mediator-did.jsonl
```

Click **+ New DID** again, enter `vta`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/VTA-did.jsonl
```

Start the mediator:

> If you configured a passphrase for the key storage backend, set it before starting:
>
> ```bash
> export MEDIATOR_FILE_BACKEND_PASSPHRASE='your-passphrase'
> ```

```bash
cd ~/mediator
nohup mediator > log.txt 2>&1 &
```

Wait one minute for the mediator to fully initialize, then start the VTA:

```bash
cd ~/vta
nohup vta > log.txt 2>&1 &
```

## Verification

Visit the DID Hosting Manager admin panel and confirm you can log in:

```text
https://dids.yourdomain.com
```

Run a health check from the PNM directory:

```bash
cd ~/vta
pnm health
```

### Step 5: Set up VTC

Create a directory for the VTC and run the setup wizard:

```bash
cd ~
mkdir vtc
cd ~/vtc
vta setup
```

When prompted, use the values below. Replace `yourdomain.com` with your actual domain.

| Prompt | Action |
| --- | --- |
| Config file path [config.toml]: | Press **Enter** (use default) |
| VTC base URL: | `https://vtc.yourdomain.com` |
| VTA DID: | Paste the **VTA DID** from 1b |
| Context name at the VTA for this community [default]: | Press **Enter** (use default) |
| DIDComm messaging [Use the VTA's mediator]: | Press **Enter** (use default) |

The wizard pauses and displays:

```text
── Operator action required ──

Authorize this ephemeral DID at the VTA before continuing:

  DID:      did:key:z6Mk...
  Context:  default

Run on a machine with PNM admin access to the VTA (did:webvh:QmTR...:dids.example.com:vta):

  pnm contexts create --id default --name "VTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h
```

In another terminal, run that command:

```bash
pnm contexts create --id default --name "VTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h
```

Then switch back to the terminal running the wizard:

| Prompt | Action |
| --- | --- |
| Has the ACL grant been created at the VTA? [y/N] | Press **y** |

**Seed storage backend:**

- Choose: **Config file (hex-encoded seed in config.toml)**

The wizard completes and displays:

```text
✅ VTC setup complete.

VTC DID:       did:webvh:QmR2...:vtc.example.com
Admin DID:     did:key:z6Mk...
Config:        config.toml
Data dir:      data

Admin key (save this — needed for CLI access):
{
  "did": "did:key:z6Mkm...",
  "signing_key": {
    "key_id": "did:key:z6Mk...",
    "public_key_multibase": "z6Mk...",
    "private_key_multibase": "z3u2..."
  },
  "ka_key": {
    "key_id": "did:key:z6Mkm...",
    "public_key_multibase": "z6LS...",
    "private_key_multibase": "z3we..."
  }
}

Install URL (one-shot, 15 min TTL):
  https://vtc.example.com/admin/install?token=eyJ0...

Claim code (required at claim time):
  NDKH...
```

> **⚠️ SAVE THESE** (5a, 5b)
>
> - Save the **VTC DID** (5a)
> - Save the **Admin DID** (5b)

Open the **Install URL** in a browser and paste the **Claim code** in the input box on the browser page.

You are then prompted to save a passkey, so go ahead and save it.

Ignore the **Claim Admin Passkey** screen for now. This is currently not used.

Navigate to `https://vtc.yourdomain.com/admin` and sign in with your new passkey.

You now have access to the VTC Admin Dashboard and can set up access for the community manager(s) of the VTC.

## Known Issues / Edge Cases

### Enrollment URL is single-use

The enrollment URL generated by `did-hosting-daemon invite` can only be used once. If you missed saving it, let it expire, or the browser visit failed, you need to regenerate it:

**1.** Stop the running daemon:

```bash
kill -9 $(pgrep -f did-hosting-daemon)
```

**2.** Regenerate the enrollment token:

```bash
cd ~/dids
did-hosting-daemon invite --role admin --did <Admin DID (4a)>
```

**3.** Restart the daemon:

```bash
nohup did-hosting-daemon > log.txt 2>&1 &
```

Then visit the new Enrollment URL in a browser and save a passkey when prompted.
