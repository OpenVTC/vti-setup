# P01 · Outside Developer

**Who you are:** A developer who is not yet a recognized member of the target VTC community. To get in under current policy you need two existing members willing to vouch for you.  
**What you'll have at the end:** A running Personal VTA, the OpenVTC CLI, an M-DID scoped to the target community, two VRCs from existing members, and — on auto-approval — a VMC and initial role VEC sealed to your M-DID, with the M-DID written `Active` into the community's ACL and trust registry.  
**Graduate to:** [P02 — Member Developer](P02-developer-member.md), once your join request is approved and you have been added to the community's members-only mediator allowlist.

## Prerequisites

- **A target community.** You need its public WebVH URL, the address of its **public/join mediator**, the DID of its **VTC service**, and the community's currently-active **join policy**.
- **At least two existing members** who know you and are willing to issue VRCs to your M-DID. Under current initial-days policy this is the floor — there is no path to membership without it. The two issuers must be distinct members.
- **A host for your Personal VTA.** Pick a deployment from [`deployments/`](../deployments/). **D01 is dev/testing only — use D02/D03/D04 for any Personal VTA you intend to keep using.**

## Path

### Step 1 — Stand up a Personal VTA

Follow [T01 — Self-Managed Personal VTA](../tutorials/T01-self-managed-personal-vta.md). You finish this step with a running VTA holding your master keys. No community connection is needed yet.

### Step 2 — Install the OpenVTC TUI

Follow [T02 — OpenVTC TUI Setup](../tutorials/T02-openvtc-tui.md). The TUI is your interactive interface to your Personal VTA, and you'll use it for every step that follows.

### Step 3 — Mint an M-DID for the target community

Using the OpenVTC CLI against your Personal VTA, mint a fresh DID dedicated to this community and label it as your M-DID. This is the identity you share with prospective issuers and the identity to which their VRCs are bound — not your Personal VTA's primary DID (see [How joining works](#how-joining-works) below).

> _Specific M-DID minting flow to be documented._

### Step 4 — Solicit VRCs from existing members

Reach out, out-of-band, to at least two existing members who know you and are willing to vouch. Share your M-DID and ask each to issue you a VRC carrying both an identity attestation and a membership recommendation. Each member issues from _their_ M-DID for the same community; you receive each VRC into your Personal VTA.

> _Specific VRC exchange flow to be documented._

### Step 5 — Submit the join request

Wrap your M-DID and the two VRCs into a Verifiable Presentation (VP), then submit it via the OpenVTC TUI — it handles the wire shape (DIDComm to the community's **public/join mediator**, addressed to the community's **VTC service**). The outcome arrives separately; see Step 6. For the wire-level details, see [How the submission reaches the VTC](#how-the-submission-reaches-the-vtc) below.

> _Specific request submission to be documented._

### Step 6 — Receive the decision

You'll receive one of three outcomes: `Approved` (a sealed VMC + role VEC bundle arrives within seconds and your M-DID is now `Active` in the community), `Rejected`, or `Pending`/`Deferred` (queued for admin review). See [The policy engine decides](#the-policy-engine-decides-admins-set-the-policy) for the full mechanics.

## Verification

After an `Approved` outcome you should be able to:

- Resolve your M-DID via the community's WebVH host.
- Present your VMC against the community's status list and see it as not-revoked.
- See your M-DID listed as `Active` in the community's trust registry.
- Receive a DIDComm message addressed to your M-DID via the **members-only mediator** (not just the public/join one).
- See an entry for your M-DID in the community's published members directory, if one is exposed.

At that point you have graduated to [P02 — Member Developer](P02-developer-member.md).

## Notes

- **VRCs are issued to your M-DID, not your Personal VTA's primary DID** — substituting the latter links your communities together.
- **M-DIDs are scoped to a single community.** Don't re-present an old one if you leave and rejoin; mint a new one.
- **The mnemonic for your Personal VTA backs every M-DID you mint.** Losing it loses every community identity you hold — see [T01](../tutorials/T01-self-managed-personal-vta.md) for recovery.
- **You can opt out of trust-registry publication** via the `registryConsent` flag (default `false` in the current SDK type). Set it true to be externally listed; most outside devs joining a community want this.
- **There's a REST alternative to the DIDComm path.** Communities that publish their VTC service over HTTPS also accept `POST /v1/join-requests` (unauthenticated, rate-limited) with the same VP body. On REST the VP must carry a **holder-binding signature** from your M-DID, since there is no DIDComm envelope to authenticate you. Use whichever the community advertises.

## How joining works

If you want to understand why the path above is shaped the way it is, read on.

### Your Personal VTA holds many DIDs, not just one

Your Personal VTA is the master key store and DID factory for _all_ of your identities. It is not itself your community identity. Each community you participate in gets its own DID — an **M-DID** (membership DID) — minted from the same VTA but logically separate. This is deliberate: a Personal VTA compromise is catastrophic, but the M-DID separation means two communities you belong to cannot correlate you simply by inspecting your published DIDs.

### One M-DID per community

You will mint a fresh M-DID for _this_ community. If you go on to join other communities later, each gets its own M-DID. Re-using an M-DID across communities, or presenting your Personal VTA's primary DID as your membership identity, would leak your cross-community presence and defeats the design. The hazard is particularly acute across revocation events — re-presenting an old M-DID after a status-list bit has been flipped invites correlation with the prior identity.

### Membership is gated by two separate claims, from two members

A VRC (Verifiable Relationship Credential) carries two kinds of attestation from the issuer: an **identity attestation** ("this M-DID belongs to the person I know") and a **membership recommendation** ("I think this person should be a member of the community"). The two are conceptually distinct — a member could in principle attest to your identity without recommending you — but the initial-days community policy requires both kinds of claim, from at least two distinct existing members, before granting membership. Expect this threshold to tighten as the community matures.

_Note: The VTC spec (§6.1) lists invitations (VICs, issued by community admins) as the natural credential type for gating joins. OpenVTC's initial-days policy deliberately uses VRCs instead — peer-issued, member-to-member trust edges — so that any two existing members can admit a new one, rather than routing applicants through an admin-controlled invitation funnel. The trade-off is acknowledged: peer-vouching does not scale to communities large enough that "two members vouching" stops representing meaningful trust, and the policy is expected to evolve before then. The specific two-claim VRC body (identity attestation + membership recommendation) used here is also ahead of the spec, which currently leaves the VRC payload undefined — OpenVTC is filling that in via the persona work._

### Two mediators, two purposes

The community runs two DIDComm mediators:

- A **public/join mediator** that accepts traffic from anyone. Its only job is to relay join-related messages to the community's **VTC service**. Because it has to be reachable by outsiders, it is the community's natural DoS surface — and is sized and protected with that in mind.
- A **members-only mediator** that filters incoming traffic against the community's current membership allowlist, derived from an ACL backed by the community's trust registry. Any DID not on that list is dropped at the mediator boundary. This is the messaging fabric for day-to-day community life and is what members use after acceptance.

As an outside developer you only ever interact with the public/join mediator. The members-only mediator is the hand-off into P02.

_Note: The two-mediator split is a deployment-level pattern OpenVTC layers around the VTC; the VTC spec itself describes a single optional DIDComm mediator on the community side. Splitting outside-vs-inside traffic across two mediators is what protects the community's day-to-day messaging fabric from DoS exposure while still leaving a publicly-reachable surface for join requests._

### How the submission reaches the VTC

The OpenVTC TUI assembles your VP and wraps it in a DIDComm message addressed to the community's VTC service, routed through the public/join mediator. The DIDComm authcrypt envelope authenticates the sender — your M-DID — so the VP itself does not need a separate holder-binding signature (the envelope already binds the message to the M-DID it was sealed from).

Every wire operation in OpenVTC carries a Trust Task URL in the DIDComm message `type` field, identifying the protocol and version. The join-request task is `https://trusttasks.org/openvtc/vtc/join-requests/submit/1.0`. The VTC's immediate reply on the same thread is a `https://trusttasks.org/openvtc/vtc/join-requests/submit-receipt/1.0` message — an acknowledgement only. The actual policy outcome, and any credentials issued on `Approved`, are delivered separately.

### The policy engine decides; admins set the policy

Your join request is _addressed to_ the community's **VTC service** — the daemon that runs community lifecycle, holds the ACL, and issues community credentials — and _routes through_ the public/join mediator. The mediator is transport; the VTC service is the decider.

When the VTC receives your request it runs the community's currently-active **join policy** against your submission. The join policy is just code — a Rego module (`join.rego`) evaluated by an engine embedded in the VTC — and admins author it. The policy returns a boolean `allow`. Under current initial-days policy the rule is simple: `allow` is true if your submission carries at least two valid VRCs whose issuers are both `Active` members in the community's trust registry. On `allow=true`, the VTC mints a **VMC** (Verifiable Membership Credential) and an initial role **VEC** (Verifiable Endorsement Credential) for your M-DID, writes your M-DID into the community's ACL and trust registry as `Active`, and sealed-transfers the bundle back within seconds — no human approval step. The same machinery will gate richer policies later (more issuers, role-specific issuers, additional credential types); admins update the policy and activate it, and the wire shape of a join request does not change.

If the policy returns `allow=false`, your request is recorded with status `Rejected` and a rationale; you cannot retry without a submission the current policy will accept. If the policy cannot complete cleanly — for example, a trust-registry check times out, or the community policy explicitly holds borderline cases — your request is recorded with status `Pending` (or `Deferred`) and queued for a community admin (see [P03 — VTC Admin](P03-vtc-admin.md)) to review manually. That manual-review path is the fallback for cases automation can't decide on its own — not the normal path.
