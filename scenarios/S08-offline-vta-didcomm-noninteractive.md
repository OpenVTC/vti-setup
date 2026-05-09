# S08 · Offline VTA · DIDComm · Non-interactive

**Setup Type:** Offline VTA — VTA unreachable at setup time\
**Transport:** DIDComm\
**Mode:** Non-interactive\
**Tested on:** [Ubuntu Server](../deployments/D02-ubuntu-server.md)

**Verified with:**

| VTA Version | Mediator Version | Webvh-daemon Version |
| --- | --- | --- |
| 0.6.0 | 0.15.2 | 0.6.0 |

## Overview

This guide replaces all interactive TUI prompts from [S07 (Interactive)](./S07-offline-vta-didcomm-interactive.md) with TOML files and CLI flags. The offline sealed-bundle bootstrap flow is the same — only the input method changes.

| Component | Interactive command | Non-interactive equivalent |
| --- | --- | --- |
| Personal VTA | `vta setup` | `vta setup --from vta-setup.toml` |
| PNM connection | `pnm setup` (wizard) | `pnm setup --name <name>` → `pnm setup continue` |
| Mediator | `mediator-setup` (TUI) | `mediator-setup --from recipe.toml` (two phases) |
| WebVH Daemon | `webvh-daemon setup` (offline wizard) | `webvh-daemon setup-offline-prepare` → `webvh-daemon setup-offline-complete` |

## Prerequisites

Complete [D02 — Ubuntu Server](../deployments/D02-ubuntu-server.md) before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | PNM admin DID | Step 1 (vta-setup.toml) |
| 1b | Mediator DID | Step 3 |
| 1c | Personal VTA DID | Step 1 |
| 2a | SHA-256 digest (mediator bundle) | Step 2 |
| 2b | Admin DID (mediator context) | Later |
| 3a | WebVH Admin DID | Step 3 |
| 3b | WebVH Admin private key | Step 3 |
| 3c | SHA-256 digest (WebVH bundle) | Step 3 |
| 3d | WebVH Daemon DID | Later |

> **Note on mnemonic:** In non-interactive VTA setup the 24-word BIP-39 mnemonic is auto-generated and stored in the configured secrets backend — it is never displayed. After PNM connects in Step 1, back it up with:
>
> ```bash
> pnm backup export --output vta-backup.vtabak
> ```

## Steps

### Step 1: Set up Personal VTA

The non-interactive flow seeds the admin DID directly into the VTA setup file, so PNM must mint its ephemeral key **before** the VTA is created. This replaces the interactive `vta import-did` step.

```bash
pnm setup --name "personal-vta"
```

> **⚠️ SAVE THIS** (1a)
>
> Copy the **Admin DID** printed in the output (e.g. `did:key:z6Mk…`) — you will paste it into `vta-setup.toml` below.

Create the directory and open the setup file:

```bash
mkdir ~/vta-p
vim ~/vta-p/vta-setup.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

Paste the following content. Replace **all four** `yourdomain.com` occurrences (`public_url`, `messaging.url`, `messaging.webvh_url`, and `vta_did.url`) with your actual domain, and replace `<ADMIN_DID (1a)>` with the Admin DID saved above:

```toml
config_path = "config.toml"
data_dir    = "data/vta"
vta_name    = "personal-vta"
public_url  = "https://vta-p.yourdomain.com"
admin_did   = "<ADMIN_DID (1a)>"
admin_label = "pnm-bootstrap"

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

> **⚠️ SAVE THESE** (1b, 1c)
>
> From the summary printed at the end:
>
> - **1b — Mediator DID** — the `Mediator:` line (e.g. `did:webvh:...:webvh.yourdomain.com:mediator`)
> - **1c — Personal VTA DID** — the `VTA DID:` line (e.g. `did:webvh:...:webvh.yourdomain.com:vta-p`)

Complete the PNM binding by passing the VTA DID saved above:

```bash
pnm setup continue personal-vta --vta-did <Personal VTA DID (1c)>
```

> **Note:** The output suggests running `vta import-did` — you can ignore this. The `admin_did` field in `vta-setup.toml` already registered the PNM admin DID during non-interactive setup. `state: complete` confirms the binding is done.

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

**→ VTA session** — open a new SSH session and run:

```bash
cd ~/vta-p
vta contexts reprovision \
  --id mediator \
  --recipient ~/mediator/bootstrap-request.json \
  --out ~/mediator/bundle.armor
```

The command outputs the bundle details:

```text
╔══════════════════════════════════════════════════════════════╗
║  Context provision bundle (sealed — hand off armored output) ║
╚══════════════════════════════════════════════════════════════╝

  Context:   mediator (DIDComm Messaging Mediator)
  Admin DID: did:key:z6Mk...
  DID:       did:webvh:...:webvh.yourdomain.com:mediator
  Recipient: mediator/conf/mediator.toml

Armored bundle written to ~/mediator/bundle.armor

  Bundle-Id:       <id>
  Producer DID:    did:key:z6Mk...
  SHA-256 digest:  <hex>
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

Before starting the mediator, comment out `did_web_self_hosted` in `~/mediator/conf/mediator.toml`:

```bash
vim ~/mediator/conf/mediator.toml
```

```toml
#did_web_self_hosted = "file://./conf/did.jsonl"
```

### Step 3: Set up WebVH Daemon

```bash
mkdir ~/webvh
cd ~/webvh
```

```bash
vim ~/webvh/config.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

Paste the following content. Replace `yourdomain.com` and `<Mediator DID (1b)>` with actual values:

```toml
public_url   = "https://webvh.yourdomain.com"
mediator_did = "<Mediator DID (1b)>"

[identity]
mode = "vta"

[vta]
context_id = "webvh"

[server]
host = "0.0.0.0"
port = 8534

[log]
level  = "info"
format = "text"

[auth]
access_token_expiry  = 900
refresh_token_expiry = 86400

[secrets]
keyring_service = "webvh-daemon"

[store]
data_dir = "data/daemon/store"

[witness_store]
data_dir = "data/daemon/witness"

[enable]
server  = true
witness = true
watcher = false
control = true
```

**Phase 1** — generate the bootstrap request:

```bash
cd ~/webvh
webvh-daemon setup-offline-prepare --config config.toml
```

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

The command outputs the bundle details.

> **⚠️ SAVE THIS** (3c)
>
> Save the **SHA-256 digest** — you will pass it to `--expect-digest` in Phase 2.

Move the bundle to the webvh directory:

```bash
mv ~/vta-p/bundle.armor ~/webvh/
cd ~/webvh
```

**Phase 2** — complete offline setup:

```bash
webvh-daemon setup-offline-complete \
  --bundle bundle.armor \
  --expect-digest <SHA-256 digest (3c)>
```

The command prints the completed setup including the daemon DID.

> **⚠️ SAVE THIS** (3d)
>
> Save the **Daemon DID** (the `Daemon DID:` line, e.g. `did:webvh:...:webvh.yourdomain.com`)

Generate an enrollment token using the Admin DID from 4a:

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

> If the file is not at that path, run `find ~/vta-p -name "*mediator*did*.jsonl"` to locate it.

Click **+ New DID** again, enter `vta-p`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta-p/data/vta/did-logs/VTA-did.jsonl
```

> If the file is not at that path, run `find ~/vta-p -name "*VTA*did*.jsonl" -o -name "*vta*did*.jsonl"` to locate it.

Before starting the mediator, start Redis:

```bash
docker run --name=redis-local --publish=127.0.0.1:6379:6379 --hostname=redis \
  --restart=on-failure --detach redis:latest
```

Then start the mediator:

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

### DID log file locations

The non-interactive `vta setup --from` writes DID log files to `<data_dir>/did-logs/`. With `data_dir = "data/vta"` in the setup TOML, the files are at:

- `~/vta-p/data/vta/did-logs/mediator-did.jsonl`
- `~/vta-p/data/vta/did-logs/VTA-did.jsonl`

The exact filenames use the context label. If the names differ from the above, use `find ~/vta-p -name "*.jsonl"` to locate them.

## Deployment Notes

> _To be documented._
