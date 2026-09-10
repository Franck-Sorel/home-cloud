# ⚠️ 03 — What Doesn't Work (honest boundaries)

> **Who this is for:** anyone who needs the line between what CI *actually
> proved* and what still needs a real machine — so nobody over-promises. These
> were found by reading the manifests and by what cannot run in a sandboxed
> CI runner.

This plan mirrors the repo's honesty culture
([`docs/08-roadmap/03-known-limits.md`](../../docs/08-roadmap/03-known-limits.md)):
saying what doesn't work is itself a signal of reliability.

---

## Not possible in CI (by definition)

| Limit | Why CI can't do it | Mitigation |
|-------|--------------------|------------|
| **No public DNS / Let's Encrypt DNS-01** | CI has no owned domain and no DNS/LE credentials | The workflow forces `tls.enabled=false` and checks over cluster-local HTTP; real certs are a manual/real-host step |
| **No Cloudflare Tunnel** | needs a tunnel token + a Cloudflare account | `mode=cloudflare` is used **only** to skip the DDNS CronJob; the `cloudflared` pod templates are empty, so E2E is a plain ingress test (healthcheck L2 is skipped) |
| **No multi-node** | k3d is single-node | see the [multi-node virtualization plan](../02-virtualization-layer/README.md) |
| **No CGNAT / router port-forward** | CI runner has no home router/ISP | only testable on the real home host |
| **Heavy upstream workloads absent** | MinIO/Vault/OpenFaaS/Harbor/Grafana aren't vendored; pulling them + a DB is heavy and needs creds | E2E proves the *glue*; install upstream charts on a real host to prove the service itself |

---

## Found by reading the manifests — real footguns

### 🚨 security default `namespaces` breaks the aggregator's own default

`bundles/security/values.yaml` defaults `namespaces: [apps, storage, auth,
secrets]`, but the **aggregator default enables only `base` + `security`**
(`auth`/`storage`/`secrets` are OFF by default). Installing the aggregator
untouched would render NetworkPolicies in the **non-existent** `storage`,
`auth`, and `secrets` namespaces → **Helm install fails** (namespace not
found).

> The E2E workflow must always pass `--set security.namespaces=...` matching
> the *actually enabled* bundles. This is a real usability bug worth fixing.

### 🚨 default NetPolicies vs Traefik → the base demo would break under an enforcing CNI

`default-deny-ingress` on `apps` blocks **all** ingress into `apps` pods —
including Traefik, which lives in `kube-system`. So **base + security** is only
"green" because:

- k3d/k3s default `flannel` does **not enforce** NetworkPolicies, and
- the E2E only asserts the policies are *present*, not that they filter.

On an enforcing CNI (e.g. Cilium — the roadmap's suggested swap), installing
`base` + `security` would make `hello` **unreachable** until you add an
explicit `Ingress` rule from Traefik. This is a genuine "doesn't work together
(yet)" finding, consistent with the repo's own
[known-limits doc](../../docs/08-roadmap/03-known-limits.md#networking-cni-enforcement).

### ⚠️ auth `protected-gate` references a service nothing creates

The middleware's `forwardAuth.address` is `http://oauth2-proxy.auth.svc.
cluster.local:80`, but **no bundle creates an `oauth2-proxy` service** — it's
an out-of-band install. So E2E can assert *presence + correct address* but
cannot attach the gate to a route in CI (that route would 5xx without the
proxy).

### ⚠️ DDNS CronJob references a Secret that only exists out-of-band

`bundles/base` (mode=ddns) renders a CronJob whose env comes from a
`ddns-credentials` Secret. If you install `base` in `mode=ddns` without that
Secret, scheduled jobs will error. The workflow avoids this by using
`mode=cloudflare` (DDNS CronJob not rendered). On a real host you must supply
the Secret.

### ⚠️ unpinned demo image

`hello` uses `hashicorp/http-echo:latest` — not reproducible over time. Fine
for a demo; a "real" E2E should pin a digest.

### ⚠️ L2/L3 layers of `healthcheck.sh` are unverified in CI

`healthcheck.sh` hard-requires a running `cloudflared` pod (L2) and a public
HTTPS URL (L3). Neither exists in CI. The E2E runs an **adapted** version that
skips exactly those two layers and calls that out explicitly rather than
silently failing.

---

## Practical rules the E2E follows because of the above

1. `security.namespaces` is always set to the enabled set.
2. `tls.enabled=false` everywhere and all probes are HTTP + `/etc/hosts`, with
   no credentials supplied.
3. `base` uses `mode=cloudflare` to avoid the DDNS CronJob/Secret.
4. Assertions on the big workloads are limited to *namespace + route +
   middleware presence*; never a claim that MinIO/Vault/etc are serving.

---

## 🧭 Navigation

► **[Next: 04 — How to extend](04-extend.md)**

◄ **[Back: 02 — What works](02-what-works.md)** · [Back: 01 E2E Validation](README.md) · [🏠 Repo home](../../README.md)
