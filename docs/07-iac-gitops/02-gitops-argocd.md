# 02 — GitOps with ArgoCD

> **Goal:** ArgoCD watches this repository and makes the cluster match it. Deploy = merge a PR. Drift = ArgoCD fixes it. Rollback = `git revert`. This is your **CodeDeploy/CodePipeline** equivalent and the single most "production" move in the project.

---

## 1. Install ArgoCD

```bash
kubectl create ns gitops
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argocd/argo-cd \
  -n gitops \
  -f deploy/gitops/argocd-values.yaml
```
`deploy/gitops/argocd-values.yaml` (in repo) — key settings:
```yaml
server:
  service:
    type: ClusterIP
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: traefik
    hostname: gitops.mycloud.com
configs:
  params:
    server.insecure: true    # behind Cloudflare edge TLS
```

Get the admin password:
```bash
kubectl -n gitops get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```
Login UI at `https://gitops.mycloud.com/`.

> 🔐 **Protect it:** `gitops.mycloud.com` should be behind Cloudflare Access — it's the most powerful console in the cloud.

---

## 2. Point ArgoCD at this repo (the "pull" contract)

```yaml
# deploy/gitops/app-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: home-cloud
  namespace: gitops
spec:
  project: default
  source:
    repoURL: https://github.com/Franck-Sorel/home-cloud.git
    path: deploy/overlays/prod       # the folder of prod manifests (see repo layout)
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: apps                   # or per-app Applications
  syncPolicy:
    automated:
      prune: true                     # delete what drifts out of git
      selfHeal: true                  # fix drift immediately
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f deploy/gitops/app-project.yaml
```

Now: **every push to `main` under `deploy/overlays/prod` is applied to the cluster** automatically. A stray `kubectl apply -f` by hand gets reverted (drift). That's GitOps.

---

## 3. The release flow (demo for recruiters)

```
feature branch → PR → CI (lint + build + test + smoke) → merge to main
                                                        │
                                ArgoCD detects change ──┤
                                                        ▼
                                        cluster reconciles, rollout, healthy
```

- **Review** happens before merge → governance built in.
- **Rollback** = `git revert` / `git checkout previous` → ArgoCD syncs back.
- **Every state change is in git history** — auditable.

---

## 4. Organizing the repo for GitOps

```
deploy/
├── base/                    # reusable, env-agnostic manifests/Helm values
│   ├── apps/
│   └── services/
├── overlays/
│   └── prod/                # the environment ArgoCD watches (knobs applied here)
│       ├── kustomization.yaml
│       └── applications.yaml
└── gitops/                  # the ArgoCD Applications themselves
```
Use **Kustomize** (built into kubectl) or **Helm** for templating; ArgoCD supports both natively. Keep the live cluster's exact rendered state in `overlays/prod` so `git diff` on `main` == cluster diff.

---

## 5. CI/CD bridge (GitHub Actions)

```yaml
# .github/workflows/release.yaml
on:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build & push image
        run: |
          docker build -t registry.mycloud.com/library/sample-api:${GITHUB_SHA::7} examples/sample-api
          docker push registry.mycloud.com/library/sample-api:${GITHUB_SHA::7}
      - name: Tag image in k8s manifests (GitOps handoff)
        run: |
          # update deploy/overlays/prod to the new image tag, commit, push
```
Merge → image built & tagged → manifest updated in git → **ArgoCD rolls the cluster**. End-to-end CI/CD with a one-line rollback. That's the "CodePipeline" story.

---

## 6. Portfolio one-liner

> *"Deploys are PRs: GitHub Actions builds and tags images, ArgoCD continuously reconciles the cluster from this repo with self-heal + prune, and rollback is a git revert. My platform is fully GitOps."*

---

## 🔗 Continue reading

► **[Next: 03 — Secrets in git (SOPS / Sealed Secrets)](03-secrets-in-git.md)**

◄ **[Back to 07 IaC & GitOps index](README.md)** · [🏠 Repo home](../../README.md)