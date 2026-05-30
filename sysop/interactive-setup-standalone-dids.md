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
| 1b | VTA DID | Step 2, Step 3 |
| 1c | Mediator DID | Step 4 |
| 3a | SHA-256 digest (mediator bundle) | Step 3 |
| 3b | Admin DID | Later |
| 4a | DID Host Admin DID | Step 4 |
| 4b | DID Host Admin private key | Step 4 |
| 4c | SHA-256 digest (DID Host bundle) | Step 4 |
| 4d | DID Host Daemon DID | Later |

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

> _To be documented._

## Verification

> _To be documented._

## Known Issues / Edge Cases

> _To be documented._

## Deployment Notes

> _To be documented._
