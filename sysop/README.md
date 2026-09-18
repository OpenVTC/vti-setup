# Sysop

You install and manage the VTI infrastructure: VTA, VTC, DIDComm Mediator, and DID Hosting. [Developers](../developer/) and [community managers](../community-manager/) use and run on top of what you set up.

## Pick a stream

| Stream | When to pick it | Shape |
| --- | --- | --- |
| [Explore](explore/) | "I want to play with the stack and learn how the pieces fit together." | Single VM, single root SSH session, build tools installed (Rust, build deps; Node.js only for the optional UI source build). Interactive TUI wizards. `nohup` for processes. **Do not put real keys here.** |
| [Deploy](deploy/) | "I want a hardened production deployment." | Run your own **VTA Farm**: a multi-tenant Kubernetes platform (RKE2 on Hetzner, built with OpenTofu) with HashiCorp Vault as the secret store. Documented in the `ic3software/vtafarm-k8s`, `vtafarm-api`, and `vtafarm` repos; the [Deploy page](deploy/) tells you where to start. |

Both streams use the **offline sealed-bundle bootstrap** flow over DIDComm — the same flow you'd use to set up a VTI where the VTA is air-gapped from Mediator and DID Host, even when they happen to share a host. The Explore stream walks it by hand; the Deploy stream runs the same recipes as Kubernetes Jobs when it provisions a full stack for a user.
