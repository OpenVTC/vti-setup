# Explore 03: Verifiable Git Infrastructure

Put a GitHub organization under the VTC you stood up in [02 — Walkthrough](02-walkthrough.md): the community decides who owns, who may merge and who may commit to each repository, publishes the commit rights to its Trust Registry, and a **bridge** turns those decisions into GitHub roles and a required pull-request check. Members link their GitHub accounts and sign commits with keys their VTA holds.

The shape to hold in your head: **the VTC decides, the bridge acts, the registry answers.** Rights are records in the VTC. The bridge, `vgi-bridge`, is the one service holding the community's GitHub App; the VTC sends it jobs over TSP or DIDComm and never talks to GitHub itself. CI reads the registry. Nobody edits GitHub by hand.

> **⚠️ Explore stream — do not use for real keys.**
> Same box, same rules as the walkthrough: everything runs as root under `/root/<svc>/` ([why root?](01-server-setup.md#why-root)). Run every command on this page from a root shell on the box unless it says otherwise.

**Tested on:** Ubuntu Server 26.04 ([Explore 01: Server Setup](01-server-setup.md))

**Verified with:**

| Build | VTA | VTC | DID Hosting Daemon | `vgi-bridge` | `cnm` | `did-git-sign` |
| --- | --- | --- | --- | --- | --- | --- |
| Nightly, 2026-10-22 | 0.64.0 | 0.12.0 | 0.11.0 | 0.20.0 (release) | 0.38.0 | 0.18.2 |

The mediator and Trust Registry were the same day's nightly builds. The bridge is a tagged release of [verifiable-git-infrastructure](https://github.com/OpenVTC/verifiable-git-infrastructure) (VGI); its own operator guide is [SETUP-GITHUB-VTC.md](https://github.com/OpenVTC/verifiable-git-infrastructure/blob/main/docs/SETUP-GITHUB-VTC.md), and the VTC side is [git-namespaces.md](https://github.com/OpenVTC/verifiable-trust-infrastructure/blob/main/docs/03-vtc/git-namespaces.md). This page is the explore-box walk through both.

## Prerequisites

- [01 — Server setup](01-server-setup.md) and [02 — Walkthrough](02-walkthrough.md) are complete, and the stack is running. If the box has rebooted since, start the services **in this order, waiting for each to come up**: DID Hosting Daemon, Mediator, VTA, Trust Registry, VTC. A registry started before the VTA boots from its cached bundle and reports `degraded`, and a degraded registry means no git right ever reaches CI. `curl -s http://127.0.0.1:3232/health` must answer `{"status":"OK","writes":"ok"}` before you go on.
- A **GitHub organization you own**. The Free plan works; the merge gate is then a check the bridge posts itself. On Team or Enterprise the bridge installs an organization required workflow instead. A personal account also works, with less (the bridge cannot create repositories there); the VGI guide's §9.1 covers the differences.
- A DNS **A record** for the bridge, `bridge.yourdomain.com`, pointing at the box, DNS only like the others. A wildcard record covers it.
- A browser where you are signed in to GitHub as an organization owner and to the VTC admin console (the passkey from Step 6 of the walkthrough).

This page uses the IDs the walkthrough had you save, plus these new ones:

| ID | What to Save | Used In |
| --- | --- | --- |
| 1b | VTA DID (walkthrough) | Step 4 |
| 6a | VTC DID (walkthrough) | Steps 2 & 4 |
| 7a | `cnm` community identity DID | Steps 2, 8 & 9 |
| 7b | Bridge DID | Step 5 |
| 7c | Namespace id (`ns_…`) | Steps 9 & 10 |

## Steps

### Step 1: Install a server build of `cnm`

Every change on this page is a signed Trust Task sent by `cnm`, the Community Network Manager. The default `cnm` build keeps its session in the OS keyring, which a headless box does not have, and stops with `the OS credential store is unavailable`. You need the **config-session** build, the counterpart of the `pnm-server` build the walkthrough installed. It keeps the session in `/root/.config/cnm/sessions.json`, in plaintext, which is acceptable on the explore box and nowhere else.

A pre-built `cnm-server` binary is not on the download server yet, so build it. The checkout from [Server Setup, Option B](01-server-setup.md#option-b-build-from-source) is at `~/fpp/verifiable-trust-infrastructure` if you built from source; otherwise clone it now, on the `nightly` branch to match the binaries you downloaded:

```bash
mkdir -p ~/fpp && cd ~/fpp
git clone --depth 1 --branch nightly https://github.com/OpenVTC/verifiable-trust-infrastructure.git
cd verifiable-trust-infrastructure
cargo build --release -p cnm-cli --no-default-features --features config-session
install -m 0755 target/release/cnm /usr/local/bin/cnm
```

On the recommended 2 vCPU / 4 GB box the build takes 20 to 40 minutes. If you would rather build on a faster Linux machine and copy the binary over, build it the same way there, and check before copying that it asks for no newer glibc than the box has (`ldd --version` on the box; `objdump -T target/release/cnm | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1` on the binary), since the two must agree.

**Check:**

```bash
cnm community list
```

> **Expected result:** `No communities configured.`, with a note that sessions are stored as plaintext. The DBus error means you still have the keyring build.

### Step 2: Give `cnm` an identity at the VTC

`cnm` acts as a `did:key` of its own, which must be a **community administrator** at the VTC: binding a namespace needs that authority, and so do the elevated grants later. The identity is minted on the box, granted while the VTC is stopped, and rotated to a fresh key once it has signed in.

Mint it, naming the **VTC DID** (6a):

```bash
cnm community add "My Community" --slug mine --vtc-did <VTC DID (6a)>
```

It prints the grant routes and one JSON line ending in `"state":"pending"`. Copy the `Admin DID` (`did:key:z6Mk…`).

Stop the VTC and grant that DID offline (the command opens the VTC's store directly, which it can only do while the daemon is stopped):

```bash
kill $(pgrep -x vtc)
cd ~/vtc
vtc --config config.toml acl add --did <Admin DID from above> --role admin --label cnm
nohup vtc > log.txt 2>&1 &
```

> **Expected result:** `Added ACL entry for did:key:… (role admin; community-admin: everything).` The VTC audits an offline write as a break-glass at its next start and lists it under Actions in the console; that is expected.

Once `https://vtc.yourdomain.com` answers again, finish the profile. `continue` signs in as the granted key and immediately rotates to a new one, so the DID you just pasted loses all standing:

```bash
cnm community continue mine
cnm community use mine
```

> **⚠️ SAVE THIS** (7a)
>
> Save the DID in `continue`'s last line, `cnm authenticates to it as did:key:…`. That is the **`cnm` community identity** (7a): it will hold the first namespace admin right, and every grant you make is signed by it.

**Check:**

```bash
cnm git namespace list
```

> **Expected result:** `No namespaces.` A `notAdministrator` refusal means the ACL grant did not land; `permissionDenied` or an authentication error means `continue` did not complete.

### Step 3: Install the bridge

The bridge is a single binary from the VGI release. Download the tarball and its checksum, verify, install:

```bash
mkdir -p ~/vgi-bridge-dl && cd ~/vgi-bridge-dl
curl -fsSLO https://github.com/OpenVTC/verifiable-git-infrastructure/releases/download/v0.20.0/vgi-bridge-x86_64-unknown-linux-gnu.tar.gz
curl -fsSLO https://github.com/OpenVTC/verifiable-git-infrastructure/releases/download/v0.20.0/vgi-bridge-x86_64-unknown-linux-gnu.tar.gz.sha256
sha256sum -c vgi-bridge-x86_64-unknown-linux-gnu.tar.gz.sha256
tar xzf vgi-bridge-x86_64-unknown-linux-gnu.tar.gz
install -m 0755 vgi-bridge-x86_64-unknown-linux-gnu/vgi-bridge /usr/local/bin/vgi-bridge
vgi-bridge --help
```

The binary needs `libdbus-1-3` and `git` at run time; the setup script installed both. The release also carries a build provenance attestation, checkable with `gh attestation verify` from a machine that has `gh`; the VGI README has the command.

GitHub sends webhooks and browser redirects to the bridge, so it needs an HTTPS front like the other services. Add an Nginx site in the same shape the setup script wrote for them, then get its certificate:

```bash
cat > /etc/nginx/sites-available/bridge.conf <<'NGX'
server {
    listen 80;
    server_name bridge.yourdomain.com;
    client_max_body_size 2m;

    location /healthz {
        allow 127.0.0.1;
        deny all;
        proxy_pass http://127.0.0.1:8080;
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $host;
    }
}
NGX
ln -sf /etc/nginx/sites-available/bridge.conf /etc/nginx/sites-enabled/bridge.conf
nginx -t && systemctl reload nginx
certbot --nginx -d bridge.yourdomain.com --non-interactive --agree-tos
```

Replace `yourdomain.com` in the `server_name` line and the `certbot` command. The `/healthz` block keeps the health endpoint off the public internet, as the bridge's guide asks.

> **Expected result:** Certbot reports `Successfully deployed certificate for bridge.yourdomain.com`. `https://bridge.yourdomain.com/` answers `502 Bad Gateway` until the bridge runs.

### Step 4: Set up the bridge

`vgi-bridge setup` writes the whole bridge folder: its configuration, a credential for a trust context of its own in the VTA, and the bridge's `did:webvh`, minted into that context on your DID Hosting Daemon. The bridge then keeps its secrets and state in the VTA, and the box holds only the credential, so a lost box is recovered by issuing a new one. It needs the **VTC DID** (6a), the **VTA DID** (1b), the bridge's public URL and the organization's GitHub login, in lowercase:

```bash
vgi-bridge setup \
  --vtc <VTC DID (6a)> \
  --vta <VTA DID (1b)> \
  --dir /root/vgi-bridge \
  --public-url https://bridge.yourdomain.com/ \
  --owner <github-org-login> \
  --service none
```

Setup resolves the Trust Registry and the mediator from the VTC's DID document and prints them, fetches GitHub's `web-flow` key, pins the check to this release's commit, then prints a temporary `did:key` and two `pnm` commands, and waits:

```text
A temporary admin DID for this setup (held in memory only):
  did:key:z6Mk…

  If the context `vgi-bridge` does not exist yet:
    pnm contexts create --id vgi-bridge --name "vgi-bridge" \
        --admin-did did:key:z6Mk… --admin-expires 1h --admin-handoff

Press Enter once one of them has run (Ctrl+C to stop)…
```

In a second root shell, run the **first** command exactly as printed (the context is new). Then press Enter in the setup shell. Setup authenticates over TSP, has the VTA roll the temporary grant over to a long-term credential scoped to the `vgi-bridge` context, mints the bridge's DID, and runs its checks:

```text
  wrote /root/vgi-bridge/vta-credential.json (0600): did:key:…
Wrote /root/vgi-bridge/bridge.toml
  minted the bridge's DID did:webvh:…:dids.yourdomain.com:<word-word>
  ok       context `vgi-bridge` exists, DID `did:webvh:…`
  ok       the credential fetches the DID's keys, and its current document lists 2 of them …
  ok       the key secrets are sealed under (`vgi-bridge/app-state-seal`) is in the context and exports
  ok       the credential writes, reads and deletes app-state (`vgi-bridge`)
  ok       the credential reaches `vgi-bridge` only

The bridge's DID:
  did:webvh:…:dids.yourdomain.com:<word-word>
```

> **⚠️ SAVE THIS** (7b)
>
> Save **The bridge's DID** (7b). `vgi-bridge --config /root/vgi-bridge/bridge.toml identity show` prints it again.

The folder now holds `bridge.toml` (nothing secret in it), `vta-credential.json` (owner-only), `web-flow.asc` and `data/`. With `--service none` setup wrote no service file; run the bridge under systemd so it survives a reboot and comes back after the VTA does:

```bash
cat > /etc/systemd/system/vgi-bridge.service <<'UNIT'
[Unit]
Description=VGI bridge (VTC-governed git namespaces)
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/vgi-bridge
ExecStart=/usr/local/bin/vgi-bridge --config /root/vgi-bridge/bridge.toml run
Restart=always
RestartSec=10
StandardOutput=append:/root/vgi-bridge/bridge.log
StandardError=append:/root/vgi-bridge/bridge.log

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now vgi-bridge.service
```

`Restart=always` matters after a reboot: the bridge needs its keys from the VTA, retries for five minutes, then exits, and systemd starts it again. (If you prefer `nohup` like the other services, the command is `vgi-bridge --config /root/vgi-bridge/bridge.toml run`.)

**Check:**

```bash
curl -s http://127.0.0.1:8080/healthz
grep -E "connected to the mediator|register\?state=" /root/vgi-bridge/bridge.log | tail -2
```

> **Expected result:** `ok`, a line `connected to the mediator`, and a WARN naming a one-time registration link, `https://bridge.yourdomain.com/github/github.com/<org>/register?state=…`. Keep that link for Step 6; the bridge prints a fresh one at every start until an App is registered.

### Step 5: Point the VTC at the bridge

The VTC refuses a bridge-mode bind for a forge it has no bridge for. Tell it which bridge serves `github.com`, with the **bridge DID** (7b). The walkthrough's `vtc setup` already wrote a `[git_ns]` section with an empty `[git_ns.bridges]` table; add one line under it:

```bash
cd ~/vtc
vi config.toml
```

```toml
[git_ns]
elevated_requires_admin = true
tick_seconds = 5

[git_ns.bridges]
"github.com" = "<bridge DID (7b)>"
```

If your config has no `[git_ns]` section at all, add the whole block. Unknown keys fail the start, so a typo shows up at once. The section is read only at start, so restart the VTC:

```bash
kill $(pgrep -x vtc)
nohup vtc > log.txt 2>&1 &
```

**Check:** `cnm git namespace list` still answers `No namespaces.`, and `grep "git-ns projector" ~/vtc/log.txt` shows `git-ns projector starting … registry=true`.

### Step 6: Register the GitHub App and enable Device Flow

The bridge registers its own GitHub App through GitHub's manifest flow, so no one copies a private key by hand. Two things happen in the browser, **as an owner of the organization**:

1. Open the registration link from the bridge log (Step 4). The page posts the App manifest to GitHub; review it and create the App. GitHub redirects back to the bridge, which stores the App's id, private key and webhook secret sealed in the VTA.
2. Open `https://github.com/organizations/<org>/settings/apps/<org>-vgi-bridge`, tick **Enable Device Flow**, and save. The manifest cannot turn this on, and members cannot link their GitHub accounts without it.

**Check:**

```bash
grep -E "is registered for|refused a registration|registration failed" /root/vgi-bridge/bridge.log | tail -1
```

> **Expected result:** a line of the form
>
> ```text
> the GitHub App `<org>-vgi-bridge` is registered for `<org>` on github.com and in service (app_id …)
> ```

### Step 7: Bind the organization

Bind the community to the organization. `--mode` defaults to `manual` (no bridge, rights only), so say `bridge`:

```bash
cnm git namespace bind --forge github.com --owner <github-org-login> --mode bridge
```

`cnm` first says what binding makes public: every right granted in the namespace is published to the community's Trust Registry, where anyone can read who owns and who may commit to each repository. Then it prints the namespace as `pending` with an installation link:

```text
github.com/<org> — pending (ns_…)
Prove control of the owner on the forge to finish binding:
  https://github.com/apps/<org>-vgi-bridge/installations/new?state=…
```

> **⚠️ SAVE THIS** (7c)
>
> Save the **namespace id** (7c), the `ns_…` in parentheses.

**An organization owner opens that link within 15 minutes** and installs the App, choosing **All repositories**. The bridge must see every repository the community adopts or creates; one outside the installation's selection does not exist to it. GitHub redirects back to the bridge, which completes the bind. The VTC then marks the namespace bound, gives the `cnm` identity (7a) the first `git.ns.admin`, and grants the bridge a `git.commit.sign` service grant on the namespace so the commits it re-signs for Dependabot pass.

**Check:**

```bash
cnm git namespace list
cnm --json git namespace list
```

> **Expected result:** `github.com/<org>  ns_…  bridge bound  admins: 1  repos: 0`. In the JSON, `forgeStatus.appRegistration` is `registered`, `missingPermissions` is empty, and `roleMapSource` is `reported`. On a Free organization `orgRulesets` is `false` and `bridgePostedCheck` is `true`; that is the merge gate you will get. If `missingPermissions` is not empty, the owner declined something at install; accept it at `https://github.com/organizations/<org>/settings/installations`.

The same namespace is now on the admin console at `https://vtc.yourdomain.com/admin` under **Community → Repos**. The page reads and writes only signed Trust Tasks, so the first visit asks you to **Set up signing** (a console key approved with your passkey) before it shows anything.

### Step 8: Give the `cnm` identity a passkey

The walkthrough set the community up in **single-administrator mode**. In that mode you may grant yourself an elevated right (`git.repo.own`, `git.repo.create`, `git.ns.admin`), which separation of duties would otherwise leave to a second administrator, by answering a passkey step-up bound to that one request. The `cnm` identity (7a) has no passkey yet, so any such grant is refused with `step-up required: … holds no step-up factor at this community`. Mint it a passkey invite now, while the VTC is stopped, the same way the walkthrough re-minted the install URL:

```bash
kill $(pgrep -x vtc)
cd ~/vtc
vtc --config config.toml admin invite --did <cnm identity DID (7a)> --ttl 3600
nohup vtc > log.txt 2>&1 &
```

It prints an **Install URL** and a **Claim code** and leaves the existing ACL entry untouched. Once the VTC is back, open the URL in your browser, enter the code, and register a passkey. It is recorded against the `cnm` identity.

You can skip this step if every elevated right will go to **other** members, never to the `cnm` identity itself.

### Step 9: Adopt a repository

An existing repository is **adopted**; a new one is created with `cnm git create`. Adoption records the owners and has the bridge inspect the repository and set up whatever the merge gate needs. Owners must be **current members** of the community, named by DID; the walkthrough's join flow gave your persona one (`cnm access list` lists every entry). Adopt is an elevated action, so under the default configuration the `cnm` identity signs it as a community administrator:

```bash
cnm git adopt github.com/<org>/<repo> --owner <member persona DID>
```

Naming the `cnm` identity itself as an owner is a self-grant. The first send is refused with a step-up request, and `cnm` prints a link to open in the browser:

```text
Open this in a browser and confirm with your passkey …
  https://vtc.yourdomain.com/v1/admin/step-up#request=…
Paste the answer code the page shows and press Enter; if the page says the gesture is recorded, just press Enter (within five minutes).
```

> **The link may be wrong in `cnm` 0.38.0 and earlier.** It is built on the API base and so carries `/v1`, which this VTC answers with the community website. Open `https://vtc.yourdomain.com/admin/step-up#request=…` instead, keeping everything after `#` exactly as printed. Fixed in [verifiable-trust-infrastructure#2267](https://github.com/OpenVTC/verifiable-trust-infrastructure/pull/2267).

Confirm with the passkey from Step 8, then press Enter in the shell. `cnm` sends the identical document again and reports `Single-administrator waiver applied`; the VTC writes a Critical audit row, by design.

On a Free organization the bridge then sets up the **bridge-posted check**: no workflow in the repository, the bridge runs the commit check itself and posts *Verify commit trust* on every pull request, and a repository ruleset **`VGI commit trust`** on the default branch requires a pull request, requires that check, and forbids force-pushes and deletion, with no bypass list.

**Check:**

```bash
cnm git repos --namespace <namespace id (7c)>
cnm --json git repos --namespace <namespace id (7c)>
```

> **Expected result:** `github.com/<org>/<repo>  active  owners: 1  sync: inSync`. In the JSON, `guard` is `bridgePostedCheck`, `driftCount` is `0`, and `steps` shows `requiredCheck` as `applied`. On GitHub, the repository's *Settings → Rules → Rulesets* lists `VGI commit trust`, active, with no bypass actors.

### Step 10: Grant rights

Rights, from broad to narrow. `own` implies `maintain` implies `commit.sign`; `ns.admin` implies everything in the namespace.

| Right | Resource | Lets the holder | Who signs |
| --- | --- | --- | --- |
| `git.ns.admin` | `github.com/<org>` | everything below on every repository; adopt; unbind | a community administrator |
| `git.repo.create` | `github.com/<org>` | create repositories and own them | a community administrator |
| `git.repo.own` | `github.com/<org>/<repo>` | grant and revoke the rights below; transfer; archive; GitHub `admin` | a community administrator |
| `git.repo.maintain` | `github.com/<org>/<repo>` | merge and triage; GitHub `maintain` | an owner or namespace admin |
| `git.commit.sign` | a repository or the namespace | author commits the check accepts; no GitHub role | an owner or namespace admin |

Give the namespace a second admin first, so it never depends on one identity, then grant as the community needs. Subjects must be current members; resources are forge-qualified and lowercase:

```bash
cnm git grant --subject <member DID> --right git.ns.admin --resource github.com/<org> --reason "second namespace admin"
cnm git grant --subject <member DID> --right git.repo.maintain --resource github.com/<org>/<repo> --reason "maintainer"
cnm git grant --subject <member DID> --right git.commit.sign --resource github.com/<org>/<repo> --expires-in 365d
cnm git revoke --subject <member DID> --right git.commit.sign --resource github.com/<org>/<repo> --reason "left the project"
```

A grant reaches the registry within seconds and GitHub when the bridge next runs its job. `cnm git view --admin` lists every recorded right with who granted it and why; the console's Repos page and each member's page show the same.

## Members: link, clone, sign

Each contributor does this once, in **OpenVTC** on their own machine ([developer guides](../../developer/)). Open the community and press `r` for its **Repos** view. It shows the member's rights, their linked forge account and the state of commit signing on that machine.

1. **Link a GitHub account** (`l`). The bridge keys GitHub roles on the account's numeric id, so an owner or maintainer gets `admin` or `maintain` on the repository only once linked. GitHub shows a device code to enter at `https://github.com/login/device`; approve the App when asked. Commit-only members need no link.
2. **Set up signing** (`s`). This runs `did-git-sign init` against the member's VTA: a one-hour `pnm` grant that hands off to a long-term credential scoped to the persona's context, then the persona and signing key to use. `init` writes no git configuration; signing is switched on per repository, or per directory of repositories, by one `include.path` line, so a contributor's existing GPG or SSH signing key keeps working everywhere else.
3. **Clone** (`c`). Owners and maintainers clone the repository directly; no fork is needed, since the bridge gave them a GitHub role. Members holding only `git.commit.sign` contribute from a fork. The clone lands under the workspace the view names (`~/src` by default, `w` to change) with signing enabled for it.

Then the ordinary flow, on a branch, because the `VGI commit trust` ruleset protects the default branch:

```bash
git switch -c first-change
# edit, then
git commit -m "Say hello"
git log -1 --format='%(trailers:key=Signed-by-DID)'
git push -u origin first-change
gh pr create --fill
```

The trailer names the member's persona DID; `did-git-sign` sent the commit's digest to the VTA, which signed it, and the private key never left the VTA. On the pull request the bridge posts *Verify commit trust*; it passes when every commit's signer is published in the registry for that repository or its namespace, and the merge button unlocks. **Merge with a merge commit**, not squash or rebase: those produce commits signed by GitHub's `web-flow` key that the check rejects the next time it sees them.

GitHub's own **Verified** badge is a separate axis. The commit is validly signed either way; the badge appears only if the member also uploads the persona's Ed25519 public key to their GitHub account as a **Signing Key** (Settings → SSH and GPG keys → New SSH key, key type *Signing Key*). The key is the `ssh-ed25519 …` part of the matching line in `~/.config/did-git-sign/allowed_signers`. Do not also enable GitHub's built-in *Require signed commits* rule: it knows only keys registered with GitHub and would block every DID-signed commit from a member who has not uploaded theirs.

## Verification

- `curl -s http://127.0.0.1:3232/health` answers `{"status":"OK","writes":"ok"}`, and `grep "projection pass" ~/vtc/log.txt | tail -1` shows `failed=0`.
- `cnm git namespace list` shows the namespace `bridge bound` with no missing permissions.
- `cnm --json git repos --namespace <7c>` shows the repository `active`, `inSync`, `driftCount 0`.
- The admin console's **Community → Repos** page shows the namespace card and the repository; a granted member sees the repository and their right at `https://vtc.yourdomain.com/members/#/repos`.
- A signed pull request passes *Verify commit trust*; a commit made with `git -c commit.gpgsign=false commit` fails it and cannot be merged.

## Known Issues / Edge Cases

### `cnm` fails with a DBus or keyring error

You have the default keyring build. Install the config-session build from [Step 1](#step-1-install-a-server-build-of-cnm).

### The step-up link opens the community website

`cnm` 0.38.0 and earlier print the link as `https://vtc.yourdomain.com/v1/admin/step-up#request=…`. Remove the `/v1` and keep the fragment: `https://vtc.yourdomain.com/admin/step-up#request=…`. A step-up request lives five minutes; if it lapsed, run the `cnm` command again for a fresh link. Fixed in [verifiable-trust-infrastructure#2267](https://github.com/OpenVTC/verifiable-trust-infrastructure/pull/2267).

### `step-up required: … holds no step-up factor at this community`

The identity that signed the command has no passkey registered at the VTC, so the single-administrator waiver cannot ask for its gesture. Do [Step 8](#step-8-give-the-cnm-identity-a-passkey), or name a different member as the subject.

### `git-ns/namespace/bind:noBridge`

The VTC has no `[git_ns.bridges]` entry for `github.com`, or it was not restarted after the entry was added ([Step 5](#step-5-point-the-vtc-at-the-bridge)).

### `permissionDenied` on bind, or `notAdministrator` on every listing

The `cnm` identity is not a community administrator. Repeat the offline `vtc acl add` from [Step 2](#step-2-give-cnm-an-identity-at-the-vtc) with the DID `cnm community list` shows as `Identity`.

### A member's link attempt fails at the device code

Device Flow is not enabled on the App ([Step 6](#step-6-register-the-github-app-and-enable-device-flow)).

### `git commit` fails with `DID not in ACL: did:key:…` from `did-git-sign`

The credential `did-git-sign init` provisioned has no ACL entry at the VTA that holds the persona, usually because the one-hour setup grant lapsed before the hand-off completed. Grant that credential, scoped to the persona's OpenVTC context and narrowed to signing, from a machine with `pnm` admin on that VTA:

```bash
pnm --vta <slug> acl create --did <credential DID from the error> --role admin --contexts <openvtc context, e.g. openvtc-alice> --capabilities sign-sshsig --label "did-git-sign"
```

`did-git-sign health` shows the credential DID and the VTA; `pnm --vta <slug> contexts list` shows which context holds the persona. Then `git config --global did-git-sign.signer vta` so it never falls back to exporting the key, and `did-git-sign verify` for a test signature.

### The first push to an empty repository became the default branch

An empty repository makes the first pushed branch its default, and the `VGI commit trust` ruleset follows the default branch, so a branch pushed as `first` is now protected and there is nothing to open a pull request against. Create `main` from the same commit, make it the default, and the ruleset moves with it:

```bash
git push origin first:main
gh repo edit <org>/<repo> --default-branch main
git push origin --delete first
```

Creating a branch is not restricted by the ruleset, so the push succeeds; from then on changes reach `main` by pull request.

### The Trust Registry reports `degraded` after a reboot

It started before the VTA or the DID Hosting Daemon was serving, could not reach the mediator, and booted from its cached bundle with its DIDComm listener stopped. Restart it once the VTA answers `https://vta.yourdomain.com/health`, and check `/health` again. The VTC's log then shows `trust-registry health probe recovered`.
