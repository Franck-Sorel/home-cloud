# 06 — Hardening checklist (pre-launch)

> **Goal:** One honest, reviewed check-list to mark complete before you start telling anyone (or the internet) about a service. Each 👉 links to where the control lives.

---

## □ A. Identity & access

- [ ] Keycloak admin reachable only behind Cloudflare Access or a protected route ([`01-authentication`](01-authentication.md))
- [ ] Admin realm uses **MFA (TOTP)** minimum ([`01-authentication`](01-authentication.md))
- [ ] Default/disabled accounts removed; demo passwords changed
- [ ] No `cluster-admin` binding on app namespaces ([`02-rbac-and-secrets`](02-rbac-and-secrets.md))

## □ B. Secrets

- [ ] No real secrets in git; `.gitignore` guards `*.creds`, `.env`, credentials files ([`07-iac-gitops/03-secrets-in-git`](../07-iac-gitops/03-secrets-in-git.md))
- [ ] K8s Secrets created imperatively (or via SOPS once GitOps) — not plaintext yaml
- [ ] Vault sealed + unseal keys in a password manager ([`03-services/04`](../03-services/04-vault-secrets.md))
- [ ] Probes / dashboards don't echo env secrets

## □ C. Networking

- [ ] Nothing inbound: `ss -tlnp` shows no public listener on 80/443 ([`05-zero-trust-exposure`](05-zero-trust-exposure.md))
- [ ] Tunnel credentials are a Secret, image pinned, 2 replicas ([`05-zero-trust-exposure`](05-zero-trust-exposure.md))
- [ ] Cloudflare **Full (strict)** is on ([`04-waf-and-rate-limiting`](04-waf-and-rate-limiting.md))
- [ ] (If multi-node / real production) CNI with NetworkPolicy enforcement + default-deny ([`03-network-policies`](03-network-policies.md))

## □ D. Edge & gateway

- [ ] CF Managed WAF + Bot Fight on (free tier) ([`04-waf-and-rate-limiting`](04-waf-and-rate-limiting.md))
- [ ] Rate-limit middleware on every public route ([`04-waf-and-rate-limiting`](04-waf-and-rate-limiting.md))
- [ ] Security headers middleware on public routes (CSP, nosniff, HSTS) ([`02-setup/03`](../02-setup/03-traefik-ingress.md))

## □ E. Cluster

- [ ] k3s + your distro patches are current; image autopatching via renovate/dependabot in CI (roadmap)
- [ ] Pod resource limits set (no a runaway app eats the box) ([`03-services/01`](../03-services/01-first-service.md))
- [ ] Liveness/readiness probes on every workload ([`03-services/01`](../03-services/01-first-service.md))
- [ ] Containers run non-root with read-only fs where possible; `runAsNonRoot` flag on your own images

## □ F. Observability (do *before* go-live)

- [ ] Loki receives k8s + ingress + app logs ([`05-observability/03`](../05-observability/03-logs.md))
- [ ] Prometheus alerts wired: pod-down, high-rate-429, node-disk-full, tunnel-down ([`05-observability/02`](../05-observability/02-metrics.md))
- [ ] Grafana dashboards exist for node, pods, ingress, and your app ([`05-observability/01`](../05-observability/01-dashboards.md))

## □ G. Backup & DR

- [ ] Velero scheduled backups to MinIO running ([`06-testing/04`](../06-testing/04-backup-restore.md))
- [ ] **A restore was actually tested** (that's the "I'm not lying about this" checkbox) ([`06-testing/04`](../06-testing/04-backup-restore.md))

---

## How to use this

- It's a **living doc** — update it as the project grows.
- Do it before section **06 exposure**; the whole point is that the world-facing URL is behind tested, observed, backed-up infra.
- Include a **screenshot/PR of a completed checklist** in the repo (`docs/04-security/security-audit.md`) — real auditors love that.

---

## 🔗 Continue reading

► **[Next section: 📈 05 — Observability](../05-observability/README.md)**

◄ **[Back to 04 Security index](README.md)** · [🏠 Repo home](../../README.md)