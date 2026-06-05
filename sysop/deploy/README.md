# Deploy Stream

Stand up the VTI stack as a hardened production deployment. Two-stage server setup (root bootstraps a `vti` operator user; `vti` then provisions the stack). Each service runs as its own dedicated system user (`vta-svc`, `mediator-svc`, `dids-svc`, `vtc-svc`, plus standalone `dids` variants) with no shell and no sudo. Processes are supervised by systemd with sandboxing. Provisioning is automated from TOML recipes — no interactive wizards. Cross-service file handoffs go through a shared `vti-exchange` group.

## Security model in one paragraph

`vti` is the human operator: SSH key only, NOPASSWD sudo for system maintenance. Service users are unprivileged system accounts with `nologin` shells — they cannot sudo, cannot SSH, cannot read each other's data. An in-process RCE on the mediator lands the attacker as `mediator-svc`, which has none of the routes a root-process compromise would have. Root SSH login is disabled by the bootstrap script.

## Path

Read in order:

1. [01 — Server bootstrap](01-server-bootstrap.md) — SSH as root, run `bootstrap-user.sh`, then reconnect as vti.
2. [02 — Server setup](02-server-setup.md) — SSH as vti, run `setup-deploy.sh`. Installs service users, systemd units, nginx, certbot.
3. [03 — Provisioning](03-provisioning.md) — TOML-recipe-driven setup for VTA, Mediator, DID Hosting Daemon, VTC, and PNM binding. Standard DID Hosting topology.
4. [04 — DID Hosting topology](04-did-hosting-topology.md) — when to pick standalone vs standard, and the standalone provisioning flow.
