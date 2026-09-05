# 🛠️ 03 — Services

> **This section is for the reader who has a running cluster + ingress + tunnel (section 02), and now wants to fill it with the "AWS services" the project promises — storage, identity, secrets, registry, serverless.**  
> Follow the docs **in order** the first time; each builds on the routing pattern from `02-setup/03-traefik-ingress.md`.

---

## 📖 What's in this section

| # | Document | You deploy | AWS equiv |
|---|----------|-----------|-----------|
| 01 | [`01-first-service.md`](01-first-service.md) | your own little API (the "hello" pattern made real) | your microservice on EKS/ECS |
| 02 | [`02-minio-s3.md`](02-minio-s3.md) | **MinIO** — S3-compatible object storage | S3 |
| 03 | [`03-keycloak-iam.md`](03-keycloak-iam.md) | **Keycloak** — OIDC/SSO identity | IAM / Cognito |
| 04 | [`04-vault-secrets.md`](04-vault-secrets.md) | **HashiCorp Vault** — secrets management | Secrets Manager / KMS |
| 05 | [`05-registry.md`](05-registry.md) | **Harbor or Gitea** — container image registry (+git) | ECR |
| 06 | [`06-serverless.md`](06-serverless.md) | **OpenFaaS** — serverless functions | Lambda |
| 07 | [`07-app-workshop.md`](07-app-workshop.md) | tie it together: an app that uses MinIO + Keycloak + Vault | a real multi-service app |

> Each doc = **daemonset/deployment + service + ingress + (helm where sensible)**. Files live in [`deploy/`](../../deploy/).

---

## 🔑 The golden pattern (from section 02)

Every service follows the same shape:

```
deployment.yaml   →  pods  (replicas, resources, probes, env from Secrets/ConfigMaps)
service.yaml      →  stable DNS name (svc name.namespace.svc.cluster.local)
ingressroute.yaml →  host(=subdomain).mycloud.com  →  service:<port>  (+ middlewares)
pv/pvc.yaml       →  durable data (local-path → $HOME/k3s-data)
```

## 🏗️ The suggested namespace layout

| Namespace | Purpose |
|-----------|---------|
| `apps` | your APIs, demo apps |
| `storage` | MinIO |
| `auth` | Keycloak |
| `secrets` | Vault |
| `registry` | Harbor/Gitea |
| `serverless` | OpenFaaS |
| `monitoring` | Prometheus + Loki + Grafana (added in section 05) |
| `gitops` | ArgoCD (added in section 07) |

> Namespaces are free. They keep `kubectl get pods -n storage` clean and give you a place for NetworkPolicies later ([`04-security`](../04-security/README.md)).

---

## ⏱️ Time per service

| Service | Time | Notes |
|---------|------|-------|
| first-service | 15 min | pure YAML, no Helm |
| MinIO | 20 min | helm or plain YAML |
| Keycloak | 25 min | helm; needs a PVC + env tweaks |
| Vault | 30 min | helm; unseal + init are the tricky bit |
| Registry | 20 min | harbor via helm or gitea via manifest |
| OpenFaaS | 30 min | helm + `faas-cli` |
| workshop app | 45 min | build your own image; the portfolio centerpiece |

---

## 🔗 Continue reading

► **[Next: 01 — Your first real service](01-first-service.md)**

◄ **[Back to repository home](../../README.md)**

---

## 🧭 Navigation

- [🏠 Repository home](../../README.md)
- [🧠 00 — Understanding](../00-understanding/README.md)
- [💡 01 — Skills](../01-skills/README.md)
- [🚀 02 — Setup](../02-setup/README.md)
- [🛠️ 03 — Services](README.md)
- [🔒 04 — Security](../04-security/README.md)
- [📈 05 — Observability](../05-observability/README.md)
- [🧪 06 — Testing](../06-testing/README.md)
- [♾️ 07 — IaC & GitOps](../07-iac-gitops/README.md)
- [🗺️ 08 — Roadmap](../08-roadmap/README.md)