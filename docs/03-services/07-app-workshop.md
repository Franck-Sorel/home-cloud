# 07 — The app workshop: tying it together

> **Goal:** Build (and deploy) one real application that uses **all** the services from this section — proving the platform is a coherent cloud, not just a bunch of pods. This is your **portfolio centerpiece**.

---

## 1. The demo app concept

A small "**photo-box / note-box**" service:

```
        ┌─────────────────────────────┐   authentication
        │   my-webapp (public)        │◄────────────────────────────── Keycloak (OIDC)
        │   + POST /notes             │
        └───────────┬─────────────────┘   check JWT + role
                   │  API calls
        ┌───────────▼─────────────────┐
        │   my-api (backend, JWT-     │──────────► MinIO        (store note/image content)
        │   protected, get token)     │──────────► Vault        (fetch DB/dynamic secrets)
        └───────────┬─────────────────┘
        ┌───────────▼─────────────────┐
        │   PostgreSQL (notes table)  │
        └─────────────────────────────┘
```

**What each piece models (AWS terms):**

| Component | AWS analog | Proven here |
|-----------|-----------|-------------|
| SPA → Keycloak login | Cognito authorizer on API Gateway | user logs in, gets JWT |
| API validates JWT (roles) | IAM policy enforcement | only `admin`/`owner` can write |
| API → MinIO bucket | S3 | object content stored |
| API → Vault | Secrets Manager | short-lived DB creds, not static |
| PostgreSQL (CloudNativePG) | RDS | durable relational storage |

---

## 2. What you'll build

In the repo under [`examples/mynotes-app/`](../../examples/mynotes-app/):

```
mynotes-app/
├── frontend/   (static SPA — calls API with Bearer JWT)
├── api/        (Go/Python/Node service)
│   └── Dockerfile
├── k8s/        (deployments, services, ingressroute, imagePullSecrets)
└── README.md   (build + deploy instructions)
```

The API endpoints:

- `POST /api/notes` — create note (JWT required, role `owner`)
- `GET  /api/notes` — list my notes (JWT required)
- `POST /api/files` — upload file → MinIO bucket `notes`
- `GET  /api/health` — health + reports whether Vault/MinIO/DB are reachable

---

## 3. Wire-up cheat sheet

### API gets JWT verification config from Keycloak discovery
```
issuer: https://auth.mycloud.com/realms/mynotes
JWKS:   https://auth.mycloud.com/realms/mynotes/protocol/openid-connect/certs
audience: mynotes-api
```
- Verify signature/claims with your language's OIDC library (e.g. `node-jose`, `python-jose`, `go-jose`).
- The full OIDC flow (validation code) is in the workshop repo.

### API talks to MinIO
S3 client with:
```
endpoint:   https://storage.mycloud.com
accessKey:  <minio user>
secretKey:  <minio pass>
bucket:     notes
```

### API talks to Vault
```
vaultUrl:   https://secrets.mycloud.com
role:       mynotes-db (dynamic DB creds)
path:       database/creds/mynotes-db
```
- It reads `db/creds` each hour (refresh flow) — never hardcodes DB passwords.

### API talks to Postgres
Use a **dynamic Vault credential** (from service 04) as `PGPASSWORD`. Optionally run Postgres via CloudNativePG operator (`08-roadmap`).

---

## 4. Deploying (end-to-end)

```bash
# 1. build & push (from examples/mynotes-app)
docker build -t registry.mycloud.com/library/mynotes-api:$TAG .
docker push ...

# 2. k8s manifests (referenced image, secrets, imagePullSecrets)
kubectl apply -f examples/mynotes-app/k8s/

# 3. route ingress with forwardAuth to Keycloak
kubectl apply -f examples/mynotes-app/k8s/ingressroute.yaml

# 4. watch it roll out
kubectl rollout status deploy/mynotes-api -n apps
```

Verification:
```bash
curl https://api.mycloud.com/health          # 401 (no JWT) — auth works
curl -H "Authorization: Bearer <jwt>" https://api.mycloud.com/notes  # 200 []
curl -H "Authorization: Bearer <jwt>" -X POST https://api.mycloud.com/notes -d '{"title":"hi"}'
mc ls homecloud/notes                        # object appears in MinIO
```

---

## 5. Why this wins the interview

This tiny app is a **microcosm of a real cloud-native system**:
- ✅ Zero-trust exposure (tunnel)
- ✅ L7 gateway with auth enforcement (Traefik + Keycloak JWT)
- ✅ Object storage parity (MinIO/S3)
- ✅ Dynamic secrets (Vault)
- ✅ Durable relational data (Postgres)
- ✅ All declarative & reproducible (git repo → deploy)
- ✅ Public HTTPS on every hop

> It's the difference between "I deployed a yaml" and "**I built a platform, and here's an app that runs on it**."

---

## 🔗 Continue reading

► **[Next section: 🔒 04 — Security](../04-security/README.md)** — harden all of this before going to the world

◄ **[Back to 03 Services index](README.md)** · [🏠 Repo home](../../README.md)