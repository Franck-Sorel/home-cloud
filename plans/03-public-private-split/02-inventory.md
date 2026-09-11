# 🔀 02 — Full inventory: what stays public vs. what goes private

> **Who this is for:** the person executing the move. This is the exhaustive,
> file-level list, so nothing is left ambiguous during migration. Two rules
> govern everything: **(1) never rename an existing public contract** (namespace /
> Service / ingress / middleware names stay byte-identical); **(2) the public
> repo's `validate` + glue `e2e` stay green at all times.**

---

## A. Stays in THIS public repo (unchanged in purpose)

| Path | Note |
|------|------|
| `README.md` | guidance hub (badge version genericized later, M7) |
| `docs/` (00–09) + `docs/GLOSSARY.md` | concepts, networking, bundles, pipeline, glossary |
| `plans/01-e2e-validation` | public **glue** proof (version hints removed at M7) |
| `plans/02-virtualization-layer` | concept reference; **the corrected bring-up lives in private** |
| `plans/03-*` (this) | the migration plan |
| `bundles/base/` | stays **real** (hello + middleware + DDNS/cloudflared connector). Public demo. |
| `bundles/security/` | stays **real** (NetworkPolicies incl. `allow-ingress-from-traefik`) |
| `bundles/{auth,storage,secrets,serverless,registry,observability}/` | become / stay **pure wraps**: `Namespace`, `IngressRoute`, `Middleware` (auth), `values`, `NOTES.txt` (now documents the contract, not a workload) |
| `bundles/home-cloud/` | aggregator of wraps (unchanged; still enables by `condition`) |
| `scripts/*.sh`, `justfile` | wrap-level helpers. `deploy` = install wraps |
| `.github/workflows/ci.yml` + `e2e.yml` | `validate` + public **glue** e2e (generic versions) |
| `terraform/cloudflare/` | edge as code (public) |
| `.yamllint.yml`, `.gitignore`, `LICENSE` | unchanged |

**Boundary:** any public file that *pins a concrete private engine version* is flagged
in the remediation list (§D) and handled at **M7** — not before.

---

## B. Created in the PRIVATE repo (`private-home-cloud`)

```
private-home-cloud/
├── README.md                  # pointers + how to operate the machine
├── versions.lock              # THE authoritative exact engine+image versions
├── .sops.yaml                 # age public key + creation rules
├── lxd/                       # virtualization foundation (corrected bring-up)
│   ├── bring-up.sh            # snap 5.21/stable, lxd init, project, profiles, launch
│   ├── profiles/{dc-base,server,worker,dns}.yml
│   ├── teardown.sh            # stop/start/snapshot/restore helpers
│   └── README.md              # full, corrected commands + verification
├── k3s/
│   ├── server-setup.sh        # get.k3s.io, version from versions.lock, --disable traefik
│   └── join-worker.sh
├── charts/                    # REAL workload charts (meet the public contracts)
│   ├── minio/                 # StatefulSet + data PVC + Services minio:9000 / minio-console:9001 + bucket init Job
│   ├── vault/                 # Deployment/StatefulSet + vault:8200 (+ HA raft later)
│   ├── keycloak/              # StatefulSet + Postgres + keycloak:8080 + realm/client init
│   ├── oauth2-proxy/          # oauth2-proxy.auth:80 (fulfils auth protected-gate)
│   ├── observability/         # kube-prometheus-stack + loki + grafana:80 + scrape config + datasources
│   ├── harbor/                # core/portal/registry + Postgres + Redis + harbor-portal:80
│   └── openfaas/              # gateway:8080 + faas-netes + openfaas-fn namespace
├── secrets/                   # SOPS/age-encrypted (*.sops.yaml): tokens, passwords, age keys absent
├── justfile                   # just deploy-minio, deploy-vault, … + just dc-up/dc-down
└── .github/workflows/
    └── e2e-private.yml        # on the LXD k3s: install real workloads + run service smokes
```

**Boundary:** the private repo must be self-contained for the workloads it deploys to
meet the public contracts; it should never require editing the public repo.

---

## C. The public→private contract checklist (per bundle)

Each private chart MUST satisfy the frozen contract (from [01 — Architecture](01-architecture.md)):

| Private chart | Must create Service (ns:name:port) |
|---------------|-----------------------------------|
| `minio` | `storage/minio:9000`, `storage/minio-console:9001` |
| `vault` | `secrets/vault:8200` |
| `keycloak` | `auth/keycloak:8080` |
| `oauth2-proxy` | `auth/oauth2-proxy:80` (forwardAuth target) |
| `observability` | `monitoring/grafana:80` |
| `harbor` | `registry/harbor-portal:80` |
| `openfaas` | `serverless/gateway:8080` |
| base/security | already provided publicly — private does **not** recreate |

> If a Service name/port must ever change, change it in **both** repos in the same
> review (this is the one cross-repo coupling, and it's rare).

---

## D. Version-remediation list (handled ONLY at M7 — public side)

Files that pin concrete versions today and must become generic at M7 (or be replaced by
"CI-only, non-authoritative"):

| File | Current pin | M7 action |
|------|-------------|-----------|
| `README.md` | k3s badge `v1.36` | → generic badge text (e.g. "current stable k3s") |
| `.github/workflows/e2e.yml` | k3s `v1.36.3+k3s1` (CI-only; cloudflared is skipped, not pinned) | keep **CI-only** inputs but comment as non-authoritative; or param via input |
| `bundles/base/values.yaml`, `deploy/cloudflared/deployment.yaml` | cloudflared `2026.9.0` | keep image tag as a **default/example**; note "authoritative version in private versions.lock" |
| `terraform/cloudflare/*` | provider `~> 4.0` | generic range is fine (not a service engine) |
| `.github/workflows/ci.yml` + `.github/workflows/release.yml` | helm `v3.15.4`, terraform `1.8.5`, GH-action majors | toolchain pins are CI hygiene, keep |
| `docs/02-setup/01-install-k3s.md` | no pin today (`curl get.k3s.io` → latest stable) | → point reader to "use the version in your private versions.lock" |

**Intent:** after M7, a reader of the public repo can learn the *concepts* but cannot
infer your exact private build or versions.

---

## Navigation

► **[Next: 03 — Milestones](03-milestones.md)** · ◄ [Back to README](README.md)
