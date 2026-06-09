# Personal VTA

**Description:** Stand up a Personal VTA — the per-developer trust anchor that mints and manages your own DIDs and keys.  
**Tested on:** [Ubuntu Server](../sysop/ubuntu-server.md)

**Verified with:**

| VTA Version | Mediator Version | DID Hosting Daemon Version |
| --- | --- | --- |
| 0.6.0 | 0.15.3 | 0.7.0 |

## Prerequisites

Complete the [Ubuntu Server](../sysop/ubuntu-server.md) deployment before continuing, but only install `vta` and `pnm` in **Step 5**.

You also need the **Community Mediator DID** before starting — obtain it from the operator of the mediator you intend to use. You will paste it in Step 1.

This tutorial uses two host placeholders. Replace them with your real domains:

- **`yourdomain.com`** — a host **you control**, where your Personal VTA's REST API runs (e.g. `https://vta.yourdomain.com`).
- **`did-host.com`** — a host serving `did:webvh` content over HTTPS. The same placeholder stands in for two distinct hosts in the examples: the **community mediator's** DID host (operated by whoever runs the mediator) and the host where **you** will publish your own VTA's DID (your choice — see Step 2). These may or may not be the same domain; if you control both, you can use the same one throughout.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 0a | Community Mediator DID (pre-collected) | Step 1 |
| 1a | Personal VTA mnemonic phrase | Recovery |
| 1b | Personal VTA DID | Step 2, Step 3 |

## Steps

### Step 1: Set up Personal VTA

Create a directory for the personal VTA:

```bash
cd ~
mkdir vta
```

Run the setup wizard:

```bash
cd ~/vta
vta setup
```

When prompted, use the values below. Replace the host placeholders (see Prerequisites) with your real domains.

| Prompt | Action |
| --- | --- |
| Config file path [config.toml]: | Press **Enter** (use default) |
| VTA name (leave empty to skip): | Enter your personal VTA name |
| Services to enable (select at least one): | Press **Enter** (default: **REST API** and **DIDComm Messaging**) |
| Server host: | Press **Enter** (default: `0.0.0.0`) |
| Server port: | Press **Enter** (default: `8100`) |
| VTA REST URL [http://localhost:8101]: | `https://vta.yourdomain.com` |
| Log level: | Press **Enter** (default: `info`) |
| Log format: | Press **Enter** (default: `text`) |
| Remote DID resolver WebSocket URL (leave empty to resolve locally): | Press **Enter** (resolve locally) |
| Audit-log retention (days) [28]: | Press **Enter** (use default) |
| Data directory: | Press **Enter** (default: `data/vta`) |

**BIP-39 mnemonic:**

- > **⚠️ SAVE THIS** (1a)
  > Save the **24-word mnemonic phrase** to your notes.
  > You cannot recover this VTA without it.
- I have saved my mnemonic phrase [y/N]: → **y**

**Seed storage backend:**

- Choose: **Config file (hex-encoded seed in config.toml)**

**DIDComm Messaging:**

| Prompt | Action |
| --- | --- |
| DIDComm messaging: | Choose **Use an existing mediator DID** |
| Mediator DID: | Paste the **Community Mediator DID** from 0a (e.g. `did:webvh:...:did-host.com:mediator`) |
| Mediator hostname for vsock-bridged TEE deployments: | Press **Enter** (skip) |

**VTA DID:**

| Prompt | Action |
| --- | --- |
| VTA DID: | Choose **Create a new `did:webvh` DID** |
| VTA DID URL: | `https://did-host.com/your-did-path` |
| Is this correct? [Y/n]: | Press **Enter** → **Y** |
| DID creation mode: | Press **Enter** (default: **Simple — VTA creates keys and document**) |
| Make this DID portable (can move to a different domain later)? [Y/n]: | Press **Enter** → **Y** |
| Number of pre-rotation keys [1]: | Press **Enter** (use default) |
| Save DID log to file [VTA-did.jsonl]: | Press **Enter** (use default) |

When all prompts are complete, the wizard prints:

```text
Setup complete!
  Config saved to: config.toml
  Seed stored in configured backend
  Seed backend: config file (hex-encoded in config.toml)
  VTA Name: <your VTA name>
  VTA REST URL: https://vta.yourdomain.com
  VTA DID: did:webvh:...:did-host.com:your-did-path
  Services: REST, DIDComm
  Server: 0.0.0.0:8100
  Mediator DID: did:webvh:...:did-host.com:mediator
  Contexts: vta (m/26'/2'/0')
```

> **⚠️ SAVE THIS** (1b)
>
> From the summary above:
>
> - **Personal VTA DID** (1b): the `VTA DID:` line

### Step 2: Publish Personal VTA DID

For other parties (mediators, peers, verifiers) to resolve your `did:webvh` DID, the **DID log** generated in Step 1 must be served at a public HTTPS URL. The URL is not a free choice — the `did:webvh` resolver derives it directly from the DID identifier, so the path you publish under must match the **VTA DID URL** you entered during `vta setup` (e.g. `https://did-host.com/your-did-path`). The resolver will fetch `https://did-host.com/your-did-path/did.jsonl`.

The wizard wrote your DID log to `~/vta/VTA-did.jsonl`. View it with:

```bash
cd ~/vta
cat VTA-did.jsonl
```

You need to publish that file (renamed to `did.jsonl`) at the matching URL. Stage it for upload by copying it under the chosen name:

```bash
cp ~/vta/VTA-did.jsonl did.jsonl
```

You do **not** need to run a DID Daemon for this tutorial — any plain static-file host will work.

Common hosting options:

- **GitHub Pages** — commit `did.jsonl` to a repo, enable Pages, and attach a custom domain that matches the host portion of your VTA DID URL. Place the file under the same path segment (e.g. `your-did-path/did.jsonl` in the repo root).
- **Your own website / static host** — copy the file to your web server (nginx, Apache, Caddy, …) under the matching path.
- **Object storage + CDN** — upload to S3, GCS, or Cloudflare R2 behind a CDN that terminates HTTPS, with the bucket key mapping to the expected path.

Technical considerations:

- **HTTPS is required.** Plain HTTP is rejected by `did:webvh` resolvers, and a misconfigured TLS chain will fail resolution silently.
- **Path and filename must match exactly.** The resolver computes the URL from the DID — a trailing slash, an extra path segment, or a renamed file will cause resolution to fail. Hosts that append `index.html` or strip `.jsonl` need to be configured around.
- **Serve as plain text.** Set `Content-Type` to `text/plain` or `application/jsonl`; the file is line-delimited JSON. Hosts that auto-detect MIME from extension are usually fine.
- **CORS may matter.** If a browser-based resolver (e.g. a wallet UI) ever needs to fetch the log, set `Access-Control-Allow-Origin: *` on the response.
- **Republish on every change.** Each key rotation or document update appends a new line to `VTA-did.jsonl`. Re-upload the **entire** file each time — never truncate, never reorder, and never edit prior entries, since the log is hash-chained and resolvers will reject a tampered history.
- **Only the DID log is public.** Do **not** host your `config.toml`, the mnemonic (1a), or anything from `data/vta/`. The log file alone is meant to be world-readable.

Once the file is reachable, sanity-check it from another machine:

```bash
curl -sSf https://did-host.com/your-did-path/did.jsonl | head -n 1
```

You should see the first line of the DID log returned over HTTPS.

### Step 3: Connect PNM to VTA

> **ℹ️ NOTE**
>
> You can run the PNM from anywhere; it does not need to be running on the same machine as your VTA.

Step 3 depends on Step 2 — the PNM resolves your Personal VTA DID over HTTPS, so the `did.jsonl` must already be reachable at the URL you configured.

```bash
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

Run that command in the `~/vta` directory on the machine where you installed the VTA:

```bash
cd ~/vta
vta import-did --did did:key:z6Mk... --role admin
```

The wizard then prints:

```text
DID imported: did:key:z6Mk...
Role: admin
Contexts: unrestricted

--- Connection info (share with DID owner) ---
Community VTA DID: did:webvh:...:did-host.com:your-did-path
Community VTA URL: https://vta.yourdomain.com
```

Now start up the VTA:

```bash
cd ~/vta
nohup vta > log.txt 2>&1 &
```

## Verification

Confirm the VTA is responding:

```bash
curl -sSf https://vta.yourdomain.com/health
```

It should return: `{"status":"ok"}`

You can also check it from the machine running the PNM:

```bash
pnm health
```

It should return the status of a number of checks it runs against the VTA, the Mediator and a DIDComm trust ping.

## Known Issues / Edge Cases

> _To be documented._

## Deployment Notes

> _To be documented._
