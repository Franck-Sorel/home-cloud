# 🧠 00 — Understanding

> **This section is for readers who want to *understand* before they *build*.**  
> It explains what a private cloud is, how the whole system is architected, the design decisions behind every choice, the constraints that shape everything, and how each piece maps to AWS.

**If you want to just start building**, skip ahead to [`docs/02-setup`](../02-setup/README.md).

---

## 📖 What's in this section

| # | Document | Covers |
|---|----------|--------|
| 01 | [`01-what-is-a-private-cloud.md`](01-what-is-a-private-cloud.md) | The big picture: what we're building and why |
| 02 | [`02-architecture.md`](02-architecture.md) | The full architecture, layer by layer |
| 03 | [`03-design-decisions.md`](03-design-decisions.md) | *Why* each technology was chosen (and what was rejected) |
| 04 | [`04-constraints.md`](04-constraints.md) | The hard constraints (e.g. "no touching the OS") and their implications |
| 05 | [`05-aws-parity.md`](05-aws-parity.md) | Mapping every AWS service to a self-hosted alternative |

---

## 🗺️ The journey at a glance

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       YOUR UBUNTU MACHINE                               │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                        K3s (Kubernetes)                           │  │
│  │                                                                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐        │  │
│  │  │  MinIO   │  │ Keycloak │  │  Vault   │  │  Your APIs   │  ...   │  │
│  │  │  (S3)    │  │  (IAM)   │  │ (Secrets)│  │  (microsvc)  │        │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────┘        │  │
│  │                              │                                     │  │
│  │                    ┌─────────▼─────────┐                           │  │
│  │                    │  Traefik Ingress  │  (reverse proxy + TLS)    │  │
│  │                    └─────────┬─────────┘                           │  │
│  └──────────────────────────────┼─────────────────────────────────────┘  │
│                                 │ outbound tunnel (no open ports)        │
│  ┌──────────────────────────────▼─────────────────────────────────────┐  │
│  │                    Cloudflare Tunnel (cloudflared)                 │  │
│  └──────────────────────────────┬─────────────────────────────────────┘  │
└─────────────────────────────────┼───────────────────────────────────────┘
                                  │ encrypted outbound connection
                        ┌─────────▼─────────┐      ┌────────────────────┐
                        │ Cloudflare Edge   │      │  Your DNS + TLS   │
                        │ (DDoS, TLS, CDN)  │◄────►│ (managed by CF)   │
                        └─────────┬─────────┘      └────────────────────┘
                                  │
                        ┌─────────▼─────────┐
                        │  THE INTERNET     │
                        │  api.mycloud.com  │
                        └───────────────────┘
```

---

## 🔗 Continue reading

► **[Next: 01 — What is a private cloud?](01-what-is-a-private-cloud.md)**

◄ **[Back to repository home](../../README.md)**

---

## 🧭 Navigation

- [🏠 Repository home](../../README.md)
- [🧠 00 — Understanding](README.md)
- [💡 01 — Skills](../01-skills/README.md)
- [🚀 02 — Setup](../02-setup/README.md)
- [🛠️ 03 — Services](../03-services/README.md)
- [🔒 04 — Security](../04-security/README.md)
- [📈 05 — Observability](../05-observability/README.md)
- [🧪 06 — Testing](../06-testing/README.md)
- [♾️ 07 — IaC & GitOps](../07-iac-gitops/README.md)
- [🗺️ 08 — Roadmap](../08-roadmap/README.md)