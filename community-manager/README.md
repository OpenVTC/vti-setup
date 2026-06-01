# Community Manager

You operate a Verifiable Trust Community (VTC). After a [system operator](../sysop/) stands up your community's infrastructure (VTA, VTC, etc.), you author and ship the join/role policies that decide who gets in and what they can do, manage the ACL and trust registry, and review the requests automation can't decide on its own.

You're not [the developer](../developer/) using the community. And you're not the [sysop](../sysop/) — they put VTA, Mediator, and DID Host on the wire; you sit on top of that, owning community lifecycle and identity decisions.

## Your path

1. **[Bootstrap a VTC](bootstrap-vtc.md)** — bring the community into existence: VTC service, initial admin keys, initial trust-registry state. _(Not yet written.)_

Future tutorials will cover authoring `join.rego` policies, role-credential issuance, ACL changes, status-list management, and the manual-review queue for `Pending`/`Deferred` join requests.

## Prerequisites you'll need before you start

- A running [VTI deployment](../sysop/) — your community VTA needs a host, a mediator to talk on, and a DID host to publish DIDs.
- A clear policy stance on who gets in. The current OpenVTC initial-days default is "two existing members vouch via VRCs" — see [Joining a Community](../developer/joining-a-community.md) for what that looks like from the applicant's side. You can change the rule, but you should know what you're changing from.
