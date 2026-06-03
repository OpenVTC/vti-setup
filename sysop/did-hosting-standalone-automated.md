# DID Hosting: Standalone Setup (Automated)

This module covers Step 3 of the VTI setup for a **standalone DID Hosting deployment** driven from TOML recipes and CLI flags instead of interactive wizards. This is the automated equivalent of [DID Hosting: Standalone Setup (Interactive)](did-hosting-standalone-interactive.md) — the offline sealed-bundle flow is unchanged; only the input method differs.

**Complete [Automated setup](automated-setup.md) Steps 1–2 (VTA and Mediator) before continuing.**

The following value from the previous steps is needed here:

| ID | Value | From |
| --- | --- | --- |
| 1b | Mediator DID | Automated setup Step 1 |

The following values will be collected in this module. Save each one as prompted:

| ID | What to Save | Used In |
| --- | --- | --- |
| 3a | Control client_did | Step 3.1 |
| 3b | SHA-256 digest (Control bundle) | Step 3.1 phase 2 |
| 3c | Control Admin DID | Step 3.3 |
| 3d | Control Admin private key | Offline backup |
| 3e | Control DID | Step 3.2 |
| 3f | Server client_did | Step 3.2 |
| 3g | SHA-256 digest (server bundle) | Step 3.2 phase 2 |
| 3h | Server DID | Step 3.3 |

## Step 3.1: Set up DID Hosting Control

```bash
mkdir ~/control
cd ~/control
```

Create the setup recipe:

```bash
vim ~/control/control-recipe.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

Paste the following content. Replace `yourdomain.com` with your actual domain, and replace `<Mediator DID (1b)>` with your actual Mediator DID:

```toml
[deployment]
service  = "control"
vta_mode = "offline-prepare"

[output]
config_path = "config.toml"

[server]
host       = "0.0.0.0"
port       = 8532
log_level  = "info"
log_format = "text"
data_dir   = "data/did-hosting-control"

[identity]
did_hosting_url = "https://dids.yourdomain.com"
did_path        = "services/control"
public_url      = "https://control.yourdomain.com"
mediator_did    = "<Mediator DID (1b)>"

[vta]
context_id   = "control"
request_path = "bootstrap-request.json"

[secrets]
backend           = "plaintext"
confirm_plaintext = true

[admin]
mode = "generate"

[reprovision]
force = false
```

**Phase 1** — generate the bootstrap request:

```bash
cd ~/control
did-hosting-control setup --from control-recipe.toml
```

The command prints:

```text
  [setup-recipe] service       = did-hosting-control
  [setup-recipe] vta_mode      = offline-prepare
  [setup-recipe] config_path   = config.toml
  [setup-recipe] public_url    = https://control.yourdomain.com

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
    4. Re-run phase 2: did-hosting-control setup --from <recipe>
```

> **⚠️ SAVE THIS** (3a)
>
> Copy the **`client_did`** value — you will pass it to `vta contexts create` in the next command.

Switch to the VTA directory and create the control context:

```bash
cd ~/vta
vta contexts create --id control --admin-expires 1h --admin-did <client_did (3a)>
```

Seal the bundle:

```bash
vta bootstrap provision-integration \
  --request ~/control/bootstrap-request.json \
  --out ~/control/bundle.armor
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

> **⚠️ SAVE THIS** (3b)
>
> Save the **SHA-256 digest** — you will pass it as `expect_digest` in Phase 2.

**Phase 2** — complete offline setup:

Open the recipe and make two changes: set `vta_mode` to `"offline-complete"` and replace the `[vta]` section with `bundle_path` and `expect_digest`:

```bash
vim ~/control/control-recipe.toml
```

Update these two sections (leave the rest of the file unchanged):

```toml
[deployment]
service  = "control"
vta_mode = "offline-complete"

[vta]
bundle_path   = "bundle.armor"
expect_digest = "<SHA-256 digest (3b)>"
```

Then run the same command from the same directory (the secret backend looks up the bootstrap seed using the `config_path` as a key):

```bash
cd ~/control
did-hosting-control setup --from control-recipe.toml
```

The command writes `config.toml` and prints:

```text
  [setup-recipe] service       = did-hosting-control
  [setup-recipe] vta_mode      = offline-complete
  [setup-recipe] config_path   = config.toml

  Existing config.toml backed up to config.toml.bak before re-provisioning.
  [setup-recipe] config written to config.toml
  [setup-recipe] secrets stored in Plaintext backend
  [setup-recipe] DID log entry written to control-did.jsonl
  Generated admin did:key: did:key:z6Mk...
  Private key (save now, not re-shown): z3u2...
  [setup-recipe] admin ACL entry added for did:key:z6Mk...

  [setup-recipe] setup complete

  Control DID:       did:webvh:...:dids.yourdomain.com
  Next: did-hosting-control --config config.toml
```

> **⚠️ SAVE THESE** (3c, 3d, 3e)
>
> - **3c — Control Admin DID** — the `Generated admin did:key:` line
> - **3d — Control Admin private key** — the `Private key (save now, not re-shown):` line — shown only once; clear your terminal scrollback after copying
> - **3e — Control DID** — the `Control DID:` line

## Step 3.2: Set up DID Hosting Server

```bash
mkdir ~/server
cd ~/server
```

Create the setup recipe:

```bash
vim ~/server/server-recipe.toml
```

> **Vim:** `i` to insert → paste content → `Esc` → `:wq` to save and quit

Paste the following content. Replace `yourdomain.com` with your actual domain, replace `<Mediator DID (1b)>` with your actual Mediator DID, and replace `<Control DID (3e)>` with the Control DID saved from Step 3.1:

```toml
[deployment]
service  = "server"
vta_mode = "offline-prepare"

[output]
config_path = "config.toml"

[server]
host       = "0.0.0.0"
port       = 8530
log_level  = "info"
log_format = "text"
data_dir   = "data/did-hosting-server"

[identity]
public_url   = "https://dids.yourdomain.com"
mediator_did = "<Mediator DID (1b)>"
control_did  = "<Control DID (3e)>"

[vta]
context_id   = "server"
request_path = "bootstrap-request.json"

[secrets]
backend           = "plaintext"
confirm_plaintext = true

[admin]
mode = "skip"

[reprovision]
force = false
```

**Phase 1** — generate the bootstrap request:

```bash
cd ~/server
did-hosting-server setup --from server-recipe.toml
```

The command prints:

```text
  [setup-recipe] service       = did-hosting-server
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
    2. Ask them to seal the response:
         vta bootstrap provision-integration --request <request-file> \
           --out <bundle-file>
       and to communicate the SHA-256 digest out-of-band.
    3. Edit your recipe (config.toml):
         - set [deployment].vta_mode = "offline-complete"
         - set [vta].bundle_path    = "<bundle-path>"
         - set [vta].expect_digest  = "<hex-digest>"
    4. Re-run phase 2 (no TTY required):
         did-hosting-server setup --from <recipe>
```

> **⚠️ SAVE THIS** (3f)
>
> Copy the **`client_did`** value — you will pass it to `vta contexts create` in the next command.

Switch to the VTA directory and create the server context:

```bash
cd ~/vta
vta contexts create --id server --admin-expires 1h --admin-did <client_did (3f)>
```

Seal the bundle:

```bash
vta bootstrap provision-integration \
  --request ~/server/bootstrap-request.json \
  --out ~/server/bundle.armor
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

> **⚠️ SAVE THIS** (3g)
>
> Save the **SHA-256 digest** — you will pass it as `expect_digest` in Phase 2.

**Phase 2** — complete offline setup:

Open the recipe and make two changes: set `vta_mode` to `"offline-complete"` and replace the `[vta]` section with `bundle_path` and `expect_digest`:

```bash
vim ~/server/server-recipe.toml
```

Update these two sections (leave the rest of the file unchanged):

```toml
[deployment]
service  = "server"
vta_mode = "offline-complete"

[vta]
bundle_path   = "bundle.armor"
expect_digest = "<SHA-256 digest (3g)>"
```

> **Note:** Run the phase 2 command from `~/server`. The plaintext secret backend stores the bootstrap seed keyed by `config_path`; running from a different directory causes it to look in the wrong location and fail.

Then run the same command:

```bash
cd ~/server
did-hosting-server setup --from server-recipe.toml
```

The command writes `config.toml` and prints:

```text
  [setup-recipe] service       = did-hosting-server
  [setup-recipe] vta_mode      = offline-complete
  [setup-recipe] config_path   = config.toml

  Existing config.toml backed up to config.toml.bak before re-provisioning.
  [setup-recipe] config written to config.toml
  [setup-recipe] secrets stored in Plaintext backend
  [setup-recipe] server DID imported at '.well-known' (scid=<scid>)

  [setup-recipe] setup complete

  Server DID:        did:webvh:...:dids.yourdomain.com
  Next: did-hosting-server --config config.toml
```

> **⚠️ SAVE THIS** (3h)
>
> Save the **Server DID** (3h): the `Server DID:` line

## Step 3.3: Wire Control and Server Together

Import the control DID log into the server store:

```bash
mv ~/control/control-did.jsonl ~/server/
cd ~/server
did-hosting-server bootstrap-did --path services/control --did-log control-did.jsonl
```

Add the server DID to the control plane ACL:

```bash
cd ~/control
did-hosting-control add-acl --role service --did <Server DID (3h)>
```

## Step 3.4: Load VTA and Mediator DIDs

Import the DID logs generated during VTA setup so the hosting server can resolve them:

```bash
cd ~/server
did-hosting-server load-did --path mediator --did-log ~/vta/data/vta/did-logs/mediator-did.jsonl
did-hosting-server load-did --path vta --did-log ~/vta/data/vta/did-logs/VTA-did.jsonl
```

## Step 3.5: Dump Server DID

Export the server's DID log before starting the hosting services — you will need it to register the server's root DID in the control plane.

```bash
cd ~/server
did-hosting-server dump-did --path .well-known > server-did.jsonl
```

## Step 4: Start Services and Upload DID Logs

**Start the DID Hosting server:**

```bash
cd ~/server
nohup did-hosting-server > log.txt 2>&1 &
```

**Start the mediator:**

> If you configured a passphrase for the key storage backend, set it before starting:
>
> ```bash
> export MEDIATOR_FILE_BACKEND_PASSPHRASE='your-passphrase'
> ```

```bash
cd ~/mediator
nohup mediator > log.txt 2>&1 &
```

Generate an enrollment invite for the admin DID before starting the control service:

```bash
cd ~/control
did-hosting-control invite --role admin --did <Admin DID (3c)>
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

**Start the DID Hosting control:**

```bash
cd ~/control
nohup did-hosting-control > log.txt 2>&1 &
```

**Register Admin Passkey:**

Visit the **Enrollment URL** printed above in a browser (`https://control.yourdomain.com/enroll?token=...`), then save a passkey when prompted.

The DID Hosting Control startup overwrites the server's DID store, so the mediator and VTA DID logs must be re-uploaded after the control plane is running.

**Register server domain and root DID:**

In a browser, go to the DID Hosting Control UI at `https://control.yourdomain.com/domains` and add the server's domain (e.g., `dids.yourdomain.com`).

**Upload DID logs:**

Go to `https://control.yourdomain.com/dids`.

Click **Create Root DID**. When `.well-known` appears in the list, click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/server/server-did.jsonl
```

Click **+ New DID** (top right), enter `mediator`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/data/vta/did-logs/mediator-did.jsonl
```

Click **+ New DID** again, enter `vta`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/data/vta/did-logs/VTA-did.jsonl
```

Click **+ New DID** again, enter `services/control`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/server/control-did.jsonl
```

## Next

Return to [Automated setup](automated-setup.md#step-4-bind-pnm) Step 4 to bind PNM.
