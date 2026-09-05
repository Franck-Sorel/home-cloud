# 01 — Knowledge map

> **Goal of this document:** A complete map of the knowledge domains required to build — and *own* — this private cloud. Each domain explains *why* you need it and *where* it shows up in the project.

---

## The 8 domains of knowledge

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      THE 8 KNOWLEDGE DOMAINS                                │
│                                                                             │
│  1. System & Linux       2. Networking & DNS       3. TLS & Certificates    │
│  4. Kubernetes           5. Containers/Docker      6. Security              │
│  7. Infrastructure-as-Code + GitOps                8. Release & Operations  │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. System & Linux

**Why you need it:** Everything is `bash`, processes, permissions, and paths. You'll run the k3s install, check logs, manage home-directory storage, and debug pods from a terminal.

| Topic | Where it shows up |
|-------|-------------------|
| Bash basics (cd, ls, pipes, redirects, env vars) | every setup command |
| Process management (`systemctl status`, `ps`, `top`) | checking k3s / pods |
| Users, groups, permissions (`chown`, `umask`) | PVCs in `$HOME/k3s-data` |
| Filesystem layout & mount points (`df`, `du`, `lsblk`) | planning storage |
| Logs (`journalctl`, `kubectl logs`) | debugging |
| Editing configs (`vim`/`nano`) | manifest tweaks |

**Level:** Working proficiency is enough — you already have it with Ubuntu.

---

## 2. Networking & DNS

**Why you need it:** This is the *biggest* prerequisite. The whole "expose without open ports" architecture depends on understanding where each piece operates.

| Topic | Why it matters here |
|-------|---------------------|
| **OSI model (L3–L7)** | Knowing the layers tells you what Traefik (L7), the tunnel (L4+), and pods (L3) each do |
| **TCP/UDP basics, ports** | Understanding why "port 443" isn't a magic thing, and that the tunnel uses outbound 7844 |
| **DNS records (A, CNAME, TXT)** | Your URL must resolve somewhere; Cloudflare-managed hostnames; TXT used for ACME DNS-01 |
| **TTL & propagation** | DNS changes aren't instant |
| **NAT / CGNAT** | Why your home IP may be *unreachable inbound* — the whole reason for tunnels |
| **Reverse proxy concepts (L4 vs L7)** | Traefik routes on hostname/path (L7), not just IP/port (L4) |
| **Virtual networking** | veth pairs, bridge, overlay (flannel vxlan) — how pod IPs work |
| **Service discovery / internal DNS** | CoreDNS resolving `myapi.default.svc.cluster.local` |

> 💡 **Portfolio talk:** Being the person who can explain "why not just expose port 443?" *and* answer with "CGNAT, IP exposure, and OS constraints → so we tunnel outbound" is exactly the kind of depth that shows senior-level networking.

---

## 3. TLS & Certificates

**Why you need it:** HTTPS is non-negotiable for a public URL, and self-hosting means you need to actually understand where encryption starts and ends.

| Topic | Why it matters |
|-------|----------------|
| TLS handshake & trust chain | understanding `https://` in front of your services |
| SNI (Server Name Indication) | how Traefik picks the right cert for `storage.mycloud.com` vs `api.mycloud.com` on one endpoint |
| Let's Encrypt / ACME | automated cert issuance at the edge or at Traefik |
| HTTP-01 vs DNS-01 challenges | why DNS-01 works even behind a tunnel (no inbound needed) |
| Certificate rotation/renewal | Traefik/Cloudflare both renew automatically — you need to verify it |
| TLS termination points | Cloudflare edge terminates outer TLS; optional re-encryption to origin |
| mTLS (bonus) | advanced service-to-service auth |

> **Default in this project:** **Cloudflare terminates TLS for you** at the edge (free, automatic). Traefik is then reached over the tunnel. If you prefer full end-to-end encryption, configure Traefik with origin certs. See [`02-setup/03-traefik-ingress.md`](../02-setup/03-traefik-ingress.md).

---

## 4. Kubernetes (k3s)

**Why you need it:** The cluster is the heart of the whole thing. You don't need to be a CNCF exam-taker to build this, but you need the core object model.

| Concept | Role in the project |
|---------|---------------------|
| **Pods** | the unit of our services (MinIO, Keycloak, your APIs) |
| **Deployments** | keep N replicas healthy; rolling updates |
| **Services** | stable DNS + load-balanced access to pods |
| **Ingress** | host rules → Traefik → services |
| **ConfigMaps / Secrets** | non-secret & secret config |
| **PersistentVolumes / Claims** | surviving data (MinIO buckets, Vault, DBs) |
| **Namespaces** | organizing: `auth`, `storage`, `monitoring`, `apps` |
| **RBAC** | who can do what with the cluster |
| **NetworkPolicies** | restrict pod-to-pod traffic (defense in depth) |
| **Helm** | package/deploy mature charts |
| **CRDs** (Traefik `IngressRoute`, etc.) | richer routing/security features |
| **kubectl** | your cockpit |

> Kil-specific: k3s bundles CoreDNS, Traefik, local-path-provisioner, metrics-server, servicelb. That's ~half your infra already installed.

---

## 5. Containers & Docker

**Why you need it:** Kubernetes runs containers. You need to think in images, layers, entrypoints, and health checks.

| Topic | Where it shows up |
|-------|-------------------|
| Image vs container vs registry | pulling public images; later pushing to your own Harbor/Gitea |
| Dockerfile basics | building your own API app images |
| Entrypoint, ports, env | how pods declare what they run |
| Layers & caching | efficient builds |
| Resource limits (cpu/mem) | sensible pod specs on a single box |
| containerd vs docker | k3s uses containerd; `ctr`/`nerdctl` if you need a CLI |
| Health/readiness probes | liveness/readiness for self-healing |

---

## 6. Security

**Why you need it:** You're putting services on the public internet. Discipline here is non-negotiable.

| Topic | Where it shows up |
|-------|-------------------|
| **Zero-trust tunneling** | why Cloudflare Tunnel beats open ports |
| Authentication (OAuth2/OIDC) | Keycloak-based SSO protecting apps |
| Authorization / RBAC | k8s RBAC + app-level roles |
| Secrets management | Vault (dynamic secrets) vs k8s Secrets |
| WAF & rate limiting | Cloudflare managed rules + Traefik middleware |
| Least-privilege / hardening | non-root containers, read-only fs, seccomp |
| Network policies | internal segmentation |
| Auditing | kube-apiserver audit log → Loki |

> See [`04-security`](../04-security/README.md) for the complete hardening guide.

---

## 7. Infrastructure-as-Code & GitOps

**Why you need it:** It takes this from "a machine I set up once" to "a platform I reproduce anywhere" — and it's what separates a hobby from a portfolio project.

| Domain | Tool | Why |
|--------|------|-----|
| Provisioning | **Terraform** | reproduce the machine/cloud state declaratively |
| Cluster manifests | **Kubernetes YAML + Helm** | the source of truth lives in this repo |
| GitOps delivery | **ArgoCD** | cluster pulls desired state from git; PR = deploy |
| Secrets in git | **SOPS / Sealed Secrets** | safe to commit encrypted secrets |

---

## 8. Release & Operations (SRE-lite)

**Why you need it:** "AWS-grade" is not about scale, it's about *ops discipline*.

| Topic | Where it shows up |
|-------|-------------------|
| Observability (logs, metrics, traces) | Loki + Prometheus + Grafana |
| Monitoring & alerting | Alertmanager rules ("pod down") |
| Backups & restore | Velero + restic; *tested* restore |
| CI/CD | GitHub Actions builds images; ArgoCD deploys |
| Incident response basics | "what to do when the site is down" runbook (in `06-testing`) |
| Capacity planning | single-box resource budgeting (maps to node-limits) |

---

## What you *don't* need (yet)

- ❌ Full CKA certification to start — build first, certify later if you like
- ❌ Cloud-provider-specific tooling (we're provider-agnostic by design)
- ❌ Deep OS kernel work (the whole point is we don't touch it)
- ❌ Enterprise service-mesh (Istio/Linkerd) — overkill for one node

---

## 🔗 Continue reading

► **[Next: 02 — AWS ↔ self-hosted map](02-aws-to-self-hosted-map.md)**

◄ **[Back to 01 Skills index](README.md)** · [🏠 Repo home](../../README.md)