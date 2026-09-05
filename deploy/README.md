# 📦 deploy/

Kubernetes manifests & Helm values organized to match the documentation sections. This folder is also the seed for the **GitOps** structure (base/overlays) once you adopt ArgoCD — see [`docs/07-iac-gitops`](../docs/07-iac-gitops/README.md).

```
deploy/
├── cloudflared/    → the tunnel pod (docs/02-setup/02)
├── hello/          → the first routed app (docs/02-setup/03)
├── apps/           → your real APIs + shared middleware (docs/03-services/01)
├── storage/        → MinIO (docs/03-services/02)
├── auth/           → Keycloak + forwardAuth middleware (docs/03-services/03, docs/04-security/01)
├── secrets/        → Vault (docs/03-services/04)
├── registry/       → Harbor/Gitea (docs/03-services/05)
├── serverless/     → OpenFaaS (docs/03-services/06)
├── security/       → NetworkPolicies (docs/04-security/03)
├── observability/  → Grafana, Prometheus, Loki, Promtail (docs/05-observability)
├── gitops/         → ArgoCD App-of-Apps (docs/07-iac-gitops/02)
├── secrets/        → SOPS-encrypted Secrets (docs/07-iac-gitops/03)
└── .git-private/   → (gitignored) imperative Secret files, never committed
```

---

## Convention

| File | Kind |
|------|------|
| `00-namespace.yaml` | Namespace (unless shared) |
| `00-configmap.yaml` | ConfigMap |
| `00-secret.yaml` | Secret (**demo values only** — real ones live in `.git-private` or Vault) |
| `01-deployment.yaml` / `01-statefulset.yaml` | workload |
| `02-service.yaml` | Service |
| `03-ingressroute.yaml` | Traefik IngressRoute |
| `*-values.yaml` | Helm values override |

> ⚠️ **Secrets policy:** never commit real values. `deploy/secrets/` holds SOPS-encrypted files; plaintext goes under the `.git-private/` folder which is gitignored. Confirm with `git grep -E '(password|token):' deploy/`.

---

◄ **[Back to repository home](../README.md)**