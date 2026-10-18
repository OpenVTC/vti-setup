# Developer

You use OpenVTC to take part in one or more VTCs. You'll run a Personal VTA that holds your keys, drive it from the OpenVTC CLI/TUI, and present credentials when communities ask for them.

You do **not** run the community's infrastructure. That's the [sysop](../sysop/). You don't bootstrap or administer a community — that's a [community manager](../community-manager/).

> **⚠️ Out of date until VTI-Fig.** These guides were verified on the builds in each page's **Verified with** table, which predate the VTI-Eucalyptus release. Prompts, flags and outputs may have changed since; where they differ, trust the tool. Take PNM, the VTA and OpenVTC from the same release so their versions match. All three guides will be re-verified on the upcoming VTI-Fig release. See [Versions](../README.md#versions).

## Your path

Work through these in order. Each one verifies before you move on.

1. **[01 — Personal VTA](01-personal-vta.md)** — spin up a VTA on the [VTA Farm](https://vtafarm.firstperson.dev) (the streamlined default), or self-host one on a server you control if you want to run it the hard way. At the end you have a running VTA holding your master keys.
2. **[02 — OpenVTC TUI Setup](02-openvtc-tui.md)** — install the TUI and bind it to the Personal VTA from step 1. This is your everyday interface.
3. **[03 — Joining a Community](03-joining-a-community.md)** — your first community: submit a join request under your persona, and get approved by a community admin.

## Prerequisites you'll need before you start

Unless you use the [VTA Farm](https://vtafarm.firstperson.dev), you will need the following:

- A host for your Personal VTA. Cheapest realistic option is a small Ubuntu VPS — see [Explore 01 — Server Setup](../sysop/explore/01-server-setup.md) in sysop.
- HTTPS-capable static hosting somewhere (GitHub Pages, your own site, S3+CDN) for the `did.jsonl` file of your VTA DID. Covered in [01 — Personal VTA](01-personal-vta.md) Step 2.

## Windows (WSL)

PNM and OpenVTC run under WSL, with a few extra steps. This section has not yet been tested end to end by the maintainers; if something here doesn't match what you see, please open an issue.

**Building from source** (OpenVTC Option B, or PNM with `cargo install`) needs these packages first. The pre-built downloads don't:

```bash
sudo apt install -y build-essential pkg-config libssl-dev libpcsclite-dev pcscd libdbus-1-dev
```

**Use file storage instead of a keyring.** PNM and OpenVTC keep their secrets in the OS keyring by default, but WSL has no desktop login to start or unlock one, and both tools refuse to start without it rather than falling back. Choose file storage for each instead:

```bash
export VTI_SECURE_STORE=file        # PNM: plaintext file at mode 0600
export OPENVTC_SECURE_STORE=file    # OpenVTC: encrypted file; needs an unlock code or hardware token
```

Add both lines to `~/.bashrc` so every new terminal uses them.

**If you set up GNOME Keyring anyway** and an **Unlock Login Keyring** dialog appears, cancel it and retry in a new terminal. Its text about your login password doesn't apply on WSL, and typing the keyring password into it can leave the keyring re-encrypted with a different password, locking you out of everything stored in it.

The keyring password and the OpenVTC unlock code are separate secrets, even though the tools may ask for them one after the other.

## Where to go next

After joining a community you graduate to the **Member Developer** flow — minting role-scoped credentials, presenting them to verifiers, rotating your personas. _(Not yet written.)_
