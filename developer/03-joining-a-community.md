# Joining a Community

**Who you are:** A developer who is not yet a member of the target Verifiable Trust Community (VTC).  
**What you'll have at the end:** A join request submitted from your Personal Verifiable Trust Agent (VTA) under a persona DID, approved by a community admin, with your persona listed as a member in the community's ACL and trust registry.

**Verified with:**

| OpenVTC Version | VTA Version | Mediator Version | DID Hosting Daemon Version | VTC Version |
| --- | --- | --- | --- | --- |
| 0.3.1 | 0.17.0 | 0.18.19 | 0.8.3 | 0.11.58 |

## Prerequisites

- **A Personal VTA and the OpenVTC TUI**, from [01](01-personal-vta.md) and [02](02-openvtc-tui.md).
- **The target community's DID.** Published on the community's home page — see Step 4.
- **A community admin who will act on your request.** A community that accepts open join requests still admits nobody until an admin approves. If it issues invitation credentials (VICs) instead, paste the VIC into the join prompt to skip the wait.

## Path

Steps 1–5 are yours. Step 6 happens on the community's side — you are waiting during it.

### Step 1 — Stand up a Personal VTA

Follow [01 — Personal VTA](01-personal-vta.md). You finish with a running VTA holding your master keys. No community connection is needed yet.

### Step 2 — Install the OpenVTC TUI

Follow [02 — OpenVTC TUI Setup](02-openvtc-tui.md). You finish on the OpenVTC dashboard.

### Step 3 — Create a persona DID

A **persona** is a `did:webvh` identity you present to a community. It is what you join as — never your Personal VTA's primary DID, and never a persona you already use elsewhere (see [How joining works](#how-joining-works) below). Setup in [02](02-openvtc-tui.md) deliberately leaves you without one: personas are community-scoped, so the first is minted here.

From the dashboard, select **Create Persona DID** in the Menu panel. The Content panel ends with `Press <Enter> to create a persona DID` — press **Enter**. (The **VTA Service** panel's Context Identities list has the same action on `n`.)

| Prompt | Action |
| --- | --- |
| Label for the new persona: | Enter a label (e.g. `alice`), then press **Enter** |

The label is local to your profile — it is how you pick this identity in the next step, and is not part of the DID.

```text
┌ Create persona DID ──────────────────────────────────────┐
│                                                          │
│  ✓ Persona created                                       │
│                                                          │
│  did:webvh:QmPersona…:dids.example.com:quiet-harbor      │
│                                                          │
│  (copied to clipboard)                                   │
│  c: copy again   ⏎/esc close                             │
└──────────────────────────────────────────────────────────┘
```

> **⚠️ SAVE THIS**
>
> Save the **persona DID**. It is how the community's admin console identifies you, and the only way to find your own request in their queue.

The DID host and the path (`quiet-harbor` above) are both chosen for you — you neither pick a URL nor upload anything. Without DID hosting rights on your VTA the mint fails outright:

```text
No WebVH server available from the VTA (serverless mint not yet supported).
```

### Step 4 — Copy the community DID

The community publishes its DID on its home page:

```text
COMMUNITY DID   did:webvh:QmRoot…:dids.example.com:example-vtc
```

Copy it. OpenVTC works out the route to the community on its own.

### Step 5 — Submit the join request

Back in the OpenVTC dashboard, select **Communities** in the Menu panel and press `j`.

```text
┌ Join a community ────────────────────────────────────────────────────┐
│                                                                      │
│  Enter the Verifiable Trust Community (VTC) DID you want to join.    │
│  OpenVTC will mint a fresh persona and submit a join request on      │
│  your behalf.                                                        │
│                                                                      │
│  Have an invitation?                                                 │
│  Load the invitation credential (VIC) JSON — it fills in the         │
│  community DID for you and rides along with the join request.        │
│  [Ctrl+V] paste an invitation from the clipboard, or paste the       │
│  JSON straight in                                                    │
│                                                                      │
│  Enter the community's DID or agent name:                            │
│  >                                                                   │
│                                                                      │
│  Examples:                                                           │
│    • did:webvh:QmRoot…:community.example.com                         │
│    • community.example.com/@acme                                     │
│                                                                      │
│  [ESC] to cancel  |  [ENTER] to join                                 │
└──────────────────────────────────────────────────────────────────────┘
```

Paste the Community DID and press **Enter**. OpenVTC then asks which identity to present:

```text
┌ Choose an identity for this community ───────────────────────────────┐
│                                                                      │
│  Select the identity to present to this community:                   │
│                                                                      │
│  ▸ alice                                                             │
│      did:webvh:QmPersona…:dids.example.com:quiet-harbor              │
│    ✦ Create a new identity for this community                        │
│      A fresh did:webvh, unlinked from your other communities         │
│                                                                      │
│  [↑/↓] select   [ENTER] choose   [ESC] cancel                        │
└──────────────────────────────────────────────────────────────────────┘
```

Pick the persona from Step 3, or let OpenVTC mint a fresh one. Either way you end up with a community-scoped identity — one persona per community is the rule (see [One M-DID per community](#one-m-did-per-community)).

Press "Y" to "reuse" the identity; this is actually the first use of it but you will see here if it has already been used before, so you don't cross-link your identity accidentally.

```text
┌ Choose an identity for this community ───────────────────────────────┐
│                                                                      │
│  Reuse an existing identity?                                         │
│                                                                      │
│  Presenting "alice" to this community links you across every         │
│  community that uses it.                                             │
│  It is not yet presented to any other community.                     │
│                                                                      │
│  [Y] reuse and continue   [N/ESC] go back                            │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

Arrow down to the "Join without it" option and press **Enter**.

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

OpenVTC creates a sub-context for the community, submits the request, and reports:

```text
┌ Joining community ───────────────────────────────────────────────────┐
│                                                                      │
│  INFO: Joining did:webvh:QmPXUR…:dids.firstperson.dev:firstperson-vtc│
│  INFO: Community reachable over TSP.                                 │
│  INFO: Reusing persona                                               │
│      did:webvh:QmeHMZ…:dids.firstperson.dev:quiet-harbor             │
│  INFO: Creating sub-context openvtc-alice/qmpxurcjupgn…              │
│  INFO: Submitting join request…                                      │
│  INFO: Connecting the new persona to its mediator…                   │
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

The community now appears in your **Communities** panel marked `Pending`, with the request ID and the persona you presented.

### Step 6 — The community decides

A community admin reviews the request in the VTC admin console — **Join requests** → your request → **Review**. The detail page shows your applicant DID, submission time, status, and any VP claims you presented — empty on an open request, whose policy asks for no credentials.

The admin then either:

- **Approve** — creates the member and ACL row atomically, and fires VMC + role-VEC issuance to your persona.
- **Reject** — closes the request with a reason. You may resubmit.

After approval your persona appears under **Members** with role `member` and a joined timestamp.

You are not involved in this step; the outcome reaches you over TSP or DIDComm.

## Verification

Confirm from the community side — the admin console's **Members** list shows your persona DID with role `member`.

On the OpenVTC side, open the **VTA Service** panel. Your persona is listed under **Context Identities**:

```text
 Context Identities (1)   ◀ focus

▸ ● did:webvh:QmPersona…:dids.example.com:quiet-harbor
      alice  ·  active  ·  1 community

↑/↓ select   n: new persona   g: agent names   d: remove orphan
```

Read that carefully: `1 community` says the persona is bound to a community, **not** that the community accepted you. Acceptance is what the credentials prove: on approval the VTC issues your persona a **VMC** (membership) and an initial role **VEC**, and both land in **My Credentials**. The checks that should pass are:

- Your persona resolves via the community's DID host.
- **My Credentials** lists a VMC and a role VEC, both issued by the community.
- Your VMC presents against the community's status list as not-revoked.
- Your persona is listed as `Active` in the community's trust registry.
- You can receive TSP and/or DIDComm messages addressed to your persona via the **members-only mediator**, not just the public/join one.

At that point you have graduated to Member Developer _(not yet written)_.

## Notes

- **"Persona" in the TUI is the M-DID in the spec.** Both mean the per-community identity minted from your Personal VTA — this page uses the TUI's word in the walkthrough and the spec's word in the background sections.
- **Present a persona, never your Personal VTA's primary DID.** Substituting the latter links all your communities together.
- **Personas are scoped to a single community.** Don't re-present an old one if you leave and rejoin; mint a new one.
- **The mnemonic for your Personal VTA backs every persona you mint.** Losing it loses every community identity you hold — see [01 — Personal VTA](01-personal-vta.md) for recovery.
- **Trust-registry publication is on by default.** The `registryConsent` flag defaults to `true` in the current SDK type, which the admin console shows as `REGISTRY CONSENT: Yes` — your persona is externally listed. Set it false to opt out and stay off the published registry.
- **There's a REST alternative to the TSP and DIDComm paths.** Communities that publish their VTC service over HTTPS also accept `POST /v1/join-requests` (unauthenticated, rate-limited) with the same VP body. On REST the VP must carry a **holder-binding signature** from your M-DID, since there is no TSP or DIDComm envelope to authenticate you. Use whichever the community advertises.

## How joining works

If you want to understand why the path above is shaped the way it is, read on.

> **ℹ️ NOTE**
>
> Join policy is per-community. The walkthrough above follows an **open-request** policy — present no credentials, an admin decides by hand. The **two-VRC** policy described below is the working target for the initial-days community and **is not what is currently active today**; it may be changed based on that community's requirements. The wire shape of a join request is the same either way.

### Your Personal VTA holds many DIDs, not just one

Your Personal VTA is the master key store and DID factory for _all_ of your identities. It is not itself your community identity. Each community you participate in gets its own DID — an **M-DID** — minted from the same VTA but logically separate. This is deliberate: the M-DID separation means two communities you belong to cannot correlate you.

### One M-DID per community

You will mint a fresh M-DID for _this_ community. If you go on to join other communities later, each gets its own M-DID. Re-using an M-DID across communities, or presenting your Personal VTA's primary DID as your membership identity, would leak your cross-community presence and defeats the design. The hazard is particularly acute across revocation events — re-presenting an old M-DID after a status-list bit has been flipped invites correlation with the prior identity.

### Membership is gated by two separate claims, from two members

A VRC carries two kinds of attestation from the issuer: an **identity attestation** ("this M-DID belongs to the person I know") and a **membership recommendation** ("I think this person should be a member of the community"). The two are conceptually distinct — a member could in principle attest to your identity without recommending you — but the initial-days community policy requires both kinds of claim, from at least two distinct existing members, before granting membership. Expect this threshold to tighten as the community matures.

_Note: The VTC spec (§6.1) lists Verifiable Invitation Credentials (VICs, issued by community admins) as the natural credential type for gating joins. OpenVTC's initial-days policy deliberately uses VRCs instead — peer-issued, member-to-member trust edges — so that any two existing members can admit a new one, rather than routing applicants through an admin-controlled invitation funnel. The trade-off is acknowledged: peer-vouching does not scale to communities large enough that "two members vouching" stops representing meaningful trust, and the policy is expected to evolve before then. The specific two-claim VRC body (identity attestation + membership recommendation) used here is also ahead of the spec, which currently leaves the VRC payload undefined._

### Two mediators, two purposes

The community runs two DIDComm mediators:

- A **public/join mediator** that accepts traffic from anyone. Its only job is to relay join-related messages to the community's **VTC service**. Because it has to be reachable by outsiders, it is the community's natural DoS surface — and is sized and protected with that in mind.
- A **members-only mediator** that filters incoming traffic against the community's current membership allowlist, derived from an ACL backed by the community's trust registry. Any DID not on that list is dropped at the mediator boundary. This is the messaging fabric for day-to-day community life and is what members use after acceptance.

As an outside developer you only ever interact with the public/join mediator. The members-only mediator is the hand-off into the Member Developer flow.

### How the submission reaches the VTC

The OpenVTC TUI assembles your VP and wraps it in a DIDComm message addressed to the community's VTC service, routed through the public/join mediator. The DIDComm authcrypt envelope authenticates the sender — your M-DID — so the VP itself does not need a separate holder-binding signature (the envelope already binds the message to the M-DID it was sealed from).

Every wire operation in OpenVTC carries a Trust Task URL in the DIDComm message `type` field, identifying the protocol and version. The join-request task is `https://trusttasks.org/openvtc/vtc/join-requests/submit/1.0`. The VTC's immediate reply on the same thread is a `https://trusttasks.org/openvtc/vtc/join-requests/submit-receipt/1.0` message — an acknowledgement only. The actual policy outcome, and any credentials issued on `Approved`, are delivered separately.

### The policy engine decides; admins set the policy

Your join request is _addressed to_ the community's **VTC service** — the daemon that runs community lifecycle, holds the ACL, and issues community credentials — and _routes through_ the public/join mediator. The mediator is transport; the VTC service is the decider.

When the VTC receives your request it runs the community's currently-active **join policy** against your submission. The join policy is just code — a Rego module (`join.rego`) evaluated by an engine embedded in the VTC — and admins author it. The policy returns a boolean `allow`. Under current initial-days policy the rule is simple: `allow` is true if your submission carries at least two valid VRCs whose issuers are both `Active` members in the community's trust registry. On `allow=true`, the VTC mints a **VMC** and an initial role **VEC** for your M-DID, writes your M-DID into the community's ACL and trust registry as `Active`, and sealed-transfers the bundle back within seconds — no human approval step. The same machinery will gate richer policies later (more issuers, role-specific issuers, additional credential types); admins update the policy and activate it, and the wire shape of a join request does not change.

If the policy returns `allow=false`, your request is recorded with status `Rejected` and a rationale; you cannot retry without a submission the current policy will accept. If the policy cannot complete cleanly — for example, a trust-registry check times out, or the community policy explicitly holds borderline cases — your request is recorded with status `Pending` (or `Deferred`) and queued for a community admin _(not yet written)_ to review manually.

Under a VRC-gated policy that manual-review path is the fallback for cases automation can't decide on its own. Under an open-request policy every submission lands there — which is why Step 6 of the walkthrough is an admin clicking **Approve**.
