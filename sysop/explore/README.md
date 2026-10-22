# Explore Stream

Stand up the VTI stack on a throwaway VM, as root, so you can play with it and learn how the pieces fit together. Running as root keeps the commands short and keeps file permissions out of your way while you learn; [Why root?](01-server-setup.md#why-root) explains the choice. Everything installed, single DID Hosting topology, interactive wizards, processes launched with `nohup`. The stack is the VTA, DIDComm Mediator, DID Hosting Daemon, Trust Registry and VTC.

> **⚠️ Do not use this stream for real keys, real users, or production data.**
> The box runs everything as root, leaves SSH wide open to the operator, and has no per-service isolation. For a hardened production deployment, see the [Deploy stream](../deploy/) (a VTA Farm on hardened Kubernetes).

## Path

Read these in order:

1. [01 — Server setup](01-server-setup.md) — create the Ubuntu host, configure DNS, run `setup-explore.sh`.
2. [02 — Walkthrough](02-walkthrough.md) — step through each tool's TUI wizard, provision the Trust Registry with `pnm`, save the IDs each step asks you to save.
3. [03 — Verifiable Git Infrastructure](03-verifiable-git-infrastructure.md) — put a GitHub organization under the VTC: install the VGI bridge, register its GitHub App, bind the organization, adopt a repository, grant members rights, and sign commits with VTA-held keys.
