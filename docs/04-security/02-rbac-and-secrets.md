# 02 — RBAC & secrets

> **Goal:** Least-privilege everywhere: what a ServiceAccount can do in the cluster is exactly enough — and secrets are either Vault-issued or, when in k8s, tightly scoped, never plaintext in git.

---

## 1. RBAC in one screen

Kubernetes authorizes requests through:

| Object | Answers |
|--------|---------|
| **Role / ClusterRole** | *what permissions?* (`get pods`, `create deployments`, …) |
| **RoleBinding / ClusterRoleBinding** | *who gets them?* (user, group, or **ServiceAccount**) |
| **ServiceAccount** | the identity a pod runs as |

> The mental model: **ServiceAccount = your IAM-role bound to a pod**. `kubectl auth whoami` tells you who's acting.

---

## 2. Least-privilege ServiceAccounts (pattern)

Every deployment gets its *own* SA with *only* what it needs:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapi
  namespace: apps
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: myapi-reader
  namespace: apps
rules:
  - apiGroups: [""]
    resources: ["pods","services","endpoints"]
    verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myapi-reader
  namespace: apps
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: myapi-reader
subjects:
  - kind: ServiceAccount
    name: myapi
    namespace: apps
```

Then in the pod spec:
```yaml
spec:
  serviceAccountName: myapi
```

**Anti-pattern to avoid:** the default SA in the `default` namespace often has broad perms via legacy bindings; don't rely on it, and never grant `ClusterRole: cluster-admin` to apps.

---

## 3. Secrets — the healthy hierarchy

| Worse ⇢ ⇢ ⇢ Better | Example |
|---------------------|---------|
| 🔴 Plaintext secret in git | `password: hunter2` in a yaml |
| 🟠 K8s Secret `Opaque` (base64 = not encryption) | the `myapi-secret` we created in `03-services/01` — fine for *demo only* |
| 🟡 K8s Secret + **restricted access** | RBAC, no `env` exposure to unrelated pods; `encryption at rest` via k3s |
| 🟢 **Vault** dynamic secrets / KV | short-lived creds, no static values in cluster at all |
| 🟣 **SOPS / Sealed Secrets** in git | encrypted blobs in the repo; decrypted at deploy-time by Flux/ArgoCD |

**Our policy for this repo:**
1. No real secrets committed anywhere (`.gitignore` guards).
2. Demo values only with `change-me` labels.
3. Real deployments read from **Vault** (dynamic) or **k8s Secrets** created at deploy time via `kubectl create secret` (not git).
4. When GitOps (**section 07**) arrives, adopt SOPS/Sealed Secrets for git-safe storage.

---

## 4. Secrets in Kubernetes — do's and don'ts

```bash
# DO: create from literal at deploy time
kubectl create secret generic minio-creds \
  --from-literal=access-key=ABC --from-literal=secret-key=XYZ -n storage

# DO: mount as files not env when possible (env vars leak into /proc, dashboards, logs)
# DON'T: commit the above values
# DON'T: use the same secret broadly; scope per service
```

> 🔐 Note: `kubectl get secret -o yaml` shows base64 — anyone with cluster read can see it. That's why **Vault for the real stuff** and strict RBAC on `secrets` list/get.

---

## 5. Vault integration for the real apps

From [`03-services/04-vault-secrets.md`](../03-services/04-vault-secrets.md), the production-ready flow:

```
pod → ServiceAccount (k8s) → Vault kubernetes-auth → role → short-lived DB creds (1h lease)
```

Setup recap (files in `deploy/vault/`):
- Enable `auth/kubernetes`, configure with your K8s API + SA JWT
- Write a Vault **policy** (least-needed read paths)
- Create **role** `mynotes-db` bound to SA `mynotes`
- App uses `vault read database/creds/mynotes-db` (or Vault Agent sidecar)

Result: **no long-lived DB password exists anywhere** — rotated hourly, revocable instantly.

---

## 6. Verify your posture (hands-on checks)

```bash
# who am I / can I
kubectl auth whoami
kubectl auth can-i --list -n apps | head -20

# SA bindings — too broad?
kubectl get rolebindings -A | grep -i cluster-admin

# what secrets exist (should be few, scoped)
kubectl get secrets -A

# where are pods running as root? (flag for hardening)
kubectl get pods -A -o json | jq -r '.items[].spec.containers[].securityContext'
```

Aim: **no `cluster-admin` bindings for app namespaces**, no `default` SA usage, few secrets, no root containers.

---

## 7. Portfolio one-liner

> *"ServiceAccounts map one-to-one to apps, bound to scoped Roles — my IAM policy model. Secrets are short-lived Vault credentials with leases, and nothing real is ever committed to git."*

---

## 🔗 Continue reading

► **[Next: 03 — Network policies](03-network-policies.md)**

◄ **[Back to 04 Security index](README.md)** · [🏠 Repo home](../../README.md)