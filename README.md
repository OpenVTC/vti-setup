# VTI Setup

Setup guides for the **Verifiable Trust Infrastructure** stack — VTA, DID Host, and the DIDComm Mediator — and for the things people do on top of it.

The repo is organised by **who you are**, not by which service you're touching. Pick your role and follow the path.

---

## Pick your role

### [Developer](developer/)

You use OpenVTC to participate in one or more VTCs. You'll run a Personal VTA for your keys, drive it from the OpenVTC CLI/TUI, and join communities to present and collect credentials.

→ [`developer/`](developer/) · stand up a Personal VTA, install the TUI, join your first community

### [Community Manager](community-manager/)

You operate a VTC: bootstrap the community, set join and role policies, manage the ACL, review what automation can't decide.

→ [`community-manager/`](community-manager/) · bootstrap a VTC, ship policies, run the community

### [Sysop](sysop/)

You run the VTI services so the other two can do their jobs. Provision the host, stand up VTA + Mediator + DID Hosting Daemon.

→ [`sysop/`](sysop/) · pick a stream: **explore** the VTI or **deploy** it for a community

---

## Components

```mermaid
graph TB
    subgraph VTI["Verifiable Trust Infrastructure (VTI)"]
        VTA["VTA Service\n(master key store, DIDs, ACL)"]
        DIDHost["DID Hosting Service\n(did:webvh hosting)"]
        MED["DIDComm Mediator\n(message relay)"]
    end

    CLI["PNM / CNM CLI\n(operator tooling)"]
    APP["3rd-party App\n(vta-sdk integration)"]

    CLI -->|"REST / DIDComm"| VTA
    APP -->|"REST / DIDComm"| VTA
    VTA -->|"provisions context + keys"| DIDHost
    VTA -->|"provisions context + keys"| MED
    MED -->|"resolves DIDs via"| DIDHost
    APP -->|"sends / receives messages"| MED
```

| Component | Repo | Role |
| --- | --- | --- |
| **VTA** | [OpenVTC/verifiable-trust-infrastructure](https://github.com/OpenVTC/verifiable-trust-infrastructure) | Master key store — manages BIP-39 seed, DIDs, contexts, and ACL |
| **DID Host** | [affinidi/affinidi-webvh-service](https://github.com/affinidi/affinidi-webvh-service) | Hosts `did:webvh` DID documents publicly |
| **Mediator** | [affinidi/affinidi-tdk-rs · affinidi-messaging-mediator](https://github.com/affinidi/affinidi-tdk-rs/tree/main/crates/messaging/affinidi-messaging-mediator) | DIDComm v2 relay and message routing |
| **OpenVTC** | [OpenVTC/openvtc](https://github.com/OpenVTC/openvtc) | CLI/TUI for joining and participating in VTCs |

---

## Contributing

If you've followed a path and have notes, fixes, or a new tested combination to add, open a PR against the relevant persona folder. Stub pages (marked _Not yet written_) are tracked roadmap, not abandoned drafts — please fill one in if you've done the work.
