# 🧪 01 — E2E Validation Workflow

> **Who this is for:** infra / CI maintainers and anyone who wants *proof* that
> the bundles in this repo actually work **together** on a real cluster — not
> just that they lint.

The repo already has `just validate` / [`ci.yml`](../../.github/workflows/ci.yml),
a **static accuracy** pipeline (helm lint + render, shellcheck, yamllint,
terraform). That proves the charts are *well-formed*, but a templated manifest
and a *running* service are different things.

This plan adds the missing half: **[`.github/workflows/e2e.yml`](../../.github/workflows/e2e.yml)**
boots a real single-node **bare k3s cluster in CI** (via the official
`curl -sfL https://get.k3s.io` script, k3s v1.36.3, started with
`--disable traefik` so it installs **our own Traefik v3** chart), installs the
bundles in dependency order, waits for pods, and then runs **cross-stack
assertions** that prove "each stack works together" (hello served through
Traefik, security headers on the wire, the auth middleware present,
namespaces + NetworkPolicies created, and the aggregator enabling exactly what
you asked).

```
┌─────────────┐    ┌───────────────────────────────────────────────────────┐
│ manual run / │▶▶▶│  e2e.yml  (workflow_dispatch | nightly cron)           │
│ nightly     │    │                                                       │
└─────────────┘    │  1. boot bare k3s (get.k3s.io, k3s v1.36.3,           │
                   │     --disable traefik) + install our Traefik v3 chart │
                   │  2. apply.sh base  →  opt-in bundles →  security       │
                   │  3. wait: hello rollout + pods Running                 │
                   │  4. healthcheck + smoke  (adapted: no public DNS)      │
                   │  5. cross-stack assertions  A–E  (phase 1)             │
                   │  6. teardown                                           │
                   │  7. home-cloud aggregator + assertion F (phase 3)      │
                   │  8. JUnit artifact + summary ("E2E green")             │
                   └───────────────────────────────────────────────────────┘
```

> **What this is NOT:** it does not prove the *upstream* heavy workloads
> (MinIO, Vault, OpenFaaS, Harbor, Prometheus/Loki/Grafana, Keycloak) run —
> those ship from **separate upstream charts** that aren't vendored. It proves
> the **glue this repo owns** (namespaces, routing, middleware, network
> policies, and the aggregator's on/off wiring) is installed and interoperates.

---

## How to trigger

| How | What happens |
|-----|--------------|
| **Manual** | Repo → **Actions** → **e2e** → **Run workflow** (optionally nightly already on) |
| **Nightly** | Cron `0 3 * * *` (UTC); a `concurrency` group cancels overlapping runs |

It is deliberately **not** wired to `pull_request`: it's heavy and slow, and
`ci.yml` already covers static accuracy on every PR.

---

## 📖 What's in this plan

| # | Document | Covers |
|---|----------|--------|
| [01](01-plan.md) | Step-by-step plan | Exact ordering, why bundle order matters, exit criteria, time budget |
| [02](02-what-works.md) | What works | What installs and interoperates **today**, from the repo's actual content |
| [03](03-what-doesnt.md) | What doesn't | Honest limits: no DNS/LE, no tunnel, no multi-node, CNI / netpol caveats |
| [04](04-extend.md) | How to extend | Add a new bundle or a new cross-stack assertion |

---

## The one-line proof

> If this workflow is **green**, then: base + auth + storage + secrets +
> serverless + registry + observability + security charts all **install** in
> order on a real k3s cluster, `hello` is served through Traefik **with
> security headers on the wire**, the auth `protected-gate` middleware exists,
> the enabled bundles' namespaces and the security `NetworkPolicy`s are
> present, and the `home-cloud` aggregator enables **exactly** the requested
> bundles (a disabled one is verifiably absent).

---

## 🧭 Navigation

► **[Next: 01 — Step-by-step plan](01-plan.md)**

◄ **[Back to repository home](../../README.md)** — the top-level map of this repo.

---

## 🧭 Also in the story

This plan complements the [test/verify docs](../../docs/06-testing/README.md)
and the [bundles & release docs](../../docs/09-bundles/README.md), and pairs
with the [multi-node virtualization plan](../02-virtualization-layer/README.md)
(when you want the same E2E story on real separate nodes going past the
single-node bare k3s CI cluster).
