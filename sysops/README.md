# Sysops

You run the VTI infrastructure: VTA, DIDComm Mediator, and DID Hosting Daemon. [Developers](../developer/) and [community managers](../community-manager/) sit on top of what you set up.

## Your path

You do two things, in this order:

### 1. Provision the host

Pick where the services will run.

| Deployment | When to pick it |
| --- | --- |
| [Ubuntu Server](ubuntu-server.md) | Production-shaped single-server setup. The most thoroughly tested path. |
| [Kubernetes](kubernetes.md) | Multi-node cluster, ingress + cert-manager. Reference is RKE2 + Rancher on Hetzner. |
| [Local Dev](local-dev.md) | Local development and testing only. _(Not yet written.)_ |
| [AWS EC2 / VPS](aws-ec2.md) | Cloud-hosted VM for Trusted Execution Environments. _(Not yet written.)_ |

### 2. Set up VTI

Same end state, two operator styles — pick one.

| How you want to drive it | Guide |
| --- | --- |
| Step through each tool's wizard interactively | [Interactive setup](interactive-setup.md) |
| Drive from TOML recipes and CLI flags | [Automated setup](automated-setup.md) |

Both use the **offline sealed-bundle bootstrap** flow over DIDComm — the same flow you'd use to set up a VTI where the VTA is air-gapped from Mediator and DID Host, even when they happen to share a host.

## Self-managed components

If you only need one piece of the stack — say, just a Mediator that doesn't hang off a VTA — these guides cover the standalone setups:

- [Self-Managed Mediator](self-managed-mediator.md) _(stub)_
- [Self-Managed DID Host](self-managed-did-host.md) _(stub)_
