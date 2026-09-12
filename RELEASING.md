# Releasing

`scripts/setup-explore.sh` runs as root, so the explore guide only has operators run a copy from a tagged GitHub Release, checked against a SHA-256 pinned in [`sysop/explore/01-server-setup.md`](sysop/explore/01-server-setup.md). Pushing a `v*` tag runs [`.github/workflows/release.yml`](.github/workflows/release.yml), which attaches `setup-explore.sh` and `SHA256SUMS` to the release and records a build provenance attestation for both.

## One-time repository setup

- Create the `release` environment (Settings → Environments) with required reviewers from the maintainers team. The publish job waits for that approval. Without it, GitHub creates the environment unprotected on the first run.
- Add a tag ruleset that restricts creating, updating and deleting `v*` tags to maintainers.

## Cutting a release

The pinned hash covers only the script, not the guide, so the guide can be updated before the tag exists.

1. Pick the next version, for example `v1.1.0`, and hash the script on `main`:

   ```bash
   git switch main && git pull --ff-only
   sha256sum scripts/setup-explore.sh
   ```

2. Open a PR that sets `VER` and `SHA256` in Step 3 of `sysop/explore/01-server-setup.md` to that version and hash. The PR must not change `scripts/setup-explore.sh`. Merge it.
3. Tag the merge commit and push the tag straight away, because the guide now points at it:

   ```bash
   git pull --ff-only
   sha256sum scripts/setup-explore.sh   # must still equal the pinned hash
   git tag -a v1.1.0 -m "v1.1.0"        # or -s if you sign tags
   git push origin v1.1.0
   ```

4. Approve the `release` environment deployment when the workflow asks for it.
5. Verify the published assets the way an operator will:

   ```bash
   VER=v1.1.0
   SHA256=<hash pinned in the guide>
   curl -fsSLO "https://github.com/OpenVTC/vti-setup/releases/download/${VER}/setup-explore.sh"
   curl -fsSLO "https://github.com/OpenVTC/vti-setup/releases/download/${VER}/SHA256SUMS"
   echo "${SHA256}  setup-explore.sh" | sha256sum -c -
   sha256sum -c SHA256SUMS
   gh attestation verify setup-explore.sh \
     --repo OpenVTC/vti-setup \
     --signer-workflow OpenVTC/vti-setup/.github/workflows/release.yml
   ```

If any check fails, delete the release and the tag, fix the pin or the script, and release again under a new version. Never move a published tag.
