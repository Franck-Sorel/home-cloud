# 01 — Deploy an example app

> **Goal:** The fastest way to have something *real* (not just a hello pod) running, routed, and public — a sample app you deploy in under 5 minutes, then iterate on.

---

## 1. The sample app (in-repo)

In [`examples/`](../../examples/) you'll find:

| Example | What it is | Stack |
|---------|-----------|-------|
| `examples/sample-api/` | tiny REST API + `/metrics` + `/health` | Python (or Node/Go) |
| `examples/mynotes-app/` | the full workshop app (from `03-services/07`) | multi-service demo |

> Start with **sample-api** — one deployment + service + ingress route, public in minutes.

---

## 2. Deploy it

```bash
cd examples/sample-api
make build        # builds image and pushes to registry.mycloud.com (or use docker build manually)
kubectl apply -f k8s/
kubectl rollout status deploy/sample-api -n apps
```

Or use the prebuilt public image (no build step, just to see the wiring):
```bash
kubectl apply -f deploy/apps/sample-api-public/    # uses a public image
```

---

## 3. Verify end-to-end

```bash
curl https://api.mycloud.com/            # {"service":"sample-api","version":"v1",...}
curl https://api.mycloud.com/health      # 200
curl https://api.mycloud.com/metrics     # prometheus output (if enabled)
curl -H "Authorization: Bearer <jwt>" ... # any JWT-protected route
```

---

## 4. Make it yours

- Change the message/config via its ConfigMap (no rebuild) — `kubectl edit cm sample-api-config`
- Point a new subdomain at it with a second IngressRoute to see host-routing
- Wire `/metrics` into the ServiceMonitor from `05-observability/02`

---

## 🔗 Continue reading

► **[Next: 02 — Expose a service to the world](02-expose-service.md)** (the finale)

◄ **[Back to 06 Testing index](README.md)** · [🏠 Repo home](../../README.md)