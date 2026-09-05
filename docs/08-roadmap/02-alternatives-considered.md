# 02 — Alternatives considered

> **Goal:** An honest record of the roads we almost took — and when each is actually the right choice. (Interviewers *love* when you can say why you didn't do X.)

---

## 1. Exposure paths

| Option | Verdict | When to revisit |
|--------|---------|-----------------|
| **Cloudflare Tunnel** (chosen) | ✅ no ports, free, hides IP | — |
| VPS + WireGuard/frp | △ | If you need *full* control of the edge, or don't want Cloudflare dependency; ~$5/mo |
| inlets / inlets-operator | △ | If you want a fully declarative tunnel operator (k8s-native CRD) on top of any cloud |
| Static IP + port-forward + DDNS | ✗ | Only if you have a static IP *and* accept exposing + managing the router/firewall; breaks under CGNAT |

## 2. Orchestration

| Option | Verdict | Why |
|--------|---------|-----|
| **k3s** (chosen) | ✅ | Lightweight K8s, bundled Traefik + storage, one-binary |
| Kind / k3d | ✗ | CI-oriented, not for a persistent home cluster |
| MicroK8s | ✗ | Snap-based, more OS coupling on Ubuntu |
| kubeadm full K8s | △ | If you want the hardest possible “real cluster” experience; heavy for one node |
| Docker Compose | ✗ | No ingress/self-heal/orchestration semantics to brag about |

## 3. Ingress

| Option | Verdict | Why |
|--------|---------|-----|
| **Traefik** (bundled) | ✅ | Fits k3s, middlewares, CRDs |
| NGINX Ingress | △ | Battle-tested, but separate install + more config drift |
| Kong | △ | Heavier; good if you want API-management-plane features later |
| Caddy | △ | Wonderful TLS, weaker as a full ingress controller |
| Istio/Linkerd | ✗ | Service-mesh overkill for one node (roadmap D-item if you grow) |

## 4. Object storage

| Option | Verdict | Why |
|--------|---------|-----|
| **MinIO** | ✅ | S3-API compatible, single-pod, erasure-coding later |
| Ceph/Rook | △ | True distributed S3+NFS; heavy — overkill until multi-node (B4) |
| SeaweedFS / Garage | △ | Cheaper alternatives, less ecosystem recognition |

## 5. Identity

| Option | Verdict | Why |
|--------|---------|-----|
| **Keycloak** | ✅ | OIDC/SAML, MFA, best-known self-hosted IAM |
| Authentik | △ | More modern UI + built-in flows; fine swap |
| Authelia / dex | △ | Lighter, but fewer federation features |

## 6. Secrets

| Option | Verdict | Why |
|--------|---------|-----|
| **Vault** | ✅ | dynamic secrets, leases, operator, industry standard |
| just k8s Secrets | 🟡 | fine until volume grows; doesn't rotate |
| Sealed Secrets only | △ | good for git, no runtime rotation |

## 7. Observability

| Option | Verdict | Why |
|--------|---------|-----|
| **Loki + Prometheus + Grafana** | ✅ | the de-facto stack |
| ELK | ✗ | heavier, more ops for the same home job |
| VictoriaMetrics / Mimir | △ | if Prometheus scales past one node, swap later |

---

## When swappin' is actually right (decision table)

| Your future situation | Switch to |
|----------------------|-----------|
| You get a cloud budget ($5/mo) and want no-Cloudflare | **VPS + WireGuard + self-managed certs** |
| You want a "really a cluster" story | **kubeadm 3-node** (+ Calico) |
| You need S3 across many disks/nodes today | **Rook-Ceph** (after B4) |
| You hate Java ops and want battery-included identity | **Authentik** |
| Your APIs get traffic + you want per-consumer plans | **Kong** as a second gateway tier in front of Traefik |

> The point isn't that these are "wrong" — they're *right for other constraints*. Documenting *when* is what makes this note valuable.

---

## 🔗 Continue reading

► **[Next: 03 — Known limits](03-known-limits.md)**

◄ **[Back to 08 Roadmap index](README.md)** · [🏠 Repo home](../../README.md)