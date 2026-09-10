# ✅ 02 — What Actually Works (grounded in the repo)

> **Who this is for:** anyone (notably a future employer or collaborator) who
> wants an *honest, evidence-based* inventory of which bundles install and
> interoperate **today** — against the real chart content in `bundles/`, not
> against aspirational README claims.

---

## The core idea: two different "works"

Every bundle chart ships **two layers**:

1. **The glue this repo owns** — namespaces, Traefik IngressRoutes, shared
   middlewares, NetworkPolicies, and aggregator on/off wiring.
2. **The heavy workload** — MinIO, Vault, OpenFaaS, Harbor, Prometheus/Loki/
   Grafana, Keycloak. These are **not vendored**; each is installed from a
   **separate upstream chart**, invoked in one documented command (see each
   bundle's `NOTES.txt`).

The E2E workflow proves layer 1 **for every bundle** and layer 2 **only for
what is trivially in-cluster** (`hello`). Layer 2 for the big workloads
requires a real machine with the upstream charts installed (see
[03 — What doesn't work](03-what-doesnt.md)).

---

## What installs and interoperates TODAY

### 🧱 base — fully working (layer 1 *and* a real demo)

`bundles/base/` renders: `apps` namespace, the `security-headers` (headers) +
`security-limits` (rate-limit) Traefik v3 Middlewares, and the `hello`
Deployment + Service + IngressRoute (`hashicorp/http-echo`). In `mode=ddns` it
also renders a DDNS CronJob; in `mode=cloudflare` it renders **nothing extra**
(the `cloudflare/` template dir is empty).

**Proven by CI:** `hello` is served through the Traefik IngressRoute, the
`security-headers` and `security-limits` middlewares are both attached, and
`curl -I` shows the **SecurityHeaders on the wire**
(`X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`).

**Not proven in CI:** the DDNS CronJob actually updating a Dynamic DNS record,
and any TLS cert issuance (see 03).

### 🔐 auth — glue works, workload doesn't

Renders: `auth` namespace, `protected-gate` forwardAuth Middleware into `apps`,
and a `keycloak` IngressRoute.

**Proven by CI:** the `protected-gate` Middleware exists and correctly points
at `oauth2-proxy.auth.svc.cluster.local:80`.

**Needs a real machine / separate install** (from `NOTES.txt`):

- Keycloak → upstream **`codecentric/keycloakx`**:
  `--set hostname.hostname=auth.mycloud.com --set postgresql.enabled=true`,
  plus a `keycloak-admin` Secret.
- The OIDC reverse proxy (e.g. oauth2-proxy / vouch) **service named
  `oauth2-proxy`** in `auth` that the middleware forwards to.

Until BOTH exist, only *presence* of the gate is verifiable — not a real login
flow.

### 💾 storage / 🔑 secrets / 🚀 serverless / 📦 registry / 📈 observability — glue works, workloads don't

Each renders only a namespace + a public IngressRoute to a service that the
bundle expects the upstream chart to provide. **Proven by CI:** the namespace
exists and the route is a real `Traefik IngressRoute`. **Not proven:** the
actual service behind it.

| Bundle | Namespace | Upstream chart (NOTES.txt) | Key knobs |
|--------|-----------|----------------------------|-----------|
| storage | `storage` | **bitnami `minio`** | `auth.rootUser`, `auth.rootPassword`, `persistence.size`, `initContainers.enabled=false` |
| secrets | `secrets` | **hashicorp `vault`** | `server.dev.enabled=true` (dev, auto-unsealed) or `server.ha.enabled=true` |
| serverless | `serverless` | **openfaas `openfaas`** | `basic_auth=true`, `functionNamespace=openfaas-fn`, `gateway.directFunctions=false` |
| registry | `registry` | **goharbor `harbor`** | `expose.type=ingress`, `externalURL=https://harbor.mycloud.com`, `core.tls.enabled=false` |
| observability | `monitoring` | **grafana `kube-prometheus-stack`** (+ `loki-stack`) | `grafana.ingress.enabled=false` (route via our IngressRoute) |

All of these are **separate `helm repo add` + `helm install`** commands that
the E2E workflow does not run (they'd be heavy and often need credentials /
DBs). Hence: the *glue* is proven in CI, the *workload* is proven only where
you actually install the upstream chart on a real cluster.

### 🛡️ security — installs; enforcement is a caveat

Renders `default-deny-ingress` + `default-deny-egress` NetworkPolicies onto the
namespaces listed in `namespaces` (default `apps, storage, auth, secrets`).

**Proven by CI:** the NetworkPolicy objects exist in those namespaces.

**Not proven / caveat:** see 03 — default k3s uses **flannel, which does NOT
enforce NetworkPolicies**, so "policies present" ≠ "traffic actually blocked".

### 🏠 home-cloud (aggregator) — proving the on/off contract

The aggregate enables `base` by default and every other bundle is opt-in via
`<bundle>.enabled`. **Proven by CI:** with a value-controlled set, the enabled
bundles' artifacts are all present and a disabled bundle is *verifiably absent*
(assertion F1/F2).

---

## Cross-stack behavior: what's proven by CI vs needs a real machine

| "Works together" claim | Proven by CI (bare k3s + our Traefik v3) | Needs a real machine |
|------------------------|---------------------|----------------------|
| `hello` → Traefik IngressRoute → HTTP 200 | ✅ | — |
| Security middleware attached + headers on the wire | ✅ | — |
| `protected-gate` middleware present + configured | ✅ (presence) | full Keycloak/oauth2 login flow |
| Enabled bundles' namespaces + routes exist | ✅ | — |
| NetworkPolicies present | ✅ (objects) | ❌ Cilium/implementing CNI enforcement |
| MinIO / Vault / OpenFaaS / Harbor / Grafana actually serve | ❌ not installed | install upstream charts + verify |
| Public HTTPS, Let's Encrypt certs, Cloudflare Tunnel | ❌ | real domain + tunnel (see 03) |

---

## 🧭 Navigation

► **[Next: 03 — What doesn't work](03-what-doesnt.md)**

◄ **[Back: 01 — Step-by-step plan](01-plan.md)** · [Back: 01 E2E Validation](README.md) · [🏠 Repo home](../../README.md)
