# 05 — Container registry (ECR equivalent: Harbor or Gitea)

> **Goal:** Run your own **ECR** — a place to push the images you build — then pull from it inside the cluster. Two options: **Harbor** (registry + vulnerability scanning) or **Gitea** (registry + Git repo in one).

---

## 1. What you get

| AWS | Self-hosted | Notes |
|-----|-------------|-------|
| ECR | **Harbor** | registry, replication, vulnerability scanning, RBAC |
| ECR (lighter) | **Gitea** | registry (Docker-compatible) **+** Git hosting in one pod |

> For a portfolio that says "I build and ship my own images like a real team," running a private registry is a strong step (it decouples you from Docker Hub limits and hardens supply chain).

---

## 2. Option A — Harbor (full-featured)

```bash
kubectl create ns registry
helm repo add harbor https://helm.goharbor.io
helm repo update
helm install harbor harbor/harbor \
  -n registry \
  -f deploy/registry/harbor-values.yaml
```
`deploy/registry/harbor-values.yaml` (in repo) — key settings:
```yaml
expose:
  type: ingress
  tls.enabled: true
  ## We route via our own Traefik IngressRoute; set ingress controller annotation to traefik
ingress:
  annotations:
    kubernetes.io/ingress.class: traefik
externalURL: https://registry.mycloud.com
persistence.enabled: true
# use: persistence.persistentVolumeClaim.registry.storageClass: local-path
```

Route:
`deploy/registry/harbor-ingressroute.yaml`:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: harbor
  namespace: registry
spec:
  entryPoints: [ web ]
  routes:
    - match: Host(`registry.mycloud.com`)
      kind: Rule
      services:
        - name: harbor
          port: 80
```

Push a test image:
```bash
docker login registry.mycloud.com -u admin -p <Harbor-UI-password>
docker tag nginx:latest registry.mycloud.com/library/nginx:test
docker push registry.mycloud.com/library/nginx:test
```

> Expect to set Harbor's admin password from the chart (`harborAdminPassword`).

---

## 3. Option B — Gitea (registry + git in one)

```bash
kubectl create ns registry
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update
helm install gitea gitea-charts/gitea \
  -n registry \
  --set service.http.port=3000 \
  --set service.ssh.port=22
```
Route: `Host(registry.mycloud.com)` → `gitea:3000`. Gitea comes with a built-in `registry.mycloud.com` Container Registry (Docker-compatible) once enabled.

---

## 4. Secret for pulling images inside the cluster

Any pod in the cluster can pull from the private registry via an `imagePullSecret`:

```yaml
kubectl create secret docker-registry regcred \
  --docker-server=registry.mycloud.com \
  --docker-username=admin \
  --docker-password=<password> -n apps
```
Reference it in the pod spec:
```yaml
spec:
  imagePullSecrets:
    - name: regcred
  containers:
    - name: myapi
      image: registry.mycloud.com/library/myapi:v1
```
(For git ops, so this persistence is used automatically — the config below shows `imagePullSecrets` wired into the Deployment from `03-services/01` example.)

---

## 5. Hardening & best practices

- [ ] Change default admin credentials from chart values
- [ ] Use **project-level RBAC** in Harbor/Gitea (push = developers, pull = CI runners)
- [ ] Enable **content trust / immutable tags** to prevent overwrites (supply-chain hygiene)
- [ ] Point Harbor **scanning** at your images (falls back to a small scanner job pod)
- [ ] In CI (GitHub Actions) use a scoped robot account, not admin

---

## 6. Portfolio one-liner

> *"I run a private container registry (Harbor/Gitea) with project-level RBAC and scanning, and my cluster pulls all its images from it via imagePullSecrets — my ECR equivalent."*

---

## 🔗 Continue reading

► **[Next: 06 — Serverless (OpenFaaS)](06-serverless.md)**

◄ **[Back to 03 Services index](README.md)** · [🏠 Repo home](../../README.md)