# Explore 02: VTI Walkthrough

Stand up the full VTI stack — VTA, Mediator, DID Hosting Daemon, Trust Registry and VTC — by stepping through each tool's interactive wizard (the DID Hosting Daemon uses a setup recipe, see Step 4; the Trust Registry is provisioned with `pnm` and a `.env` file, see Step 5). Uses the offline sealed-bundle bootstrap flow over DIDComm.

> **⚠️ Explore stream — do not use for real keys.**
> The box runs everything as root in `/root/<svc>/` with no isolation between services ([why root?](01-server-setup.md#why-root)). Run every command on this page from a root shell, not with `sudo`. For a hardened production deployment, see the [Deploy stream](../deploy/) (a VTA Farm on hardened Kubernetes).

**Tested on:** Ubuntu Server 26.04 ([Explore 01: Server Setup](01-server-setup.md))

**Verified with:**

| Build | VTA Version | Mediator Version | DID Hosting Daemon Version | Trust Registry Version | VTC Version |
| --- | --- | --- | --- | --- | --- |
| Nightly, 2026-10-17 | 0.62.0 | 0.43.0 | 0.10.0 | 0.26.0 | 0.11.58 |

**Verified on a nightly, not a release.** Nightly builds are only kept for a week or two, so these exact builds will soon be gone from the download server. This page will be re-verified on the upcoming VTI-Fig release, after which every guide in this repo tracks a coordinated release.

## Prerequisites

Complete the [01 — Server setup](01-server-setup.md) first.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | VTA mnemonic phrase | Recovery |
| 1b | VTA DID | Steps 2, 3 & 6 |
| 1c | Mediator DID | Steps 4 & 5 |
| 3a | SHA-256 digest (mediator bundle) | Step 3 |
| 4a | SHA-256 digest (DID Host bundle) | Step 4 |
| 4b | DID Host DID | Step 4 |
| 4c | DID Host Admin DID | Step 4 |
| 5a | SHA-256 digest (Trust Registry bundle) | Step 5 |
| 5b | Trust Registry DID | Step 6 |
| 6a | VTC DID | Step 6 |
| 6b | VTC Admin DID | Re-minting the install URL |

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
| Services to enable (select at least one): | Press **Enter** (all three services selected) |
| Server host [0.0.0.0]: | Press **Enter** (use default) |
| Server port [8100]: | Press **Enter** (use default) |
| VTA REST URL [http://localhost:8100]: | `https://vta.yourdomain.com` |
| Log level [info]: | Press **Enter** (use default) |
| Log format: | Press **Enter** (default: **text**) |
| Audit-log retention (days) [28]: | Press **Enter** (use default) |
| Data directory [data/vta]: | Press **Enter** (use default) |
| Configure advanced server options (CORS, trusted proxy header, WebAuthn)? [y/N] | Press **Enter** (use default) |
| Seed storage backend: | Press **Enter** (default: Config file) |
| Enable hardened configuration? (encrypts the fjall store...) y/N | Press **Enter** (use default) |

**DIDComm Messaging:**

| Prompt | Action |
| --- | --- |
| DIDComm messaging: | Choose **Create a new mediator DID (did:webvh)** |
| Trust context for the mediator DID [mediator]: | Press **Enter** (use default) |
| Mediator URL: | `https://mediator.yourdomain.com/mediator/v1` |
| Mediator WebSocket URL: [wss://mediator.yourdomain.com/mediator/v1/ws] | Press **Enter** (use default) |
| mediator DID URL [http://mediator.yourdomain.com/mediator/v1]: | `https://dids.yourdomain.com/mediator` |
| Mediator hostname for vsock-bridged TEE deployments (leave empty to skip): | Press **Enter** (leave empty) |
| Upstream routing-key DIDs for this mediator (comma-separated, leave empty to skip): | Press **Enter** (leave empty) |
| Automatically provision ACL on mediator after connecting? y/N | Press **Enter** (use default) |

**VTA DID:**

| Prompt | Action |
| --- | --- |
| VTA DID: | Choose **Create a new did:webvh DID** |
| VTA DID URL [http://localhost:8000/]: | `https://dids.yourdomain.com/vta` |
| DID creation mode: | Press **Enter** (default: **Simple — VTA creates keys and document**) |
| Make this DID portable (can move to a different domain later)? [Y/n]: | Press **Enter** (use default) |
| Number of pre-rotation keys [1]: | Press **Enter** (use default) |

The wizard then displays a 24-word mnemonic.

- > **⚠️ SAVE THIS** (1a)
  > Save the **24-word mnemonic phrase** to your notes.
  > You cannot recover this VTA without it.
- I have saved my mnemonic phrase [y/N]: → **y**

| Prompt | Action |
| --- | --- |
| Save DID log to file [mediator-did.jsonl]: | Press **Enter** (use default) |
| Save DID log to file [VTA-did.jsonl]: | Press **Enter** (use default) |

When all prompts are complete, the wizard prints:

```text
Setup complete.
  Config:   config.toml
  Data dir: data/vta
  Name:     Ada VTA
  URL:      https://vta.ada.ic3.dev
  VTA DID: did:webvh:...:dids.yourdomain.com:vta
  Mediator DID: did:webvh:...:dids.yourdomain.com:mediator
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

PNM will output a `vta import-did` command; copy it:

```text
vta import-did --did did:key:z6Mk... --role admin
```

Then run that command in the `~/vta` directory:

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

Press **Enter** to continue.

**Messaging Protocol:**

| Prompt | Action |
| --- | --- |
| [Space] toggles protocol, [Enter] continue: | Press **Enter** (use defaults) |

**Security:**

| Prompt | Action |
| --- | --- |
| Configure transport security: | Choose **No SSL (use TLS-terminating proxy)** (default) |
| Configure authentication tokens: | Choose **Generate a fresh JWT signing key (recommended)** (default) |
| Network access posture: | Choose **Open network** (default) |
| CORS policy: | Choose **Allow any origin** |

**Database:**

| Prompt | Action |
| --- | --- |
| Choose between Redis (multi-mediator) and Fjall (embedded single-node): | Choose **Redis** (default) |
| Connection string for the mediator's Redis-compatible database. | Press **Enter** (default: `redis://127.0.0.1/`) |

**Admin Account:**

| Prompt | Action |
| --- | --- |
| Configure the admin DID for mediator management: | Choose **Generate a new admin did:key** (default) |
| Where should the wizard write mediator.toml?: | Press **Enter** (default: `conf/mediator.toml`) |

The wizard shows a **Summary — Review Configuration** screen. Press **Enter** to write the configuration.

### Step 4: Set up DID Hosting Daemon

> **Why this step uses a recipe instead of the wizard.** Since DID Hosting Daemon 0.8.3 the setup wizard refuses to continue on a host with no OS keychain (a headless Ubuntu box has none) and no longer offers plaintext secrets storage. Plaintext is still available for test deployments, but only through a non-interactive setup recipe that sets `backend = "plaintext"` together with `confirm_plaintext = true`. The explore box is a throwaway, so that is what we do here. The private keys end up in `~/dids/config.secrets.plaintext`; delete the box when you are done with it.

Create a directory for the daemon and write the recipe:

```bash
cd ~
mkdir dids
cd dids
vi daemon.toml
```

Paste the following, replacing `yourdomain.com` with your actual domain and the mediator DID with the **Mediator DID** (1c):

```toml
[deployment]
service = "daemon"
vta_mode = "offline-prepare"

[output]
config_path = "config.toml"

[server]
host = "0.0.0.0"
port = 8534
log_level = "info"
log_format = "text"
data_dir = "data/daemon"

[identity]
public_url = "https://dids.yourdomain.com"
mediator_did = "<Mediator DID (1c)>"
transport = "both"

[vta]
context_id = "webvh"
request_path = "bootstrap-request.json"

[daemon]
enable_control = true
enable_server = true
enable_witness = true
enable_watcher = false

[secrets]
backend = "plaintext"
confirm_plaintext = true

[admin]
mode = "generate"
```

A bare host in `public_url` publishes the daemon's own DID at `.well-known`. The daemon runs control, server and witness in one process, the same defaults the wizard would pick.

**Phase 1 — write the bootstrap request:**

```bash
cd ~/dids
did-hosting-daemon setup --from daemon.toml
```

The recipe runner prints:

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
```

Nothing needs saving from this output. The `client_did` is the ephemeral bootstrap key, not the admin DID.

Move the bootstrap request to the VTA directory and create the WebVH context:

```bash
mv ~/dids/bootstrap-request.json ~/vta/
cd ~/vta
```

```bash
vta contexts create --id webvh
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
  Template:        did-host-didcomm (did-host-didcomm)
  Secrets:         1
  Outputs:         1
  SHA-256 digest:  <hex>
```

> **⚠️ SAVE THESE** (4a, 4b)
>
> - Save the **SHA-256 digest** (4a) — you will put it in the recipe for phase 2.
> - Save the **Integration DID** (4b) — this is the DID Host DID you will register with the VTA.

Move the bundle to the dids directory:

```bash
mv ~/vta/bundle.armor ~/dids/
cd ~/dids
```

**Phase 2 — open the sealed bundle:**

Edit the same recipe. Change `vta_mode` and add the two bundle lines under `[vta]`; leave everything else as it is:

```bash
cd ~/dids
vi daemon.toml
```

```toml
[deployment]
service = "daemon"
vta_mode = "offline-complete"

[vta]
context_id = "webvh"
request_path = "bootstrap-request.json"
bundle_path = "bundle.armor"
expect_digest = "<SHA-256 digest (4a)>"
```

Run the same command again:

```bash
did-hosting-daemon setup --from daemon.toml
```

The recipe runner opens the bundle with the seed it stored in phase 1, writes `config.toml`, imports the daemon DID, and generates the admin identity:

```text
  [setup-recipe] service       = did-hosting-daemon
  [setup-recipe] vta_mode      = offline-complete
  [setup-recipe] config_path   = config.toml
  [setup-recipe] public_url    = https://dids.yourdomain.com

  [setup-recipe] config written to config.toml
  [setup-recipe] secrets stored in Plaintext backend
  [setup-recipe] daemon DID imported at '.well-known' (scid=<scid>)
  Generated admin did:key: did:key:z6Mk...
  Private key (save now, not re-shown): z3u2...
  [setup-recipe] admin ACL entry added for did:key:z6Mk...
  [setup-recipe] provisioning-VTA ACL entry added for did:webvh:...:dids.yourdomain.com:vta

  [setup-recipe] setup complete

  Next: did-hosting-daemon --config config.toml
```

> **⚠️ SAVE THIS** (4c)
>
> Save the **Admin DID** (4c) (the `Generated admin did:key:` line). This is the DID you will enroll with a passkey. It is not the `client_did` from phase 1 and not the `Client DID` from the bundle output.

Now generate an **Enrollment URL** for the admin of the DID hosting service:

```bash
cd ~/dids
```

```bash
did-hosting-daemon invite --role admin --did <Admin DID (4c)>
```

The command outputs a one-time use URL and a claim code:

```text
  Enrollment URL:
  https://dids.yourdomain.com/enroll?token=...

  Claim code:
  XXXX-XXXX-XXXX
```

Start the DID hosting daemon:

```bash
cd ~/dids
nohup did-hosting-daemon > log.txt 2>&1 &
```

Visit the Enrollment URL in a browser, enter the claim code, then save a passkey when prompted.

> The enrollment URL is **single-use**. If you missed it or the passkey prompt failed, see [DID Enrollment URL is single-use](#did-enrollment-url-is-single-use).

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

Register the DID Hosting Daemon with the VTA:

```bash
cd ~/vta
pnm did-mgmt servers add --id did-hosting-daemon --did <DID Host DID (4b)>
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

### Step 5: Set up Trust Registry

The Trust Registry holds no private keys of its own. At startup it authenticates to the VTA, pulls its DID and keys from a VTA context, and connects to the mediator over DIDComm. Provisioning that context is a sealed-bundle handoff like Steps 3 and 4, except that both ends of it are `pnm`, so you can do the whole thing in one terminal. This step follows the upstream [Trust Registry + VTA setup guide](https://github.com/affinidi/affinidi-trust-registry-rs/blob/main/VTA_SETUP.md), with the values the explore box uses.

The registry and the VTC each need something from the other. The VTC wizard in Step 6 asks for the registry's DID, so that it can publish a `TrustRegistry` referral in the VTC's DID document. The registry only accepts trust-record writes from the DIDs in its `ADMIN_DIDS` setting, and the VTC's DID does not exist until Step 6. So this step provisions the registry and writes its configuration, but does **not** start it. You fill in `ADMIN_DIDS` and start the registry in Step 6, right after `vtc setup` and before starting the VTC.

The VTA, mediator and DID Hosting Daemon must be running (they are, if you finished Step 4). The `trust-registry` binary must be installed, from either option in [Server Setup, Step 5](01-server-setup.md#step-5-install-service-binaries).

**Generate a recipient request:**

```bash
cd ~
mkdir trust-registry
cd ~/trust-registry
pnm bootstrap request --out tr-request.json --label trust-registry
```

The command prints:

```text
Bootstrap request written to tr-request.json

  Bundle-Id:  <id>
  Client DID: did:key:z6Mk...
  Seed saved: /root/.config/pnm/bootstrap-secrets/<id>.key

Hand the request to the producer. They will return an armored bundle.
Verify the SHA-256 digest they print to you out-of-band, then run:
  pnm bootstrap open --bundle <file> --expect-digest <hex>
```

Nothing needs saving from this output. The request file holds only a public key and a nonce. The seed file is what opens the bundle in a moment, and it is single-use.

**Provision the context and the registry DID:**

```bash
cd ~/trust-registry
pnm contexts provision \
  --id trust-registry \
  --name "Trust Registry" \
  --server did-hosting-daemon \
  --did-path trust-registry \
  --mediator-service \
  --recipient tr-request.json \
  > tr-sealed.txt
```

This creates the `trust-registry` context at the VTA, mints an admin credential for it, creates the registry's `did:webvh` on the DID Hosting Daemon, and seals all of it to the request. `--server did-hosting-daemon` is the server id you registered with `pnm did-mgmt servers add` at the end of Step 4. `--did-path trust-registry` publishes the DID at `https://dids.yourdomain.com/trust-registry`; leave it out and the host assigns a path. `--mediator-service` adds the mediator endpoint to the DID document, which the registry needs since it talks DIDComm.

The armored bundle goes to standard output, which the `> tr-sealed.txt` redirect captures. Everything else goes to standard error, so it stays on your terminal:

```text
Creating context 'trust-registry'...
Minting local admin credential and registering ACL...
Creating WebVH DID...
Fetching DID key secrets...

╔══════════════════════════════════════════════════════════════╗
║  Context provision bundle (sealed — hand off armored output) ║
╚══════════════════════════════════════════════════════════════╝

  Context:   trust-registry (Trust Registry)
  Admin DID: did:key:z6Mk...
  DID:       did:webvh:...:dids.yourdomain.com:trust-registry
  Recipient: trust-registry

  Bundle-Id:       <id>
  Producer DID:    did:key:z6Mk...
  SHA-256 digest:  <hex>

Communicate the digest to the recipient out-of-band so they can run:
  pnm bootstrap open --bundle <file> --expect-digest <hex>
```

> **⚠️ SAVE THESE** (5a, 5b)
>
> - Save the **SHA-256 digest** (5a) — you will pass it to `pnm bootstrap open` next.
> - Save the **Trust Registry DID** (5b) — the `DID:` line (`did:webvh:...:trust-registry`), not the `Admin DID:` line. You will paste it into the VTC wizard in Step 6.

If `pnm contexts provision` fails partway, or you run it a second time, it stops with an error that the context already exists. See [Trust Registry context already exists](#trust-registry-context-already-exists).

**Open the sealed bundle:**

```bash
cd ~/trust-registry
pnm bootstrap open \
  --bundle tr-sealed.txt \
  --expect-digest <SHA-256 digest (5a)> \
  --out /root/trust-registry/vta-credential.json
```

The digest check is mandatory. `--out` writes the registry's credential bundle as JSON (mode `0600`) with four fields: `did`, `privateKeyMultibase`, `vtaDid` and `vtaUrl`. That file is what the registry's `TR_VTA_CREDENTIAL` setting points at.

> **Do not omit `--out`.** Without it, `pnm bootstrap open` only inspects the bundle: it prints a summary and writes nothing, and it never prints the private key. A successful `--out` write consumes the single-use seed, so the same bundle cannot be opened twice. If you did miss it, see [Trust Registry bundle opened without `--out`](#trust-registry-bundle-opened-without---out).

**Write the configuration:**

The standalone `trust-registry` binary reads a `.env` file from the directory it is started in.

```bash
cd ~/trust-registry
vi .env
```

Paste the following. Replace the mediator DID with the **Mediator DID** (1c), and leave `ADMIN_DIDS` as the placeholder for now; Step 6 fills it in with the VTC DID.

```dotenv
# --- DIDComm and TSP. The VTA path only runs inside DIDComm, so it stays on. ---
ENABLE_DIDCOMM=true
ENABLE_TSP=true
MEDIATOR_DID=<Mediator DID (1c)>

# --- Identity from the VTA (Step 5) ---
TR_VTA_CREDENTIAL=file:///root/trust-registry/vta-credential.json
TR_VTA_CONTEXT_ID=trust-registry

# --- Who may write trust records. Filled in during Step 6. ---
ADMIN_DIDS=<VTC DID (6a)>
ACL_MODE=ExplicitDeny

# --- Trust-record storage: embedded fjall store under ./data ---
TR_STORAGE_BACKEND=fjall
TR_FJALL_PATH=data

# --- Offline cache of the VTA bundle: plaintext file under ./.trust-registry (dev/test only) ---
TR_SECRETS_ALLOW_PLAINTEXT=true

# --- REST/TRQP surface. Local only on the explore box; used for health checks. ---
LISTEN_ADDRESS=127.0.0.1:3232
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001
AUDIT_LOG_FORMAT=text
RUST_LOG=info
```

A few notes on these values:

- `ENABLE_TSP=true` needs a binary built with the `tsp` feature. Both the pre-built binary and the source build in Server Setup include it. The VTC's default transports are TSP and DIDComm, so the registry answers both.
- `ACL_MODE=ExplicitDeny` is the registry's public mode: any DID may query it, and only `ADMIN_DIDS` may write. The registry sets this mode on its own mediator account at startup.
- `TR_SECRETS_ALLOW_PLAINTEXT=true` lets the registry cache the bundle it fetched from the VTA in a plaintext file, so it can restart while the VTA is briefly down. It is the same dev-only trade-off as the plaintext secrets in Steps 3 and 4. A production deployment would use one of the `secrets-*` backends, such as HashiCorp Vault, instead.
- `LISTEN_ADDRESS` is bound to loopback because the explore box has no Nginx vhost or DNS record for the registry. Clients find it through its DID and the mediator, not over REST. To expose the REST/TRQP API, add a vhost and DNS record for port 3232 and set `TR_PUBLIC_URL` to its `https://` URL.
- Do not set `PROFILE_CONFIG`; in VTA mode it is ignored.

Do not start the registry yet. Continue to Step 6.

### Step 6: Set up VTC

Create a directory for the VTC and run the setup wizard:

```bash
cd ~
mkdir vtc
cd ~/vtc
vtc setup
```

When prompted, use the values below. Replace `yourdomain.com` with your actual domain.

| Prompt | Action |
| --- | --- |
| Config file path [config.toml]: | Press **Enter** (use default) |
| VTC base URL: | `https://vtc.yourdomain.com` |
| VTA DID: | Paste the **VTA DID** from 1b |
| Context name at the VTA for this community [default]: | Press **Enter** (use default) |
| Trust registry DID (blank for none): | Paste the **Trust Registry DID** from 5b (see note below) |
| Second administrator DID (blank for none): | Press **Enter** (use default) |
| Run as a single-administrator community? [y/N] | Select **y** |
| DIDComm messaging [Use the VTA's mediator]: | Press **Enter** (use default) |
| Transports (space to toggle, enter to confirm): | Press **Enter** (use default: TSP & DIDComm) |

> The registry DID you give the wizard is used for one thing only: a `TrustRegistry` referral in the VTC's DID document, so that clients holding the community's DID can find its registry. It is **not** copied into the VTC's own configuration. The setting that makes the VTC itself talk to the registry is added to `config.toml` below, before the VTC starts.

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

**DID Hosting:**

| Prompt | Action |
| --- | --- |
| Where should the VTC DID be published?: | Press **Enter** (use default: did-hosting-daemon) |
| WebVH path (blank → server-assigned): | `vtc` |

**Seed storage backend:**

- Choose: **Config file (hex-encoded seed in config.toml)**

The wizard then displays:

```text
✅ VTC setup complete.

VTC DID:       did:webvh:QmR2...:vtc.example.com
Admin DID:     did:key:z6Mk...
Config:        config.toml
Data dir:      data
```

> **⚠️ SAVE THESE** (6a, 6b)
>
> - Save the **VTC DID** (6a), the `VTC DID:` line. It goes into the Trust Registry's `ADMIN_DIDS` below.
> - Save the **VTC Admin DID** (6b), the `Admin DID:` line. It is the `did:key` the install URL binds your passkey to, and you need it to mint a new install URL if this one expires (see [VTC install URL expired or already used](#vtc-install-url-expired-or-already-used)).

| Prompt | Action |
| --- | --- |
| Display the admin private key now? It's needed for CLI access and is shown only once [y/N] | Press **Enter** (use default) |

```text
Install URL (one-shot, 15 min TTL):
  https://vtc.example.com/admin/install?token=eyJ0...

Claim code (required at claim time):
  NDKH...
```

**Finish and start the Trust Registry:**

Now that the VTC DID exists, put it in the registry's `.env` from Step 5:

```bash
cd ~/trust-registry
vi .env
```

Replace the `ADMIN_DIDS` placeholder with the **VTC DID** (6a):

```dotenv
ADMIN_DIDS=<VTC DID (6a)>
```

Start the registry. It must be running before the VTC starts, so that the VTC finds it when it comes up:

```bash
cd ~/trust-registry
nohup trust-registry > log.txt 2>&1 &
```

Give it a few seconds, then check it:

```bash
curl -s http://127.0.0.1:3232/health
```

A healthy registry answers `{"status":"OK"}`. A `degraded` status means the mediator refused the ACL-mode update; `detail` says why. Then confirm from the log that it fetched its identity from the VTA and authenticated to the mediator:

```bash
grep -iE 'vta|mediator' ~/trust-registry/log.txt
```

The registry's DID is also listed at `https://dids.yourdomain.com/dids`, published by the DID Hosting Daemon under the `trust-registry` path.

**Start the VTC:**

Before starting the VTC, ensure the **Trust Registry DID** (5b) is added.

```bash
cd ~/vtc
vi config.toml
```

Find the `[registry]` section (add it if it is not there) and add the following line under it:

```toml
[registry]
did = "<Trust Registry DID (5b)>"
```

The DID is enough on its own. The VTC reaches the registry over whichever transport both DID documents advertise, TSP first and then DIDComm; a `url` key is only needed for a REST-only registry.

Start the VTC:

```bash
cd ~/vtc
nohup vtc > log.txt 2>&1 &
```

Open the **Install URL** in a browser and paste the **Claim code** in the input box on the browser page.

You are then prompted to save a passkey, so go ahead and save it.

Ignore the **Claim Admin Passkey** screen for now. This is currently not used.

Navigate to `https://vtc.yourdomain.com/admin` and sign in with your new passkey.

You now have access to the VTC Admin Dashboard and can set up access for the community manager(s) of the VTC.

## Known Issues / Edge Cases

### DID Enrollment URL is single-use

The enrollment URL generated by `did-hosting-daemon invite` can only be used once. If you missed saving it, let it expire, or the browser visit failed, you need to regenerate it:

**1.** Stop the running daemon:

```bash
kill -9 $(pgrep -f did-hosting-daemon)
```

**2.** Regenerate the enrollment token:

```bash
cd ~/dids
did-hosting-daemon invite --role admin --did <Admin DID (4c)>
```

**3.** Restart the daemon:

```bash
nohup did-hosting-daemon > log.txt 2>&1 &
```

Then visit the new Enrollment URL in a browser and save a passkey when prompted.

### VTC install URL expired or already used

The install URL from `vtc setup` is single-use and expires 15 minutes after it is minted. If the browser shows **Install URL expired or already used**, mint a fresh one for the same admin DID. The command opens the VTC's store directly, which it can only do while the daemon is stopped:

**1.** Stop the running VTC:

```bash
kill $(pgrep -x vtc)
```

**2.** Mint a new install URL for the **VTC Admin DID** (6b). If you did not save it, it is the `Admin DID:` line from the `vtc setup` summary, and also the DID in the `vtc --config config.toml acl add --did ...` hint the wizard printed at the end. The default lifetime is 15 minutes; `--ttl` sets it in seconds:

```bash
cd ~/vtc
vtc --config config.toml admin invite --did <VTC Admin DID (6b)> --ttl 3600
```

**3.** Restart the VTC:

```bash
nohup vtc > log.txt 2>&1 &
```

Then open the new install URL, enter the new claim code, and save a passkey as before. The command also grants the DID its admin ACL entry if the first install was never claimed, so nothing else needs repairing.

### Trust Registry context already exists

`pnm contexts provision` creates the `trust-registry` context at the VTA before it mints the DID and seals the bundle, so a run that failed after that point, or a second run, stops because the context already exists. Do not delete the context. Make a fresh request and re-mint the bundle for the existing context instead:

```bash
cd ~/trust-registry
pnm bootstrap request --out tr-request.json --label trust-registry
pnm contexts reprovision --id trust-registry --recipient tr-request.json > tr-sealed.txt
```

Save the new digest from the banner, then continue from **Open the sealed bundle** in [Step 5](#step-5-set-up-trust-registry). The registry DID (5b) does not change.

### Trust Registry exits asking for `PROFILE_CONFIG`

If `log.txt` ends with `Required environment variable 'PROFILE_CONFIG' is not set` and the process exits with code 101, the binary was built without the `vta` feature, so it never looked at `TR_VTA_CREDENTIAL` and fell through to the non-VTA identity path. Do not set `PROFILE_CONFIG`. Check the binary:

```bash
grep -ac TR_VTA_CREDENTIAL "$(command -v trust-registry)"
```

Zero confirms it. Install a binary built with the feature, as described in [Server Setup](01-server-setup.md#trust-registry), then start the registry again. The `.env` and `vta-credential.json` from Step 5 stay as they are.

### Trust Registry bundle opened without `--out`

Inspecting a bundle (no `--out`) keeps the seed, so simply run `pnm bootstrap open` again with `--out`. If `open` reports that the seed is gone, or you deleted `tr-sealed.txt`, the bundle cannot be opened again: follow [Trust Registry context already exists](#trust-registry-context-already-exists) to get a fresh bundle and seed.
