# 03 — Skills checklist

> **Goal of this document:** An honest self-assessment tool. For each skill: what level you need, what "good" looks like, and how to practice it *inside this project*.

---

## How to use this checklist

- Mark your current level per skill.
- If you're **Not ready** for a prerequisite, do the linked practice **while building** — don't stop the whole project.
- Re-visit this page after each milestone in [`06-testing`](../06-testing/README.md) and re-grade yourself. That's your portfolio evidence of growth.

---

## Legend

- 🔴 **Not ready** — I can't use this day-to-day yet
- 🟡 **Working** — I can do the common cases
- 🟢 **Proficient** — I can do it without looking things up, and can teach it
- ⚡ **Expert** — I've met real-world edge cases and could workshop it (for interview purposes, 🟢 on most is already strong)

---

## 1. System & Linux

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| Bash CLI | 🟡 Working | Navigate, pipe, set env, background processes | every `[setup]` command |
| Process supervision | 🟡 Working | `systemctl status k3s`, read `journalctl` | [`02-setup/01-install-k3s.md`](../02-setup/01-install-k3s.md) |
| Logs & debugging | 🟡 Working | `kubectl logs -f`, `journalctl -u k3s` | [`06-testing/00-verify-cluster.md`](../06-testing/00-verify-cluster.md) |
| Storage/paths | 🟡 Working | `df -h`, `du -sh`, understand `$HOME/k3s-data` | [`02-setup/01-install-k3s.md`](../02-setup/01-install-k3s.md) |

## 2. Networking & DNS

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| OSI model L3–L7 | 🟢 Proficient | Explain what layer a reverse proxy (L7), a tunnel (L4+), and pod networking (L3) each work at | [`00-understanding/02-architecture.md`](../00-understanding/02-architecture.md) |
| DNS records (A/CNAME/TXT) | 🟡 Working | Create a tunnel hostname; explain TTL | [`02-setup/02-cloudflare-tunnel.md`](../02-setup/02-cloudflare-tunnel.md) |
| NAT / CGNAT | 🟢 Proficient | Explain why inbound is blocked and why tunnel solves it | [`00-understanding/03-design-decisions.md`](../00-understanding/03-design-decisions.md) |
| Reverse proxy L4 vs L7 | 🟢 Proficient | Configure Traefik route by host + path | [`02-setup/03-traefik-ingress.md`](../02-setup/03-traefik-ingress.md) |
| Internal DNS | 🟡 Working | Explain `svc.cluster.local` resolution | [`01-knowledge-map.md`](01-knowledge-map.md#4-kubernetes) |
| Virtual networking | 🟡 Working | Know why pods get IPs and traffic encapsulation | [`00-understanding/02-architecture.md`](../00-understanding/02-architecture.md) |

## 3. TLS & certificates

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| HTTPS & trust chains | 🟡 Working | Understand the three certificate trust steps | [`02-setup/02-cloudflare-tunnel.md`](../02-setup/02-cloudflare-tunnel.md) |
| SNI and multi-host certs | 🟡 Working | Traefik serving multiple subdomains | [`02-setup/03-traefik-ingress.md`](../02-setup/03-traefik-ingress.md) |
| ACME / Let's Encrypt | 🟡 Working | Explain HTTP-01 vs DNS-01 and why DNS-01 works behind tunnel | [`02-setup/03-traefik-ingress.md`](../02-setup/03-traefik-ingress.md) |
| Cert rotation | 🟡 Working | Verify auto-renewal in Grafana/logs | [`05-observability`](../05-observability/README.md) |

## 4. Kubernetes

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| Pods / Deployments / Services | 🟢 Proficient | Deploy a service with replicas + rolling update | [`03-services/01-first-service.md`](../03-services/01-first-service.md) |
| Ingress / routing | 🟢 Proficient | Wire a subdomain to a service through Traefik | [`02-setup/03-traefik-ingress.md`](../02-setup/03-traefik-ingress.md) |
| ConfigMaps / Secrets | 🟢 Proficient | Pass config safely to a pod | [`03-services/01-first-service.md`](../03-services/01-first-service.md) |
| PV / PVC | 🟢 Proficient | Give MinIO or Vault durable storage | [`03-services`](../03-services/README.md) |
| Namespaces & labels | 🟡 Working | Organize `auth`, `storage`, `monitoring` | throughout setup |
| Helm | 🟡 Working | `helm install` charts, override values | [`03-services`](../03-services/README.md) |
| RBAC | 🟢 Proficient | Restrict what service accounts can do | [`04-security/02-rbac-and-secrets.md`](../04-security/02-rbac-and-secrets.md) |
| NetworkPolicies | 🟡 Working | Default-deny between namespaces | [`04-security/03-network-policies.md`](../04-security/03-network-policies.md) |
| kubectl fluency | 🟢 Proficient | Debug, check resources, exec, describe, logs | [`06-testing/00-verify-cluster.md`](../06-testing/00-verify-cluster.md) |

## 5. Containers & Docker

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| Images & layers | 🟡 Working | Write a Dockerfile for the demo API | [`examples`](../../examples/) |
| Resources & health probes | 🟡 Working | Set limits + probes on a deployment | [`03-services/01-first-service.md`](../03-services/01-first-service.md) |
| Building/pushing | 🟡 Working | Push to your own Harbor/Gitea registry | [`05-registry.md`](../03-services/05-registry.md) |
| containerd | 🟢 Proficient | Know k3s uses containerd, `ctr`/`nerdctl` for debugging | [`01-knowledge-map.md`](01-knowledge-map.md#5-containers--docker) |

## 6. Security

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| Zero-trust tunnels | 🟢 Proficient | Explain why tunnel beats open ports | [`02-setup/02-cloudflare-tunnel.md`](../02-setup/02-cloudflare-tunnel.md) |
| OAuth2 / OIDC | 🟡 Working | Protect a service via Keycloak JWT | [`04-security/01-authentication.md`](../04-security/01-authentication.md) |
| Secrets management | 🟡 Working | App reads a Vault-issued secret | [`04-security/02-rbac-and-secrets.md`](../04-security/02-rbac-and-secrets.md) |
| RBAC / least privilege | 🟢 Proficient | Restrict SA permissions; non-root containers | [`04-security`](../04-security/README.md) |
| WAF / rate limiting | 🟡 Working | Add a Traefik rate-limit middleware, edge WAF rule | [`04-security/04-waf-and-rate-limiting.md`](../04-security/04-waf-and-rate-limiting.md) |
| Auditing | 🟡 Working | Enable & view kube-apiserver audit logs in Loki | [`05-observability/03-logs.md`](../05-observability/03-logs.md) |

## 7. IaC & GitOps

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| Terraform basics | 🟡 Working | Define the cloudflare zone/tunnel as code | [`07-iac-gitops/01-terraform.md`](../07-iac-gitops/01-terraform.md) |
| Helm values | 🟢 Proficient | Override chart values for your needs | [`03-services`](../03-services/README.md) |
| ArgoCD / GitOps | 🟡 Working | Deploy a service just by merging a PR | [`07-iac-gitops/02-gitops-argocd.md`](../07-iac-gitops/02-gitops-argocd.md) |
| SOPS / Sealed-Secrets | 🟡 Working | Commit encrypted secret, decrypt in-cluster | [`07-iac-gitops/03-secrets-in-git.md`](../07-iac-gitops/03-secrets-in-git.md) |

## 8. Release & Operations

| Skill | Needed | "Good" looks like | Practice here |
|-------|--------|-------------------|---------------|
| Monitoring & alerting | 🟡 Working | Alert fires when a pod is down | [`05-observability/02-metrics.md`](../05-observability/02-metrics.md) |
| Centralized logs | 🟡 Working | Grafana → Loki → pod logs | [`05-observability/03-logs.md`](../05-observability/03-logs.md) |
| Backups & restore | 🟡 Working | Velero backup → restore in a scratch cluster | [`06-testing/04-backup-restore.md`](../06-testing/04-backup-restore.md) |
| CI/CD | 🟡 Working | GitHub Action builds image; ArgoCD ships it | [`07-iac-gitops/02-gitops-argocd.md`](../07-iac-gitops/02-gitops-argocd.md) |
| Incident basics | 🟡 Working | Written runbook for "site is down" | [`06-testing/05-incident-response.md`](../06-testing/05-incident-response.md) |

---

## Your interview-ready summary paragraph (steal this)

> "I run a private Kubernetes cluster on a single Ubuntu box using **k3s**, exposed through a **zero-trust Cloudflare Tunnel** so the machine needs zero inbound ports. On it I run **MinIO** (S3-compatible storage), **Keycloak** (OIDC identity), **Vault** (secrets), **Traefik** as the API gateway, and **Prometheus + Loki + Grafana** for observability — all declared as code and deployed via **GitOps with ArgoCD**. It reproduces the architecture patterns of AWS (EKS, S3, IAM, Secrets Manager, CloudWatch, WAF) rather than its scale."

---

## 🔗 Continue reading

► **[Next: 04 — Learning path](04-learning-path.md)**

◄ **[Back to 01 Skills index](README.md)** · [🏠 Repo home](../../README.md)