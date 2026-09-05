# ♾️ 07 — Infrastructure-as-Code & GitOps

> **This section is for the reader who wants the *reproducibility* half — the thing that turns a laptop experiment into a portfolio-defining "platform."**  
> After this: the entire private cloud is described as code, and a pull-request *is* the deploy. That is exactly how serious production teams (and AWS itself) operate.

---

## 📖 What's in this section

| # | Document | Covers |
|---|----------|--------|
| 01 | [`01-terraform.md`](01-terraform.md) | Terraform for the Cloudflare side: zone, tunnel, hostnames, WAF as code |
| 02 | [`02-gitops-argocd.md`](02-gitops-argocd.md) | ArgoCD: the cluster pulls its desired state from this repo; PR = deploy |
| 03 | [`03-secrets-in-git.md`](03-secrets-in-git.md) | SOPS / Sealed Secrets: committing secrets safely with a public repo |

---

## The principle

```
                    ┌──────────────────────────────────────────────┐
                    │   GIT (this repo) = single source of truth   │
                    └───────────────┬──────────────────────────────┘
                                    │
        push/merge (PR)             │  ArgoCD continuously
                                    ▼  reads & reconciles
                    ┌──────────────────────────────────────────────┐
                    │   k3s cluster state  ⇦  desired state in git │
                    └──────────────────────────────────────────────┘
                    Terraform (Cloudflare, DNS, tunnels) also from code
```

- **Declarative** — the repo describes *what* should exist, not *how* to build it step-by-step.
- **Pull-based** — ArgoCD polls git; a human can't drift the cluster silently, because ArgoCD fixes drift automatically.
- **Reviewable** — every change is a reviewed PR; rollback is `git revert`.

---

## 🔗 Continue reading

► **[Next: 01 — Terraform for Cloudflare](01-terraform.md)**

◄ **[Back to repository home](../../README.md)**

---

## 🧭 Navigation

- [🏠 Repository home](../../README.md)
- [🧠 00 — Understanding](../00-understanding/README.md)
- [💡 01 — Skills](../01-skills/README.md)
- [🚀 02 — Setup](../02-setup/README.md)
- [🛠️ 03 — Services](../03-services/README.md)
- [🔒 04 — Security](../04-security/README.md)
- [📈 05 — Observability](../05-observability/README.md)
- [🧪 06 — Testing](../06-testing/README.md)
- [♾️ 07 — IaC & GitOps](README.md)
- [🗺️ 08 — Roadmap](../08-roadmap/README.md)