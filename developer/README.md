# Developer

You use OpenVTC to take part in one or more VTCs. You'll run a Personal VTA that holds your keys, drive it from the OpenVTC CLI/TUI, and present credentials when communities ask for them.

You do **not** run the community's infrastructure. That's the [sysop](../sysop/). You don't bootstrap or administer a community — that's a [community manager](../community-manager/).

## Your path

Work through these in order. Each one verifies before you move on.

1. **[Personal VTA](personal-vta.md)** — stand up your own VTA on a host you control. At the end you have a running VTA holding your master keys.
2. **[OpenVTC TUI Setup](openvtc-tui.md)** — install the TUI and bind it to the Personal VTA from step 1. This is your everyday interface.
3. **[Joining a Community](joining-a-community.md)** — your first community: mint an M-DID, collect VRCs from two existing members, submit a join request, receive your VMC.

## Prerequisites you'll need before you start

- A host for your Personal VTA. Cheapest realistic option is a small Ubuntu VPS — see [Ubuntu Server](../sysop/ubuntu-server.md) in sysop. `local-dev` is fine for trying things out but don't keep a real identity on it.
- HTTPS-capable static hosting somewhere (GitHub Pages, your own site, S3+CDN) for the `did.jsonl` file of your VTA DID. Covered in [Personal VTA](personal-vta.md) Step 2.

## Where to go next

After joining a community you graduate to the **Member Developer** flow — minting role-scoped credentials, presenting them to verifiers, rotating M-DIDs. _(Not yet written.)_
