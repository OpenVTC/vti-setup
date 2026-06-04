# Explore Stream

Stand up the VTI stack on a throwaway VM, as root, so you can play with it and learn how the pieces fit together. Everything installed, single DID Hosting topology, interactive wizards, processes launched with `nohup`.

> **⚠️ Do not use this stream for real keys, real users, or production data.**
> The box runs everything as root, leaves SSH wide open to the operator, and has no per-service isolation. For a hardened production deployment, use the [Deploy stream](../deploy/) instead.

## Path

Read these in order:

1. [Server setup](server-setup.md) — create the Ubuntu host, configure DNS, run `setup-explore.sh`.
2. [Walkthrough](walkthrough.md) — step through each tool's TUI wizard, save the IDs each step asks you to save.
