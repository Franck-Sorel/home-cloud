# 04 — Learning path

> **Goal of this document:** A concrete, mostly-free, ordered learning roadmap that parallels the project — so you level up *as you build*, not before it.

> **Core principle:** Don't binge courses for months before starting. Learn the 20% that unblocks you, build, then deepen the areas that actually hurt.

---

## Phase 0 — (1 weekend) The minimum to start

| What | Resource |
|------|----------|
| Bash basics | *Learn the command line* (freeBSD handbook chapter) — ~3h |
| What is a container | Docker's official "Get started" orientation — ~1h |
| What is Kubernetes | K8s docs concept pages / **KillerCoda** interactive: *Kubernetes playground* — ~3h |

**Exit criteria:** you can `kubectl get pods` in a playground and vaguely know what a `Deployment` and `Service` are.

## Phase 1 — (2–3 weekends) The build

| What | Resource |
|------|----------|
| k3s install | This repo: [`02-setup/01-install-k3s.md`](../02-setup/01-install-k3s.md) |
| Domain + Cloudflare | Cloudflare docs: "Create a tunnel" quickstart (this repo: [`02-setup/02-cloudflare-tunnel.md`](../02-setup/02-cloudflare-tunnel.md)) |
| Ingress | Traefik docs: "Kubernetes Ingress" + "IngressRoute" (this repo: [`02-setup/03-traefik-ingress.md`](../02-setup/03-traefik-ingress.md)) |
| Helm | `helm.sh/learn`, then `helm install` a chart from this repo's `deploy/` |

## Phase 2 — (ongoing) Level-up domains

| Domain | Best free-track |
|--------|-----------------|
| Networking (the big one) | **TryHackMe** "Network+ Prep" rooms → **Cisco Networking Academy** free courses. Then revisit [`01-knowledge-map.md`](01-knowledge-map.md#2-networking-and-dns) |
| Linux / ops | **OverTheWire: Bandit** (game) → read `man` pages when you hit them |
| Kubernetes depth | **KodeKloud** "Kubernetes Basics" (cheap $) or **KillerCoda** free scenarios → official CKA curriculum if you want the cert later |
| Security | **OWASP Top 10** free; **TryHackMe** "OWASP top 10" room; then this repo's [`04-security`](../04-security/README.md) |
| GitOps | **ArgoCD** official tutorials (free) → implement [`07-iac-gitops`](../07-iac-gitops/README.md) |
| Dockerfile craft | Hadolint rules + Docker docs "best practices" |

## Phase 3 — (optional) Certification game

If you want credentials that echo this project:

| Cert | Value vs this project |
|------|------------------------|
| **CKA** (Kubernetes Admin) | Directly validates everything you did |
| **CKAD** (Developer) | Nice-to-have app-focused |
| **LFCS** (Linux) | Validates the host fundamentals |
| **CKS** (Security) | After you're comfortable: matches our security section |

> All four are real and funded-by-Linux-Foundation. CKA is the one most worth it for cloud-platform roles.

---

## The "learn while building" cheat-sheet

| When I'm doing this… | …I should be learning that |
|----------------------|----------------------------|
| Creating a subdomain | DNS, TTL, CNAME |
| Setting up HTTPS | TLS handshake, cert chains, Let's Encrypt |
| First `Deployment` | Pod lifecycle, probes |
| First `Service` | ClusterIP vs NodePort, labels/selectors |
| First `Ingress` | L7 routing, host rules, virtual hosts |
| Helm install | Charts, values, templating |
| Keycloak SSO | OIDC flows, JWT, claims, scopes |
| Vault dynamic secrets | Least privilege, lease lifecycle |
| Prometheus alert | Alerting, SLO thinking |
| Velero restore | RTO/RPO concepts, DR testing |
| ArgoCD sync | GitOps reconciliation, drift |

---

## 🔗 Continue reading

► **[Next section: 02 — Setup](../02-setup/README.md)**

◄ **[Back to 01 Skills index](README.md)** · [🏠 Repo home](../../README.md)