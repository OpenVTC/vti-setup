# Personal VTA

**Description:** Stand up a Personal VTA — the per-developer trust anchor that mints and manages your own DIDs and keys.  
**Tested on:** [Ubuntu Server](../sysop/explore/01-server-setup.md) 26.04 (Path B only — Path A runs in VTA Farm's managed cluster)

**Verified with:**

| Release | VTA | PNM | Mediator | DID Hosting |
| --- | --- | --- | --- | --- |
| VTI-Fig | 0.87.2 | 0.66.2 | 0.56.0 | 0.12.0 |

**Path B was verified by an automated run** on a fresh Ubuntu 26.04 server: every wizard was driven through tmux and its screens compared with this page. Not tested on macOS, Windows/WSL, or with a hardware security key. **Path A is not part of the automated runs**, because VTA Farm's sign-up needs an email address. Its PNM step below matches the VTI-Fig `pnm`, but its VTA Farm screens past the sign-up form are from an earlier release. See [Versions](../README.md#versions).

## Two paths

There are two ways to bring up a Personal VTA. Both end in the same place: a running VTA holding your master keys, reachable from your PNM. The downstream tutorials ([OpenVTC TUI](02-openvtc-tui.md), [Joining a Community](03-joining-a-community.md)) work the same regardless of which path you take.

- **[Path A — VTA Farm (streamlined, recommended)](#path-a--vta-farm-streamlined)** — [VTA Farm](https://vtafarm.firstperson.dev) spins up your VTA in a managed Kubernetes cluster (the sysop [Deploy stream](../sysop/deploy/) describes how a farm is built). You provision it from a browser with a passkey and connect your local PNM to it. No server, no public domain, no DID hosting, no mediator wiring on your side.
- **[Path B — VTA the hard way (self-hosted)](#path-b--vta-the-hard-way-self-hosted)** — run the VTA on a host you control, publish your own `did:webvh` DID log, and wire it to a community mediator yourself. More moving parts, more to learn.

Pick whichever fits how much infrastructure you want to manage. If you're new to the stack, take Path A.

## Path A — VTA Farm (streamlined)

> **ℹ️ Just want a VTA, without an account?** The VTA Farm's home page also offers **Create your first Trust Agent**. It needs no Farm account: you install the **Keyring** app on your phone, press **Get my Trust Agent**, scan the QR code with Keyring and compare a six-character code, and the Farm hands Keyring a VTA it has already prepared. The page then walks you through joining a demo community from Keyring. That VTA's administrator is Keyring, not PNM, so this path doesn't lead into the PNM and OpenVTC guides here. To follow them, set up an account as below.

### Prerequisites

- A computer with **passkey** support.
- **PNM installed locally.** PNM is a CLI tool and can run on your computer — it does not need its own server. Download it for [Linux (x86-64)](https://download.firstperson.dev/pnm/latest/pnm) or [macOS](https://download.firstperson.dev/releases/latest/macOS/pnm). PNM changes quickly and some of its changes break older VTAs, so take it from the same release as your VTA.

The following values will be collected during setup. Save each one as prompted — they are needed across steps.

| ID | What to Save | Used In |
| --- | --- | --- |
| 1a | Personal VTA DID (from VTA Farm UI) | Step 2 |
| 2a | Temp DID (`did:key:...` from PNM) | Step 3 |

### Steps

#### Step 1: Create the VTA in VTA Farm

1. At the [VTA Farm](https://vtafarm.firstperson.dev), click **Set up an account**, enter your email address, and click **Create account with Passkey**.
2. Complete the passkey prompt on your computer.
3. Click **Create VTA**.
4. Enter a **name** for your VTA, leave the default image selected, and click **Create session**.
5. Copy the **VTA DID** displayed on the page.

> **⚠️ SAVE THIS** (1a)
>
> The **Personal VTA DID** shown in the VTA Farm UI. You'll paste it into PNM in the next step.

#### Step 2: Connect PNM

```bash
pnm setup
```

When prompted:

| Prompt | Action |
| --- | --- |
| What would you like to do?: | Choose **Connect to an existing non-TEE VTA** |
| Name for this VTA: | Enter the **same name** you used in Step 1 |
| VTA DID (leave blank to finish setup later): | Paste the **Personal VTA DID** from 1a |

PNM first generates a temporary admin identity and prints it, with a **Next steps** list, before it asks for the name. After you paste the VTA DID, it stores the session and prints it again:

```text
Session stored for '<your-vta-name>'.

  VTA slug: <your-vta-name>
  VTA DID:  did:webvh:...
  Temp DID: did:key:z6Mk...
```

PNM then checks whether the VTA accepts the Temp DID yet. It doesn't, so PNM prints a `vta import-did` command for it. That command is for a self-hosted VTA; on the VTA Farm you paste the DID into the browser instead.

> **⚠️ SAVE THIS** (2a)
>
> The **Temp DID**: the `Temp DID:` line from PNM's output. You'll paste it into VTA Farm in the next step. Copy just the DID, for example: **did:key:z6MkqYgeCR8hJS9A5Eu98hfMBiYHb8MZ8S9R2Mz4PqErZyLF**

#### Step 3: Provision the agent

Back in the VTA Farm browser tab:

1. Paste the **Temp DID** from 2a into the **Admin DID** input box.
2. Click **Provision agent**.
3. Wait for the **Agent is online** message.

### Verification

From the PNM machine:

```bash
pnm health
```

It should return the status of a number of checks it runs against the VTA, the Mediator, and DIDComm/TSP trust pings.

### Next

Assuming the health check is successful, you can now install the TUI and bind it to this VTA: [02 — OpenVTC TUI Setup](02-openvtc-tui.md).

## Path B — VTA the hard way (self-hosted)

### Prerequisites

Complete the [Ubuntu Server](../sysop/explore/01-server-setup.md) deployment before continuing, but only install `vta` and `pnm` in **Step 5**.

> **Which PNM build?** Step 5 of that guide installs the `pnm-server` build, which keeps secrets in plaintext config instead of an OS keyring — the right choice for the headless server you are standing up. If you would rather drive that VTA from your own workstation, install the default build there instead, from the [Linux (x86-64) download](https://download.firstperson.dev/pnm/latest/pnm). Either way the binary is called `pnm`, so every command below is unchanged.

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

### Steps

#### Step 1: Set up Personal VTA

Create a directory for the personal VTA and run the setup wizard:

```bash
cd ~
mkdir vta
cd ~/vta
vta setup
```

When prompted, use the values below. Replace the host placeholders (see Prerequisites) with your real domains.

| Prompt | Action |
| --- | --- |
| Config file path [config.toml]: | Press **Enter** (use default) |
| VTA name (leave empty to skip): | Enter a name for this VTA |
| Services to enable (select at least one): | Press **Enter** (REST, DIDComm and TSP are all selected by default) |
| Server host [0.0.0.0]: | Press **Enter** (use default) |
| Server port [8100]: | Press **Enter** (use default) |
| VTA REST URL [http://localhost:8100]: | `https://vta.yourdomain.com` |
| Log level [info]: | Press **Enter** (use default) |
| Log format: | Press **Enter** (default: **text**) |
| Audit-log retention (days) [28]: | Press **Enter** (use default) |
| Data directory [data/vta]: | Press **Enter** (use default) |
| Configure advanced server options (CORS, trusted proxy CIDRs, WebAuthn)? [y/N] | Press **Enter** (use default) |
| Seed storage backend: | Press **Enter** (default: Config file) |
| Enable hardened configuration? (encrypts the fjall store...) y/N | Press **Enter** (use default) |

**Seed storage backend:** the default, **Config file (hex-encoded seed in config.toml)**, is first in the list. The other choices are **Encrypted file (passphrase, systemd-creds or TPM key)** and **Plaintext file (NOT recommended)**.

**DIDComm Messaging:**

| Prompt | Action |
| --- | --- |
| DIDComm messaging: | Choose **Use an existing mediator DID** |
| Mediator DID: | Paste the **Community Mediator DID** from 0a (e.g. `did:webvh:...:did-host.com:mediator`) |
| Mediator hostname for vsock-bridged TEE deployments (leave empty to skip): | Press **Enter** (skip) |
| Automatically provision ACL on mediator after connecting? (enable if mediator uses ExplicitAllow mode) [y/N] | Press **Enter** (use default) |

The wizard then checks the mediator and prints `Mediator did:webvh:... advertises TSP.` If it says the mediator advertises no TSP service instead, TSP is dropped from your VTA's services; DIDComm still works.

**VTA DID:**

| Prompt | Action |
| --- | --- |
| VTA DID: | Press **Enter** (default: **Create a new did:webvh DID (recommended for production)**) |
| VTA DID URL [http://localhost:8000/]: | `https://did-host.com/your-did-path` |
| DID creation mode: | Press **Enter** (default: **Simple — VTA creates keys and document (recommended)**) |
| Make this DID portable (can move to a different domain later)? [Y/n]: | Press **Enter** → **Y** |
| Number of pre-rotation keys [1]: | Press **Enter** (use default) |
| Present this VTA's DIDs as: | Press **Enter** (default: **did:webvh (recommended; what every existing peer expects)**) |
| List the did:scid alias in alsoKnownAs, so peers can also use that form? [Y/n] | Press **Enter** → **Y** |

**BIP-39 mnemonic:**

- > **⚠️ SAVE THIS** (1a)
  > Save the **24-word mnemonic phrase** to your notes.
  > You cannot recover this VTA without it.
- I have saved my mnemonic phrase [y/N]: → **y**

| Prompt | Action |
| --- | --- |
| Save DID log to file [VTA-did.jsonl]: | Press **Enter** (use default) |

When all prompts are complete, the wizard prints `To self-host this DID, upload VTA-did.jsonl to the DID URL.` (that is Step 2) and then:

```text
Setup complete.
  Config:   config.toml
  Data dir: data/vta
  Name:     <your VTA name>
  URL:      https://vta.yourdomain.com
  VTA DID:  did:webvh:...:did-host.com:your-did-path
  Mediator: did:webvh:...:did-host.com:mediator

  ACL is empty. Seed the first admin:
  ...
```

The rest of the summary describes two ways to add the first admin. Step 3 uses the first, `vta import-did`.

> **⚠️ SAVE THIS** (1b)
>
> From the summary above:
>
> - **Personal VTA DID** (1b): the `VTA DID:` line

#### Step 2: Publish Personal VTA DID

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

#### Step 3: Connect PNM to VTA

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
| VTA DID (leave blank to finish setup later): | Paste the **Personal VTA DID** from 1b |

PNM first generates a temporary admin identity and prints it, with a **Next steps** list, before it asks for the name. After you paste the VTA DID, it stores the session, prints the `Temp DID:`, and checks whether the VTA accepts it yet. The VTA isn't running, so expect an error like this, followed by the command to run:

```text
Could not reach did:webvh:... to check whether it accepts did:key:z6Mk...: tsp transport error:
 TSP relationship failed: ... status(403) ... "Message not accepted for delivery" ...
If the VTA has not granted this identity admin access yet, ask your VTA admin to run:

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

#### Step 4: Get DID hosting for your personas

OpenVTC, in the next two guides, mints a `did:webvh` persona for each community you join. It asks your VTA to create the persona on a **DID hosting server**, and that server must let your VTA in. A VTA Farm VTA comes with this already; a self-hosted one does not. Without it, creating a persona stalls at `Creating persona DID via did-hosting-daemon…`. The VTA retries every 30 seconds, and the server's log says `trust task refused: sender has no ACL entry`.

Ask the operator of a DID Hosting Daemon (on an [explore box](../sysop/explore/02-walkthrough.md#step-4-set-up-did-hosting-daemon), that's you) to add your **Personal VTA DID** (1b) to its ACL. The command needs the daemon stopped, so it is a short restart:

```bash
cd ~/dids
pkill -f did-hosting-daemon
did-hosting-daemon add-acl --did <Personal VTA DID (1b)> --label personal-vta
nohup did-hosting-daemon >> log.txt 2>&1 &
```

The default role, `owner`, is enough. Then, from your PNM, register that server with your VTA, using the daemon's own DID (**DID Host DID (4b)** on an explore box):

```bash
pnm did-mgmt servers add --id did-hosting-daemon --did <DID Hosting Daemon DID>
```

### Verification

Confirm the VTA is responding:

```bash
curl -sSf https://vta.yourdomain.com/health
```

It should return: `{"status":"ok"}`

You can also check it from the machine running the PNM:

```bash
pnm health
```

It should return the status of a number of checks it runs against the VTA, the Mediator and DIDComm/TSP trust pings, each marked ✓. The first successful connection also replaces PNM's temporary DID with a long-lived one.

### Next

Install the TUI and bind it to this VTA: [02 — OpenVTC TUI Setup](02-openvtc-tui.md).
