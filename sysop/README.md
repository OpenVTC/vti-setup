# Sysop

You install and manage the VTI infrastructure: VTA, VTC, DIDComm Mediator, and DID Hosting. [Developers](../developer/) and [community managers](../community-manager/) use and run on top of what you set up.

## Pick a stream

| Stream | When to pick it | Shape |
| --- | --- | --- |
| [Explore](explore/) | "I want to play with the stack and learn how the pieces fit together." | Single VM, single root SSH session, everything installed (Rust, Node, Docker, build deps). Interactive TUI wizards. `nohup` for processes. **Do not put real keys here.** |
| [Deploy](deploy/) | "I want a hardened production deployment." | Hardened Kubernetes deployment with HashiCorp Vault as the secret store. _(To be documented.)_ |

Both streams use the **offline sealed-bundle bootstrap** flow over DIDComm — the same flow you'd use to set up a VTI where the VTA is air-gapped from Mediator and DID Host, even when they happen to share a host.
