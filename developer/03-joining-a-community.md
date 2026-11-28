# Joining a Community

**Who you are:** A developer who is not yet a member of the target Verifiable Trust Community (VTC).  
**What you'll have at the end:** A join request submitted from your Personal Verifiable Trust Agent (VTA) under a persona DID, approved by a community admin, with your persona listed as a member in the community's ACL (and in its trust registry, if you consent).

**Verified with:**

| Release | OpenVTC | VTA | PNM | Mediator | DID Hosting | VTC |
| --- | --- | --- | --- | --- | --- | --- |
| VTI-Fig | 0.9.0 | 0.87.2 | 0.66.2 | 0.56.0 | 0.12.0 | 0.35.2 |

**Verified by an automated run** on a fresh Ubuntu 26.04 server, joining the community from the [explore walkthrough](../sysop/explore/02-walkthrough.md): OpenVTC was driven through tmux, and the admin's side in the VTC console through headless Chromium with a virtual passkey. Not tested on macOS, Windows/WSL, or with a hardware security key. See [Versions](../README.md#versions).

## Prerequisites

- **A Personal VTA and the OpenVTC TUI**, from [01](01-personal-vta.md) and [02](02-openvtc-tui.md).
- **The target community's DID.** Published on the community's home page — see Step 4.
- **A community admin who will act on your request.** A new community's default join criteria send an open request to its administrators for review, so it admits nobody until one approves. (A community can change that.) If it issues invitation credentials (VICs) instead, create your persona first (Step 3), give its DID to the admin, and paste the VIC they send you into the join prompt to skip the wait.

## Path

Steps 1–5 are yours. Step 6 happens on the community's side — you are waiting during it.

### Step 1 — Stand up a Personal VTA

Follow [01 — Personal VTA](01-personal-vta.md). You finish with a running VTA holding your master keys. No community connection is needed yet.

### Step 2 — Install the OpenVTC TUI

Follow [02 — OpenVTC TUI Setup](02-openvtc-tui.md). You finish on the OpenVTC dashboard.

### Step 3 — Create a persona DID

A **persona** is a DID you present to a community, a `did:webvh` unless you choose otherwise. It is what you join as — never your Personal VTA's primary DID, and never a persona you already use elsewhere (see [How joining works](#how-joining-works) below). Setup in [02](02-openvtc-tui.md) deliberately leaves you without one: personas are community-scoped, so the first is minted here or during the join.

This step is optional. If you have no persona when you join in Step 5, OpenVTC mints one for you. Make one here if the community will send you an invitation credential (VIC): an invitation is bound to a persona DID, so the community admin needs yours before you join.

From the dashboard, select **My Identity** in the Menu panel and press **Enter** to move into the Content panel. It opens on the **Personas** tab, which reads `You have no personas yet.` Press `n` to open the **Create persona DID** overlay:

| Prompt | Action |
| --- | --- |
| What should this persona be called? | Enter a name (e.g. `alice`), then press **Enter** |
| Where should this persona's DID live on the hosting server? | Press **Enter** to create it with a path the server picks (press `p` first if you want to type the path yourself, or `m` to change the DID method) |

The name is only for you: communities are shown the DID, not the name, and you can rename it later. It also names the VTA sub-context the persona's keys live in (`openvtc/alice` for the default profile).

```text
┌ Create persona DID ──────────────────────────────────────┐
│                                                          │
│  ✓ Persona created                                       │
│                                                          │
│  did:webvh:QmPersona…:dids.example.com:quiet-harbor      │
│                                                          │
│  (copied to clipboard)                                   │
│  c: copy again · Enter/Esc: close                        │
└──────────────────────────────────────────────────────────┘
```

> **⚠️ SAVE THIS**
>
> Save the **persona DID**. It is how the community's admin console identifies you, and the only way to find your own request in their queue.

The DID host is chosen for you, and so is the path (`quiet-harbor` above) unless you pressed `p`. You don't upload anything. If your VTA has no DID hosting server registered, the mint fails outright:

```text
No WebVH server available from the VTA (serverless mint not yet supported).
```

If the server is registered but hasn't let your VTA in, the overlay stays on `Creating persona DID via did-hosting-daemon…` with no error, while the VTA retries every 30 seconds. On a self-hosted VTA, that means [01, Path B, Step 4](01-personal-vta.md#step-4-get-did-hosting-for-your-personas) hasn't been done yet. The mint completes on the next retry once it has.

If the mint fails with a **502** or **504** instead, the VTA's call to its DID hosting server failed. The fault is between those two, not in OpenVTC or your setup, and `pnm health` passing does not rule it out. Report it to your VTA operator (for VTA Farm, the Farm team) with the time it happened. Skipping this step won't get you past it: a join mints a persona through the same server.

### Step 4 — Copy the community DID

The community publishes its DID on its home page, on a card headed **Community DID** with a QR code and a **Copy** button. Copy it. OpenVTC works out the route to the community on its own.

### Step 5 — Submit the join request

Back in the OpenVTC dashboard, select **Communities** in the Menu panel, press **Enter** to move into the Content panel, then press `n`.

```text
┌ Join a community ────────────────────────────────────────────────────┐
│                                                                      │
│  Enter the Verifiable Trust Community (VTC) DID you want to join.    │
│  OpenVTC will mint a fresh persona and submit a join request on      │
│  your behalf.                                                        │
│                                                                      │
│  Enter the community's DID or agent name:                            │
│  >                                                                   │
│                                                                      │
│  Don't have the DID?                                                 │
│  If you were handed an invitation credential (VIC), paste the JSON   │
│  here instead — it names the community, so it fills the DID in for   │
│  you, and it rides along with the join request.                      │
│  [Ctrl+V] paste from the clipboard — a DID goes in the field, an     │
│  invitation is loaded                                                │
│                                                                      │
│  Examples:                                                           │
│    • did:webvh:QmRoot…:community.example.com                         │
│    • did:scid:vh:1:QmRoot…?src=community.example.com                 │
│    • community.example.com/@acme                                     │
│                                                                      │
│  [ESC] to cancel  |  [ENTER] to join                                 │
└──────────────────────────────────────────────────────────────────────┘
```

Paste the Community DID and press **Enter**. What comes next depends on whether you made a persona in Step 3.

**If you skipped Step 3**, OpenVTC goes straight to **Where should this community live?** Press **Enter** to accept the first option, `✦ A context of its own`, which puts the community in a new VTA sub-context named after it, with a new persona. Then skip ahead to the **Joining community** progress page below.

**If you made a persona in Step 3**, OpenVTC asks which persona to present:

```text
┌ Who should this community know you as? ──────────────────────────────┐
│                                                                      │
│  Choose the persona this community will know you as:                 │
│                                                                      │
│  ▸ alice                                                             │
│      did:webvh:QmPersona…:dids.example.com:quiet-harbor              │
│    ✦ Be someone new to this community                                │
│      A fresh persona DID — nothing links it to your other            │
│      communities                                                     │
│      Presented as your account's default  [m] change                 │
│                                                                      │
│  [↑/↓] select   [ENTER] choose   [ESC] cancel                        │
└──────────────────────────────────────────────────────────────────────┘
```

Pick the persona from Step 3, or let OpenVTC mint a fresh one. Either way you end up with a community-scoped identity — one persona per community is the rule (see [One persona per community](#one-persona-per-community)).

Choosing an existing persona always brings up a linkage warning, even on its first use. It is there so you don't link your identities across communities by accident; the last line tells you whether any other community already knows you by this persona. Press **Y** to continue.

```text
┌ Who should this community know you as? ──────────────────────────────┐
│                                                                      │
│  Use a persona this community can already be linked to?              │
│                                                                      │
│  Being known here as "alice" makes you the same person to anyone     │
│  who sees both this community and the others using it.               │
│  No other community knows you by it yet.                             │
│                                                                      │
│  [Y] reuse and continue   [N/ESC] go back                            │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

OpenVTC then offers any invitation it holds for this persona. With none, arrow down to **Join without it — send an open request** and press **Enter**.

```text
┌ Use an invitation for this community? ───────────────────────────────┐
│                                                                      │
│  Choose an invitation to present, or join without one:               │
│                                                                      │
│    No invitation found for this identity in your credential vault.   │
│                                                                      │
│  ▸ ⎘ Paste an invitation credential (VIC)                            │
│      [ENTER] to read your clipboard, or paste the JSON straight in.  │
│    Join without it — send an open request                            │
│      The community reviews and approves the request manually.        │
│                                                                      │
│  [↑/↓] select   [ENTER] choose   [ESC] cancel                        │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

A persona from Step 3 already has its own sub-context (`openvtc/alice`), so the community joins that one and OpenVTC doesn't ask where it should live.

A community that vets its members, or asks applicants to tell it about themselves, adds a page here first. It sets out what the community requires or asks, and what would be sent, before anything leaves. An open-request community shows neither.

Every join then stops on **Review and send**. Nothing has been sent yet. The page lists what the community will receive: your identity, invitation and vetting, and how it decides (`with no invitation or vetting, the request goes to its moderators to decide`). It also says what the community's member directory would show about you. At the bottom is one checkbox:

```text
    [ ] Publish my membership in this community's trust registry
```

Leave it unticked and the community will not publish your membership in its public trust registry, even after it admits you. Tick it with **Space** to allow that. You can't change the answer after joining except by leaving and joining again. Press **Enter** to send the request.

OpenVTC prepares the sub-context, submits the request, and reports:

```text
┌ Joining community ───────────────────────────────────────────────────┐
│                                                                      │
│  INFO: Joining did:webvh:QmPXUR…:dids.firstperson.dev:firstperson-vtc│
│  INFO: Community reachable over TSP.                                 │
│  INFO: Using context openvtc/alice.                                  │
│  INFO: Reusing persona                                               │
│      did:webvh:QmeHMZ…:dids.firstperson.dev:quiet-harbor…            │
│  INFO: Submitting join request…                                      │
│  INFO: Persona connected — ready to receive the community's reply.   │
│  INFO: Join request sent over TSP. Waiting for the community to      │
│  acknowledge it — it's Pending in your Communities list, which will  │
│  flag it if no response arrives.                                     │
│                                                                      │
│  Join request sent.                                                  │
│                                                                      │
│    Community DID:                                                    │
│      did:webvh:QmPXUR…:dids.firstperson.dev:firstperson-vtc          │
│    Your persona:                                                     │
│      did:webvh:QmeHMZ…:dids.firstperson.dev:quiet-harbor             │
│    Status:        Pending  ·  not yet acknowledged                   │
│    Sent over:     TSP                                                │
│    Invitation:    None  ·  open request (awaiting approval)          │
│    Registry:      Not consented  ·  the community will not publish   │
│                   this membership                                    │
│                                                                      │
│  It's now in your Communities list, marked Pending — it will update  │
│  there as the community responds.                                    │
│  The community hasn't acknowledged it yet. That normally takes       │
│  seconds; if it doesn't arrive, the Communities list will flag the   │
│  request as possibly not received.                                   │
│                                                                      │
│  [ENTER] to return                                                   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

The community now appears in your **Communities** panel marked `Pending`, with the persona you presented, its context, and the request ID. **c** on that entry cancels the join.

### Step 6 — The community decides

A community admin reviews the request in the VTC admin console: **Join requests** lists it with your persona DID, when you sent it, and whether you consented to registry publication; **Review** opens it. The same request also appears under **Actions**. Every decision in the console is a signed document, so the admin must have completed **Set up signing** (see [the walkthrough's Step 6](../sysop/explore/02-walkthrough.md#step-6-set-up-vtc)) and hold the `vtc.join.decide` capability. The detail page shows a summary (your DID, submission time, status, registry consent) and any vetting or credentials you presented, which are empty on an open request, then a **Decide** section.

The admin then either:

- **Approve**, confirmed in an **Approve join request?** dialog: creates the member and ACL row atomically, and issues your persona its credentials, a VMC and a role VAC.
- **Reject**: closes the request, with an optional reason. You may resubmit.

After approval your persona appears under **Members** with role `member` and a joined timestamp. OpenVTC's activity log shows the credentials arriving (`credential-exchange/issue/0.1`).

You are not involved in this step; the outcome reaches you over TSP or DIDComm.

## Verification

Confirm from the community side — the admin console's **Members** list shows your persona DID with role `member`.

On the OpenVTC side, open the **My Identity** panel. Your persona is listed on the **Personas** tab:

```text
 1 persona

▸ ● did:webvh:QmPersona…:dids.example.com:quiet-harbor
      alice  ·  active  ·  known to 1 community

↑/↓: select · n: new persona · g: agent names · Tab/→: next tab · Shift+Tab/←: previous tab · Esc: back
```

Read that carefully: `known to 1 community` says the persona is bound to a community, **not** that the community accepted you. Acceptance is what the credentials prove: on approval the VTC issues your persona a **VMC** (membership) and an initial role **VAC**, and both land on the **Membership** tab of **My Credentials**, labeled **Membership** and **Role: member**, next to an **Acknowledgement**. The checks that should pass are:

- Your persona resolves via the community's DID host.
- **My Credentials** lists a Membership and a Role credential, both issued by the community.
- Your VMC presents against the community's status list as not-revoked.
- If you ticked the registry checkbox, and the community publishes, your persona is listed in the community's trust registry. The admin can see it in the console under **Recognition** → **Trust registry records**, as `recognise` · `member of this community`.

At that point you have graduated to Member Developer _(not yet written)_.

## Notes

- **"Persona" is what older spec drafts called an M-DID.** The DTG credentials spec has retired the M-DID, R-DID, C-DID and P-DID identifier types ([dtgwg-cred-spec#30](https://github.com/trustoverip/dtgwg-cred-spec/pull/30)). An identifier is now a plain DID with a declared correlation scope: `pairwise`, `directed` or `public`. This page uses the TUI's word, **persona**, throughout.
- **Present a persona, never your Personal VTA's primary DID.** Substituting the latter links all your communities together.
- **Personas are scoped to a single community.** Don't re-present an old one if you leave and rejoin; mint a new one.
- **The mnemonic for your Personal VTA backs every persona you mint.** Losing it loses every community identity you hold — see [01 — Personal VTA](01-personal-vta.md) for recovery.
- **Trust-registry publication is your choice.** The **Review and send** page asks on every join, unticked by default, and sends the answer as the request's `registryConsent` flag.
- **The VTC also has a REST join endpoint**, `POST /v1/join-requests`, but OpenVTC doesn't use it for a `did:webvh` persona: it accepts `did:key` applicants only. OpenVTC joins over TSP or DIDComm.

## How joining works

If you want to understand why the path above is shaped the way it is, read on.

> **ℹ️ NOTE**
>
> Join policy is per-community: each community publishes the **join criteria** it accepts and decides how each is admitted. A new community starts with three: an invitation (admitted automatically), a membership credential (automatic) and a review (an admin decides). The walkthrough above is the review route: present no credentials, an admin decides by hand. The **two-VRC** policy described below is only an **example** of what a community could require; OpenVTC does not prescribe it. The wire shape of a join request is the same whatever the policy.

### Your Personal VTA holds many DIDs, not just one

Your Personal VTA is the master key store and DID factory for _all_ of your identities. It is not itself your community identity. Each community you participate in gets its own DID — a **persona** — minted from the same VTA but logically separate. This is deliberate: because each persona is known only to its own community, two communities you belong to cannot correlate you.

### One persona per community

You will mint a fresh persona for _this_ community. If you go on to join other communities later, each gets its own. In the spec's terms, a persona known only to its community is `pairwise`: it has exactly one counterparty. Re-using it with another community widens it to `directed`, known to every community you chose to use it with, which leaks your cross-community presence and defeats the design. Presenting your Personal VTA's primary DID as your membership identity does the same, across everything that DID is used with. The hazard is particularly acute across revocation events — re-presenting an old persona after a status-list bit has been flipped invites correlation with the prior identity.

### An example policy: two separate claims, from two members

A VRC carries two kinds of attestation from the issuer: an **identity attestation** ("this persona belongs to the person I know") and a **membership recommendation** ("I think this person should be a member of the community"). The two are conceptually distinct — a member could in principle attest to your identity without recommending you — so a community can require either or both. One example policy requires both kinds of claim, from at least two distinct existing members, before granting membership. A community using it might tighten that threshold as it grows.

_Note: The VTC spec (§6.1) lists Verifiable Invitation Credentials (VICs, issued by community admins) as the natural credential type for gating joins. A VRC-based policy like this example is an alternative: VRCs are peer-issued, member-to-member trust edges, so any two existing members can admit a new one rather than routing applicants through an admin-controlled invitation funnel. The trade-off is that peer-vouching does not scale to communities large enough that "two members vouching" stops representing meaningful trust. Which approach suits a community is that community's decision. The two-claim VRC body (identity attestation + membership recommendation) in this example is also ahead of the spec, which currently leaves the VRC payload undefined._

### How the submission reaches the VTC

The OpenVTC TUI assembles your submission and sends it to the community's VTC service, routed through the community's mediator. It sends over TSP when the community's DID document offers TSP and your persona's mediator carries it, and falls back to DIDComm when the community also offers DIDComm and your mediator doesn't carry TSP. The progress page tells you which it used (`Sent over:`). Either envelope authenticates the sender, your persona, and the submission document itself also carries your persona's signature (an `eddsa-jcs-2022` proof).

Every wire operation in OpenVTC carries a Trust Task URL identifying the protocol and version (in DIDComm, the message `type` field). The join-request task is `https://trusttasks.org/spec/vtc/join-requests/submit/0.3`. The VTC's immediate reply on the same thread is its `#response`, carrying the verdict so far (on an open request, that it is pending review). Credentials issued on `Approved` are delivered separately.

### The policy engine decides; admins set the policy

Your join request is _addressed to_ the community's **VTC service** — the daemon that runs community lifecycle, holds the ACL, and issues community credentials — and _routes through_ the community's mediator. The mediator is transport; the VTC service is the decider.

When the VTC receives your request it matches it against the community's published **join criteria**. Each criterion names what it accepts (credentials, described with DCQL and the issuers the community trusts; an invitation; or vetting statements from existing members) and whether a match is admitted **automatically** or goes to **review**. Admins manage them in the console under **Vetting → Requirements**. A community can also run a Rego policy (`join.rego`), which returns a decision: `allow`, `refer`, `deny` or `request_more`. A policy can never admit a submission that doesn't meet its criterion, or one under a review criterion, and a join can never grant `admin`.

On an automatic admission, the VTC mints a **VMC** and an initial role **VAC** for your persona, writes your persona's DID into the community's ACL (and, if you consented, its trust registry), and sends the credentials back within seconds, with no human approval step. A `refer` (or a review criterion) records your request as `Pending` for an admin. `request_more` records it as `Deferred`: the community wants something more from you, such as a missing credential. `deny` records it as `Rejected`, with a rationale. You can also withdraw a request yourself (`Withdrawn`).

The two-VRC example above would be a credential criterion that asks for two VRCs from issuers who are current members. Under the default review criterion, every open request lands with an admin, which is why Step 6 of the walkthrough is an admin clicking **Approve**.
