# S08 · Offline VTA · DIDComm · Non-interactive

**Setup Type:** Offline VTA — VTA unreachable at setup time\
**Transport:** DIDComm\
**Mode:** Non-interactive\
**Tested on:** [Ubuntu Server](../deployments/D02-ubuntu-server.md)

**Verified with:**

| VTA Version | Mediator Version | Webvh-daemon Version |
| --- | --- | --- |
| 0.6.0 | 0.15.3 | 0.7.0 |
| 0.6.0 | 0.15.2 | 0.6.0 |

## Overview

This guide replaces all interactive TUI prompts from [S07 (Interactive)](./S07-offline-vta-didcomm-interactive.md) with TOML files and CLI flags. The offline sealed-bundle bootstrap flow is the same — only the input method changes.

| Component | Interactive command | Non-interactive equivalent |
| --- | --- | --- |
| Personal VTA | `vta setup` | `vta setup --from vta-setup.toml` |
| PNM connection | `pnm setup` (wizard) | `pnm setup --name <name>` → `pnm setup continue` |
| Mediator | `mediator-setup` (TUI) | `mediator-setup --from recipe.toml` (two phases) |
| WebVH Daemon | `webvh-daemon setup` (offline wizard) | `webvh-daemon setup-offline-prepare` → *(VTA admin)* → `webvh-daemon setup-offline-complete` |

## Prerequisites

Complete [D02 — Ubuntu Server](../deployments/D02-ubuntu-server.md) before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | Mediator DID | Step 3 |
| 1b | Personal VTA DID | Step 4 |
| 2a | SHA-256 digest (mediator bundle) | Step 2 |
| 2b | Mediator Admin DID | Later |
| 2c | Mediator Admin private key | Offline backup |
| 3a | WebVH Admin DID | Step 3 |
| 3b | WebVH Admin private key | Offline backup |
| 3c | SHA-256 digest (WebVH bundle) | Step 3 |
| 3d | WebVH Daemon DID | Later |
| 4a | PNM admin DID | Step 4 |

## Steps

### Step 1: Set up Personal VTA

Create the directory and open the setup file:

```bash
mkdir ~/vta-p
vim ~/vta-p/vta-setup.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

Paste the following content. Replace **all four** `yourdomain.com` occurrences (`public_url`, `messaging.url`, `messaging.webvh_url`, and `vta_did.url`) with your actual domain:

```toml
config_path = "config.toml"
data_dir    = "data/vta"
vta_name    = "personal-vta"
public_url  = "https://vta-p.yourdomain.com"

[services]
rest    = true
didcomm = true

[server]
host = "0.0.0.0"
port = 8101

[log]
level  = "info"
format = "text"

[secrets]
backend = "plaintext"

[messaging]
kind      = "create_mediator"
context   = "mediator"
url       = "https://mediator.yourdomain.com/mediator/v1"
webvh_url = "https://webvh.yourdomain.com/mediator"

[vta_did]
kind               = "create_webvh"
url                = "https://webvh.yourdomain.com/vta-p"
portable           = true
pre_rotation_count = 1
```

Run the setup:

```bash
cd ~/vta-p
vta setup --from vta-setup.toml
```

The command prints the created DIDs and writes DID log files under `data/vta/did-logs/`.

> **⚠️ SAVE THESE** (1a, 1b)
>
> From the summary printed at the end:
>
> - **1a — Mediator DID** — the `Mediator:` line (e.g. `did:webvh:...:webvh.yourdomain.com:mediator`)
> - **1b — Personal VTA DID** — the `VTA DID:` line (e.g. `did:webvh:...:webvh.yourdomain.com:vta-p`)

### Step 2: Set up Mediator

The VTA already holds the mediator DID (created in Step 1 via `messaging.kind = "create_mediator"`). Use `vta_mode = "sealed-export"` to retrieve the existing context material.

```bash
mkdir ~/mediator
cd ~/mediator
```

```bash
vim ~/mediator/mediator-recipe.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

```toml
[deployment]
type      = "server"
protocols = ["didcomm"]
use_vta   = true
vta_mode  = "sealed-export"

[vta]
context = "mediator"

[secrets]
storage = "file://conf/secrets.json"

[security]
ssl          = "none"
admin        = "generate"
jwt_mode     = "generate"
network_mode = "open"

[database]
url = "redis://127.0.0.1/"

[storage]
backend = "fjall"
data_dir = "./data/mediator"

[output]
config_path    = "conf/mediator.toml"
listen_address = "0.0.0.0:7037"
```

**Phase 1** — generate the bootstrap request:

```bash
cd ~/mediator
mediator-setup --from mediator-recipe.toml
```

This writes `./bootstrap-request.json` and prints the VTA-side command to run.

Switch to the VTA directory and run the reprovision command:

```bash
cd ~/vta-p
vta contexts reprovision \
  --id mediator \
  --recipient ~/mediator/bootstrap-request.json \
  --out ~/mediator/bundle.armor
```

The command outputs the bundle details:

```text
Minted fresh admin key 'm/26'/2'/1'/3'' in context 'mediator'
Created ACL entry for did:key:z6Mk... in context 'mediator'

╔══════════════════════════════════════════════════════════════╗
║  Context provision bundle (sealed — hand off armored output) ║
╚══════════════════════════════════════════════════════════════╝

  Context:   mediator (DIDComm Messaging Mediator)
  Admin DID: did:key:z6Mk...
  DID:       did:webvh:...:webvh.yourdomain.com:mediator
  Recipient: mediator setup — mediator

Armored bundle written to ~/mediator/bundle.armor

  Bundle-Id:       <id>
  Producer DID:    did:key:z6Mk...
  SHA-256 digest:  <hex>

Communicate the digest to the recipient out-of-band so they can run:
  pnm bootstrap open --bundle <file> --expect-digest <hex>
```

> **⚠️ SAVE THESE** (2a, 2b)
>
> - **2a — SHA-256 digest** — you will pass it as `--digest` in Phase 2.
> - **2b — Admin DID** (the `Admin DID:` line)

**Phase 2** — apply the bundle:

```bash
cd ~/mediator
mediator-setup --from mediator-recipe.toml \
  --bundle bundle.armor \
  --digest <SHA-256 digest (2a)>
```

```text
  VTA-exported mediator DID: did:webvh:...:webvh.yourdomain.com:mediator
  Using rotated admin DID from VTA session: did:key:z6Mk...
  Provisioning unified secret backend: file:///secrets.json
    ✔ mediator_jwt_secret
    ✔ mediator_operating_secrets (4 keys)
    ✔ mediator_admin_credential
    ✔ mediator/vta/last_known_bundle (4 keys)
  ✔ Saved DID log: conf/did.jsonl
  ✔ Configuration: conf/mediator.toml
  ✔ Lua functions: conf/atm-functions.lua
  ✔ Admin DID: did:key:z6Mk...

   UNSAFE  Admin private key printed below for operator bookkeeping.
  This key is already stored in the configured secret backend — copy it to an
  offline store now and clear your terminal scrollback if you care about confidentiality.
  Private key (multibase): z3u2...
  VTA DID: did:webvh:...:webvh.yourdomain.com:vta-p   Context: mediator
  ✔ Secrets: conf/secrets.json
  ✔ Setup artefacts removed — the mediator has everything it needs in the configured secret backend.

  ━━━ Summary ━━━

  Files created:
    /root/mediator/conf/mediator.toml  — mediator configuration
    conf/atm-functions.lua  — Redis Lua functions
    conf/mediator-build.toml  — build recipe (reproducible setup)
    conf/secrets.json  — private keys (keep secure!)
```

> **⚠️ SAVE THIS** (2c)
>
> Copy the **Admin private key** (the `Private key (multibase):` line, e.g. `z3u2…`) to an offline store and clear your terminal scrollback.

### Step 3: Set up WebVH Daemon

```bash
mkdir ~/webvh
cd ~/webvh
```

**Phase 1** — generate the bootstrap request:

```bash
webvh-daemon setup-offline-prepare
```

When prompted:

| Prompt | Action |
| --- | --- |
| Configuration file path [config.toml]: | Press **Enter** (use default) |
| Which services should the daemon run?: | Press **Enter** (default: control, server, witness) |
| Public URL: | `https://webvh.yourdomain.com` |
| VTA context ID [webvh]: | Press **Enter** (use default) |
| Mediator DID (leave empty to skip) []: | Paste the **Mediator DID** (1a) |
| Listen host [0.0.0.0]: | Press **Enter** (use default) |
| Listen port [8534]: | Press **Enter** (use default) |
| Log level [info]: | Press **Enter** (use default) |
| Log format [text]: | Press **Enter** (use default) |
| Data directory root [data/daemon]: | Press **Enter** (use default) |
| Continue with plaintext secrets storage? [y/N]: | **y** |
| Admin ACL entry: | Choose **Generate a new did:key identity for the operator** |

The command generates `bootstrap-request.json` and `setup-offline-state.toml`, and prints:

```text
  Generated admin did:key: did:key:z6Mk...
  Private key (save this now — will not be re-shown): z3u2...

  Offline setup step 1/2 complete.

  Request file:   bootstrap-request.json
  State file:     setup-offline-state.toml
  ...
```

> **⚠️ SAVE THESE** (3a, 3b)
>
> - Save the **Admin DID** (3a) (the `Generated admin did:key:` line)
> - Save the **Admin private key** (3b) (the `Private key:` line — shown only once)

**Phase 2 (VTA admin)** — create the WebVH context and seal the bundle:

```bash
cd ~/vta-p
vta contexts create --id webvh --admin-expires 1h --admin-did <Admin DID (3a)>
```

```bash
vta bootstrap provision-integration \
  --request ~/webvh/bootstrap-request.json \
  --out ~/webvh/bundle.armor
```

The command outputs the bundle details.

> **⚠️ SAVE THIS** (3c)
>
> Save the **SHA-256 digest** — you will pass it to `--expect-digest` in Phase 3.

**Phase 3** — complete offline setup (non-interactive):

```bash
cd ~/webvh
webvh-daemon setup-offline-complete \
  --bundle bundle.armor \
  --state setup-offline-state.toml \
  --expect-digest <SHA-256 digest (3c)>
```

The command prints the completed setup including the daemon DID.

> **⚠️ SAVE THIS** (3d)
>
> Save the **Daemon DID** (the `Daemon DID:` line, e.g. `did:webvh:...:webvh.yourdomain.com`)

Generate an enrollment token using the Admin DID from 3a:

```bash
cd ~/webvh
webvh-daemon invite --role admin --did <Admin DID (3a)>
```

Start the WebVH daemon:

```bash
nohup webvh-daemon > log.txt 2>&1 &
```

Visit the Enrollment URL printed by `webvh-daemon invite` in a browser, then save a passkey when prompted.

> The enrollment URL is **single-use**. If you missed it or the passkey prompt failed, see [Enrollment URL is single-use](#enrollment-url-is-single-use).

**Upload DID logs:**

Go to `https://webvh.yourdomain.com/dids`.

Click **+ New DID** (top right), enter `mediator`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta-p/data/vta/did-logs/mediator-did.jsonl
```

Click **+ New DID** again, enter `vta-p`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta-p/data/vta/did-logs/VTA-did.jsonl
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

### Step 4: Bind PNM

```bash
pnm setup --name "personal-vta"
```

```text
Pending VTA 'personal-vta' created.
  Admin DID: did:key:z6Mk...

Next: set `admin_did = "did:key:z6Mk..."` in the VTA setup.toml, boot the VTA,
      then run: pnm setup continue personal-vta --vta-did <did:...>
{"slug":"personal-vta","admin_did":"did:key:z6Mk...","state":"pending"}
```

> **⚠️ SAVE THIS** (4a)
>
> Copy the **Admin DID** (the `Admin DID:` line) — you will pass it to `vta import-did` below.
>
> **Note:** The `Next:` line suggests setting `admin_did` in the setup TOML — ignore this. We register the DID with `vta import-did` instead.

```bash
cd ~/vta-p
vta import-did --role admin --label pnm-bootstrap --did <Admin DID (4a)>
```

```text
DID imported: did:key:z6Mk...
Role: admin
Contexts: unrestricted
Label: pnm-bootstrap

--- Connection info (share with DID owner) ---
Community VTA DID: did:webvh:...:webvh.yourdomain.com:vta-p
Community VTA URL: https://vta-p.yourdomain.com
```

```bash
pnm setup continue personal-vta --vta-did <Personal VTA DID (1b)>
```

```text
Bound VTA DID for 'personal-vta': did:webvh:...:webvh.yourdomain.com:vta-p
Ask the VTA admin to grant admin access:
  vta import-did --did did:key:z6Mk... --role admin
{"slug":"personal-vta","admin_did":"did:key:z6Mk...","state":"complete"}
```

> **Note:** The output suggests running `vta import-did` — ignore this. The DID was already imported in the step above. `state: complete` confirms the binding is done.

With PNM bound, start the VTA:

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

> *To be documented.*
