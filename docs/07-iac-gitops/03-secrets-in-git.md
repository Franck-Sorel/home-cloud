# 03 — Secrets in git (SOPS / Sealed Secrets)

> **Goal:** Keep the "single source of truth = this public repo" while never leaking a real secret. Two battle-tested tools do this; pick one.

---

## 1. The problem

GitOps says everything lives in git. But `apiVersion: v1, kind: Secret` in a git repo is **base64, not encryption** — public repo = anyone can read your passwords. Solution: encrypt secrets *before* commit, decrypt *at deploy time* only.

---

## 2. The two tools

| Tool | How it works | Best if |
|------|--------------|---------|
| **SOPS** (Mozilla) | Encrypts the *values* (or whole file) with **age keys**, GCP/KMS/AWS-KMS | you want simple, hermetic, provider-light; Age keys fit a laptop |
| **Sealed Secrets** (Bitnami) | Controller in-cluster holds the decrypt key; `kubeseal` produces a public-key-encrypted `SealedSecret` | you want the key to *never exist outside the cluster* |

**Recommendation for this project:** SOPS + Age — simple, no in-cluster controller, keys managed in your password manager; ArgoCD supports SOPS decryption natively (a big reason).

---

## 3. SOPS + Age walkthrough

```bash
# 1. generate an age key (store in password manager, NOT in git)
age-keygen -o ~/.config/sops/age/keys.txt

# 2. an example secret file (never commit RAW)
cat > deploy/secrets/myapi.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: myapi-secret
  namespace: apps
type: Opaque
stringData:
  API_TOKEN: super-secret-value
EOF

# 3. encrypt it
sops --age $(cat ~/.config/sops/age/keys.txt | grep public | cut -d: -f2) \
     --encrypt --encrypted-regex '^(data|stringData)$' \
     deploy/secrets/myapi.yaml > deploy/secrets/myapi.yaml
# file now holds: sops: { age: [ public key ] }, encrypted values

# 4. decrypt safely on deploy (ArgoCD does this automatically with sops gpg/age plugin)
sops --decrypt deploy/secrets/myapi.yaml | kubectl apply -f -
```

**Verify what's committed:**
```bash
git grep -E '(password|token|secret):' -- deploy/secrets   # should be quiet (encrypted)
```

> 🔐 Add `sops_age_key: <public-age-key>` to your repo's `.sops.yaml` so ArgoCD knows the encryption config. The **private** age key lives only in your password manager / secret manager — never in git.

---

## 4. ArgoCD integration

```yaml
# deploy/gitops/argocd-cm.yaml (patch)
data:
  kustomize.buildOptions: ""
  sops:
    age:
      # the private key is provided to ArgoCD at install via a k8s Secret,
      # or injected from your secret manager (SOPS native support in ArgoCD ≥2)
```

> Read the ArgoCD "SOPS integration" docs in the repo's `deploy/gitops/README.md`. The pattern: ArgoCD's repo-server *decrypts* SOPS files with the age secret at sync time, then applies real k8s Secrets. Nothing plaintext ever lands in git.

---

## 5. Hygiene checklist

- [ ] No `*.yaml` under `deploy/` containing plaintext secret values (a grep guard in CI enforces it)
- [ ] `.gitignore` ignores `*.tfvars`, `keys.txt`, `.age`, `*.key`
- [ ] sops private key not in repo (only public encryption key config)
- [ ] Rotate after any key exposure (password manager history)

---

## 6. Portfolio one-liner

> *"Secrets are committed encrypted with SOPS+Age; the private key never touches git, and ArgoCD decrypts at sync time. A fully GitOps platform that keeps a public repo — without ever leaking a credential."*

---

## 🔗 Continue reading

► **[Next section: 🗺️ 08 — Roadmap](../08-roadmap/README.md)**

◄ **[Back to 07 IaC & GitOps index](README.md)** · [🏠 Repo home](../../README.md)