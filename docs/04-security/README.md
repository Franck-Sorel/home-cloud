# 🔒 04 — Security

> **This section is for anyone who will put a service on the internet (that's all of us, section 06 is coming) OR who wants to defend the architecture.** Exposing something publicly makes you a target; this section is the shield: identity, secrets, RBAC, WAF/rate-limiting, and zero-trust posture.

---

## 📖 What's in this section

| # | Document | Covers |
|---|----------|--------|
| 01 | [`01-authentication.md`](01-authentication.md) | OAuth2/OIDC, Keycloak-protected services, JWT validation, MFA |
| 02 | [`02-rbac-and-secrets.md`](02-rbac-and-secrets.md) | K8s RBAC, least privilege, Secret + Vault patterns |
| 03 | [`03-network-policies.md`](03-network-policies.md) | Default-deny, pod segmentation, egress control |
| 04 | [`04-waf-and-rate-limiting.md`](04-waf-and-rate-limiting.md) | Cloudflare WAF, bot rules, Traefik rate-limit middlewares |
| 05 | [`05-zero-trust-exposure.md`](05-zero-trust-exposure.md) | Cloudflare Access (Zero Trust), tunnel hygiene, why no open ports |
| 06 | [`06-hardening-checklist.md`](06-hardening-checklist.md) | The full pre-public-launch checklist |

---

## 🔐 Security model at a glance

```
                 ┌────────────────── Cloudflare Edge ──────────────────┐
                 │ WAF rules · Bot Fight Mode · Rate limits · TLS      │
                 │ Cloudflare Access (zero-trust login) [optional]      │
                 └───────────────────────┬─────────────────────────────┘
                                          │ tunnel (no open ports)
   ┌────────────────── k3s ──────────────▼────────────────────────────────┐
   │  Traefik  → rate-limit · fwd-auth (Keycloak) · security headers       │
   │  NetworkPolicies (default-deny between namespaces)                    │
   │  RBAC (least-privilege SAs) · Secrets scrubbed · Vault dynamic creds  │
   │  Apps run non-root, read-only fs, seccomp where possible              │
   └───────────────────────────────────────────────────────────────────────┘
```

## Core principle — defense in depth
> No single control is trusted. TLS at edge, an auth gate at Traefik, RBAC in the cluster, network isolation, monitored logs. Each layer assumes the ones above it might be bypassed.

---

## Quick-reference matrix

| Concern | Control | Where configured |
|---------|---------|------------------|
| Who can log in to a service | Keycloak OIDC / Cloudflare Access | [`01-authentication.md`](01-authentication.md), [`05-zero-trust-exposure.md`](05-zero-trust-exposure.md) |
| What a ServiceAccount may do | k8s RBAC | [`02-rbac-and-secrets.md`](02-rbac-and-secrets.md) |
| Where secrets live | Vault / k8s Secrets / SOPS | [`02-rbac-and-secrets.md`](02-rbac-and-secrets.md) |
| Can pod A reach pod B | NetworkPolicies | [`03-network-policies.md`](03-network-policies.md) |
| Flood / abuse protection | Cloudflare WAF + Traefik ratelimit | [`04-waf-and-rate-limiting.md`](04-waf-and-rate-limiting.md) |
| Is a request from the internet even allowed inbound | Tunnel (no ports) + CF Access | [`05-zero-trust-exposure.md`](05-zero-trust-exposure.md) |
| Am I ready to go live | the checklist | [`06-hardening-checklist.md`](06-hardening-checklist.md) |

---

## ⏱️ Required before section 06 (exposure to the world)

At minimum, do these four before pointing the world at your cluster:

1. **[01-authentication](01-authentication.md)** — gate at least the admin consoles
2. **[02-rbac-and-secrets](02-rbac-and-secrets.md)** — no `admin` SAs kicking around, no plaintext secrets
3. **[04-waf-and-rate-limiting](04-waf-and-rate-limiting.md)** — edge WAF + a rate-limit on public routes
4. **[06-hardening-checklist](06-hardening-checklist.md)** — run through it honestly

---

## 🔗 Continue reading

► **[Next: 01 — Authentication](/01-authentication.md)**

◄ **[Back to repository home](../../README.md)**

---

## 🧭 Navigation

- [🏠 Repository home](../../README.md)
- [🧠 00 — Understanding](../00-understanding/README.md)
- [💡 01 — Skills](../01-skills/README.md)
- [🚀 02 — Setup](../02-setup/README.md)
- [🛠️ 03 — Services](../03-services/README.md)
- [🔒 04 — Security](README.md)
- [📈 05 — Observability](../05-observability/README.md)
- [🧪 06 — Testing](../06-testing/README.md)
- [♾️ 07 — IaC & GitOps](../07-iac-gitops/README.md)
- [🗺️ 08 — Roadmap](../08-roadmap/README.md)