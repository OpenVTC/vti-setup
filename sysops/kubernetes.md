# Deployment: Kubernetes

This guide covers deploying the VTI stack on Kubernetes. Our reference setup uses **Hetzner Cloud** with **RKE2** and **Rancher** for cluster management, and **Longhorn** for persistent volumes.

The steps below should work on any Kubernetes cluster as long as it has an Nginx ingress controller. The cluster must have **cert-manager** and a **ClusterIssuer** configured — Steps 1 and 2 cover that setup.

## Service Configuration

| Service | Default Port | DNS Record | WebVH Path |
| --- | --- | --- | --- |
| WebVH Service | 8534 | `webvh.yourdomain.com` | `https://webvh.yourdomain.com` |
| Community VTA | 8100 | `vta-c.yourdomain.com` | `https://webvh.yourdomain.com/vta-c` |
| Personal Community VTA | 8100 | `vta-p.yourdomain.com` | `https://webvh.yourdomain.com/vta-p` |
| Mediator | 7037 | `mediator.yourdomain.com` | — |

## Prerequisites

| Requirement | Details |
| --- | --- |
| `kubectl` | The Kubernetes CLI for controlling your cluster. Must be configured to point to your cluster (`kubectl get nodes` should work). |
| `helm` | Required for cert-manager and VTA/Mediator chart installations. |
| A running Kubernetes cluster | Any provider (Hetzner, AWS, GKE, etc.) with an Nginx ingress controller. |
| Registered domain + DNS access | We recommend [Cloudflare](https://www.cloudflare.com) for DNS management. |

## Step 1: Install cert-manager

cert-manager handles automatic TLS certificate provisioning via Let's Encrypt.

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Verify all pods are running before continuing:

```bash
kubectl get pods -n cert-manager
```

## Step 2: Create ClusterIssuer

Create a `ClusterIssuer` named `letsencrypt-prod`. This name is referenced by the Mediator and VTA Helm charts — only change it if a ClusterIssuer with this name already exists in your cluster.

Replace `your@email.com` with your email (used for Let's Encrypt expiry notifications), or remove the `email` line to register without one.

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

Verify the issuer is ready:

```bash
kubectl get clusterissuer letsencrypt-prod
```

The `READY` column should show `True`.

## Step 3: Configure DNS Records

Save these URLs somewhere (Notion, plain text file) as you will reuse them throughout the setup. Replace `yourdomain.com` with your actual domain:

```text
https://vta-c.yourdomain.com
https://vta-p.yourdomain.com
https://webvh.yourdomain.com
https://mediator.yourdomain.com
```

Get your cluster's ingress IP, then create the following DNS **A records**:

| Type | Name | Content (IPv4) | Notes |
| --- | --- | --- | --- |
| A | `vta-c` | `<INGRESS_IP>` | DNS only |
| A | `vta-p` | `<INGRESS_IP>` | DNS only |
| A | `webvh` | `<INGRESS_IP>` | DNS only |
| A | `mediator` | `<INGRESS_IP>` | DNS only |

> **Cloudflare users:** You can use a single wildcard **`*`** A record pointing to `<INGRESS_IP>` instead of four separate records. Either way, set records to **DNS only** (grey cloud, proxy disabled) — cert-manager's HTTP-01 challenge requires direct access to port 80.

Wait for DNS propagation before proceeding:

```bash
dig +short vta-c.yourdomain.com
```

## Next: set up VTI

With the cluster provisioned and DNS propagated, pick how you want to drive the VTI setup:

| How you want to drive it | Guide |
| --- | --- |
| Step through the wizards interactively | [Interactive setup](interactive-setup.md) |
| Drive from TOML recipes / CLI flags | [Automated setup](automated-setup.md) |

> Note: the setup guides were verified on [Ubuntu Server](ubuntu-server.md). Adapting them to Kubernetes is straightforward — `vta`, `mediator`, and `did-hosting-daemon` all run as standard containers — but the exact manifests are not yet documented here.
