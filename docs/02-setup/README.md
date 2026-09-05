# 🚀 02 — Setup

> **This section is for the reader who wants to get from an empty Ubuntu machine to a secure, publicly-accessible private cloud — as fast as possible, with working commands.**  
> It assumes the *understanding* motivation is optional; every command is copy-paste and explained in one line.

---

## 📖 What's in this section

| # | Document | You'll end up with |
|---|----------|--------------------|
| 00 | [`00-prerequisites.md`](00-prerequisites.md) | A checklist: account, domain, machine, tools |
| 01 | [`01-install-k3s.md`](01-install-k3s.md) | A running single-node Kubernetes cluster (k3s) |
| 02 | [`02-cloudflare-tunnel.md`](02-cloudflare-tunnel.md) | A `cloudflared` pod → your first public URL |
| 03 | [`03-traefik-ingress.md`](03-traefik-ingress.md) | Host-based routing + HTTPS on your domain |

---

## The payoff after this section

```
Internet → Cloudflare (edge + DNS) → Tunnel → Traefik → first service on your domain
```

- 🔐 HTTPS on `*.mycloud.com`
- 🌍 A service reachable publicly at `https://<service>.mycloud.com`
- 🚫 **Zero** host OS changes, **zero** router config, **zero** inbound ports

---

## ⏱️ Time & cost

| Item | Estimate |
|------|----------|
| Time | ~1–2 hours |
| Domain | `~$10/yr` |
| Cloudflare | `$0` (free tier) |

---

## Prerequisite overview (full detail in doc 00)

- [ ] An Ubuntu machine (this doc assumes Ubuntu 22.04 LTS / 24.04 LTS)
- [ ] A domain you own (e.g. `mycloud.com`) — [Namecheap](https://www.namecheap.com), [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/), or similar
- [ ] A **Cloudflare account** with your domain added (free plan)
- [ ] `curl`, `wget` (usually present)

---

## 🔗 Start here

► **[Next: 00 — Prerequisites](00-prerequisites.md)**

◄ **[Back to repository home](../../README.md)**

---

## 🧭 Navigation

- [🏠 Repository home](../../README.md)
- [🧠 00 — Understanding](../00-understanding/README.md)
- [💡 01 — Skills](../01-skills/README.md)
- [🚀 02 — Setup](README.md)
- [🛠️ 03 — Services](../03-services/README.md)
- [🔒 04 — Security](../04-security/README.md)
- [📈 05 — Observability](../05-observability/README.md)
- [🧪 06 — Testing](../06-testing/README.md)
- [♾️ 07 — IaC & GitOps](../07-iac-gitops/README.md)
- [🗺️ 08 — Roadmap](../08-roadmap/README.md)