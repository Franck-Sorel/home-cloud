# mynotes-app — the full "workshop" application

This is the **portfolio centerpiece** described in
[`docs/03-services/07-app-workshop.md`](../../docs/03-services/07-app-workshop.md).
It demonstrates a real cloud-native application that uses *every* service in
the private cloud:

```
browser → [Keycloak OIDC login] ── JWT ──► mynotes-api
               testing/api                       ├─► MinIO   (S3: note/file content)
                                                 ├─► Vault   (dynamic DB creds)
                                                 └─► Postgres (notes table)
```

| Capability | AWS analog | Proved here |
|------------|-----------|-------------|
| SSO login (SPA → Keycloak) | Cognito + API Gateway | user logs in, gets JWT |
| API validates JWT + roles | IAM policy | only owner can write |
| Object content → MinIO | S3 | uploads stored |
| Short-lived DB creds → Vault | Secrets Manager | no static DB passwords |
| Relational data | RDS | notes table |

---

```
examples/mynotes-app/
├── frontend/            static SPA (calls API with Bearer JWT)
├── api/                 backend service + Dockerfile
│   ├── Dockerfile
│   ├── (flask/fastapi or node/express)
│   └── tests/e2e.sh     the end-to-end test from docs/06-testing/03
├── k8s/                 deployment, service, ingressroute, serviceMonitor
└── README.md            build & deploy instructions (this file)
```

---

## Build & deploy (summary)

```bash
# 1. build & push
docker build -t registry.mycloud.com/library/mynotes-api:v1 examples/mynotes-app/api
docker push registry.mycloud.com/library/mynotes-api:v1

# 2. manifests (env vars, secrets refs, imagePullSecret)
kubectl apply -f examples/mynotes-app/k8s/

# 3. route (forwardAuth to Keycloak)
kubectl apply -f examples/mynotes-app/k8s/ingressroute.yaml

# 4. watch
kubectl rollout status deploy/mynotes-api -n apps
```

## Verify

```bash
curl https://api.mycloud.com/health                 # 401 (no JWT) — auth works
curl -H "Authorization: Bearer <jwt>" https://api.mycloud.com/notes      # 200 []
curl -H "Authorization: Bearer <jwt>" -X POST https://api.mycloud.com/notes -d '{"title":"hi"}'
mc ls homecloud/notes                               # object appears in MinIO
```

## The implied services (set up in service docs)

- Keycloak realm `mynotes`, client `mynotes-api` (docs/03-services/03)
- MinIO bucket `notes` with access key (docs/03-services/02)
- Vault DB role `mynotes-db` + Postgres (docs/03-services/04)
- PostgreSQL (docs/08-roadmap; or CloudNativePG)