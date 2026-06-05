# Deploy 03: Provisioning

Provision the VTI stack from TOML recipes. Every command runs as a per-service system user via `sudo -u <svc>-svc`. Recipes live at `/var/lib/<svc>-svc/<svc>-recipe.toml` and use absolute paths throughout. Cross-service file handoffs (`bootstrap-request.json`, `bundle.armor`) go through `/var/lib/vti-exchange/`.

This guide assumes the **standard** DID Hosting topology (single integrated daemon). For the standalone topology (control + server + witness + watcher split), do Steps 1, 2, 4, and 5 here, then do [04 — DID Hosting topology](04-did-hosting-topology.md) in place of Step 3.

**Verified with:**

| VTA Version | Mediator Version | DID Hosting Daemon Version |
| --- | --- | --- |
| 0.8.2 | 0.15.13 | 0.7.0 |

## Prerequisites

Complete [01 — Server bootstrap](01-server-bootstrap.md) and [02 — Server setup](02-server-setup.md) first.

The following values will be collected during setup. Save each one as prompted.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | VTA DID | Step 3, 4 |
| 1b | Mediator DID | Step 3 |
| 2a | SHA-256 digest (mediator bundle) | Step 2 |
| 2b | Mediator Admin DID | Later |
| 2c | Mediator Admin private key | Offline backup |
| 3a | SHA-256 digest (WebVH bundle) | Step 3 |
| 3b | WebVH Admin DID | Step 3 |
| 3c | WebVH Admin private key | Offline backup |
| 3d | DID Hosting Daemon DID | Later |
| 4a | PNM admin DID | Step 4 |

## Editing recipes

Recipes are stored under `/var/lib/<svc>-svc/` so the service user can read them. Owner `root`, group `<svc>-svc`, mode `0640` — the service user has read access, and `vti` edits them via `sudoedit` (which runs as root). `sudoedit` refuses to open a file that's writable by the invoking user, so the owner must be `root`, not `vti`.

To edit:

```bash
sudoedit /var/lib/<svc>-svc/<recipe>.toml
```

`sudoedit` opens your shell's `$EDITOR` on a temp copy, then atomically moves it back preserving ownership and perms. No need to `sudo vim` directly.

To create a new recipe file with the right ownership:

```bash
sudo install -m 0640 -o root -g <svc>-svc /dev/null /var/lib/<svc>-svc/<recipe>.toml
sudoedit /var/lib/<svc>-svc/<recipe>.toml
```

> NOTE: You can change the default `sudoedit` editor to vim with:  
> `sudo update-alternatives --set editor /usr/bin/vim.basic`

## Step 1: Set up VTA

Create and edit the VTA recipe:

```bash
sudo install -m 0640 -o root -g vta-svc /dev/null /var/lib/vta-svc/vta-setup.toml
sudoedit /var/lib/vta-svc/vta-setup.toml
```

Paste the following. Replace **all four** `yourdomain.com` occurrences with your actual domain:

```toml
config_path = "/var/lib/vta-svc/config.toml"
data_dir    = "/var/lib/vta-svc/data/vta"
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

Run the setup as the service user:

```bash
sudo -u vta-svc /usr/local/bin/vta setup --from /var/lib/vta-svc/vta-setup.toml
```

The command prints the created DIDs and writes DID log files under `/var/lib/vta-svc/data/vta/did-logs/`.

> **⚠️ SAVE THESE** (1a, 1b)
>
> - **1a — VTA DID** — the `VTA DID:` line (e.g. `did:webvh:...:dids.yourdomain.com:vta`)
> - **1b — Mediator DID** — the `Mediator:` line (e.g. `did:webvh:...:dids.yourdomain.com:mediator`)

## Step 2: Set up Mediator

The VTA already holds the mediator DID (created in Step 1 via `messaging.kind = "create_mediator"`). Use `vta_mode = "sealed-export"` to retrieve the existing context material.

Create and edit the mediator recipe:

```bash
sudo install -m 0640 -o root -g mediator-svc /dev/null /var/lib/mediator-svc/mediator-recipe.toml
sudoedit /var/lib/mediator-svc/mediator-recipe.toml
```

Paste:

```toml
[deployment]
type      = "server"
protocols = ["didcomm"]
use_vta   = true
vta_mode  = "sealed-export"

[vta]
context = "mediator"

[secrets]
storage = "file:///var/lib/mediator-svc/conf/secrets.json"

[security]
ssl          = "none"
admin        = "generate"
jwt_mode     = "generate"
network_mode = "open"

[database]
url = "redis://127.0.0.1/"

[storage]
backend  = "fjall"
data_dir = "/var/lib/mediator-svc/data/mediator"

[output]
config_path    = "/var/lib/mediator-svc/conf/mediator.toml"
listen_address = "0.0.0.0:7037"
```

> **Why `file:///` with three slashes:** the `file://` URL form parses per RFC 3986 as authority + path. `file://conf/secrets.json` is **authority=`conf`, path=`/secrets.json`** — silently writes to the filesystem root. Three slashes (`file:///<absolute path>`) means **empty authority, absolute path** — what you want. Always use the three-slash form.
>
> **Backend consistency across phases:** Phase 1 persists the ephemeral HPKE seed into the configured secret backend; Phase 2 reads it back to unseal the bundle. Both phases must point at the same `[secrets].storage` URL — switching backends mid-handoff strands the seed and Phase 2 fails to open the bundle.

**Phase 1** — generate the bootstrap request as mediator-svc. The wizard writes `bootstrap-request.json` to its working directory, so `cd` into `/var/lib/vti-exchange/` first (the shared handoff dir vta-svc reads via the `vti-exchange` group). `sudo --chdir` requires a `CWD=*` sudoers tag that the default `NOPASSWD:ALL` fragment doesn't grant, so wrap with `bash -c` instead. Set `umask 0027` so the dropped file is group-readable (mediator-svc's default umask is `0077`, which would leave the file mode `0600` and lock vta-svc out):

```bash
sudo -u mediator-svc bash -c 'umask 0027 && cd /var/lib/vti-exchange && /usr/local/bin/mediator-setup --from /var/lib/mediator-svc/mediator-recipe.toml'
```

This writes `/var/lib/vti-exchange/bootstrap-request.json`, persists the ephemeral seed into the configured secret backend, and prints the VTA-side command to run.

> **In-flight bootstrap check:** If Phase 1 fails partway through (or you re-run it), the seed remains in the backend index and a second Phase 1 refuses with *"A bootstrap is already in progress"*. Either finalise with Phase 2 (`--bundle …`) or wipe with `--force-reprovision`. Stale seeds auto-expire after 24h.

Run the VTA reprovision command as vta-svc:

```bash
sudo -u vta-svc /usr/local/bin/vta contexts reprovision \
  --config /var/lib/vta-svc/config.toml \
  --id mediator \
  --recipient /var/lib/vti-exchange/bootstrap-request.json \
  --out /var/lib/vti-exchange/mediator-bundle.armor
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

Armored bundle written to /var/lib/vti-exchange/mediator-bundle.armor

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

**Phase 2** — apply the bundle as mediator-svc:

```bash
sudo -u mediator-svc /usr/local/bin/mediator-setup --from /var/lib/mediator-svc/mediator-recipe.toml \
  --bundle /var/lib/vti-exchange/mediator-bundle.armor \
  --digest <SHA-256 digest (2a)>
```

```text
  VTA-exported mediator DID: did:webvh:...:dids.yourdomain.com:mediator
  Using rotated admin DID from VTA session: did:key:z6Mk...
  Provisioning unified secret backend: file:///var/lib/mediator-svc/conf/secrets.json
    ✔ mediator_jwt_secret
    ✔ mediator_operating_secrets (4 keys)
    ✔ mediator_admin_credential
    ✔ mediator/vta/last_known_bundle (4 keys)
  ✔ Saved DID log: /var/lib/mediator-svc/conf/did.jsonl
  ✔ Configuration: /var/lib/mediator-svc/conf/mediator.toml
  ✔ Lua functions: /var/lib/mediator-svc/conf/atm-functions.lua
  ✔ Admin DID: did:key:z6Mk...

   UNSAFE  Admin private key printed below for operator bookkeeping.
  This key is already stored in the configured secret backend — copy it to an
  offline store now and clear your terminal scrollback if you care about confidentiality.
  Private key (multibase): z3u2...
  VTA DID: did:webvh:...:dids.yourdomain.com:vta   Context: mediator
  ✔ Secrets: /var/lib/mediator-svc/conf/secrets.json
  ✔ Setup artefacts removed — the mediator has everything it needs in the configured secret backend.

  ━━━ Summary ━━━

  Files created:
    /var/lib/mediator-svc/conf/mediator.toml  — mediator configuration
    /var/lib/mediator-svc/conf/atm-functions.lua  — Redis Lua functions
    /var/lib/mediator-svc/conf/mediator-build.toml  — build recipe (reproducible setup)
    /var/lib/mediator-svc/conf/secrets.json  — private keys (keep secure!)
```

> **⚠️ SAVE THIS** (2c)
>
> Copy the **Admin private key** (the `Private key (multibase):` line, e.g. `z3u2…`) to an offline store and clear your terminal scrollback.

The mediator unit's `ExecStart` is `/usr/local/bin/mediator` — but the binary expects to find `mediator.toml` via its working directory. The systemd unit sets `WorkingDirectory=/var/lib/mediator-svc`, so this works as long as the config landed at `conf/mediator.toml` (it did, per the recipe's `[output] config_path`).

## Step 3: Set up DID Hosting Daemon (standard topology)

> **Standalone deployment:** For a split control + server + witness + watcher deployment, skip this step and follow [04 — DID Hosting topology](04-did-hosting-topology.md) instead.

Create and edit the daemon recipe:

```bash
sudo install -m 0640 -o root -g dids-svc /dev/null /var/lib/dids-svc/webvh-recipe.toml
sudoedit /var/lib/dids-svc/webvh-recipe.toml
```

Paste the following. Replace `yourdomain.com` with your actual domain, and replace `<Mediator DID (1b)>` with your actual mediator DID:

```toml
[deployment]
service  = "daemon"
vta_mode = "offline-prepare"

[output]
config_path = "/var/lib/dids-svc/config.toml"

[server]
host       = "0.0.0.0"
port       = 8534
log_level  = "info"
log_format = "text"
data_dir   = "/var/lib/dids-svc/data/daemon"

[identity]
public_url   = "https://dids.yourdomain.com"
mediator_did = "<Mediator DID (1b)>"

[vta]
request_path = "/var/lib/vti-exchange/dids-bootstrap-request.json"

[daemon]
enable_control = true
enable_server  = true
enable_witness = true
enable_watcher = false

[secrets]
backend           = "plaintext"
confirm_plaintext = true

[admin]
mode = "generate"

[reprovision]
force = false
```

**Phase 1** — generate the bootstrap request as dids-svc:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-daemon setup --from /var/lib/dids-svc/webvh-recipe.toml
```

The command writes `/var/lib/vti-exchange/dids-bootstrap-request.json`, stores the bootstrap seed in the configured secret backend, and prints:

```text
  [setup-recipe] service       = did-hosting-daemon
  [setup-recipe] vta_mode      = offline-prepare
  [setup-recipe] config_path   = /var/lib/dids-svc/config.toml
  [setup-recipe] public_url    = https://dids.yourdomain.com

  [setup-recipe:offline-prepare] phase 1 complete
  [setup-recipe:offline-prepare] request_path = /var/lib/vti-exchange/dids-bootstrap-request.json
  [setup-recipe:offline-prepare] client_did   = did:key:z6Mk...
  [setup-recipe:offline-prepare] nonce        = <nonce>
  [setup-recipe:offline-prepare] seed stored in configured secret backend
```

> The `client_did` line is printed for verification only — it is already embedded in `dids-bootstrap-request.json`. Nothing to save here.

**Phase 2 (VTA admin)** — seal the bundle as vta-svc:

```bash
sudo -u vta-svc /usr/local/bin/vta bootstrap provision-integration \
  --request /var/lib/vti-exchange/dids-bootstrap-request.json \
  --out /var/lib/vti-exchange/dids-bundle.armor \
  --create-context
```

The command outputs the bundle details.

> **⚠️ SAVE THIS** (3a)
>
> Save the **SHA-256 digest** — you will pass it as `expect_digest` in Phase 3.

**Phase 3** — complete offline setup:

Open the recipe and make two changes: set `vta_mode` to `"offline-complete"` and replace the `[vta]` section with `bundle_path` and `expect_digest`:

```bash
sudoedit /var/lib/dids-svc/webvh-recipe.toml
```

Update these two sections (leave the rest of the file unchanged):

```toml
[deployment]
service  = "daemon"
vta_mode = "offline-complete"

[vta]
bundle_path   = "/var/lib/vti-exchange/dids-bundle.armor"
expect_digest = "<SHA-256 digest (3a)>"
```

Then run the same command:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-daemon setup --from /var/lib/dids-svc/webvh-recipe.toml
```

The command writes `config.toml` and prints:

```text
  [setup-recipe] service       = did-hosting-daemon
  [setup-recipe] vta_mode      = offline-complete
  [setup-recipe] config_path   = /var/lib/dids-svc/config.toml
  [setup-recipe] public_url    = https://dids.yourdomain.com

  Existing config.toml backed up to config.toml.bak before re-provisioning.
  [setup-recipe] config written to /var/lib/dids-svc/config.toml
  [setup-recipe] secrets stored in Plaintext backend
  [setup-recipe] daemon DID imported at '.well-known' (scid=<scid>)
  Generated admin did:key: did:key:z6Mk...
  Private key (save now, not re-shown): z3u2...
  [setup-recipe] admin ACL entry added for did:key:z6Mk...

  [setup-recipe] setup complete
```

> **⚠️ SAVE THESE** (3b, 3c)
>
> - **3b — Admin DID** — the `Generated admin did:key:` line
> - **3c — Admin private key** — the `Private key (save now, not re-shown):` line — shown only once; clear your terminal scrollback after copying

Read the Daemon DID from the generated config:

```bash
sudo grep '^server_did' /var/lib/dids-svc/config.toml
```

> **⚠️ SAVE THIS** (3d)
>
> Save the **Daemon DID** (the `server_did` value, e.g. `did:webvh:...:dids.yourdomain.com`)

Generate an enrollment token using the Admin DID from 3b:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-daemon invite --role admin --did <Admin DID (3b)>
```

> Save the **Enrollment URL** printed — you will need it after starting the daemon.

Start the daemon under systemd:

```bash
sudo systemctl enable --now dids-svc
sudo systemctl status dids-svc
```

Tail the logs to confirm startup:

```bash
journalctl -u dids-svc -n 50 -f
```

Visit the Enrollment URL in a browser, then save a passkey when prompted.

> The enrollment URL is **single-use**. If you missed it or the passkey prompt failed, see [Enrollment URL is single-use](#enrollment-url-is-single-use).

**Upload DID logs:**

Go to `https://dids.yourdomain.com/dids`.

Click **+ New DID** (top right), enter `mediator`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
sudo cat /var/lib/vta-svc/data/vta/did-logs/mediator-did.jsonl
```

Click **+ New DID** again, enter `vta`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
sudo cat /var/lib/vta-svc/data/vta/did-logs/VTA-did.jsonl
```

**Start the mediator:**

> If you configured a passphrase for the key storage backend, set it as a systemd environment variable before starting. Create `/etc/systemd/system/mediator-svc.service.d/override.conf` via `sudo systemctl edit mediator-svc` with:
>
> ```ini
> [Service]
> Environment=MEDIATOR_FILE_BACKEND_PASSPHRASE=your-passphrase
> ```

```bash
sudo systemctl enable --now mediator-svc
sudo systemctl status mediator-svc
```

## Step 4: Bind PNM

PNM is a CLI tool that talks to the VTA's state, so it runs as `vta-svc`:

```bash
sudo -u vta-svc /usr/local/bin/pnm setup --name "personal-vta"
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
sudo -u vta-svc /usr/local/bin/vta import-did --role admin --label pnm-bootstrap --did <Admin DID (4a)>
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
sudo -u vta-svc /usr/local/bin/pnm setup continue personal-vta --vta-did <VTA DID (1a)>
```

```text
Bound VTA DID for 'personal-vta': did:webvh:...:dids.yourdomain.com:vta
Ask the VTA admin to grant admin access:
  vta import-did --did did:key:z6Mk... --role admin
{"slug":"personal-vta","admin_did":"did:key:z6Mk...","state":"complete"}
```

> **Note:** The output suggests running `vta import-did` — ignore this. The DID was already imported in the step above. `state: complete` confirms the binding is done.

**Start the VTA:**

```bash
sudo systemctl enable --now vta-svc
sudo systemctl status vta-svc
```

## Step 5: Confirm everything is running

```bash
sudo systemctl status mediator-svc vta-svc dids-svc
```

All three should be `active (running)`. Each process should be owned by its corresponding `-svc` user:

```bash
ps -o user= -p $(pgrep -f /usr/local/bin/mediator)             # → mediator-svc
ps -o user= -p $(pgrep -f /usr/local/bin/vta)                  # → vta-svc
ps -o user= -p $(pgrep -f /usr/local/bin/did-hosting-daemon)   # → dids-svc
```

## Verification

Visit the DID Hosting Daemon admin panel and confirm you can log in:

```text
https://dids.yourdomain.com
```

Run a health check as vta-svc:

```bash
sudo -u vta-svc /usr/local/bin/pnm health
```

## Known Issues / Edge Cases

### Enrollment URL is single-use

The enrollment URL generated by `did-hosting-daemon invite` can only be used once. If you missed saving it, let it expire, or the browser visit failed, regenerate it:

**1.** Stop the running daemon:

```bash
sudo systemctl stop dids-svc
```

**2.** Regenerate the enrollment token:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-daemon invite --role admin --did <Admin DID (3b)>
```

**3.** Restart the daemon:

```bash
sudo systemctl start dids-svc
```

Then visit the new Enrollment URL in a browser and save a passkey when prompted.

## Deployment notes

> _To be documented._
