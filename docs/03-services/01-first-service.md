# 01 — Your first real service (an API pod, "hello" made real)

> **Goal:** Deploy your own tiny HTTP API — not just a public hello — exercising pods, services, ingress, secrets, and persistent config. This is the *template* every future service clones.

---

## 1. The shape of a service in k8s

```
                ┌─────────────────────────────────────────────────────┐
  public        │                k3s                                 │
  hello.mycloud.com ─► Traefik ─► Service "myapi" (ClusterIP, :80) ─► ┤
                │                                                     │         pod:8080
                │   IngressRoute/Ingress matches host + forwards ──►  │
                └─────────────────────────────────────────────────────┘
```

Three resources (plus optional ConfigMap/Secret) are all you need:

---

## 2. Deploy a demo API (no image-building needed at first)

Use `hashicorp/http-echo` again but in a richer form, or (recommended) write the **demo API** in the repo:

### A. The app itself
Repo: [`examples/`](../../examples/) — a tiny Node/Python/Go HTTP server (see `examples/sample-api/`) that:
- returns `{ "service": "myapi", "host": <pod>, "version": "v1" }` at `/`
- reads its config from a **ConfigMap**
- reads a **Secret** (API token) and prints whether it's set (`present/absent`) at `/health`

```dockerfile
# examples/demo-api/Dockerfile   (see the repo for a working one)
FROM node:20-alpine
WORKDIR /app
COPY . .
CMD ["node", "server.js"]
```

### B. ConfigMap + Secret
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapi-config
  namespace: apps
data:
  MESSAGE: "Hello from home-cloud"
---
apiVersion: v1
kind: Secret
metadata:
  name: myapi-secret
  namespace: apps
type: Opaque
stringData:
  API_TOKEN: "change-me-please"
```

> ⚠️ Committing real secrets = anti-pattern. `change-me-please` + SOPS in [`07-iac-gitops`](../07-iac-gitops/README.md) for later.

### C. Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapi
  namespace: apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapi
  template:
    metadata:
      labels:
        app: myapi
    spec:
      containers:
        - name: myapi
          image: ghcr.io/<you>/demo-api:v1      # your image (or hashicorp/http-echo as placeholder)
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef: { name: myapi-config }
          env:
            - name: API_TOKEN
              valueFrom:
                secretKeyRef: { name: myapi-secret, key: API_TOKEN }
          resources:
            requests: { cpu: 100m, memory: 64Mi }
            limits:   { cpu: 500m, memory: 256Mi }
          livenessProbe:  { httpGet: { path: /health, port: 8080 }, initialDelaySeconds: 3, periodSeconds: 10 }
          readinessProbe: { httpGet: { path: /health, port: 8080 }, initialDelaySeconds: 3, periodSeconds: 5 }
```

### D. Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapi
  namespace: apps
spec:
  selector: { app: myapi }
  ports:
    - { port: 80, targetPort: 8080 }
```

### E. IngressRoute (Traefik CRD, the richer form we recommend)
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapi
  namespace: apps
spec:
  entryPoints: [ web ]
  routes:
    - match: Host(`api.mycloud.com`)
      kind: Rule
      middlewares:
        - name: security-headers
          namespace: apps
        - name: security-limits
          namespace: apps
      services:
        - name: myapi
          port: 80
```

Apply:
```bash
kubectl create ns apps 2>/dev/null || true
kubectl apply -f deploy/apps/00-configmap.yaml
kubectl apply -f deploy/apps/00-secret.yaml
kubectl apply -f deploy/apps/01-deployment.yaml
kubectl apply -f deploy/apps/02-service.yaml
kubectl apply -f deploy/apps/03-ingressroute.yaml
kubectl rollout status deploy/myapi -n apps
```

---

## 3. Verify

```bash
kubectl get pods -n apps -o wide
kubectl get svc -n apps myapi
curl https://api.mycloud.com/            # public path
curl https://api.mycloud.com/health      # probe path
```

Then set the Secret value to something real later in [`04-security`](../04-security/README.md).

---

## 4. Rolling updates (the "AWS-grade" hygiene)

Change image to `:v2`, then:

```bash
kubectl set image deploy/myapi myapi=ghcr.io/<you>/demo-api:v2 -n apps
kubectl rollout status deploy/myapi -n apps
kubectl rollout history deploy/myapi -n apps          # full history
kubectl rollout undo deploy/myapi -n apps             # instant rollback
```

You've now reproduced what ECS/EKS gives you: **zero-downtime deployments + rollback** — for free.

---

## 5. Why this is your template

- ✅ **ConfigMap** — non-secret config separate from code
- ✅ **Secret** — secret config as env (or mount, see Vault doc)
- ✅ **Probes** — self-healing: bad pod gets restarted/removed from LB
- ✅ **Resources** — predictable usage on a single box
- ✅ **IngressRoute + middleware** — public, rate-limited, secured

Congratulations — that's a **production-shaped microservice** pattern.

---

## 🔗 Continue reading

► **[Next: 02 — MinIO (S3)](02-minio-s3.md)**

◄ **[Back to 03 Services index](README.md)** · [🏠 Repo home](../../README.md)