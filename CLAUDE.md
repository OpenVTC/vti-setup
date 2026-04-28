# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A documentation-only repository — no build system, no tests, no application code. Every file in `scenarios/` and `deployments/` is a Markdown guide describing how to set up the VTI stack (VTA + WebVH + DIDComm Mediator).

## Linting

```bash
markdownlint-cli2 "**/*.md"
```

`.markdownlint.json` disables MD013 (line length).

## Document structure

### Scenarios (`scenarios/`)

12 files named `S{NN}-{setup-type}-{transport}-{mode}.md`. Each follows this exact template:

```markdown
## Prerequisites
## Steps
## Verification
## Known Issues / Edge Cases
## Deployment Notes
```

The 12 scenarios come from: **3 setup types** × **2 transports** × **2 modes**:

| Setup Type | Transport | Mode |
| --- | --- | --- |
| online-vta | rest | interactive |
| offline-vta | didcomm | noninteractive |
| self-managed | | |

### Deployments (`deployments/`)

4 files named `D{NN}-{environment}.md` (local-dev, ubuntu-server, kubernetes, AWS-ec2). Deployment is a cross-cutting concern — any scenario can run on any deployment.

## Key concepts

- **Online VTA**: VTA is running and reachable; services connect to it directly.
- **Offline VTA**: VTA exists but is unreachable at setup time; services import pre-generated bundles.
- **Self-Managed**: No VTA; Mediator and WebVH manage their own keys independently.
- **Interactive**: Human in the loop.
- **Non-interactive**: Fully scripted / automated.
