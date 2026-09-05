# 01 — Authentication (OAuth2 / OIDC with Keycloak)

> **Goal:** Make sure *nothing sensitive is reachable without authentication*. You'll protect services with a gateway-level auth (forward-auth to Keycloak) and understand JWT validation at the app level.

> **Video-first users skip to step 3.** If you just want a protected URL: deploy Keycloak ([`03-services/03`](../03-services/03-keycloak-iam.md)) and attach the forwardAuth middleware below.

---

## 1. The concepts in 2 minutes

- **OAuth2**: the *authorization* protocol — issues tokens (access/refresh).
- **OIDC**: OAuth2 + an `id_token` (identity) — so apps also learn *who* the user is.
- **JWT**: the signed token format (`header.payload.signature`). Validate signature with the provider's public keys (JWKS); read claims (`sub`, `iss`, `aud`, `exp`, `roles`).
- **forwardAuth** (Traefik): Traefik sends a request to Keycloak to validate the session/JWT *before* proxying to your app. If invalid → redirect to login.

---

## 2. Where auth is enforced (defense in depth)

| Layer | Enforces | Typical use |
|-------|----------|-------------|
| **Cloudflare Access (optional)** | Login wall before even reaching the tunnel | admin consoles, Vault UI |
| **Traefik forwardAuth middleware** | Valid SSO session/JWT at the gateway | any public subdomain |
| **App-level JWT validation** | Signature + claims per-route | your APIs (roles/aud) |
| **App-level RBAC** | per-user authorization | feature/route access |

---

## 3. Protect public subdomains with forwardAuth (gateway-level)

### A. Create the middleware
`deploy/auth/forwardauth-middleware.yaml`:
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

### B. Attach to an IngressRoute
```yaml
middlewares:
  - name: forwardauth-keycloak
    namespace: apps
```

### C. Test
```bash
curl -I https://grafana.mycloud.com/          # 302 → auth.mycloud.com (no session)
# (login in browser) →
curl -s https://grafana.mycloud.com/api/health # works with session cookie
```

> ⚙️ For the *gotchas* (valid session cookie vs JWT-only APIs, basic-auth variants, custom headers), see the repo notes in `deploy/auth/README.md`.

---

## 4. App-level JWT validation (for your APIs)

Any service (your `mynotes-api` from `03-services/07`) validates JWTs like this:

```js
// node — using jose
import { createRemoteJWKSet, jwtVerify } from 'jose'
const jwks = createRemoteJWKSet(new URL('https://auth.mycloud.com/realms/mynotes/protocol/openid-connect/certs'))
const { payload } = await jwtVerify(token, jwks, { issuer: 'https://auth.mycloud.com/realms/mynotes', audience: 'mynotes-api' })
// payload.roles → ['owner']  → enforce in route handlers
```

Key claims you enforce:
- `iss`: exactly your realm URL (prevents token-swapping from other issuers)
- `aud`: your client id (prevents one app using another's token)
- `exp`: never trust an unexpired-looking-but-unsigned token — signature must verify first
- `azp`/`roles`: authorization

> Full example in `examples/mynotes-app/api/`.

---

## 5. MFA (the "IAM-grade" touch)

In Keycloak admin console → your realm → **Authentication**:

- Turn on **TOTP** (Required/Alternative) for users
- Add **WebAuthn** (passkeys) as an alternative
- In **Brute Force Detection**: enable + set thresholds

> 💡 You can even require admin realm-users to be MFA-only — a real IAM admin policy.

---

## 6. Common pitfalls

| Pitfall | Fix |
|---------|-----|
| Redirect loop | Valid Redirect URIs must match host/port/encoding exactly |
| `trustForwardHeader: true` but Cloudflare-origin headers wrong | ensure `X-Forwarded-*` preserved (default OK) |
| JWT rejected ("invalid signature") | clock skew — services should allow ±60s (`leeway`) |
| `aud` mismatch | app must send its own client id, not the gateway's |
| Sessions expire mid-API-call | use refresh tokens / silent renew (SPA) or service-account tokens (server-to-server) |

---

## 7. Checklist

- [ ] Keycloak admin on a secure (or Access-protected) route
- [ ] forwardAuth on every public app you don't want anonymous
- [ ] App validates `iss` + `aud` + signature (not just `Authorization: Bearer …` presence)
- [ ] MFA enabled for admin users
- [ ] Key rotation: Keycloak rotates realm keys automatically; verify apps use JWKS (always fetch, don't cache forever)

---

## 8. Portfolio one-liner

> *"Every public service is gated: Traefik forward-auth checks an SSO session with Keycloak at the gateway, and my APIs independently verify the JWT signature, issuer and audience — an IAM pattern that matches AWS API Gateway + Cognito."*

---

## 🔗 Continue reading

► **[Next: 02 — RBAC & secrets](02-rbac-and-secrets.md)**

◄ **[Back to 04 Security index](README.md)** · [🏠 Repo home](../../README.md)