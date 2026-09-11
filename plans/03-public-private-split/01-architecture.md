# 🔀 01 — Architecture: Public Wrap / Private Deploy

> **Who this is for:** the maintainer who wants the clean mechanism before any
> command runs. This page pins down the exact roles, the seam, and how versions
> and secrets stay out of the public repo.

---

## 1. The two roles

| Repo | Role | Owns |
|------|------|------|
| **Public** `home-cloud` (this) | Guidance + **wrap** | docs, glossary, nav, the public bundle *charts* (Namespace + IngressRoute + Middleware + values + contract), `scripts`/`justfile`, `validate` CI + **glue** e2e, plans, LICENSE |
| **Private** `private-home-cloud` | Deploy + real logic | `versions.lock`, virtualization foundation (`lxd/`), the real workload charts (`charts/minio`, `charts/vault`, …), SOPS secrets, private Dockerfiles/images, the private CI that installs + smoke-tests everything on the real cluster |

Public = **"how it is shaped"** and the wrappers. Private = **"what actually runs,
in exactly which version, with my credentials."**

---

## 2. The seam: a version-agnostic **Contract** per bundle

The ONLY thing the two repos must agree on per bundle — and the only public artifact
the private repo must satisfy — is a small contract. Contracts are **frozen** and
**never renamed**, so the private charts can target them without ever touching public.

### Contract table (frozen from the current public wraps)

| Bundle | Namespace | Public service contract (name:port) | Middleware / extras |
|--------|-----------|-------------------------------------|---------------------|
| base | `apps` | `hello:80` → targetPort `8080` (real, public) | `security-headers` + `security-limits` (in `apps`) |
| auth | `auth` | `keycloak:{{ .Values.keycloak.apiPort }}` (8080) | `protected-gate` → `oauth2-proxy.auth.svc:80` (in `apps`) |
| storage | `storage` | `minio:{{ .Values.minio.apiPort }}` (9000) · `minio-console:{{ .Values.minio.consolePort }}` (9001) | — |
| secrets | `secrets` | `vault:{{ .Values.vault.port }}` (8200) | — |
| serverless | `serverless` | `gateway:{{ .Values.openfaas.gatewayPort }}` (8080) | — |
| registry | `registry` | `harbor-portal:{{ .Values.harbor.corePort }}` (80) | — |
| observability | `monitoring` | `grafana:{{ .Values.stack.grafanaPort }}` (80) | — |
| security | (applies to namespaces list) | NetworkPolicies incl. `allow-ingress-from-traefik` | — |

> The ports above are **templated from the public `values.yaml`**. The default values
> are shown in parentheses; the private chart must satisfy the **resolved** name/port.

### The seam mechanism (NO umbrella chart)

For each bundle there are exactly **two independent installs**, joined only by the contract:

```
PUBLIC wrap            PRIVATE workload
(public repo)          (private repo)
─────────────────      ─────────────────────────────
Namespace              Deployment / StatefulSet
IngressRoute ──name──► Service (same name:port) ◄── PVC
Middleware             init Job (bucket / realm / …)
config / values        exact-version images + SOPS secrets
```

1. **Public wrap install:** `just deploy base storage …`
   → creates Namespace, IngressRoute (pointing at the contract `Service` by name),
     Middleware, public ConfigMaps/values. **Never creates the workload.**
2. **Private workload install:** `just deploy-minio`, `just deploy-vault`, …
   → in the **same namespace**, creates the real `Deployment`/`StatefulSet` + `PVC`
     + the **exact `Service` (name/port)** the contract expects, with pinned images
     and SOPS-decrypted secrets.

The two installs are independent and idempotent; the end state is identical in either
order (the wrap creates the Namespace/IngressRoute/Middleware but **not** the Service; the
private workload chart creates the Service **and** the workload together via Helm). We
recommend installing the wrap **first** so the Namespace and IngressRoute exist to receive
traffic the moment the Service appears — but this is a convenience, not a dependency. A
thin connector (a `just` recipe or 3-line script) runs them in order; it is **not** an
umbrella chart.

> **"No umbrella chart" is scoped to the cross-repo seam**: there is no single chart that
> spans both repos (that would couple public to private). The **public** repo still ships
> its own `bundles/home-cloud` aggregator to enable public wraps — that's a separate,
> public-only concern and does not violate this rule.

---

## 3. Version policy (how "software versions are hidden")

- **Public** gives **generic** guidance: "install current stable k3s", "use the latest
  Traefik v3 chart", "log in to your registry" — never a concrete locked version.
- **Private** owns `versions.lock` and pins EVERY engine/image:
  `k3s 1.36.x+k3s1`, `cloudflared <y>`, `traefik chart v<z>`, `minio image <tag>`,
  `keycloak <tag>`, `vault <tag>`, `harbor <tag>`, `kube-prometheus-stack <ver>`,
  `loki <ver>`, `openfaas <ver>`.
- Public CI still exercises things, but against **"current stable"** inputs, asserting
  *correctness* not a particular build. The e2e's concrete k3s/cloudflared/chart
  versions are treated as *CI-only, non-authoritative* and are **removed last** (M7).

---

## 4. Secrets policy

- Public: placeholders only (`token: ""`, `password: CHANGE-ME`) — no real values.
- Private: real values in SOPS/age-encrypted files under `secrets/` (`.sops.yaml` with
  the private age key). Service-account/probe credentials live in Vault at runtime.
- The private age **secret key** exists only on your machine/private CI — never public.

---

## 5. CI split

| Workflow | Repo | Proves |
|----------|------|--------|
| `validate` | public | static accuracy of wraps + scripts + terraform (generic versions) |
| `e2e` (glue) | public | wraps install on a generic k3s; `hello` serves; namespaces/ingress/middleware exist |
| `e2e-private` | private | on the **LXD k3s**, installs the REAL workloads + runs service smokes (`mc ls`, `vault status`, Keycloak token, Grafana health, Harbor push/pull, OpenFaaS invoke) |

The private CI is where each bundle is **actually proven functional**, and its output
never appears in the public repo.

---

## Navigation

► **[Next: 02 — Full inventory](02-inventory.md)** · ◄ [Back to README](README.md)
