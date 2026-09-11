# 🔀 03 — Public Wrap / Private Deploy split

> **Who this is for:** the maintainer who wants to keep this "guidance" repo
> public — showing *how*, the *wrap*, and generic knowledge — while hiding all
> **real logic, exact software versions, and underlying engines** in a
> **private** repo that actually **deploys** the workloads.
>
> **Motto: "The wrap is public, the deploy is private."** This repo = the
> guidance + the public Helm *wrapper* charts. The private repo = the real
> workloads that make it actually run on **your** machine.

---

## Decision summary

| Question | Decision |
|----------|----------|
| Private hosting | **Private GitHub repo** (same owner) |
| Public repo stops pinning concrete versions | **Yes** (generic guidance; locked truth private) |
| Public bundles become **pure wraps** (no workload, no real version) | **Yes** |
| Seam = two installs joined by a **Service contract** | **Yes** (no umbrella chart) |
| First milestones | **M0** private scaffold + corrected LXD/k3s foundation, then **M1** MinIO fully operational — stop for review |

**Order / strategy:** proceed **step by step**; only start a step once the previous is
fully operational and verified (see [03 — Milestones](03-milestones.md)). The public
repo's existing green CI (`validate` + glue `e2e`) **must never break** — every change
keeps it green, and version-pin removal is deliberately the **last** public milestone.

---

## The shape at a glance

```
PUBLIC repo (this one, home-cloud)            PRIVATE repo (private-home-cloud)
────────────────────────────────────          ───────────────────────────────────
docs/ (00–09) · GLOSSARY · navigation         versions.lock   ← exact engines/tags
bundles/*  = WRAP                              lxd/            ← virtualization foundation
  Namespace + IngressRoute + Middleware        charts/minio, vault, keycloak, ...
  + values + CONTRACT  (no workload)           secrets/        ← SOPS/age-encrypted
scripts/ · justfile · CI (validate + glue)     CI (private e2e → service smokes)
plans/                                         JUST deploy-<svc>
```

The **seam** between them is a single, stable, version-agnostic **contract** per
bundle (namespace + expected `Service` name/ports). The public wrap creates the
namespace/ingress/middleware and points at a Service *name*; the private chart
creates the real workload *and* that exact Service. Nothing else about a bundle
is shared.

---

## 📖 What's in this plan

| # | Document | Covers |
|---|----------|--------|
| [01](01-architecture.md) | The two-repo model | roles, the contract-first seam, mechanism, version/secrets/CI split |
| [02](02-inventory.md) | Full inventory | **precise** what-stays-public vs. what-goes-private, the contract table, version-remediation list |
| [03](03-milestones.md) | Milestones | M0–M7 step-by-step with gates + acceptance criteria |
| [04](04-risks-and-conflicts.md) | Migration safety | how-generic-change-won't-break-existing work, rollback, fine-tuning rules |

---

## Quick answers to "what isolates public from private"

- **Public never** contains: exact image tags/k3s/cloudflared/chart versions, real
  passwords/tokens, the produced container images for the services, or the private
  repo's CI smoke results.
- **Public still contains:** the *concepts*, the *wrap* (namespaces/ingress/middleware),
  the *contract* each bundle must satisfy, the public validation + glue e2e.
- **Private provides:** the real `Deployment`/`StatefulSet`+`PVC`+`Service` per bundle,
  pinned to exact versions, with SOPS-encrypted secrets and a private CI that proves
  each one works (`mc ls`, `vault status`, Keycloak token, …).

---

## Navigation

► **[Next: 01 — Architecture](01-architecture.md)**

◄ **[Back to repository home](../../README.md)**
