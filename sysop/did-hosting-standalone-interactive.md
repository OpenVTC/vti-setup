# DID Hosting: Standalone Setup (Interactive)

This module covers Step 4 of the VTI interactive setup for a **standalone DID Hosting deployment**, where the control, server, witness, and watcher components run as separate services.

**Complete [Interactive setup](interactive-setup.md) Steps 1–3 (VTA, PNM, Mediator) before continuing.**

The following value from the previous steps is needed here:

| ID | Value | From |
| --- | --- | --- |
| 1c | Mediator DID | Interactive setup Step 3 |

The following values will be collected in this module. Save each one as prompted:

| ID | What to Save | Used In |
| --- | --- | --- |
| 4a | Control Admin DID | Step 4.3 |
| 4b | Control Admin private key | Later |
| 4c | Consumer DID (control context) | Step 4.1 |
| 4d | SHA-256 digest (Control bundle) | Step 4.1 |
| 4e | Control DID | Step 4.2 |
| 4f | Consumer DID (server context) | Step 4.2 |
| 4g | SHA-256 digest (server bundle) | Step 4.2 |
| 4h | Server DID | Step 4.3 |

## Step 4.1: Set up DID Hosting Control

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

> **⚠️ SAVE THESE** (4a, 4b, 4c)
>
> - Save the **Admin DID** (4a): the `Generated admin did:key:` line
> - Save the **Admin private key** (4b): the `Private key:` line — shown only once
> - Save the **Consumer DID** (4c): the `Consumer DID:` line

Move the bootstrap request to the VTA directory and create the control context:

```bash
mv ~/control/bootstrap-request.json ~/vta/
cd ~/vta
```

```bash
vta contexts create --id control --admin-expires 1h --admin-did <Consumer DID (4c)>
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

> **⚠️ SAVE THIS** (4d)
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
| Expected SHA-256 digest (lowercase hex): | Paste the **SHA-256 digest** (4d) |
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
```

> **⚠️ SAVE THIS** (4e)
>
> Save the **Control DID** (4e): the `Control DID:` line

## Step 4.2: Set up DID Hosting Server

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
| Control plane DID (leave empty to set later) []: | Paste the **Control DID** (4e) |
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

> **⚠️ SAVE THIS** (4f)
>
> Save the **Consumer DID** (4f): the `Consumer DID:` line

Move the bootstrap request to the VTA directory and create the server context:

```bash
mv ~/server/bootstrap-request.json ~/vta/
cd ~/vta
```

```bash
vta contexts create --id server --admin-expires 1h --admin-did <Consumer DID (4f)>
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

> **⚠️ SAVE THIS** (4g)
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
| Expected SHA-256 digest (lowercase hex): | Paste the **SHA-256 digest** (4g) |
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
```

> **⚠️ SAVE THIS** (4h)
>
> Save the **Server DID** (4h): the `Server DID:` line

## Step 4.3: Wire Control and Server Together

Import the control DID log into the server store:

```bash
mv ~/control/control-did.jsonl ~/server/
cd ~/server
did-hosting-server bootstrap-did --path services/control --did-log control-did.jsonl
```

Add the server DID to the control plane ACL:

```bash
cd ~/control
did-hosting-control add-acl --role service --did <Server DID (4h)>
```

Create an enrollment invite for the admin DID:

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

## Step 4.4: Load VTA and Mediator DIDs

Import the DID logs generated during VTA setup so the hosting server can resolve them:

```bash
cd ~/server
did-hosting-server load-did --path mediator --did-log ~/vta/mediator-did.jsonl
did-hosting-server load-did --path vta --did-log ~/vta/VTA-did.jsonl
```

## Step 4.5: Dump Server DID

Export the server's DID log before starting the hosting services — you will need it to register the server's root DID in the control plane.

```bash
cd ~/server
did-hosting-server dump-did --path server > server-did.jsonl
```

## Step 4.6: Start DID Hosting Services

```bash
cd ~/control
nohup did-hosting-control > log.txt 2>&1 &
```

```bash
cd ~/server
nohup did-hosting-server > log.txt 2>&1 &
```

## Step 4.7: Register Admin Passkey

Visit the **Enrollment URL** from Step 4.3 in a browser (`https://control.yourdomain.com/enroll?token=...`), then save a passkey when prompted.

## Step 5: Upload DID Logs and Start Services

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

Wait one minute for the mediator to fully initialize, then start the VTA:

```bash
cd ~/vta
nohup vta > log.txt 2>&1 &
```

The DID Hosting Control startup overwrites the server's DID store, so the mediator and VTA DID logs must be re-uploaded after the control plane is running.

**Register server domain and root DID:**

In a browser, go to the DID Hosting Control UI at `https://control.yourdomain.com/domains` and add the server's domain (e.g., `dids.yourdomain.com`).

**Upload DID logs:**

Go to `https://control.yourdomain.com/dids`.

Click **+ Create Root DID**. When `.well-known` appears in the list, click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/server/server-did.jsonl
```

Click **+ New DID** (top right), enter `mediator`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/mediator-did.jsonl
```

Click **+ New DID** again, enter `vta`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/vta/VTA-did.jsonl
```

Click **+ New DID** again, enter `services/control`, then click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
cat ~/server/control-did.jsonl
```

## Next

Return to [Interactive setup](interactive-setup.md#step-5-set-up-vtc) Step 5 to complete the VTC setup.
