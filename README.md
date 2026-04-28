# VTI Setup Guide

An IC3-maintained collection of setup paths for the stack: VTA, WebVH, and the DIDComm Mediator.

- [Verifiable Trust Infrastructure](https://github.com/OpenVTC/verifiable-trust-infrastructure)
- [WebVH](https://github.com/affinidi/affinidi-webvh-service)
- [Mediator](https://github.com/affinidi/affinidi-tdk-rs/tree/main/crates/messaging/affinidi-messaging-mediator)

The goal is to document every realistic combination of setup type, transport, mode, and deployment environment so that anyone — from a first-time developer to an ops team deploying to production — can find a tested, reproducible path.

---

## Components

```mermaid
graph TB
    subgraph VTI["Verifiable Trust Infrastructure (VTI)"]
        VTA["VTA Service\n(master key store, DIDs, ACL)"]
        WebVH["WebVH Service\n(did:webvh hosting)"]
        MED["DIDComm Mediator\n(message relay)"]
    end

    CLI["PNM / CNM CLI\n(operator tooling)"]
    APP["3rd-party App\n(vta-sdk integration)"]

    CLI -->|"REST / DIDComm"| VTA
    APP -->|"REST / DIDComm"| VTA
    VTA -->|"provisions context + keys"| WebVH
    VTA -->|"provisions context + keys"| MED
    MED -->|"resolves DIDs via"| WebVH
    APP -->|"sends / receives messages"| MED
```

| Component | Repo | Role |
| --------- | ---- | ---- |
| **VTA** | [OpenVTC/verifiable-trust-infrastructure](https://github.com/OpenVTC/verifiable-trust-infrastructure) | Master key store — manages BIP-39 seed, DIDs, contexts, and ACL |
| **WebVH** | [affinidi/affinidi-webvh-service](https://github.com/affinidi/affinidi-webvh-service) | Hosts `did:webvh` DID documents publicly |
| **Mediator** | [affinidi/affinidi-tdk-rs · affinidi-messaging-mediator](https://github.com/affinidi/affinidi-tdk-rs/tree/main/crates/messaging/affinidi-messaging-mediator) | DIDComm v2 relay and message routing |

---

## The Four Dimensions

Every setup path is defined by four independent choices:

```mermaid
mindmap
  root((VTI Setup))
    Setup Type
      Online VTA
      Offline VTA
      Self-Managed
    Transport
      REST
      DIDComm
    Mode
      Interactive
      Non-interactive
    Deployment
      Local Dev
      Ubuntu Server
      Kubernetes
      EC2 / VPS
```

| # | Dimension | Options | Notes |
| - | --------- | ------- | ----- |
| 1 | **Setup Type** | Online VTA · Offline VTA · Self-Managed | How Mediator and WebVH interact with the VTA |
| 2 | **Transport** | REST · DIDComm | Protocol used to talk to the VTA |
| 3 | **Mode** | Interactive · Non-interactive | Human in the loop vs fully scripted |
| 4 | **Deployment** | Local Dev · Ubuntu Server · Kubernetes · EC2/VPS | Runtime environment — affects keyring availability |

### Setup Type explained

```mermaid
flowchart TD
    Q1{"Is the VTA\nreachable?"}
    Q2{"Do you have a VTA\nbut it is not reachable\nat setup time?"}
    ONLINE["① Online VTA\nVTA is running and reachable.\nServices connect to it directly\nfor key issuance and DID management."]
    OFFLINE["② Offline VTA\nVTA exists but is unreachable\n(air-gapped or bootstrapping).\nVTA wizard runs offline;\nservices import pre-generated bundles."]
    SELF["③ Self-Managed\nNo VTA involved.\nMediator and WebVH operate\nindependently and manage\ntheir own keys."]

    Q1 -->|Yes| ONLINE
    Q1 -->|No| Q2
    Q2 -->|Yes| OFFLINE
    Q2 -->|No| SELF
```

---

## 12 Core Scenarios

The three setup types × two transports × two modes produce **12 scenarios**. The deployment environment is a cross-cutting concern — any scenario can run on any of the four deployment environments.

| | **REST** | **REST** | **DIDComm** | **DIDComm** |
| --- | :---: | :---: | :---: | :---: |
| | Interactive | Non-interactive | Interactive | Non-interactive |
| **Online VTA** | [S01](scenarios/S01-online-vta-rest-interactive.md) | [S02](scenarios/S02-online-vta-rest-noninteractive.md) | [S03](scenarios/S03-online-vta-didcomm-interactive.md) | [S04](scenarios/S04-online-vta-didcomm-noninteractive.md) |
| **Offline VTA** | [S05](scenarios/S05-offline-vta-rest-interactive.md) | [S06](scenarios/S06-offline-vta-rest-noninteractive.md) | [S07](scenarios/S07-offline-vta-didcomm-interactive.md) | [S08](scenarios/S08-offline-vta-didcomm-noninteractive.md) |
| **Self-Managed** | [S09](scenarios/S09-self-managed-rest-interactive.md) | [S10](scenarios/S10-self-managed-rest-noninteractive.md) | [S11](scenarios/S11-self-managed-didcomm-interactive.md) | [S12](scenarios/S12-self-managed-didcomm-noninteractive.md) |

---

## Contributing

Each scenario file follows a common template:

1. **Prerequisites** — what must be in place before you start
2. **Environment** — which deployment this was tested on
3. **Steps** — numbered, reproducible commands
4. **Verification** — how to confirm it worked
5. **Known issues** — edge cases encountered during testing

If you have tested a path, please open a PR filling in the corresponding scenario file and deployment notes.
