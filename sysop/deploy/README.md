# Deploy Stream

Run the VTI stack as a hardened, multi-tenant production deployment on **Kubernetes**. This is the **VTA Farm**: the same platform that hosts the Personal VTAs developers get from [vtafarm.firstperson.dev](https://vtafarm.firstperson.dev) in [Path A of the developer guide](../../developer/01-personal-vta.md#path-a--vta-farm-streamlined). This stream is for running a farm of your own.

Where the [Explore stream](../explore/) puts everything on one root-owned VM and drives each service by hand, a farm gives every user their own Kubernetes namespace, keeps every VTA master seed encrypted in **HashiCorp Vault**, terminates TLS at the ingress with a cert-manager wildcard certificate, and provisions VTAs from a browser with a passkey.

## Same bootstrap flow, automated

A farm provisions each user's stack with the same **offline sealed-bundle bootstrap** over DIDComm that the [Explore walkthrough](../explore/02-walkthrough.md) steps through by hand. The API renders the same TOML recipes and runs them as one-off Kubernetes Jobs:

| Walkthrough step | What the farm runs |
| --- | --- |
| Step 1 — `vta setup` | A `vta setup --from` Job on the VTA's volume |
| Step 2 — `pnm setup`, then `vta import-did` | You still run `pnm setup` on your own machine and hand the admin DID to the farm. The farm runs the `vta import-did --role admin` Job for you, after the mediator and DID host steps and just before the VTA starts |
| Step 3 — mediator phase 1, `vta contexts reprovision`, mediator phase 2 | Three Jobs. The reprovision Job mounts both the VTA and mediator volumes so it can read `bootstrap-request.json` and write `bundle.armor`, exactly as the two home directories are used on the single host |
| Step 4 — DID host phase 1, `vta bootstrap provision-integration`, DID host phase 2, admin invite, `did-mgmt servers add` | The same three-Job handoff, then Jobs for the admin invite, for loading the VTA and mediator DID logs into the daemon, and for registering the daemon with the VTA |
| Step 5 — `vtc setup`, `contexts create` | Three Jobs: generate the VTC's setup key, grant it on the VTA, then `vtc setup --from` once VTA, mediator, and DID host are all reachable |
| `nohup <binary> &` | A Deployment per component |

The difference is who holds the secrets: every component stores them in the farm Vault via Kubernetes auth, so no secret sits in plaintext on a volume. The full mapping is in [`docs/full-stack-setup-design.md`](https://github.com/ic3software/vtafarm-api/blob/main/docs/full-stack-setup-design.md) in `vtafarm-api`.

This applies to **Full Stack** sessions, which provision VTA, mediator, DID host, and VTC per user. A **VTA Only** session, which is what a developer's Personal VTA is, points its VTA at the farm's shared mediator and DID host instead, so no bundle exchange is needed.

## The three repos

The deploy stream lives in three repositories under [ic3software](https://github.com/ic3software). Read them in this order.

| Repo | What it is | Start with |
| --- | --- | --- |
| [vtafarm-k8s](https://github.com/ic3software/vtafarm-k8s) | OpenTofu stacks that build the clusters and platform layer on Hetzner Cloud, plus the operator runbooks | The README's eight deploy steps, then [`docs/vault.md`](https://github.com/ic3software/vtafarm-k8s/blob/main/docs/vault.md) |
| [vtafarm-api](https://github.com/ic3software/vtafarm-api) | Go REST API that creates VTA setup sessions, isolates users into per-user namespaces, provisions their Vault policies, and drives the sealed-bundle bootstrap as Kubernetes Jobs | The README's **Production Deployment** section (TLS, Vault, secrets, Helm, migrations), then [`docs/vta-setup-design.md`](https://github.com/ic3software/vtafarm-api/blob/main/docs/vta-setup-design.md) and [`docs/full-stack-setup-design.md`](https://github.com/ic3software/vtafarm-api/blob/main/docs/full-stack-setup-design.md) |
| [vtafarm](https://github.com/ic3software/vtafarm) | React frontend: user portal, VTA creation, admin panel | The README, then [`docs/release.md`](https://github.com/ic3software/vtafarm/blob/main/docs/release.md) for publishing an image |

## What gets built

`vtafarm-k8s` builds five layers, each as its own OpenTofu stack, in this order:

1. A three-node high-availability **k3s** management cluster.
2. **Rancher**, running on that cluster.
3. An **RKE2** cluster that Rancher creates for the farm.
4. The platform inside that cluster: **cert-manager**, **Longhorn**, and **HashiCorp Vault** (Raft, HA, auto-unsealed by a separate transit Vault).
5. The `vtafarm` frontend and `vtafarm-api` backend, deployed via Helm.

Layers 1 and 2 are built once. Layers 3 to 5 make up one farm, so they repeat for every farm you run.

## Before you start

The [vtafarm-k8s prerequisites](https://github.com/ic3software/vtafarm-k8s#prerequisites) are the authoritative list. In short, you need:

- A Hetzner Cloud project, API token, private Object Storage bucket for OpenTofu state and etcd snapshots, and S3 credentials.
- A DNS zone you control. The farm domain must be on **Cloudflare**, because the API creates per-tenant DNS records there and Cloudflare is the only provider it supports today.
- OpenTofu 1.12+, `kubectl`, `helm`, and `jq` on your workstation.
- A `did:key` keypair for the API's DID hosting integration, generated with `make gen-keypair` in `vtafarm-api` and registered with the DID hosting service as a **Service** role.

## Day-two operations

The `vtafarm-k8s` [`docs/`](https://github.com/ic3software/vtafarm-k8s/tree/main/docs) folder holds the runbooks: operations, backup and restore, upgrades (cluster and Vault), cluster migration, teardown, troubleshooting, cost, and the design decisions behind the layout.

## Still learning the stack?

Use the [Explore stream](../explore/) first. It walks through every service's wizard by hand, which is the fastest way to understand what a farm automates. Just don't put real keys or production data on an explore box.
