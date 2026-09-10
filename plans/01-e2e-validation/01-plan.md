# 📋 01 — Step-by-step E2E plan

> **Who this is for:** the operator who wants the exact `e2e.yml` execution
> order, *why* each step must come before the next, and how to know it worked.

This is the runbook for the workflow in
[`e2e.yml`](../../.github/workflows/e2e.yml). Read this first if you're about
to debug a red E2E run.

---

## The ordering rule (why it matters)

Every bundle builds on something. The dependency order is **base first, then
the opt-in bundles, then security last**:

| Order | Bundle(s) | Why here |
|-------|-----------|----------|
| 1 | **base** | Creates the `apps` namespace, the `security-headers` + `security-limits` Traefik v3 Middlewares (one type each), and the `hello` demo. Everything else *routes through* or *reads from* `apps`. |
| 2 | **auth storage secrets serverless registry observability** | Each creates its own namespace + Traefik IngressRoute (and `auth` adds the `protected-gate` Middleware into `apps`). They are independent of each other but all sit *inside* the base-provided cluster ingress. |
| 3 | **security** | Applies **default-deny NetworkPolicies** onto the *already-existing* namespaces. It must run **last**: it hardens whatever is already there—if it ran first there'd be nothing to protect, and its default target namespaces (`apps, storage, auth, secrets`) wouldn't all exist yet. |

> Think of it like building and then locking a house: **frame the rooms
> (base), furnish them (opt-in bundles), then lock every door (security).**

Because `security` targets namespaces that *must already exist*, installing it
against a set of namespaces you haven't created will fail Helm (see
[03 — What doesn't work](03-what-doesnt.md) for the exact footgun).

---

## Phase 1 — install, then prove the cross-stack story

| Step | What runs | Exit criterion |
|------|-----------|----------------|
| Boot | bare k3s via `curl -sfL https://get.k3s.io` (k3s v1.36.3, `--disable traefik`); install **our own Traefik v3** chart; map hostnames to the Traefik LoadBalancer EXTERNAL-IP (`curl --noproxy '*'`, since the runner sets an HTTP_PROXY) | `kubectl get nodes` → 1 node `Ready`; Traefik Deployment rolled out |
| Host alias | `sudo ... 127.0.0.1 hello.mycloud.com` in `/etc/hosts` | hostname resolves to cluster-local Traefik (no public DNS) |
| Deploy | `apply.sh base` → `apply.sh auth storage secrets serverless registry observability` → `apply.sh security` | each `helm upgrade --install` returns 0; bundles listed in `✔ bundles applied` |
| Wait | `kubectl -n apps rollout status deploy/hello` + all pods | hello `Available`, no non-Running pods |
| Healthcheck | adapted for CI (L0 node / L1 kube-system / L4 routes / L5 pods) | all present (L2 tunnel + L3 public TLS skipped—see [03](03-what-doesnt.md)) |
| Smoke | adapted for CI—`curl http://hello.mycloud.com/` via cluster-local Traefik | HTTP `200` |
| **Assertions** | A–E below | every check `✔` |

### The cross-stack assertions (phase 1) — how the stacks prove each other

| ID | Assertion | What it actually proves |
|----|-----------|-------------------------|
| **A1** | `hello` Deployment has available replicas | base's demo workload is serving |
| **A2** | `curl http://hello.mycloud.com/` → `200` + expected body | **base ↔ Traefik IngressRoute** interop (the route exists and works through the real ingress) |
| **B1** | `security-headers` **and** `security-limits` Middlewares exist **and** are both attached to the hello route | **base** wiring: the route references the shared middlewares |
| **B2** | `curl -I` shows `X-Content-Type-Options: nosniff` + `X-Frame-Options: SAMEORIGIN` | the middleware's **SecurityHeaders are applied on the wire** |
| **C1** | `protected-gate` Middleware exists, pointing at `oauth2-proxy.auth.svc` | **auth** layer present and correctly configured (presence only—see 03) |
| **D1** | namespaces `apps auth storage secrets serverless registry monitoring` exist | **every enabled bundle** actually created its namespace |
| **E1** | `default-deny-ingress` + `default-deny-egress` NetworkPolicies in `apps/auth/storage/secrets` | **security** bundle added its policies to the existing namespaces |

---

## Phase 3 — the aggregator's on/off contract (assertion F)

After phase 1 proves *step-by-step* install, we tear it all down and re-create
the same world through the **`home-cloud` aggregator** chart instead:

```
enabled : base + auth + storage + registry + security
disabled: secrets + serverless + observability
tls     : disabled (base.tls.enabled=false → no DNS/LE in CI)
```

| ID | Assertion | What it proves |
|----|-----------|----------------|
| **F1** | enabled set is present: `hello` serving again, namespaces `apps/auth/storage/registry`, `protected-gate` middleware, `minio-api`/`harbor` routes, NetworkPolicies | the aggregator **enables exactly** the requested bundles (base re-deployed via the aggregator proves the aggregator really installs what it claims) |
| **F2** | disabled set is absent: namespaces `secrets/serverless/monitoring`, `vault` & `faas-gateway` routes NOT found | the aggregator **does not** leak disabled bundles — a verifiable negative |

---

## Exit criteria (what "green" means)

1. Phase 1: all assertions **A1–E1** report `✔` and the step prints `E2E PHASE 1 GREEN`.
2. Phase 3: assertions **F1–F2** report `✔` and `E2E PHASE 3 GREEN`.
3. A **JUnit** XML is written for each phase and archived as the `e2e-junit`
   artifact, and the run summary says "home-cloud E2E result".
4. Any `✘` flips the workflow red — failures are **granular**, named per
   assertion (e.g. `B2 SecurityHeaders applied`), so you can see *which* stack
   link broke instead of a single generic "tests failed".

---

## Time budget

| Stage | Rough time |
|-------|-----------|
| bare k3s boot via get.k3s.io (k3s v1.36.3, --disable traefik) + Traefik v3 install | 1–3 min |
| Phase 1 install + rollout + assert | 2–4 min |
| Phase 3 aggregator + assert | 1–2 min |
| **Total** | **≈ 5–9 min** |

> This is why it is not on `pull_request`: it's cheap enough to run nightly /
> on demand, too heavy to gate every PR (static `ci.yml` covers PRs).

---

## 🧭 Navigation

► **[Next: 02 — What works](02-what-works.md)**

◄ **[Back: 01 E2E Validation](README.md)** · [🏠 Repo home](../../README.md)
