# P01 · Outside Developer

**Who you are:** A developer who is not yet a recognized member of the target VTC community. You may already know people in that community, or you may be coming in completely cold — either way, the community treats you as an outsider until your membership is formally accepted. To get in under current policy you will need two existing members willing to vouch for you.  
**What you'll have at the end:** A running Personal VTA, the OpenVTC CLI installed against it, a freshly-minted M-DID scoped to the target community, two VRCs (Verifiable Relationship Credentials) issued to that M-DID by existing members, and — assuming the community's join policy auto-allows your submission — a fresh VMC (Verifiable Membership Credential) and initial role VEC (Verifiable Endorsement Credential) sealed back to your M-DID, with your M-DID written into the community's ACL and trust registry as an Active member.  
**Graduate to:** [P02 — Member Developer](P02-developer-member.md), once your join request is approved and you have been added to the community's members-only mediator allowlist.

## Prerequisites

- **A target community.** You need the community's public WebVH URL, the address of its **public/join mediator**, the DID of the community's **VTC service** (the recipient of your join request), and the community's currently-published **join policy** — so you can prepare a submission that satisfies the criteria the policy encodes.
- **At least two existing members** who know you and are willing to issue VRCs to your M-DID. Under current initial-days policy this is the floor — there is no path to membership without it. The two issuers must be distinct members.
- **A host for your Personal VTA.** Pick a deployment environment:
  - For exploring or local experimentation: [D01 — Local Dev](../deployments/D01-local-dev.md).
  - For a Personal VTA you intend to keep using: one of [D02 — Ubuntu Server](../deployments/D02-ubuntu-server.md), [D03 — Kubernetes](../deployments/D03-kubernetes.md), or [D04 — AWS EC2](../deployments/D04-AWS-ec2.md). **D01 is dev-and-testing only and must not be used for live identity.**

## How joining works

Read this section before walking the steps — several pieces of the flow only make sense once the underlying model is in mind.

### Your Personal VTA holds many DIDs, not just one

Your Personal VTA is the master key store and DID factory for *all* of your identities. It is not itself your community identity. Each community you participate in gets its own DID — an **M-DID** (membership DID) — minted from the same VTA but logically separate. This is deliberate: a Personal VTA compromise is catastrophic, but the M-DID separation means two communities you belong to cannot correlate you simply by inspecting your published DIDs.

### One M-DID per community

You will mint a fresh M-DID for *this* community. If you go on to join other communities later, each gets its own M-DID. Re-using an M-DID across communities, or presenting your Personal VTA's primary DID as your membership identity, would leak your cross-community presence and defeats the design.

### Membership is gated by two separate claims, from two members

A VRC carries two kinds of attestation from the issuer: an **identity attestation** ("this M-DID belongs to the person I know") and a **membership recommendation** ("I think this person should be a member of the community"). The two are conceptually distinct — a member could in principle attest to your identity without recommending you — but the initial-days community policy requires both kinds of claim, from at least two distinct existing members, before granting membership. Expect this threshold to tighten as the community matures.

_Note: The VTC spec (§6.1) lists invitations (VICs, issued by community admins) as the natural credential type for gating joins. OpenVTC's initial-days policy deliberately uses VRCs instead — peer-issued, member-to-member trust edges — so that any two existing members can admit a new one, rather than routing applicants through an admin-controlled invitation funnel. The trade-off is acknowledged: peer-vouching does not scale to communities large enough that "two members vouching" stops representing meaningful trust, and the policy is expected to evolve before then. The specific two-claim VRC body (identity attestation + membership recommendation) used here is also ahead of the spec, which currently leaves the VRC payload undefined — OpenVTC is filling that in via the persona work._

### Two mediators, two purposes

The community runs two DIDComm mediators:

- A **public/join mediator** that accepts traffic from anyone. Its only job is to relay join-related messages to the community's **VTC service**. Because it has to be reachable by outsiders, it is the community's natural DoS surface — and is sized and protected with that in mind.
- A **members-only mediator** that filters incoming traffic against the community's current membership allowlist, derived from an ACL backed by the community's trust registry. Any DID not on that list is dropped at the mediator boundary. This is the messaging fabric for day-to-day community life and is what members use after acceptance.

As an outside developer you only ever interact with the public/join mediator. The members-only mediator is the hand-off into P02.

_Note: The two-mediator split is a deployment-level pattern OpenVTC layers around the VTC; the VTC spec itself describes a single optional DIDComm mediator on the community side. Splitting outside-vs-inside traffic across two mediators is what protects the community's day-to-day messaging fabric from DoS exposure while still leaving a publicly-reachable surface for join requests._

### The policy engine decides; admins set the policy

Your join request is *addressed to* the community's **VTC service** — the daemon that runs community lifecycle, holds the ACL, and issues community credentials — and *routes through* the public/join mediator. The mediator is transport; the VTC service is the decider.

When the VTC receives your request it runs the community's currently-active **join policy** against your submission. The join policy is just code — a Rego module (`join.rego`) evaluated by an engine embedded in the VTC — and admins author it. The policy returns a boolean `allow`. Under current initial-days policy the rule is simple: `allow` is true if your submission carries at least two valid VRCs whose issuers are both `Active` members in the community's trust registry, in which case the VTC issues you membership in-process — no human approval step, just a sealed-back bundle within seconds. The same machinery will gate richer policies later (more issuers, role-specific issuers, additional credential types); admins update the policy and activate it, and the wire shape of a join request does not change.

If the policy returns `allow=false`, your request is recorded with status `Rejected` and a rationale. If the policy cannot complete cleanly — for example, a trust-registry check times out, or the community policy explicitly holds borderline cases — your request is recorded with status `Pending` (or `Deferred`) and queued for a community admin (see [P03 — VTC Admin](P03-vtc-admin.md)) to review manually. That manual-review path is the fallback for cases automation can't decide on its own — not the normal path.

## Path

### Step 1 — Stand up a Personal VTA

Follow [T01 — Self-Managed Personal VTA](../tutorials/T01-self-managed-personal-vta.md). You finish this step with a running VTA holding your master keys. No community connection is needed yet.

### Step 2 — Install the OpenVTC CLI

Install the PNM (Personal Network Manager) client and point it at the Personal VTA you just stood up. See the [OpenVTC organization](https://github.com/OpenVTC) for the current CLI distribution and installation instructions.

> _Detailed install steps to be documented here once the CLI distribution is finalized._

### Step 3 — Mint an M-DID for the target community

Using the OpenVTC CLI against your Personal VTA, mint a fresh DID dedicated to this community and label it as your M-DID for the community. This is the identity you will share with prospective issuers and the identity to which their VRCs will be bound. Do not share your Personal VTA's primary DID for this purpose — see *How joining works* above.

> _Specific commands to be documented once the M-DID minting flow is finalized._

### Step 4 — Solicit VRCs from existing members

Reach out, out-of-band, to at least two existing members who know you and are willing to vouch. Share your M-DID with each and ask them to issue a VRC carrying both an identity attestation and a membership recommendation. Each member issues the credential from *their* M-DID for the same community; you receive each VRC into your Personal VTA.

This step is partly social and partly procedural. The social part — *who* is willing to vouch for you and on what basis — is outside the scope of this guide. The procedural part — how a member issues a VRC and how you receive it — is covered from the issuer's side in [P02 — Member Developer](P02-developer-member.md).

### Step 5 — Submit the join request

Wrap your M-DID and the two VRCs into a Verifiable Presentation (VP) naming your M-DID as the holder, and send the join request via DIDComm through the community's **public/join mediator**, addressed to the community's **VTC service**. On the DIDComm path the authcrypt envelope authenticates you as the sender, so the VP itself does not need a separate holder-binding signature. The OpenVTC CLI assembles the VP, sets the DIDComm message `type` field to the join-request Trust Task URL (`https://trusttasks.org/openvtc/vtc/join-requests/submit/1.0`), and hands the message off to the mediator for relay. The VTC's immediate reply on the same thread is a `https://trusttasks.org/openvtc/vtc/join-requests/submit-receipt/1.0` message — an acknowledgement carrying the assigned `request_id` and an initial `status` (`pending` in the current implementation). The actual policy outcome, and any credentials issued, are delivered separately (see Step 6).

> _Specific CLI invocation to be documented._

**Alternative: REST submission.** Communities that publish their VTC service over HTTPS may also accept join requests at the unauthenticated, rate-limited REST endpoint `POST /v1/join-requests`. The request body carries the same VP, but on this path the VP must carry a **holder-binding signature** from your M-DID — there is no DIDComm envelope authenticating the sender, so the VP itself is what proves you control the M-DID. The DIDComm path is the default for an outside developer (it reuses the community's existing public mediator rather than requiring the VTC service to be directly reachable from the open internet), but REST is available wherever the community has chosen to publish it. The two paths bind to the same Trust Task, run the same policy, and produce the same outcomes; use whichever the community advertises.

### Step 6 — Receive the decision

The VTC service evaluates your VP against the community's join policy and your request resolves into one of three outcome categories (mapped to `JoinRequest.status` values in the VTC spec):

- **`Approved` — the normal path.** Policy returned `allow=true`. The VTC mints a **VMC** (Verifiable Membership Credential) and an initial role **VEC** (Verifiable Endorsement Credential — your member role) for your M-DID, writes your M-DID into the community's ACL and trust registry as `Active`, and sealed-transfers the credentials back to your M-DID. You receive the bundle within seconds.
- **`Rejected`.** Policy returned `allow=false`. The VTC persists the request as `Rejected` with a rationale and notifies you over DIDComm where reachable. You cannot retry without a submission the current policy will accept — typically that means soliciting different or additional VRCs.
- **`Pending` or `Deferred` — manual review.** The policy could not make a clean call (for example, a trust-registry check it couldn't resolve in time), or the community's policy is configured to surface borderline cases for human review. Your request stays in the queue (`Pending`, or `Deferred` if the policy explicitly held it) for a community admin to act on. This is the fallback path, not the normal one.

On `Approved`, the community's members-only mediator subsequently begins accepting traffic to and from your M-DID, because your DID is now on the allowlist derived from the trust registry.

## Verification

After an `Approved` outcome you should be able to:

- Resolve your M-DID via the community's WebVH host.
- Present your VMC against the community's status list and see it as not-revoked.
- See your M-DID listed as `Active` in the community's trust registry.
- Receive a DIDComm message addressed to your M-DID via the **members-only mediator** (not just the public/join one).
- See an entry for your M-DID in the community's published members directory, if one is exposed.

At that point you have graduated to [P02 — Member Developer](P02-developer-member.md).

## Notes

- **The two-VRC threshold is the community's current join policy** — encoded as a Rego module the admins maintain — and will tighten as the community grows. Future policies may require more issuers, specific issuer roles, or additional credential types. The submission shape (a signed VP carrying your M-DID and supporting credentials) does not change; only the criteria the policy applies do.
- **VRCs are issued to your M-DID, not your Personal VTA's primary DID.** Don't substitute the latter for membership purposes — it links your communities together.
- **M-DIDs are scoped to a single community.** If you ever leave and rejoin a community, plan on minting a new M-DID; re-presenting an old one is a privacy hazard, especially across revocation events.
- **The mnemonic for your Personal VTA backs every M-DID you mint.** Loss of that mnemonic loses every community identity you hold. This is the single most expensive mistake you can make on this path — see the recovery notes in [T01](../tutorials/T01-self-managed-personal-vta.md).
- **You can opt out of trust-registry publication.** Your submission carries a `registryConsent` flag (default `false` in the current SDK type). If you set it true, your M-DID is written to the community's public trust registry on `Approved` per the community's `registry.rego`; leave it false and your membership stays inside the community (visible via the ACL and the members-only mediator) but is not externally listed. Most outside devs joining a community want external verifiability, so setting it true is usually the right call.
- **You are not running community infrastructure.** If you also want to operate a community mediator or WebVH host, see [P05 — Infra Operator](P05-infra-operator.md).
