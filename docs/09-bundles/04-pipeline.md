# 🧪 04 — Accuracy Pipeline & Release

Two promises make this repo usable without reading: **accuracy** (CI proves
every artifact is valid) and **packaging** (each bundle ships as a package you
choose). There are **two CI layers**:

| Workflow | When | Proves |
|----------|------|--------|
| `ci.yml` → `just validate` | every push/PR | **static** accuracy: every chart lints/render, scripts shellcheck-clean, terraform valid |
| `e2e.yml` → boot a real k3s cluster | manual + nightly | **dynamic**: the bundles actually install together and interoperate |

Learn what the real-cluster run proves (and can't) in
[`plans/01-e2e-validation`](../../plans/01-e2e-validation/README.md).

---

## The accuracy pipeline

The single command is `just validate` — and GitHub Actions runs the *same*
suite on every push/PR in `.github/workflows/ci.yml`.

| Check | Tool | Catches |
|-------|------|---------|
| Helm charts lint | `helm lint` | malformed Chart.yaml / values / templates |
| Helm charts render | `helm template` (ddns **and** cloudflare) | Go-template errors, missing values |
| Aggregator resolves | `helm dependency update` + `helm template` | broken bundle wiring |
| Bash scripts | `shellcheck` | unbound vars, unsafe quoting |
| Manifests YAML | `yamllint` | malformed / inconsistent YAML |
| Terraform | `terraform fmt -check` + `validate` | formatting + config errors |
| No hardcoded secrets | `git grep` in CI | committed passwords/tokens |

```bash
just doctor     # check tooling
just lint       # quick helm + shell only
just validate   # full suite  (alias: just v)
```

> `validate.sh` treats missing optional tools (terraform, yamllint) as a
> warning locally, but CI installs them so they are **mandatory** in CI.

---

## Release as packages

Tag `v0.1.0` triggers `.github/workflows/release.yml`:

```
helm package bundles/*  →  dist/home-cloud-<name>-0.1.0.tgz
helm push dist/*.tgz    →  oci://ghcr.io/<owner>/home-cloud-<name>:0.1.0
```

Each bundle becomes an independent OCI Helm chart; the `home-cloud` aggregator
is packaged with its dependencies vendored so it's self-contained.

### For users (the payoff)

```bash
# from a released bundle — no git, no docs:
helm install base    oci://ghcr.io/Franck-Sorel/home-cloud-base    --version 0.1.0
helm install auth    oci://ghcr.io/Franck-Sorel/home-cloud-auth    --version 0.1.0
helm install storage oci://ghcr.io/Franck-Sorel/home-cloud-storage --version 0.1.0

# or the whole thing, choosing with flags:
helm install home-cloud oci://ghcr.io/Franck-Sorel/home-cloud  --version 0.1.0 \
  --set auth.enabled=true --set storage.enabled=true
```

### From this repo (fresh from main)

```bash
just deps      # vendor aggregator subcharts
just package   # build dist/*.tgz
just publish   # login-wrapped: helm push to ghcr.io
```

---

## Maintenance rules

- **Never** break `just validate`. Fix the check, not the symptom.
- Keep charts **lintable offline** — the heavy services stay as documented
  upstream installs (see `NOTES.txt`), so packaging doesn't need the internet.
- Secrets stay in gitignored files / Vault / SOPS — never in a chart.

---

◄ [Back to 09 — Bundles](README.md)
