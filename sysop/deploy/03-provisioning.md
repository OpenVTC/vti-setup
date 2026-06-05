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
| 6a | VTC DID | Later |
| 6b | VTC Admin DID | Step 6, install-URL regen |
| 6c | VTC Install URL + Claim code | Step 6 (15-min TTL) |

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
storage = "file:///var/lib/mediator-svc/conf/mediator-secrets.json"

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
> **Why the filename is `mediator-secrets.json`, not `secrets.json`:** the wizard has a stale code path (`generators/secrets.rs::write_secrets_file`, invoked from `config_writer.rs` whenever `[secrets].storage` is a `file://` URL) that always writes a legacy `affinidi_secrets_resolver`-format array to `<config_dir>/secrets.json` — clobbering the unified-backend file if it has the same name. Using a different filename keeps the unified backend (envelope format, what the mediator binary actually reads) intact. The legacy `secrets.json` is still produced as dead-weight; ignore it (and don't grant it group read).
>
> **Backend consistency across phases:** Phase 1 persists the ephemeral HPKE seed into the configured secret backend; Phase 2 reads it back to unseal the bundle. Both phases must point at the same `[secrets].storage` URL — switching backends mid-handoff strands the seed and Phase 2 fails to open the bundle.

**Phase 1** — generate the bootstrap request as mediator-svc. The wizard writes `bootstrap-request.json` to its working directory, so `cd` into `/var/lib/vti-exchange/` first (the shared handoff dir vta-svc reads via the `vti-exchange` group). `sudo --chdir` requires a `CWD=*` sudoers tag that the default `NOPASSWD:ALL` fragment doesn't grant, so wrap with `bash -c` instead. The wizard writes the request file with hardcoded mode `0o600` (via an internal `write_sensitive` helper that ignores umask), so we have to `chmod 0640` after the fact for vta-svc to read it:

```bash
sudo -u mediator-svc bash -c 'cd /var/lib/vti-exchange && /usr/local/bin/mediator-setup --from /var/lib/mediator-svc/mediator-recipe.toml'
sudo chmod 0640 /var/lib/vti-exchange/bootstrap-request.json
```

This writes `/var/lib/vti-exchange/bootstrap-request.json`, persists the ephemeral seed into the configured secret backend, and prints the VTA-side command to run. The follow-up `chmod` opens group-read access so vta-svc (also in `vti-exchange`) can read the handoff file.

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
  --config /var/lib/vta-svc/config.toml \
  --request /var/lib/vti-exchange/dids-bootstrap-request.json \
  --out /var/lib/vti-exchange/dids-bundle.armor \
  --create-context
```

The command outputs the bundle details.

> **⚠️ SAVE THIS** (3a)
>
> Save the **SHA-256 digest** — you will pass it as `expect_digest` in Phase 3.

**Phase 3** — complete offline setup:

Open the recipe and replace its contents with the Phase 3 version below. Only two things change from Phase 1: `vta_mode = "offline-complete"`, and the `[vta]` section now carries `bundle_path` + `expect_digest` instead of `request_path`. The full recipe is shown so there's no risk of editing the wrong section.

```bash
sudoedit /var/lib/dids-svc/webvh-recipe.toml
```

Replace `yourdomain.com` with your actual domain, `<Mediator DID (1b)>` with your saved Mediator DID, and `<SHA-256 digest (3a)>` with the digest the VTA printed in Phase 2:

```toml
[deployment]
service  = "daemon"
vta_mode = "offline-complete"

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
bundle_path   = "/var/lib/vti-exchange/dids-bundle.armor"
expect_digest = "<SHA-256 digest (3a)>"

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
sudo -u dids-svc /usr/local/bin/did-hosting-daemon invite --config /var/lib/dids-svc/config.toml --role admin --did <Admin DID (3b)>
```

> Save the **Enrollment URL** printed — you will need it after starting the daemon.

Start the daemon under systemd:

```bash
sudo systemctl enable --now dids-svc
sudo systemctl status dids-svc
```

Tail the logs to confirm startup:

```bash
sudo journalctl -u dids-svc -n 50 -f
```

> **Why `sudo`:** `journalctl -u <unit>` silently filters out entries from other users (per-service users like `dids-svc`) unless you're in the `systemd-journal` (or `adm`) group. `bootstrap-user.sh` adds `vti` to `systemd-journal` at user-creation time so this works without `sudo` on fresh installs, but operators bootstrapped before that change need `sudo usermod -aG systemd-journal vti` and an SSH reconnect to pick it up. Prefixing with `sudo` here works in either case.

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
sudo -u vta-svc /usr/local/bin/vta import-did --config /var/lib/vta-svc/config.toml --role admin --label pnm-bootstrap --did <Admin DID (4a)>
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

Visit the DID Hosting Daemon admin panel and confirm you can log in:

```text
https://dids.yourdomain.com
```

Run the per-service health/status checks. Each binary looks for `config.toml` in CWD; `vta` and `did-hosting-daemon` accept `--config <path>`, but `pnm` doesn't — wrap it with `sh -c 'cd ... && ...'` instead:

```bash
sudo -u vta-svc /usr/local/bin/vta status --config /var/lib/vta-svc/config.toml
sudo -u vta-svc sh -c 'cd /var/lib/vta-svc && /usr/local/bin/pnm health'
sudo -u dids-svc /usr/local/bin/did-hosting-daemon health --config /var/lib/dids-svc/config.toml
```

## Step 6: Set up VTC (optional)

Sets up a single Verifiable Trust Community on this VTI. **Optional** — needed only if you're hosting at least one VTC. In a separated-roles deployment the community manager runs this; in a single-operator deployment the sysop does.

**Prerequisites:**

- Steps 1–4 complete and Step 5 green (`mediator-svc`, `vta-svc`, `dids-svc` all `active (running)`).
- PNM bound to the VTA (Step 4) — the wizard pauses for a PNM-driven ACL grant mid-flow.
- Two SSH sessions open to the box (one for the wizard, one for the ACL grant).

**Why no recipe:** `vtc-service` ships only an interactive `vtc setup` wizard — there's no `--from <recipe>` driver like `mediator-setup`, `vta setup`, or `did-hosting-daemon setup` have. The hardened version is the wizard wrapped in `sudo -u vtc-svc` with `--config` pointed at the right path; the ACL-grant pause makes the wizard inherently operator-gated anyway, so the loss-of-declarativeness is small.

### Phase 1: Start the wizard

In your first SSH session, launch the wizard as `vtc-svc`:

```bash
sudo -u vtc-svc /usr/local/bin/vtc --config /var/lib/vtc-svc/config.toml setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| Config file path [/var/lib/vtc-svc/config.toml] | Press **Enter** (use `default`) |
| VTC base URL: | `https://vtc.yourdomain.com` |
| VTA DID: | Paste the **VTA DID** from 1a |
| Context name at the VTA for this community [default]: | Press **Enter** (use `default`) |
| DIDComm messaging: | Press **Enter** (use the VTA's mediator) |

The wizard mints an ephemeral DID and pauses with the ACL-grant instructions:

```text
── Operator action required ──

Authorize this ephemeral DID at the VTA before continuing:

  DID:      did:key:z6Mk...
  Context:  default

Run on a machine with PNM admin access to the VTA:

  pnm contexts create --id default --name "VTC" \
  --admin-did did:key:z6Mk... --admin-expires 1h
```

Copy the ephemeral `did:key:…` value — you'll need it in Phase 2.

> **Leave this terminal at the wizard prompt.** It's waiting on the ACL grant; do not press `y` yet.

### Phase 2: Grant ACL access at the VTA

Open a **second SSH session** to the box. Run the `pnm contexts create` command from the wizard's instructions — but as `vta-svc`, wrapped in `sh -c 'cd ... && …'` because `pnm` doesn't accept `--config`:

```bash
sudo -u vta-svc sh -c 'cd /var/lib/vta-svc && /usr/local/bin/pnm contexts create --id default --name "VTC" --admin-did <ephemeral did:key from Phase 1> --admin-expires 1h'
```

When that returns successfully, the ACL is in place. Return to the first SSH session.

### Phase 3: Finish the wizard

Back at the wizard prompt:

| Prompt | Action |
| --- | --- |
| Has the ACL grant been created at the VTA? [y/N]: | Press **y** |

The wizard now authenticates the ephemeral key against the VTA and prompts for the VTC's WebVH hosting target:

| Prompt | Action |
| --- | --- |
| DID hosting server: | Choose **Serverless** — the VTC self-hosts its `did.jsonl` at `https://vtc.yourdomain.com/.well-known/did.jsonl`, served by `vtc-svc` itself. (Picking your `dids-svc` server instead is also valid; it puts the VTC DID under `https://dids.yourdomain.com/<path>` and adds a dependency on `dids-svc`.) |
| Seed storage backend: | Choose **Config file (hex-encoded seed in config.toml)** |

The wizard performs the VTA round-trip, writes config + secrets, and prints a summary:

```text
✅ VTC setup complete.

VTC DID:       did:webvh:...:vtc.yourdomain.com
Admin DID:     did:key:z6Mk...
Config:        /var/lib/vtc-svc/config.toml
Data dir:      /var/lib/vtc-svc/data

Admin key (save this — needed for CLI access):
{
  "did": "did:key:z6Mk...",
  ...
}

Install URL (one-shot, 15 min TTL):
  https://vtc.yourdomain.com/admin/install?token=...

Claim code (required at claim time):
  ...
```

> **⚠️ SAVE THESE** (6a, 6b, 6c)
>
> - **6a — VTC DID** — the `VTC DID:` line
> - **6b — VTC Admin DID** — the `Admin DID:` line. Needed if you ever have to regenerate the install URL (see [VTC install URL expired or used](#vtc-install-url-expired-or-used)).
> - **6c — Install URL + Claim code** — single-use, **15-minute TTL**. You must complete Phase 5 within that window or regenerate.

### Phase 4: Start vtc-svc

```bash
sudo systemctl enable --now vtc-svc
sudo systemctl status vtc-svc
```

The unit's `WorkingDirectory=/var/lib/vtc-svc/` lets the binary find `config.toml` in CWD. Tail logs to confirm startup:

```bash
sudo journalctl -u vtc-svc -n 50 -f
```

### Phase 5: Claim the admin passkey

Open the **Install URL** (6c) in a browser, paste the **Claim code** in the input box, and save a passkey when prompted.

> The browser shows a **Claim Admin Passkey** screen immediately after — ignore it. It's not used in the current release.

Navigate to `https://vtc.yourdomain.com/admin` and sign in with the passkey you just enrolled. You're in.

## Known Issues / Edge Cases

### Enrollment URL is single-use

The enrollment URL generated by `did-hosting-daemon invite` can only be used once. If you missed saving it, let it expire, or the browser visit failed, regenerate it:

**1.** Stop the running daemon:

```bash
sudo systemctl stop dids-svc
```

**2.** Regenerate the enrollment token:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-daemon invite --config /var/lib/dids-svc/config.toml --role admin --did <Admin DID (3b)>
```

**3.** Restart the daemon:

```bash
sudo systemctl start dids-svc
```

Then visit the new Enrollment URL in a browser and save a passkey when prompted.

### VTC install URL expired or used

The install URL printed at the end of Step 6 Phase 3 is single-use with a 15-minute TTL. If you missed it, let it expire, or the browser claim failed, regenerate via `vtc admin invite`. The daemon must be **stopped** first — `vtc admin invite` opens the Fjall store directly and would conflict with a running daemon.

**1.** Stop the daemon:

```bash
sudo systemctl stop vtc-svc
```

**2.** Regenerate the install URL using the VTC Admin DID from 6b:

```bash
sudo -u vtc-svc /usr/local/bin/vtc --config /var/lib/vtc-svc/config.toml admin invite --did <VTC Admin DID (6b)>
```

The command grants the supplied DID an admin ACL entry if one doesn't exist (idempotent), mints a fresh single-use install URL, and prints both the URL and the new Claim code.

**3.** Restart the daemon:

```bash
sudo systemctl start vtc-svc
```

Then visit the new Install URL in a browser and complete the passkey claim.

## Tips

### Helpful `.bash_aliases`

Save a lot of typing with these aliases:

```bash
# Check running status of services
alias st='sudo systemctl status mediator-svc vta-svc dids-svc vtc-svc'
# Check health/status of each service. Each binary defaults to looking
# for config.toml in CWD; pass --config explicitly so the alias works
# from anywhere.
alias dh='sudo -u dids-svc /usr/local/bin/did-hosting-daemon health --config /var/lib/dids-svc/config.toml'
alias vas='sudo -u vta-svc /usr/local/bin/vta status --config /var/lib/vta-svc/config.toml'
alias vcs="sudo -u vtc-svc sh -c 'cd /var/lib/vtc-svc && /usr/local/bin/vtc status'"
alias ph="sudo -u vta-svc sh -c 'cd /var/lib/vta-svc && /usr/local/bin/pnm health'"
# Shortcuts for running commands
alias p='sudo -u vta-svc /usr/local/bin/pnm'
alias va='sudo -u vta-svc /usr/local/bin/vta'
alias vc='sudo -u vta-svc /usr/local/bin/vtc'
alias m='sudo -u mediator-svc /usr/local/bin/mediator'
alias d='sudo -u dids-svc /usr/local/bin/did-hosting-daemon'
```

Instead of `sudo -u vta-svc /usr/local/bin/pnm vta list` just type `p vta list`.
