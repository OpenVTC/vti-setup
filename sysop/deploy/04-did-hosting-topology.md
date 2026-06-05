# Deploy 04: DID Hosting Topology

The DID Hosting layer can be deployed two ways. The deploy script's `--standalone` flag selects the topology at server-setup time; this page covers the decision and the provisioning flow for standalone. The standard topology is covered by [03 — Provisioning](03-provisioning.md) Step 3.

## Decision: standard vs standalone

| | Standard | Standalone |
| --- | --- | --- |
| Binary | `did-hosting-daemon` | `did-hosting-control` + `did-hosting-server` + `webvh-witness` + `webvh-watcher` |
| Service users | `dids-svc` | `dids-svc` + `control-svc` + `witness-svc` + `watcher-svc` |
| Subdomains | `dids` | `dids` + `control` + `witness` + `watcher` |
| Setup | One recipe, one service to provision | One recipe per role, more handoffs |
| Resource use | One process, one journal stream | Four processes |

**Pick standard if:**

- Single host, single operator, modest traffic. This is the default and what most deployments should use.

**Pick standalone if:**

- You want to scale read traffic (server) independently from admin traffic (control).
- You need each component on its own subdomain — for example, to firewall the admin UI to specific source IPs.
- You're operating multiple `did-hosting-server` replicas behind one `did-hosting-control` plane.

If you're unsure, pick standard. Re-deploying to standalone later is straightforward (the underlying DIDs and config recipes survive).

## Standalone provisioning

This replaces Step 3 of [03 — Provisioning](03-provisioning.md). Do Steps 1 (VTA), 2 (Mediator), 4 (PNM), and 5 (verify) from that doc, and use the steps below in place of Step 3.

**Verified with:**

| VTA Version | Mediator Version | DID Hosting Daemon Version |
| --- | --- | --- |
| 0.8.1 | 0.15.12 | 0.7.0 |

The following value from earlier steps is needed here:

| ID | Value | From |
| --- | --- | --- |
| 1b | Mediator DID | 03 — Provisioning Step 1 |

The following values will be collected:

| ID | What to Save | Used In |
| --- | --- | --- |
| 3a | Control client_did | Step 3.1 |
| 3b | SHA-256 digest (Control bundle) | Step 3.1 phase 2 |
| 3c | Control Admin DID | Step 3.3 |
| 3d | Control Admin private key | Offline backup |
| 3e | Control DID | Step 3.2 |
| 3f | Server client_did | Step 3.2 |
| 3g | SHA-256 digest (Server bundle) | Step 3.2 phase 2 |
| 3h | Server DID | Step 3.2 |

### Step 3.1: Set up DID Hosting Control

Create and edit the control recipe:

```bash
sudo install -m 0640 -o root -g control-svc /dev/null /var/lib/control-svc/control-recipe.toml
sudoedit /var/lib/control-svc/control-recipe.toml
```

Paste. Replace `yourdomain.com` with your actual domain, and replace `<Mediator DID (1b)>` with your actual Mediator DID:

```toml
[deployment]
service  = "control"
vta_mode = "offline-prepare"

[output]
config_path = "/var/lib/control-svc/config.toml"

[server]
host       = "0.0.0.0"
port       = 8532
log_level  = "info"
log_format = "text"
data_dir   = "/var/lib/control-svc/data/did-hosting-control"

[identity]
did_hosting_url = "https://dids.yourdomain.com"
did_path        = "services/control"
public_url      = "https://control.yourdomain.com"
mediator_did    = "<Mediator DID (1b)>"

[vta]
context_id   = "control"
request_path = "/var/lib/vti-exchange/control-bootstrap-request.json"

[secrets]
backend           = "plaintext"
confirm_plaintext = true

[admin]
mode = "generate"

[reprovision]
force = false
```

**Phase 1** — generate the bootstrap request as control-svc:

```bash
sudo -u control-svc /usr/local/bin/did-hosting-control setup --from /var/lib/control-svc/control-recipe.toml
```

The command prints:

```text
  [setup-recipe:offline-prepare] phase 1 complete
  [setup-recipe:offline-prepare] request_path = /var/lib/vti-exchange/control-bootstrap-request.json
  [setup-recipe:offline-prepare] client_did   = did:key:z6Mk...
  ...
```

> **⚠️ SAVE THIS** (3a)
>
> Copy the **`client_did`** value — you will pass it to `vta contexts create` next.

Create the control context at the VTA:

```bash
sudo -u vta-svc /usr/local/bin/vta contexts create --config /var/lib/vta-svc/config.toml --id control --admin-expires 1h --admin-did <client_did (3a)>
```

Seal the bundle as vta-svc:

```bash
sudo -u vta-svc /usr/local/bin/vta bootstrap provision-integration \
  --config /var/lib/vta-svc/config.toml \
  --request /var/lib/vti-exchange/control-bootstrap-request.json \
  --out /var/lib/vti-exchange/control-bundle.armor
```

The command outputs the bundle details.

> **⚠️ SAVE THIS** (3b)
>
> Save the **SHA-256 digest** — you will pass it as `expect_digest` in Phase 2.

**Phase 2** — complete offline setup:

```bash
sudoedit /var/lib/control-svc/control-recipe.toml
```

Update these two sections (leave the rest of the file unchanged):

```toml
[deployment]
service  = "control"
vta_mode = "offline-complete"

[vta]
bundle_path   = "/var/lib/vti-exchange/control-bundle.armor"
expect_digest = "<SHA-256 digest (3b)>"
```

Then run the same command as control-svc:

```bash
sudo -u control-svc /usr/local/bin/did-hosting-control setup --from /var/lib/control-svc/control-recipe.toml
```

The command writes `config.toml` and prints:

```text
  [setup-recipe] secrets stored in Plaintext backend
  [setup-recipe] DID log entry written to /var/lib/control-svc/control-did.jsonl
  Generated admin did:key: did:key:z6Mk...
  Private key (save now, not re-shown): z3u2...
  [setup-recipe] admin ACL entry added for did:key:z6Mk...

  [setup-recipe] setup complete

  Control DID:       did:webvh:...:dids.yourdomain.com
```

> **⚠️ SAVE THESE** (3c, 3d, 3e)
>
> - **3c — Control Admin DID** — the `Generated admin did:key:` line
> - **3d — Control Admin private key** — the `Private key (save now, not re-shown):` line — shown only once; clear your terminal scrollback after copying
> - **3e — Control DID** — the `Control DID:` line

### Step 3.2: Set up DID Hosting Server

Create and edit the server recipe:

```bash
sudo install -m 0640 -o root -g dids-svc /dev/null /var/lib/dids-svc/server-recipe.toml
sudoedit /var/lib/dids-svc/server-recipe.toml
```

Paste. Replace `yourdomain.com` with your actual domain, replace `<Mediator DID (1b)>` with your actual Mediator DID, and replace `<Control DID (3e)>` with the Control DID:

```toml
[deployment]
service  = "server"
vta_mode = "offline-prepare"

[output]
config_path = "/var/lib/dids-svc/config.toml"

[server]
host       = "0.0.0.0"
port       = 8530
log_level  = "info"
log_format = "text"
data_dir   = "/var/lib/dids-svc/data/did-hosting-server"

[identity]
public_url   = "https://dids.yourdomain.com"
mediator_did = "<Mediator DID (1b)>"
control_did  = "<Control DID (3e)>"

[vta]
context_id   = "server"
request_path = "/var/lib/vti-exchange/server-bootstrap-request.json"

[secrets]
backend           = "plaintext"
confirm_plaintext = true

[admin]
mode = "skip"

[reprovision]
force = false
```

**Phase 1** — generate the bootstrap request as dids-svc (which runs `did-hosting-server` in standalone mode):

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-server setup --from /var/lib/dids-svc/server-recipe.toml
```

> **⚠️ SAVE THIS** (3f)
>
> Copy the **`client_did`** value — you will pass it to `vta contexts create` next.

Create the server context at the VTA:

```bash
sudo -u vta-svc /usr/local/bin/vta contexts create --config /var/lib/vta-svc/config.toml --id server --admin-expires 1h --admin-did <client_did (3f)>
```

Seal the bundle as vta-svc:

```bash
sudo -u vta-svc /usr/local/bin/vta bootstrap provision-integration \
  --config /var/lib/vta-svc/config.toml \
  --request /var/lib/vti-exchange/server-bootstrap-request.json \
  --out /var/lib/vti-exchange/server-bundle.armor
```

> **⚠️ SAVE THIS** (3g)
>
> Save the **SHA-256 digest** — you will pass it as `expect_digest` in Phase 2.

**Phase 2** — complete offline setup:

```bash
sudoedit /var/lib/dids-svc/server-recipe.toml
```

Update these two sections (leave the rest unchanged):

```toml
[deployment]
service  = "server"
vta_mode = "offline-complete"

[vta]
bundle_path   = "/var/lib/vti-exchange/server-bundle.armor"
expect_digest = "<SHA-256 digest (3g)>"
```

> **Note:** Phase 2 must run with the same `config_path` as phase 1 — the plaintext secret backend stores the bootstrap seed keyed by it.

Run again as dids-svc:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-server setup --from /var/lib/dids-svc/server-recipe.toml
```

```text
  [setup-recipe] secrets stored in Plaintext backend
  [setup-recipe] server DID imported at '.well-known' (scid=<scid>)

  [setup-recipe] setup complete

  Server DID:        did:webvh:...:dids.yourdomain.com
```

> **⚠️ SAVE THIS** (3h)
>
> Save the **Server DID** — the `Server DID:` line.

### Step 3.3: Wire Control and Server together

Pass the control DID log to the server. control-svc wrote `/var/lib/control-svc/control-did.jsonl`; the server needs to import it. Move it through the exchange directory:

```bash
sudo install -o vti -g vti-exchange -m 0640 \
  /var/lib/control-svc/control-did.jsonl \
  /var/lib/vti-exchange/control-did.jsonl

sudo -u dids-svc /usr/local/bin/did-hosting-server bootstrap-did \
  --path services/control \
  --did-log /var/lib/vti-exchange/control-did.jsonl
```

Add the server DID to the control plane ACL:

```bash
sudo -u control-svc /usr/local/bin/did-hosting-control add-acl --role service --did <Server DID (3h)>
```

### Step 3.4: Load VTA and Mediator DIDs into the server store

Import the DID logs generated during VTA setup so the hosting server can resolve them:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-server load-did \
  --path mediator \
  --did-log /var/lib/vta-svc/data/vta/did-logs/mediator-did.jsonl

sudo -u dids-svc /usr/local/bin/did-hosting-server load-did \
  --path vta \
  --did-log /var/lib/vta-svc/data/vta/did-logs/VTA-did.jsonl
```

> The vta-svc-owned DID log files are readable by dids-svc because both users are members of the `vti-exchange` group and the data dir's perms allow it. If your install differs, copy the files into `/var/lib/vti-exchange/` first via `sudo install`.

### Step 3.5: Dump the Server DID

Export the server's DID log before starting it — you will need it to register the server's root DID in the control plane:

```bash
sudo -u dids-svc /usr/local/bin/did-hosting-server dump-did --path .well-known \
  | sudo tee /var/lib/vti-exchange/server-did.jsonl > /dev/null
sudo chown vti:vti-exchange /var/lib/vti-exchange/server-did.jsonl
sudo chmod 0640 /var/lib/vti-exchange/server-did.jsonl
```

### Step 3.6: Start services and upload DID logs

**Start the DID Hosting server:**

```bash
sudo systemctl enable --now dids-svc
sudo systemctl status dids-svc
```

**Start the mediator:**

> If you configured a passphrase for the key storage backend, set it via `sudo systemctl edit mediator-svc` with:
>
> ```ini
> [Service]
> Environment=MEDIATOR_FILE_BACKEND_PASSPHRASE=your-passphrase
> ```

```bash
sudo systemctl enable --now mediator-svc
```

**Generate an enrollment invite for the admin DID before starting the control service:**

```bash
sudo -u control-svc /usr/local/bin/did-hosting-control invite --role admin --did <Control Admin DID (3c)>
```

Save the **Enrollment URL** printed.

**Start the DID Hosting control:**

```bash
sudo systemctl enable --now control-svc
sudo systemctl status control-svc
```

**Register admin passkey:**

Visit the **Enrollment URL** in a browser, then save a passkey when prompted.

The DID Hosting Control startup overwrites the server's DID store, so the mediator and VTA DID logs must be re-uploaded after the control plane is running.

**Register server domain and root DID:**

In a browser, go to the DID Hosting Control UI at `https://control.yourdomain.com/domains` and add the server's domain (e.g., `dids.yourdomain.com`).

**Upload DID logs at `https://control.yourdomain.com/dids`:**

Click **Create Root DID**. When `.well-known` appears in the list, click the generated DID. In the **Upload DID Log** section, paste the output of:

```bash
sudo cat /var/lib/vti-exchange/server-did.jsonl
```

Click **+ New DID**, enter `mediator`, then click the generated DID. Paste:

```bash
sudo cat /var/lib/vta-svc/data/vta/did-logs/mediator-did.jsonl
```

Click **+ New DID**, enter `vta`. Paste:

```bash
sudo cat /var/lib/vta-svc/data/vta/did-logs/VTA-did.jsonl
```

Click **+ New DID**, enter `services/control`. Paste:

```bash
sudo cat /var/lib/vti-exchange/control-did.jsonl
```

## Witness and Watcher services

`setup-deploy.sh --standalone` provisions `witness-svc` and `watcher-svc` system users and systemd units alongside control and server. Their provisioning recipes follow the same shape as `did-hosting-server` (offline-prepare → VTA reprovision → offline-complete) but the detailed recipe and `bootstrap-did` flow is not yet documented here.

> _To be documented in a future revision._

For now, leave their units disabled (they were installed but not enabled). Enable them only after writing the corresponding recipes and validating against your topology.

## Next

Return to [03 — Provisioning](03-provisioning.md) Step 4 to bind PNM and finish the deploy.
