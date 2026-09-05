# 03 — Keycloak (IAM / Cognito equivalent)

> **Goal:** Deploy **Keycloak**, your **IAM** (identity & access) service — SSO, OIDC, MFA, user management — reachable at `auth.mycloud.com`. In the next section it becomes the auth gate in front of every other service.

---

## 1. What you get

| AWS | Self-hosted | Notes |
|-----|-------------|-------|
| IAM (identities, roles, policies) | **Keycloak** (or Authentik) | OIDC/SAML provider; SSO, MFA, social login, user federation |

It is the "control plane" of who-is-who in your cloud. Everything else authenticates against it.

---

## 2. Deploy

### Via Helm (recommended)
```bash
kubectl create ns auth
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo update
helm install keycloak codecentric/keycloak \
  -n auth \
  -f deploy/auth/keycloak-values.yaml
```
`deploy/auth/keycloak-values.yaml` (in repo) — key settings:
```yaml
resources:
  requests: { cpu: 200m, memory: 512Mi }
  limits:   { cpu: 1,   memory: 2Gi }
replicas: 1
extraEnv: |
  - name: PROXY_ADDRESS_FORWARDING
    value: "true"              # because Cloudflare/Traefik proxy terminates TLS
  - name: KEYCLOAK_USER
    value: admin
  - name: KEYCLOAK_PASSWORD
    valueFrom:
      secretKeyRef: { name: keycloak-credentials, key: password }
  - name: DB_VENDOR
    value: H2                 # switch to Postgres in `08-roadmap` for production realism
persistence:
  deployPostgres: false       # start simple: embedded H2, or set true for Postgres
  dbName: keycloak
service:
  type: ClusterIP
  port: 8080
```
> H2 is fine for demo; a real deployment should use Postgres + Vault-issued creds (`08-roadmap`, `04-security`).

### Post-install: create the admin user
```bash
kubectl get secret keycloak-credentials -n auth -o jsonpath='{.data.password}' | base64 -d
```

---

## 3. Route it through Traefik

`deploy/auth/keycloak-ingressroute.yaml`:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: keycloak
  namespace: auth
spec:
  entryPoints: [ web ]
  routes:
    - match: Host(`auth.mycloud.com`)
      kind: Rule
      middlewares:
        - name: security-and-limits
          namespace: apps
      services:
        - name: keycloak
          port: 8080
```

Verify:
```bash
kubectl rollout status deploy/keycloak -n auth
curl -I https://auth.mycloud.com/realms/master/.well-known/openid-configuration
```

✅ The discovery document JSON = Keycloak is alive and reachable publicly.

---

## 4. Create an SSO client (the IAM-as-a-service bit)

In the Keycloak admin console (https://auth.mycloud.com):

1. **Realm** → create one (or use `master`).
2. **Clients** → create a new client, e.g. `myapi`.
   - Access Type: `confidential` (or `public` for SPAs)
   - Valid redirect URIs: `https://api.mycloud.com/*`
   - Standard flow: ✅
3. **Roles** → add `reader`, `admin` (your "IAM policies").
4. **Users** → create a test user, set a password (with temporary flag off).

> This is literally "Cognito user pool + client": users authenticate, get JWTs, and your apps validate them.

---

## 5. Protect another service with Keycloak (forward-auth)

The pattern: **Traefik forwardAuth middleware → Keycloak OIDC** before traffic reaches any protected service.

`deploy/auth/middleware.yaml` (conceptual — see repo for full):
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: forwardauth-keycloak
  namespace: apps
spec:
  forwardAuth:
    address: https://auth.mycloud.com/realms/master/protocol/openid-connect/token
    trustForwardHeader: true
    authResponseHeaders:
      - Authorization
      - X-Auth-Email
```
Attach it to the `IngressRoute` of a service you want SSO-protected:

```yaml
middlewares:
  - name: forwardauth-keycloak
    namespace: apps
```

Now `https://<service>.mycloud.com/**` redirects to Keycloak for login, and requires a valid SSO session/JWT. **That is your IAM enforcement point at the gateway** — the API-Gateway-requires-auth behavior from AWS.

> ⚙️ For JWT validation *at the app level* (not just gateway), apps can verify Keycloak-issued JWTs via the discovery endpoint + your public realm key — detailed in [`04-security/01-authentication.md`](../04-security/01-authentication.md).

---

## 6. Hardening reminders

- [ ] Change default admin password immediately (or first-boot flow)
- [ ] Use a dedicated realm, not `master`, for your apps
- [ ] Force **MFA** (TOTP) on the admin realm / sensitive clients
- [ ] Enable brute-force detection (Realm Settings → Security Defenses)
- [ ] Restrict admin console to internal-only or behind Cloudflare Access
- [ ] Later: migrate H2 → Postgres, Vault-managed DB creds

---

## 7. Troubleshooting quick sheet

| Symptom | Fix |
|---------|-----|
| `auth.mycloud.com` blank / 502 | rollout not done; `kubectl logs -n auth deploy/keycloak` |
| Login page TLS warning | Proxy forwarding env missing → `PROXY_ADDRESS_FORWARDING=true` |
| Client's redirect loop | Valid Redirect URI must match exactly; use `https://`, no trailing slashes mismatch |
| JWT rejected by API | app must check `iss` = `https://auth.mycloud.com/realms/<realm>` |

---

## 8. Portfolio one-liner

> *"Keycloak is my IAM/Cognito equivalent: a self-hosted OIDC identity provider with realms, clients, roles and MFA, and Traefik forward-auth enforces SSO at the gateway before any public service is reached."*

---

## 🔗 Continue reading

► **[Next: 04 — Vault (Secrets Manager)](04-vault-secrets.md)**

◄ **[Back to 03 Services index](README.md)** · [🏠 Repo home](../../README.md)