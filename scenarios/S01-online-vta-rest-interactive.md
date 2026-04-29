# S01 · Online VTA · REST · Interactive

**Setup Type:** Online VTA — connecting to an already-running VTA\
**Transport:** REST\
**Mode:** Interactive\
**Tested on:** [Ubuntu Server](../deployments/D02-ubuntu-server.md)

## Prerequisites

Complete [D02 — Ubuntu Server](../deployments/D02-ubuntu-server.md) before continuing.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | Personal VTA mnemonic phrase | Recovery |
| 1b | Personal VTA DID | Step 2, Step 3 |
| 3a | Mediator DID | Later |
| 3b | Admin DID | Later |

## Steps

### Step 1: Set up Personal VTA

Create a directory for the personal VTA:

```bash
cd ~
mkdir vta-p
```

Run the setup wizard:

```bash
cd ~/vta-p
vta setup
```

When prompted, use the values below. Replace `yourdomain.com` with your actual domain.

| Prompt | Action |
| --- | --- |
| Config file path [config.toml]: | Press **Enter** (use default) |
| VTA name (leave empty to skip): | Enter your personal VTA name |
| Services to enable (select at least one): | Select **REST API** only |
| Public URL for this VTA (leave empty to skip): | `https://vta-p.yourdomain.com` |
| Server host: | Press **Enter** (default: `0.0.0.0`) |
| Server port: | **8101** (do not use default) |
| Log level: | Press **Enter** (default: `info`) |
| Log format: | Press **Enter** (default: `text`) |
| Data directory: | Press **Enter** (default: `data/vta`) |

**BIP-39 mnemonic:**

- Choose: **Generate new 24-word mnemonic**
- > **⚠️ SAVE THIS** (1a)
  > Save the **24-word mnemonic phrase** to your notes.
  > You cannot recover this VTA without it.
- I have saved my mnemonic phrase [y/N]: → **y**

**Seed storage backend:**

- Choose: **Config file (hex-encoded seed in config.toml)**

**VTA DID:**

- Choose: **Create a new did:webvh DID**
- VTA DID URL [http://localhost:8000/]: `https://webvh.yourdomain.com/vta-p`
- Is this correct? [Y/n]: → **Y**
- DID creation mode: → **Simple — VTA creates keys and document (recommended)**
- Make this DID portable (can move to a different domain later)? [Y/n]: → **Y**
- Number of pre-rotation keys [1]: → **1**
- > **⚠️ SAVE THIS** (1b)
  > Save the **created DID**
  > (e.g. `Created DID: did:webvh:...:webvh.yourdomain.com:vta-p`)
  > to your notes.
- Save DID log to file [VTA-did.jsonl]: → Press **Enter** (saves to `VTA-did.jsonl`)

### Step 2: Connect PNM to VTA

```bash
cd ~/vta-p
pnm setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| What would you like to do?: | Choose **Connect to an existing non-TEE VTA** |
| Name for this VTA: | Enter a name for this VTA |
| VTA DID: | Paste the **Personal VTA DID** from 1b |

PNM will output a `vta import-did` command. Note it down — it contains a generated temp DID unique to this session:

```text
vta import-did --did did:key:z6Mk... --role admin
```

Run that command in the `~/vta-p` directory:

```bash
cd ~/vta-p
vta import-did --did did:key:z6Mk... --role admin
```

Then start the VTA service:

```bash
nohup vta > log.txt 2>&1 &
```

Verify the service is running:

```text
https://vta-p.yourdomain.com/health
```

You should see:

```json
{"status":"ok"}
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
| Decide whether the VTA should...: | Choose **Full setup — VTA mints my mediator DID** |
| Pick online or sealed handoff: | Choose **Online** |
| The DID of the VTA you want to connect to: | Paste the **Personal VTA DID** from 1b |
| Name of the VTA context this mediator will live in: | `mediator` |
| URL this mediator will serve at: | `https://mediator.yourdomain.com` |

The wizard generates a `pnm contexts create` command. Press **c** to copy it, then run it on the server:

```bash
pnm contexts create --id mediator --name "Mediator" --admin-did did:key:z6Mk... --admin-expires 1h
```

Back in `mediator-setup`, select **Test VTA connection** to confirm. You should see:

```text
Connected via REST.
```

Then collect and save the two DIDs:

- Press **m** to display the Mediator DID:
  > **⚠️ SAVE THIS** (3a)
  > Save the **Mediator DID**
  > (e.g. `did:webvh:...:mediator.yourdomain.com`) to your notes.
- Press **a** to display the Admin DID:
  > **⚠️ SAVE THIS** (3b)
  > Save the **Admin DID** to your notes.

Press **Enter** to continue to the next step.

**Protocol:**

| Prompt | Action |
| --- | --- |
| Toggle protocols with Enter: | Select **DIDComm v2 (recommended)** |

**SSL/TLS & JWT:**

| Prompt | Action |
| --- | --- |
| Configure transport security: | Choose **No SSL (use TLS-terminating proxy)** |
| Configure authentication tokens: | Choose **Generate a fresh JWT signing key (recommended)** |
| Enter the Redis connection URL: | Press **Enter** (default: `redis://127.0.0.1/`) |
| Configure the admin DID for mediator management: | Choose **Generate admin DID from VTA** |
| Where should the wizard write mediator.toml?: | Press **Enter** (default: `conf/mediator.toml`) |

Before starting the mediator, start Redis:

```bash
docker run --name=redis-local --publish=6379:6379 --hostname=redis \
  --restart=on-failure --detach redis:latest
```

Then start the mediator:

```bash
nohup mediator > log.txt 2>&1 &
```

## Verification

Visit the following URL to confirm the Mediator DID document is publicly accessible:

```text
https://mediator.yourdomain.com/.well-known/did.jsonl
```

You should see a JSONL file returned in the browser or via `curl`:

```bash
curl https://mediator.yourdomain.com/.well-known/did.jsonl
```

## Known Issues / Edge Cases

> _To be documented._

## Deployment Notes

> _To be documented._
