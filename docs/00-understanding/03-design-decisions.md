# 03 — Design decisions

> **Goal of this document:** Explain every important technology choice, the alternatives that were considered and rejected, and the trade-offs — so you can later *defend* the architecture in an interview or on your portfolio.

---

## 0. The decision that drives everything: "don't touch the host OS"

| Decision | Choice | Reason |
|----------|--------|--------|
| How to add capabilities without system changes | **Run everything in containers/pods** | Containers isolate software from the host; only minimal host prerequisites (kernel features) are needed |
| How to be reachable from the internet | **Cloudflare Tunnel (outbound)** | Removes any need to open inbound ports, get a static public IP, edit the router, or modify `ufw`/`iptables` |
| Where requests converge | **Traefik ingress** | One entry point, host-based routing to many services, TLS handling, middleware — like an AWS ALB + API Gateway |

This single rule → cloudflare tunnel → trivially also enables a **zero-trust** posture (a later section).

---

## 1. Why Kubernetes (and specifically k3s)?

**Why Kubernetes at all?**

> You want to serve **many microservices** (API, auth, storage, etc.) with the same ergonomics AWS offers: declarative deployments, health checks, rolling restarts, service discovery, secret handling, scaling. Kubernetes is the industry-standard control plane that does exactly that — and it's the same technology AWS EKS runs.

**Alternatives considered:**

| Alternative | Verdict | Why rejected |
|-------------|---------|--------------|
| Plain Docker Compose | ✗ | Single node, no native ingress behavior, weaker control loop, harder to reproduce AWS-like patterns (Services, Ingress, RBAC, GitOps) |
| Nomad | △ | Good, but smaller ecosystem, k8s is the more valuable skill/portfolio asset |
| Podman Quadlets / systemd | ✗ | Systemd units = touching the OS (violates constraint); no orchestration |
| OpenShift / Rancher | ✗ | Heavy, overkill for one machine |
| **K3s** | ✅ | See below |

**Why k3s over "full" Kubernetes (kubeadm/k3s vs kind/k3d etc.):**

| Reason | Detail |
|--------|--------|
| Single-binary control plane | `k3s` bundles apiserver, scheduler, etcd/SQLite, controller-manager, containerd, CoreDNS, and Traefik into ~60MB |
| Low resource use | Designed for edge/Raspberry Pi; happily runs on a laptop while you keep working |
| Built-in extras | Ships Traefik (our ingress!) + local-path-provisioner (our storage!) out of the box |
| Single install command | One binary, one systemd service — minimal, well-documented host touch |
| CNCF-certified | Still standard Kubernetes: `kubectl`, Helm, CRDs, and GitOps all work as usual |

Alternatives rejected: **kind/k3d** (for CI, not persistent), **MicroK8s** (snap-based, heavier, couples to Ubuntu snap), **kubeadm** (too much manual assembly for the goal).

---

## 2. Why Cloudflare Tunnel for exposure?

The "expose to internet" decision space has basically four families:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Cloudflare Tunnel** | Zero inbound ports, free, hides home IP, DDoS/WAF/TLS included, no router change | You're in Cloudflare's ecosystem; free tier constraints | ✅ **Chosen** |
| VPS + WireGuard/frp | You control the edge; your own IP never appears; full TLS control | Costs ~$5/mo; you manage the VPS | △ Secondary (documented in roadmap/alternatives) |
| inlets / inlets-operator | Declarative (apply a Tunnel CRD), cloud provisioned automatically | Still needs a cloud account/secret; less common | △ Nice-to-have |
| Static IP + port-forward + DDNS | No third-party | Needs static IP or DDNS, opens inbound ports, exposes home IP, breaks under CGNAT, requires router+firewall changes | ✗ Rejected |

`cloudflared` runs as a **pod** → zero host installs. It also gives us **automatic DNS** (Cloudflare manages records for the tunnel hostnames) and **free origin TLS**.

> ⚠️ Modern note: Cloudflare may deprecate token-based tunnels in favor of the newer service-token flow. We document the current stable approach and note migration in the roadmap. (Keep this doc honest & future-proofed.)

---

## 3. Why Traefik as the ingress / edge router?

| Reason | Detail |
|--------|--------|
| Bundled with k3s | Zero extra install — it's already there |
| Native k8s integration | Watches Ingress + its own `IngressRoute` CRD |
| L7 routing by host/path | Exactly the "one IP, many services on subdomains" pattern |
| Middleware system | Rate limiting, security headers, forward-auth to Keycloak, retries — first-class API-gateway behaviors |
| Automatic TLS | Let's Encrypt ACME (HTTP-01/DNS-01) or passthrough to Cloudflare's edge certs |
| Active/active by default | Multiple replicas possible behind klipper-lb/loadbalancer |

**Alternatives considered:** NGINX Ingress (solid but more config drift, separate controller to install), Kong (heavier, overkill initially), HAProxy (excellent L4, weaker L7/k8s-native integration), Caddy (great TLS, but weaker as a full ingress controller). Traefik wins on *fit for k3s*.

---

## 4. Why these AWS-service replacements?

| AWS service | Replacement | Why this one |
|-------------|-------------|--------------|
| S3 | **MinIO** | 100% S3-API compatible; tiny footprint; runs as a single pod; can do erasure coding later across more disks/nodes |
| IAM / Cognito | **Keycloak** (or Authentik) | Full OIDC/SAML; SSO, MFA, social login; battle-tested; k8s operator exists. (Authentik is the more "modern UI" alternative.) |
| Secrets Manager / KMS | **Vault** | Dynamic secrets, encryption-as-a-service, lease lifecycle, k8s operator; industry standard |
| ECR | **Harbor** (or Gitea) | Vulnerability scanning, replication, role-based access; Gitea if you also want Git + registry in one |
| Lambda | **OpenFaaS** | FaaS on k8s, watchdog per function, works with any container |
| CloudWatch logs | **Loki + Grafana** | grep-like log querying at scale; pairs with Prometheus metrics in one dashboard |
| CloudWatch metrics | **Prometheus + Grafana + Alertmanager** | de-facto k8s monitoring stack |
| Route 53 (internal) | **CoreDNS** (in-cluster) + registrar DNS managed by Cloudflare | Internal discovery is CoreDNS; public DNS is Cloudflare-managed tunnel hostnames |
| ELB | **klipper-lb (built-in) + Traefik** | Built-in `servicelb` gives LoadBalancer-type a stable address; Traefik does L7 |

> Full row-by-row mapping table with rationale: [`docs/01-skills/02-aws-to-self-hosted-map.md`](../01-skills/02-aws-to-self-hosted-map.md)

---

## 5. Why IaC + GitOps (Terraform + ArgoCD)?

| Layer | Tool | Why |
|-------|------|-----|
| Provisioning | **Terraform** (or Ansible) | Declarative, reproducible bootstrap; your cluster is code |
| Cluster state | **ArgoCD** | GitOps: your desired cluster state lives in this repo; ArgoCD reconciles the cluster to match — the same pull-based model used by serious production teams |
| Secrets in git | **SOPS / Sealed Secrets** | Secrets stay encrypted at rest in git; only decrypted at the cluster |

This gives you the "portfolio-impressive" story: **infrastructure as a pull-request.**

---

## 6. Conscious trade-offs (be aware!)

| Trade-off | Where we land |
|-----------|---------------|
| Single node | Everything on one machine = easy + cheap, but no HA. Multi-node k3s is documented as a roadmap item. |
| Home internet reliability | Tunnel survives reboots; DNS is Cloudflare-managed. Power/UPS and ISP outages remain external. |
| Security posture | Publicly reachable = threat surface. We mitigate with tunnel (no open ports), edge WAF, auth layer (Keycloak/OIDC), rate limiting, and RBAC. |
| "Actually portable to real AWS" | Yes — the YAML, Helm charts, and GitOps flow work on EKS almost as-is. That's the point of the portfolio. |
| Free tier limits | Cloudflare free = fine for light personal/portfolio traffic. Heavy traffic → consider paid plan or VPS route. |

---

## 7. Summary decision table

| Question | Decision | One-liner rationale |
|----------|----------|---------------------|
| Runtime & orchestration | **k3s (Kubernetes)** | Lightweight standard K8s on a single box |
| Container runtime | **containerd** (bundled in k3s) | Zero extra install |
| Internet ingress | **Cloudflare Tunnel** | Zero inbound ports, free, hides IP |
| Edge router | **Traefik** | Bundled, L7, middleware-ready |
| Object storage | **MinIO** | S3-compatible, tiny |
| Identity | **Keycloak** | OIDC/SSO/MFA, industry standard |
| Secrets | **Vault** | Dynamic secrets, operator |
| Registry | **Harbor/Gitea** | Scanning + replication |
| Logs/Metrics | **Loki + Prometheus + Grafana** | The standard observability trio |
| Provisioning | **Terraform (+ Ansible)** | Reproducible via code |
| GitOps | **ArgoCD** | Cluster state from this repo |
| Secrets-in-git | **SOPS / Sealed Secrets** | Safe to commit encrypted |

---

## 🔗 Continue reading

► **[Next: 04 — Constraints](04-constraints.md)**

◄ **[Back to 00 Understanding index](README.md)** · [🏠 Repo home](../../README.md)