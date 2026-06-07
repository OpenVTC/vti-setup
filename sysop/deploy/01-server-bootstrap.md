# Deploy 01: Server Bootstrap

Create the non-root `vti` operator user and lock down sshd. Run this once, as root, on a fresh Ubuntu 26.04 host. After it completes, you reconnect as `vti` and never use the root account again.

## Prerequisites

| Requirement | Details |
| --- | --- |
| Registered domain + DNS access | We use [Cloudflare](https://www.cloudflare.com) for DNS management. |
| VPS or cloud account | We use [Hetzner](https://www.hetzner.com). Create an Ubuntu 26.04 instance. |
| SSH key pair | Your public key must already be in `/root/.ssh/authorized_keys`. The bootstrap script copies it to vti. |
| `curl` on the server | Hetzner Ubuntu image already includes it. |

## Step 1: Create Ubuntu 26.04 server

Create a new Ubuntu 26.04 server and ensure you select at least one SSH key to include in `/root/.ssh/authorized_keys`. Note its **public IP address** — you will need it for DNS configuration in [02 — Server setup](02-server-setup.md).

## Step 2: Run the bootstrap script

SSH into your server as **root** and run:

```bash
curl -sSL https://raw.githubusercontent.com/OpenVTC/vti-setup/main/scripts/bootstrap-user.sh | bash
```

The script will:

1. Create the `vti` user and add it to the `sudo` group.
2. Drop `/etc/sudoers.d/90-vti-nopasswd` so vti can sudo without a password (vti has no password set, and SSH password auth is disabled — this is the standard cloud-VM admin pattern, not a downgrade).
3. Copy `/root/.ssh/authorized_keys` → `/home/vti/.ssh/authorized_keys`.
4. Drop `/etc/ssh/sshd_config.d/01-vti-hardening.conf` with `PermitRootLogin no` and `PasswordAuthentication no`.
5. Validate the sshd config with `sshd -t` and reload sshd.

The script is idempotent — re-running it is safe.

## Step 3: Reconnect as vti

Disconnect from the root session and reconnect as `vti`:

```bash
ssh vti@<server>
```

Your existing SSH key works because the bootstrap script copied it to `/home/vti/.ssh/authorized_keys`.

## Verification

```bash
id vti                                                           # vti is in the 'sudo' group
sudo -n true                                                     # passwordless sudo works
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication'  # both no
```

From your local machine, confirm root SSH is refused:

```bash
ssh root@<server>   # Permission denied
```

## Next

Run the deploy setup: [02 — Server setup](02-server-setup.md).
