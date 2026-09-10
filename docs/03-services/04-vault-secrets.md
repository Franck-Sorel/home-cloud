# 04 — Vault (Secrets Manager / KMS equivalent)

> **Goal:** Deploy **HashiCorp Vault** — your **Secrets Manager** — so apps receive *dynamic, short-lived, revoked-after-use* credentials instead of long-lived ones. Reachable at `secrets.mycloud.com`.

---

## 1. What you get

| AWS | Self-hosted | Notes |
|-----|-------------|-------|
| Secrets Manager / KMS | **HashiCorp Vault** | static secrets, **dynamic** secrets (DB/cloud creds on request, lease-limited), encryption-as-a-service (transit), auto-unseal later |

The *killer* feature over a plain k8s Secret: **secrets are issued on demand with leases** — they expire, rotate, and can be revoked centrally.

---

## 2. Deploy

### Via the official Helm chart

```bash
kubectl create ns secrets
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
  -n secrets \
  --set server.ha.enabled=false \
  --set server.standalone.enabled=true \
  --set server.dataStorage.enabled=true \
  --set server.dataStorage.size=5Gi \
  --set server.dataStorage.storageClass=local-path \
  --set global.externalVaultAddr="https://secrets.mycloud.com"
```

> ⚠️ **Vault is sealed by default** and needs `init` + `unseal` tokens — without them the API returns `503`. The steps below are the "unsealing dance" — think of it as *initial provisioning* (your KMS root key ceremony).

---

## 3. Initialize & unseal (the "root key ceremony")

```bash
# exec into the vault pod
kubectl exec -n secrets vault-0 -- vault operator init -key-shares=1 -key-threshold=1
```

- This prints **1 unseal key** and **1 root token** — **store them in a password manager**. Never in git.

```bash
# unseal with the key (repeat: you chose 1-share for home convenience; 3/5 for real prod)
kubectl exec -n secrets vault-0 -- vault operator unseal <unseal-key>

# login with root token
kubectl exec -n secrets vault-0 -- vault login <root-token>
```

> ⏩ Production-like: 5 key shares, threshold 3; auto-unseal via Cloudflare KMS not needed at home. For HA/auto-unseal, roadmap note: use `server.ha.enabled=true` + raft storage + auto-unseal.

---

## 4. Route through Traefik

`deploy/secrets/vault-ingressroute.yaml`:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: vault
  namespace: secrets
spec:
  entryPoints: [ web ]
  routes:
    - match: Host(`secrets.mycloud.com`)
      kind: Rule
      middlewares:
        - name: security-and-limits
          namespace: apps
      services:
        - name: vault
          port: 8200
```

Verify:
```bash
kubectl rollout status statefulset/vault -n secrets
curl -s https://secrets.mycloud.com/v1/sys/health | jq
# { "initialized": true, "sealed": false, "standby": true, "version": "1.x" }
```

---

## 5. Give apps dynamic secrets (the real-world value)

Enable a KV store + a DB engine, then issue short-lived secrets:

```bash
# enable KV v2
kubectl exec -n secrets vault-0 -- vault secrets enable -version=2 kv

# write a static secret
kubectl exec -n secrets vault-0 -- vault kv put kv/myapi TOKEN=$(openssl rand -hex 24)
```

Enable a **database dynamic secret** engine (e.g. for your Postgres from `08-roadmap`):

```bash
kubectl exec -n secrets vault-0 -- vault secrets enable database
kubectl exec -n secrets vault-0 -- vault write database/config/myapp-db \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://vault:{{username}}:vault:{{password}}@postgres.db.svc:5432/app?sslmode=disable" \
  allowed_roles="app" root_rotation_statements="ALTER ROLE \"{{name}}\" WITH PASSWORD '{{password}}'"
kubectl exec -n secrets vault-0 -- vault write database/roles/app \
  db_name=myapp-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'" \
  default_ttl="1h" max_ttl="24h"
```

Now the app can `vault read database/creds/app` → **fresh credentials that stop working after 1h**. That is Secrets Manager parity, minus the AWS console.

---

## 6. Kubernetes auth for apps (the modern pattern)

Instead of root tokens in pods, bind pod ServiceAccounts to Vault roles:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapi
  namespace: apps
---
# (vault policy + role created via `vault write auth/kubernetes/role/myapi ...`)
```
Then your app uses Vault Agent/`vault-k8s` sidecar to fetch secrets with **auto-rotation**. Reference: [`deploy/`](../../deploy/), and full guide in [`04-security/02-rbac-and-secrets.md`](../04-security/02-rbac-and-secrets.md).

---

## 7. Hardening reminders

- [ ] Store unseal keys + root token in a password manager (KeePass/Bitwarden/1Password)
- [ ] **Threat: single key-share** is home-convenience; 3/5 for any real production claim
- [ ] Restrict `secrets.mycloud.com` behind Keycloak/Cloudflare Access (don't expose the UI publicly if avoidable)
- [ ] Use `-policy=` smallest needed on every Vault role
- [ ] Later: enable TLS with your `cert-manager` inside the cluster

---

## 8. Troubleshooting quick sheet

| Symptom | Fix |
|---------|-----|
| `503` / `sealed` | run the unseal steps; verify with `/v1/sys/health` |
| `permission denied` | login/role missing or wrong policy |
| Health shows `sealed: false` but init needed | you wiped storage; re-init (see `06-testing/04-backup-restore.md`) |
| Apps can't connect | `global.externalVaultAddr` must match the public URL apps use |

---

## 9. Portfolio one-liner

> *"Vault issues short-lived dynamic credentials to my workloads via Kubernetes auth and leases — my self-hosted Secrets Manager. Unseal keys are kept out of git and stored in a password manager."*

---

## 🔗 Continue reading

► **[Next: 05 — Container registry](05-registry.md)**

◄ **[Back to 03 Services index](README.md)** · [🏠 Repo home](../../README.md)