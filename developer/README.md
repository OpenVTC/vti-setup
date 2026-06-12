# Developer

You use OpenVTC to take part in one or more VTCs. You'll run a Personal VTA that holds your keys, drive it from the OpenVTC CLI/TUI, and present credentials when communities ask for them.

You do **not** run the community's infrastructure. That's the [sysop](../sysop/). You don't bootstrap or administer a community — that's a [community manager](../community-manager/).

## Your path

Work through these in order. Each one verifies before you move on.

1. **[01 — Personal VTA](01-personal-vta.md)** — spin up a VTA on the [VTA Farm](https://vtafarm.firstperson.dev) (the streamlined default), or self-host one on a server you control if you want to run it the hard way. At the end you have a running VTA holding your master keys.
2. **[02 — OpenVTC TUI Setup](02-openvtc-tui.md)** — install the TUI and bind it to the Personal VTA from step 1. This is your everyday interface.
3. **[03 — Joining a Community](03-joining-a-community.md)** — your first community: mint an M-DID, collect VRCs from two existing members, submit a join request, receive your VMC.

## Prerequisites you'll need before you start

Unless you use the [VTA Farm](https://vtafarm.firstperson.dev), you will need the following:

- A host for your Personal VTA. Cheapest realistic option is a small Ubuntu VPS — see [Ubuntu Server](../sysop/explore/01-server-setup.md) in sysop. `local-dev` is fine for trying things out but don't keep a real identity on it.
- HTTPS-capable static hosting somewhere (GitHub Pages, your own site, S3+CDN) for the `did.jsonl` file of your VTA DID. Covered in [01 — Personal VTA](01-personal-vta.md) Step 2.

## Where to go next

After joining a community you graduate to the **Member Developer** flow — minting role-scoped credentials, presenting them to verifiers, rotating M-DIDs. _(Not yet written.)_
