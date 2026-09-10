# 🧩 01 — The Bundle Catalog

Each bundle is a small, standalone Helm chart (in `bundles/<name>/`) that
wires a slice of the private cloud. They are the unit of **choice**: pick the
set you want, `just deploy` them, and ignore the rest.

> The heavy third-party workloads (MinIO, Keycloak, Vault, OpenFaaS, Harbor,
> Grafana/Loki) are installed from their **upstream** charts in one command
> (see each bundle's `NOTES.txt`). The bundle itself provides the namespace,
> public IngressRouting, shared middleware and the configuration hooks — so it
> is self-contained and publishable without vendoring huge upstream charts.

---

## The catalog

| Bundle | Chart (`bundles/`) | Deploys / wires | AWS analog | Core manifest(s) |
|--------|--------------------|-----------------|-----------|------------------|
| 🧱 **base** | `base/` | namespaces, shared middleware, hello demo, **DDNS updater** or **cloudflared** | EKS + ALB + CloudFront | `templates/{middleware,hello,ddns|cloudflare}` |
| 🔐 **auth** | `auth/` | `auth` ns, Keycloak route, Traefik **forwardAuth gate** | IAM / Cognito + API GW auth | `templates/protected-gate-middleware.yaml` |
| 💾 **storage** | `storage/` | `storage` ns, MinIO routes (API + console) | S3 | `templates/ingressroute.yaml` |
| 🔑 **secrets** | `secrets/` | `secrets` ns, Vault route | Secrets Manager / KMS | `templates/ingressroute.yaml` |
| 🚀 **serverless** | `serverless/` | `serverless` ns, OpenFaaS gateway route | Lambda | `templates/ingressroute.yaml` |
| 📦 **registry** | `registry/` | `registry` ns, Harbor route | ECR | `templates/ingressroute.yaml` |
| 📈 **observability** | `observability/` | `monitoring` ns, Grafana route | CloudWatch | `templates/ingressroute.yaml` |
| 🛡️ **security** | `security/` | default-deny NetworkPolicies | Security Groups / NACL | `templates/default-deny-*.yaml` |

**Aggregator** `bundles/home-cloud/` — enables any combination (`base` on by
default, everything else opt-in).

---

## How to choose (no reading required)

```bash
# bare minimum — cluster + edge + one demo service on your domain
just deploy base

# a useful home cloud — everything, with hardened isolation
just deploy base auth storage secrets observability security

# "auth only" for an existing cluster
just deploy auth

# same via released packages
helm install auth oci://ghcr.io/Franck-Sorel/home-cloud-auth --version 0.1.0
```

### Suggested profiles

| Profile | Bundles | Result |
|---------|---------|--------|
| **Minimal** | `base` | one public URL, HTTPS, DDNS self-healing |
| **Home cloud** | `base auth storage secrets` | SSO + object storage + dynamic secrets |
| **Developer** | `base registry serverless` | push images, ship functions |
| **Full** | `base auth storage secrets serverless registry observability security` | the whole AWS-parity story |
| **Locked down** | any + `security` | default-deny networking |

---

## Configuring a bundle

Every bundle reads `values.yaml`; overrides via `--set` or `--values`:

```bash
just deploy base domain=cloud.example.com mode=cloudflare

helm install storage oci://ghcr.io/Franck-Sorel/home-cloud-storage \
  --set domain=cloud.example.com --set tls.enabled=false
```

Shared knobs (consistent across bundles):

- `domain` — your public domain
- `tls.enabled` — set `false` when you terminate TLS at the Cloudflare edge
- `mode` (base only) — `ddns` (default) or `cloudflare`, see [02-networking-models](02-networking-models.md)

---

## Secrets you must provide

The bundles **never** hardcode secrets. Each needs a Secret you create:

| Bundle | Secret | Purpose |
|--------|--------|---------|
| base (ddns) | `ddns-credentials` | deSEC token / Dynu user+pass |
| base (cloudflare) | `cloudflared-credentials` | tunnel credentials JSON |
| auth | `oauth2-proxy-credentials` | OIDC client secret |
| auth (keycloak) | `keycloak-admin` | admin password |
| storage (minio) | (via upstream chart) | MinIO root user/pass |

---

## Structure of a bundle

```
bundles/storage/
├── Chart.yaml      # name: home-cloud-storage, version
├── values.yaml     # domain, tls, service host/port — the knobs
└── templates/
    ├── _helpers.tpl     # shared labels + hostname helpers
    ├── namespace.yaml   # the namespace for this capability
    ├── ingressroute.yaml# public Traefik route -> service
    └── NOTES.txt        # step-by-step, incl. the upstream chart install
```

---

► **[Next: Networking models ($0 DDNS vs Cloudflare)](02-networking-models.md)** |
◄ [Back to 09 — Bundles](README.md)
