# Sysop

You install and manage the VTI infrastructure: VTA, VTC, DIDComm Mediator, and DID Hosting. [Developers](../developer/) and [community managers](../community-manager/) use and run on top of what you set up.

## Pick a stream

Two end-to-end paths, completely independent. Pick based on what you want out of this server.

| Stream | When to pick it | Shape |
| --- | --- | --- |
| [Explore](explore/) | "I want to play with the stack and learn how the pieces fit together." | Single VM, single root SSH session, everything installed (Rust, Node, Docker, build deps). Interactive TUI wizards. `nohup` for processes. **Do not put real keys here.** |
| [Deploy](deploy/) | "I want a hardened production deployment." | Two-stage server bootstrap (root creates a `vti` operator user, locks down sshd). Per-service system users with no shell, no sudo. systemd units with sandboxing. Automated TOML-recipe provisioning. Both DID Hosting topologies (standard or standalone). |

Both streams use the **offline sealed-bundle bootstrap** flow over DIDComm — the same flow you'd use to set up a VTI where the VTA is air-gapped from Mediator and DID Host, even when they happen to share a host.

## Other deployment targets

| Target | Status |
| --- | --- |
| [Kubernetes](kubernetes.md) | Multi-node cluster, ingress + cert-manager. Reference is RKE2 + Rancher on Hetzner. |
| [Local Dev](local-dev.md) | Local development and testing. _(Not yet written.)_ |
| [AWS EC2 / VPS](aws-ec2.md) | Cloud-hosted VM for Trusted Execution Environments. _(Not yet written.)_ |
