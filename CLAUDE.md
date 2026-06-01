# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A documentation-only repository — no build system, no tests, no application code. Every page is a Markdown guide describing how to set up or use the VTI stack (VTA + DID Host + DIDComm Mediator).

## Layout

Organised by **persona** — who's reading — not by topic.

| Folder | Reader | Contents |
| --- | --- | --- |
| `developer/` | Individual using OpenVTC to take part in VTCs | Personal VTA, OpenVTC TUI, joining a community |
| `community-manager/` | VTC operator | Bootstrap a VTC, policy authoring, ACL/registry management (mostly future) |
| `sysop/` | VTI infra operator | Host deployments (Ubuntu / Kubernetes / local-dev / AWS-EC2), interactive + automated VTI setup, self-managed component variants |

Each folder has a `README.md` that is the persona's entry point — a one-page index of the journey, with links into the per-topic pages.

Some files are stubs (`_To be documented._` or `_Not yet written._`). Those are intentional placeholders for tracked roadmap, not abandoned drafts.

## Linting

```bash
markdownlint-cli2 "**/*.md"
```

`.markdownlint.json` disables MD013 (line length). Do not manually wrap long lines — leave prose as single lines and let the editor handle soft-wrapping.

## Key concepts

- **VTA** — Verifiable Trust Agent; the master key store. A **Personal VTA** is one a developer runs for themselves; an **infrastructure VTA** is the trust anchor at the centre of a VTI deployment.
- **VTC** — Verifiable Trust Community; the social/policy layer that sits on top of a VTI.
- **Offline VTA setup** — the VTA is unreachable at setup time (air-gapped, or just bootstrapping). Mediator and WebVH import pre-generated sealed bundles. This is the flow both `sysop/interactive-setup.md` and `sysop/automated-setup.md` describe.
- **Interactive vs automated** — same end state, two operator styles. Interactive walks each tool's TUI; automated drives the same flow from TOML recipes and CLI flags.
