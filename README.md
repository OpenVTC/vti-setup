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
      Kubernetes
      Local Dev
      EC2 / VPS
```

| # | Dimension | Options | Notes |
| - | --------- | ------- | ----- |
| 1 | **Setup Type** | Online VTA · Offline VTA · Self-Managed | How your service gets its keys and DID |
| 2 | **Transport** | REST · DIDComm | Protocol used to talk to the VTA |
| 3 | **Mode** | Interactive · Non-interactive | Human in the loop vs fully scripted |
| 4 | **Deployment** | Kubernetes · Local Dev · EC2/VPS | Runtime environment — affects keyring availability |

### Setup Type explained

```mermaid
flowchart TD
    Q1{"Is there already\na running VTA\nyou can reach?"}
    Q2{"Do you want\nto run your\nown VTA?"}
    ONLINE["① Online VTA\nConnect your app/service\nto the existing VTA.\nNo private info leaves\nthe VTA."]
    OFFLINE["② Offline VTA\nAir-gapped or\nboot-strapping order.\nVTA wizard runs offline;\nservices import\npre-generated bundles."]
    SELF["③ Self-Managed\nYou operate the VTA\nyourself — full control,\nfull responsibility."]

    Q1 -->|Yes| ONLINE
    Q1 -->|No| Q2
    Q2 -->|"No (use a VTA\nbut it's unreachable\nat setup time)"| OFFLINE
    Q2 -->|Yes| SELF
```

---

## 12 Core Scenarios

The three setup types × two transports × two modes produce **12 scenarios**. The deployment environment is a cross-cutting concern documented separately (see [Deployment Environments](#deployment-environments)).

| | **REST** | **REST** | **DIDComm** | **DIDComm** |
| --- | :---: | :---: | :---: | :---: |
| | Interactive | Non-interactive | Interactive | Non-interactive |
| **Online VTA** | [S01](scenarios/S01-online-vta-rest-interactive.md) | [S02](scenarios/S02-online-vta-rest-noninteractive.md) | [S03](scenarios/S03-online-vta-didcomm-interactive.md) | [S04](scenarios/S04-online-vta-didcomm-noninteractive.md) |
| **Offline VTA** | [S05](scenarios/S05-offline-vta-rest-interactive.md) | [S06](scenarios/S06-offline-vta-rest-noninteractive.md) | [S07](scenarios/S07-offline-vta-didcomm-interactive.md) | [S08](scenarios/S08-offline-vta-didcomm-noninteractive.md) |
| **Self-Managed** | [S09](scenarios/S09-self-managed-rest-interactive.md) | [S10](scenarios/S10-self-managed-rest-noninteractive.md) | [S11](scenarios/S11-self-managed-didcomm-interactive.md) | [S12](scenarios/S12-self-managed-didcomm-noninteractive.md) |

### High-level flow per setup type

#### Online VTA

```mermaid
sequenceDiagram
    participant Admin as VTA Admin
    participant VTA as VTA (running)
    participant App as Your App

    Admin->>VTA: provision context for App
    VTA-->>Admin: credential bundle (base64url)
    Admin->>App: hand over credential bundle
    App->>VTA: authenticate with credential bundle
    VTA-->>App: DidSecretsBundle (DID + private keys)
    App->>App: cache secrets locally
    note over App: App now operates with its own DID
```

#### Offline VTA (boot-strap / air-gapped)

```mermaid
sequenceDiagram
    participant Wizard as VTA Setup Wizard
    participant VTA as VTA Service
    participant WebVH as WebVH Service
    participant MED as Mediator

    note over Wizard: Runs fully offline — no services up yet
    Wizard->>Wizard: generate BIP-39 seed
    Wizard->>Wizard: derive DIDs + key material
    Wizard->>Wizard: write config.toml + secrets bundles

    note over WebVH,MED: Services start and import pre-generated artifacts
    VTA->>WebVH: import-did (did:webvh log)
    MED->>MED: load-did / --import-bundle
    WebVH-->>VTA: DID hosted publicly

    note over VTA: VTA now reachable; normal Online VTA flow continues
```

#### Self-Managed

```mermaid
sequenceDiagram
    participant Ops as Operator
    participant VTA as VTA Service
    participant WebVH as WebVH Service
    participant MED as Mediator
    participant App as Your App

    Ops->>VTA: run setup wizard (interactive or scripted)
    VTA->>WebVH: provision WebVH context + DID
    VTA->>MED: provision mediator context + DID
    Ops->>VTA: provision app context
    VTA-->>Ops: credential bundle for App
    Ops->>App: configure with credential bundle
    App->>VTA: authenticate
    VTA-->>App: DidSecretsBundle
```

---

## Deployment Environments

The deployment environment is orthogonal to the 12 scenarios above — any scenario can run on any environment, but each environment has constraints that affect how secrets are stored.

```mermaid
graph LR
    subgraph "Secret Storage Options"
        KR["OS Keyring\n(macOS Keychain,\nGNOME Keyring,\nWindows Credential Mgr)"]
        CFG["Config File\n(config-seed feature)\nK8s Secret → mounted file"]
        AWS["AWS Secrets\nManager"]
        GCP["GCP Secret\nManager"]
        AZ["Azure Key Vault"]
    end

    D01["D01 Local Dev"] -->|default| KR
    D02["D02 Ubuntu Server"] -->|no keyring daemon| CFG
    D03["D03 Kubernetes"] -->|no keyring daemon| CFG
    D03 --> AWS
    D03 --> GCP
    D03 --> AZ
    D04["D04 AWS EC2"] -->|no desktop keyring| CFG
    D04 --> AWS
```

| Environment | Keyring | Recommended seed storage | Notes |
| ----------- | :-----: | ------------------------ | ----- |
| [D01 Local Dev](deployments/D01-local-dev.md) | ✅ | `keyring` (default) | macOS Keychain / GNOME Keyring |
| [D02 Ubuntu Server](deployments/D02-ubuntu-server.md) | ❌ | `config-seed` | Headless Linux |
| [D03 Kubernetes](deployments/D03-kubernetes.md) | ❌ | `config-seed` | |
| [D04 AWS EC2](deployments/D04-AWS-ec2.md) | ⚠️ | `aws-secrets` | IAM role for Secrets Manager access |

---

## Repository Layout

```text
vti-setup/
├── README.md
├── scenarios/
│   ├── S01-online-vta-rest-interactive.md
│   ├── S02-online-vta-rest-noninteractive.md
│   ├── S03-online-vta-didcomm-interactive.md
│   ├── S04-online-vta-didcomm-noninteractive.md
│   ├── S05-offline-vta-rest-interactive.md
│   ├── S06-offline-vta-rest-noninteractive.md
│   ├── S07-offline-vta-didcomm-interactive.md
│   ├── S08-offline-vta-didcomm-noninteractive.md
│   ├── S09-self-managed-rest-interactive.md
│   ├── S10-self-managed-rest-noninteractive.md
│   ├── S11-self-managed-didcomm-interactive.md
│   └── S12-self-managed-didcomm-noninteractive.md
└── deployments/
    ├── D01-local-dev.md
    ├── D02-ubuntu-server.md
    ├── D03-kubernetes.md
    └── D04-AWS-ec2.md
```

---

## Contributing

Each scenario file follows a common template:

1. **Prerequisites** — what must be in place before you start
2. **Environment** — which deployment this was tested on
3. **Steps** — numbered, reproducible commands
4. **Verification** — how to confirm it worked
5. **Known issues** — edge cases encountered during testing

If you have tested a path, please open a PR filling in the corresponding scenario file and deployment notes.
