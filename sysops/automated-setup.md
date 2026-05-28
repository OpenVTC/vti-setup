# Automated VTI Setup

Stand up the full VTI stack — VTA, Mediator, and DID Hosting Daemon — driven from TOML recipes and CLI flags instead of interactive wizards. Same offline sealed-bundle flow as [Interactive setup](interactive-setup.md); only the input method changes.

**Tested on:** [Ubuntu Server](ubuntu-server.md)

**Verified with:**

| VTA Version | Mediator Version | DID Hosting Daemon Version |
| --- | --- | --- |
| 0.7.0 | 0.15.5 | 0.7.0 |
| 0.6.0 | 0.15.4 | 0.7.0 |
| 0.6.0 | 0.15.3 | 0.7.0 |

## Overview

This guide replaces the interactive TUI prompts of [Interactive setup](interactive-setup.md) with TOML recipes and CLI flags. The offline sealed-bundle bootstrap flow itself is unchanged — read [Interactive setup](interactive-setup.md) first if you want to see what each step is doing under the hood.

| Component | Interactive command | Automated equivalent |
| --- | --- | --- |
| VTA | `vta setup` | `vta setup --from vta-setup.toml` |
| PNM connection | `pnm setup` (wizard) | `pnm setup --name <name>` → `pnm setup continue` |
| Mediator | `mediator-setup` (TUI) | `mediator-setup --from recipe.toml` (two phases) |
| DID Hosting Daemon | `did-hosting-daemon setup` (offline wizard) | `did-hosting-daemon setup --from recipe.toml` → *(VTA admin)* → `did-hosting-daemon setup --from recipe.toml` |

## Prerequisites

Complete the [Ubuntu Server](ubuntu-server.md) deployment before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | VTA DID | Step 4 |
| 1b | Mediator DID | Step 3 |
| 2a | SHA-256 digest (mediator bundle) | Step 2 |
| 2b | Mediator Admin DID | Later |
| 2c | Mediator Admin private key | Offline backup |
| 3a | SHA-256 digest (WebVH bundle) | Step 3 |
| 3b | WebVH Admin DID | Step 3 |
| 3c | WebVH Admin private key | Offline backup |
| 3d | DID Hosting Daemon DID | Later |
| 4a | PNM admin DID | Step 4 |

## Steps

### Step 1: Set up VTA

Create the directory and open the setup file:

```bash
mkdir ~/vta
vim ~/vta/vta-setup.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

Paste the following content. Replace **all four** `yourdomain.com` occurrences (`public_url`, `messaging.url`, `messaging.webvh_url`, and `vta_did.url`) with your actual domain:

```toml
config_path = "config.toml"
data_dir    = "data/vta"
vta_name    = "personal-vta"
public_url  = "https://vta.yourdomain.com"

[services]
rest    = true
didcomm = true

[server]
host = "0.0.0.0"
port = 8100

[log]
level  = "info"
format = "text"

[secrets]
backend = "plaintext"

[messaging]
kind      = "create_mediator"
context   = "mediator"
url       = "https://mediator.yourdomain.com/mediator/v1"
webvh_url = "https://dids.yourdomain.com/mediator"

[vta_did]
kind               = "create_webvh"
url                = "https://dids.yourdomain.com/vta"
portable           = true
pre_rotation_count = 1
```

Run the setup:

```bash
cd ~/vta
vta setup --from vta-setup.toml
```

The command prints the created DIDs and writes DID log files under `data/vta/did-logs/`.

> **⚠️ SAVE THESE** (1a, 1b)
>
> From the summary printed at the end:
>
> - **1a — VTA DID** — the `VTA DID:` line (e.g. `did:webvh:...:dids.yourdomain.com:vta`)
> - **1b — Mediator DID** — the `Mediator:` line (e.g. `did:webvh:...:dids.yourdomain.com:mediator`)

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
cd ~/vta
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
  DID:       did:webvh:...:dids.yourdomain.com:mediator
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
  VTA-exported mediator DID: did:webvh:...:dids.yourdomain.com:mediator
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
  VTA DID: did:webvh:...:dids.yourdomain.com:vta   Context: mediator
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

### Step 3: Set up DID Hosting Daemon

```bash
mkdir ~/dids
cd ~/dids
```

Create the setup recipe:

```bash
vim ~/dids/webvh-recipe.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

Paste the following content. Replace `yourdomain.com` with your actual domain, and replace `<Mediator DID (1b)>` with your actual mediator DID:

```toml
[deployment]
service  = "daemon"
vta_mode = "offline-prepare"

[output]
config_path = "config.toml"

[server]
host       = "0.0.0.0"
port       = 8534
log_level  = "info"
log_format = "text"
data_dir   = "data/daemon"

[identity]
public_url   = "https://dids.yourdomain.com"
mediator_did = "<Mediator DID (1b)>"

[vta]
request_path = "bootstrap-request.json"

[daemon]
enable_control  = true
enable_server   = true
enable_witness  = true
enable_watcher  = false

[secrets]
backend = "plaintext"
confirm_plaintext = true

[admin]
mode = "generate"

[reprovision]
force = false
```

**Phase 1** — generate the bootstrap request:

```bash
cd ~/dids
did-hosting-daemon setup --from webvh-recipe.toml
```

The command generates `bootstrap-request.json`, stores the bootstrap seed in the configured secret backend, and prints:

```text
  [setup-recipe] service       = did-hosting-daemon
  [setup-recipe] vta_mode      = offline-prepare
  [setup-recipe] config_path   = config.toml
  [setup-recipe] public_url    = https://dids.yourdomain.com

  [setup-recipe:offline-prepare] phase 1 complete
  [setup-recipe:offline-prepare] request_path = bootstrap-request.json
  [setup-recipe:offline-prepare] client_did   = did:key:z6Mk...
  [setup-recipe:offline-prepare] nonce        = <nonce>
  [setup-recipe:offline-prepare] seed stored in configured secret backend

  Next steps:
    1. Ferry bootstrap-request.json to your VTA admin.
    2. Ask them to seal the response and communicate the SHA-256 digest OOB.
    3. Edit your recipe (config.toml): set vta_mode = "offline-complete",
       [vta].bundle_path, [vta].expect_digest.
    4. Re-run phase 2: did-hosting-daemon setup --from <recipe>
```

> The `client_did` line is printed for verification only — it is already embedded in `bootstrap-request.json`. Nothing to save here.

**Phase 2 (VTA admin)** — seal the bundle:

```bash
cd ~/vta
vta bootstrap provision-integration \
  --request ~/dids/bootstrap-request.json \
  --out ~/dids/bundle.armor \
  --create-context
```

The command outputs the bundle details.

> **⚠️ SAVE THIS** (3a)
>
> Save the **SHA-256 digest** — you will pass it as `expect_digest` in Phase 3.

**Phase 3** — complete offline setup:

Open the recipe and make two changes: set `vta_mode` to `"offline-complete"` and replace the `[vta]` section with `bundle_path` and `expect_digest`:

```bash
vim ~/dids/webvh-recipe.toml
```

Update these two sections (leave the rest of the file unchanged):

```toml
[deployment]
service  = "daemon"
vta_mode = "offline-complete"

[vta]
bundle_path   = "bundle.armor"
expect_digest = "<SHA-256 digest (3a)>"
```

Then run the same command:

```bash
cd ~/dids
did-hosting-daemon setup --from webvh-recipe.toml
```

The command writes `config.toml` and prints:

```text
  [setup-recipe] service       = did-hosting-daemon
  [setup-recipe] vta_mode      = offline-complete
  [setup-recipe] config_path   = config.toml
  [setup-recipe] public_url    = https://dids.yourdomain.com

  Existing config.toml backed up to config.toml.bak before re-provisioning.
  [setup-recipe] config written to config.toml
  [setup-recipe] secrets stored in Plaintext backend
  [setup-recipe] daemon DID imported at '.well-known' (scid=<scid>)
  Generated admin did:key: did:key:z6Mk...
  Private key (save now, not re-shown): z3u2...
  [setup-recipe] admin ACL entry added for did:key:z6Mk...

  [setup-recipe] setup complete

  Next: did-hosting-daemon --config config.toml
```

> **⚠️ SAVE THESE** (3b, 3c)
>
> - **3b — Admin DID** — the `Generated admin did:key:` line
> - **3c — Admin private key** — the `Private key (save now, not re-shown):` line — shown only once; clear your terminal scrollback after copying

Read the Daemon DID from the generated config:

```bash
grep '^server_did' ~/dids/config.toml
```

> **⚠️ SAVE THIS** (3d)
>
> Save the **Daemon DID** (the `server_did` value, e.g. `did:webvh:...:dids.yourdomain.com`)

Generate an enrollment token using the Admin DID from 3a:

```bash
cd ~/dids
did-hosting-daemon invite --role admin --did <Admin DID (3b)>
```

Start the WebVH daemon:

```bash
nohup did-hosting-daemon > log.txt 2>&1 &
```

Visit the Enrollment URL printed by `did-hosting-daemon invite` in a browser, then save a passkey when prompted.

> The enrollment URL is **single-use**. If you missed it or the passkey prompt failed, see [Enrollment URL is single-use](#enrollment-url-is-single-use).

**Upload DID logs:**

Go to `https://dids.yourdomain.com/dids`.

Click **+ New DID** (top right), enter `mediator`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/data/vta/did-logs/mediator-did.jsonl
```

Click **+ New DID** again, enter `vta`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/data/vta/did-logs/VTA-did.jsonl
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
cd ~/vta
vta import-did --role admin --label pnm-bootstrap --did <Admin DID (4a)>
```

```text
DID imported: did:key:z6Mk...
Role: admin
Contexts: unrestricted
Label: pnm-bootstrap

--- Connection info (share with DID owner) ---
Community VTA DID: did:webvh:...:dids.yourdomain.com:vta
Community VTA URL: https://vta.yourdomain.com
```

```bash
pnm setup continue personal-vta --vta-did <VTA DID (1a)>
```

```text
Bound VTA DID for 'personal-vta': did:webvh:...:dids.yourdomain.com:vta
Ask the VTA admin to grant admin access:
  vta import-did --did did:key:z6Mk... --role admin
{"slug":"personal-vta","admin_did":"did:key:z6Mk...","state":"complete"}
```

> **Note:** The output suggests running `vta import-did` — ignore this. The DID was already imported in the step above. `state: complete` confirms the binding is done.

With PNM bound, start the VTA:

```bash
cd ~/vta
nohup vta > log.txt 2>&1 &
```

## Verification

Visit the DID Hosting Daemon admin panel and confirm you can log in:

```text
https://dids.yourdomain.com
```

Run a health check from the PNM directory:

```bash
cd ~/vta
pnm health
```

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
did-hosting-daemon invite --role admin --did <Admin DID (3b)>
```

**3.** Restart the daemon:

```bash
nohup did-hosting-daemon > log.txt 2>&1 &
```

Then visit the new Enrollment URL in a browser and save a passkey when prompted.

## Deployment Notes

> *To be documented.*
