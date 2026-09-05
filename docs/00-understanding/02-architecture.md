# 02 — Architecture

> **Goal of this document:** The complete end-to-end architecture, layer by layer. After reading this you should be able to draw the system on a whiteboard and explain every hop a request takes.

---

## 1. The full stack, at a glance

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                THE INTERNET                                 │
│                           api.mycloud.com ← requires a domain               │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      LAYER 1 — Cloudflare (managed)                         │
│                                                                             │
│   • DNS for your domain (A/CNAME records)                                   │
│   • TLS termination (automatic HTTPS)                                       │
│   • DDoS protection & Web Application Firewall (WAF)                        │
│   • Zero Trust Access (optional, adds login in front of every service)      │
│   • Tunnel controller: receives requests, forwards down the tunnel          │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │  (outbound-only TLS connection, port 7844)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              YOUR UBUNTU MACHINE — LAYERS 2–6 (all in user space)           │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │  LAYER 2 — Cloudflare Tunnel (cloudflared pod in k3s)                   │ │
│ │   • Connects OUT to Cloudflare, needs zero inbound ports                │ │
│ │   • Terminates the tunnel, forwards to Traefik on localhost:443         │ │
│ └──────────────────────────────────┬──────────────────────────────────────┘ │
│                                    │                                        │
│ ┌──────────────────────────────────▼──────────────────────────────────────┐ │
│ │  LAYER 3 — Traefik Ingress Controller (L7 reverse proxy)                │ │
│ │   • Host-based routing: secret routes each subdomain to the right svc   │ │
│ │   • (Optional) TLS re-encryption / cert generation with Let's Encrypt   │ │
│ │   • Middleware: rate limiting, headers, auth forwarding, WAF rules      │ │
│ └──────────────────────────────────┬──────────────────────────────────────┘ │
│                                    │                                        │
│ ┌──────────────────────────────────▼──────────────────────────────────────┐ │
│ │  LAYER 4 — k3s Networking          │                                     │ │
│ │   • Services (ClusterIP)          │ Pod-to-pod via overlay (vxlan/flannel)│ │
│ │   • CoreDNS: internal DNS          │                                     │ │
│ │   • Network Policies: restrictions│                                     │ │
│ └──────────────────────────────────┬──────────────────────────────────────┘ │
│                                    │                                        │
│ ┌──────────────────────────────────▼──────────────────────────────────────┐ │
│ │  LAYER 5 — k3s Core (Kubernetes control plane)                           │ │
│ │   • kube-apiserver, scheduler, controller-manager, etcd (single node)    │ │
│ │   • controller-runtime for ingress (Traefik provider)                    │ │
│ │   • CSI/CNI: local-storage, flannel                                    │ │
│ └──────────────────────────────────┬──────────────────────────────────────┘ │
│                                    │                                        │
│ ┌──────────────────────────────────▼──────────────────────────────────────┐ │
│ │  LAYER 6 — Workloads (the "AWS services" as pods)                        │ │
│ │   MinIO · Keycloak · Vault · Harbor · OpenFaaS · your apps · backups     │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Layer-by-layer breakdown

### Layer 1 — Cloudflare (managed edge, $0 on free tier)

Cloudflare is the *public half* of your cloud. It performs:

| Function | Why it matters |
|----------|----------------|
| **DNS** | Your domain's records point to Cloudflare (proxied mode `☁️ orange`). Hostnames resolve to Cloudflare IPs, not your machine. |
| **TLS termination** | Cloudflare issues/terminates HTTPS on your behalf — automatic SSL, wildcard support. Your origin *could* use Cloudflare-origin certs or full-strict mode. |
| **DDoS / WAF** | Free DDoS mitigation and optional WAF rules in front of everything. |
| **Tunnel controller** | Matches incoming requests to the correct `cloudflared` endpoint via the tunnel connection ID. |

> 🔁 The tunnel direction is **outbound** from your machine. This is the single most important architectural decision — see [`03-design-decisions.md`](03-design-decisions.md).

---

### Layer 2 — Cloudflare Tunnel (`cloudflared` pod)

Runs as a **pod inside k3s**. On startup it:

1. Authenticates to Cloudflare with a **token** (created via `cloudflared tunnel` or the CF Zero Trust dashboard).
2. Opens a persistent outbound connection to Cloudflare edge (port 7844, HTTPS/QUIC).
3. Waits for Cloudflare to push requests down the tunnel.
4. Forwards them to `https://traefik.kube-system.svc.cluster.local` (or `:443` on kube-system namespace service) — i.e., to Traefik.

**Network effect:** `sudo ufw` stays untouched, the router needs no port-forward, and your home IP is never exposed in DNS.

---

### Layer 3 — Traefik (ingress controller)

Traefik ships with k3s by default. It acts as the **L7 reverse proxy and API gateway**:

- Watches Kubernetes **Ingress** resources (and its own richer **IngressRoute** CRDs) to learn routing rules.
- Routes by **Host header** + path. E.g.:
  - `auth.mycloud.com/*` → Keycloak service
  - `storage.mycloud.com/*` → MinIO service
  - `api.mycloud.com/*` → your API service
- Applies **middlewares**: rate-limiting, security headers, auth (forwardAuth to Keycloak), compression, gzip.
- Handles **TLS**: if not using Cloudflare TLS, Traefik can use Let's Encrypt (HTTP-01 or DNS-01).

> There is **one** public endpoint (`:443` reached via the tunnel) and **many** virtual hosts behind it. This is exactly how a cloud `LoadBalancer + API Gateway` behaves.

---

### Layer 4 — Kubernetes networking inside k3s

| Component | Role in our stack |
|-----------|-------------------|
| **Service (ClusterIP)** | Stable virtual IP + DNS name per app (`myapi.default.svc.cluster.local`). Load-balanced across replicas. |
| **CoreDNS** | Resolves `svc.cluster.local` names → ClusterIPs. Internal DNS, the analog of internal Route 53. |
| **Ingress** | Host rules → Traefik routes to Services. |
| **NetworkPolicies** | (Optional, recommended) Egress/ingress restrictions between namespaces. |
| **overlay network (flannel/vxlan)** | Gives pods their own IPs across the single node; traffic encapsulated in user space. |
| **Local Path Provisioner** | Persistent volumes mapped to a host directory (e.g. `/home/$USER/k3s-data`) — no OS partition change needed. |

---

### Layer 5 — k3s control plane

K3s packages the entire control plane **into one small binary + a single process**:

- `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`
- an embedded `etcd` (or SQLite, default) for state
- `containerd` as the CRI (container runtime)
- bundled `traefik`, `local-path-provisioner`, `servicelb` (klipper-lb), `metrics-server`

> Because it installs to `/var/lib/rancher/k3s` with a systemd unit, we classify it as the **one minimal, documented OS-touch** in this project. It stays *fully containerized* in terms of workloads — everything you deploy is a container/pod.

---

### Layer 6 — Workloads (your "AWS services")

The cloud services we deploy as pods. Full details + deployment files are in [`docs/03-services`](../03-services/README.md).

| Service (pod) | Purpose | "AWS equivalent" |
|---------------|---------|------------------|
| MinIO | S3-compatible object storage | S3 |
| Keycloak / Authentik | OIDC/OAuth2 identity, SSO, MFA | IAM / Cognito |
| HashiCorp Vault | Secrets (dynamic DB creds, encryption keys) | Secrets Manager / KMS |
| Harbor / Gitea | Container image registry + optionally git | ECR + CodeCommit |
| OpenFaaS / Knative | Serverless functions on k8s | Lambda |
| Loki + Prometheus + Grafana | Logs + metrics + dashboards | CloudWatch / X-Ray |
| ArgoCD (optional) | GitOps: cluster state from a git repo | CodeDeploy / CodePipeline |
| Backups (restic/velero) | Cluster + data backups | AWS Backup / EBS snapshots |

---

## 3. How a single request travels (walkthrough)

Say a user visits **`https://storage.mycloud.com/api/v1/buckets/my-bucket`**:

```
1. Browser resolves storage.mycloud.com → Cloudflare edge IP (TLS cert valid)
2. Request arrives at Cloudflare. WAF inspects it. Logged.
3. Cloudflare looks up the tunnel for this hostname.
   → picks your machine's cloudflared connection (already open, outbound)
4. cloudflared receives the request → forwards to https://traefik:443 (in-cluster)
5. Traefik reads Host: storage.mycloud.com
   → matches IngressRule → forwards to service "minio" in "storage" namespace → Pod
6. MinIO handles the API request, writes to a PersistentVolume (host directory)
7. Response travels back the same path (reverse), all TLS-protected
```

Every layer did **only its own job**, and nLD of it required an inbound open port.

---

## 4. Architecture variants (for later)

| Variant | When to use |
|---------|-------------|
| **Cloudflare Tunnel** (this doc) | Default. Zero inbound ports, free, hides home IP. |
| **VPS + WireGuard/frp** | You want to fully own the edge, avoid Cloudflare, or hide even the tunnel exit. Costs ~$5/mo. |
| **inlets/inlets-operator** | A k8s-native operator that provisions a cloud "exit node" and manages tunnels as CRDs. |
| **Static public IP + port-forward** | Only if you have a static IP — *not recommended*, exposes your IP and requires router/firewall changes. |

---

## 5. Failure modes & design responses

| Risk | Response |
|------|----------|
| Home machine reboots | Tunnels/ingress/services auto-restart via k3s systemd + pod `restartPolicy: Always` |
| Power outage | Uninterruptible Power Supply (UPS) recommended |
| Home ISP changes IP | No impact — tunnel is outbound, no inbound records to update |
| Tunnel outage (Cloudflare) | Optional fallback VPS route; monitor with UptimeRobot/Cloudflare health checks |
| Disk fills up | Set per-volume quotas, monitor with Grafana, alert via Alertmanager |
| Single-node = single point of failure | Accept for portfolio; document in `08-roadmap` (multi-node HA is a future path) |

---

## 🔗 Continue reading

► **[Next: 03 — Design decisions](03-design-decisions.md)**

◄ **[Back to 00 Understanding index](README.md)** · [🏠 Repo home](../../README.md)