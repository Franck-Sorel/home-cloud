# 03 — Traefik ingress routing

> **Goal:** Turn Traefik (bundled with k3s) into the **central L7 gateway** of your cloud: host-based routing, TLS, and middleware. After this doc, `https://hello.mycloud.com` serves a real app instead of a 404.

---

## 1. The mental model

```
hello.mycloud.com ─┐
api.mycloud.com ───┼──► Cloudflare edge ──► tunnel ──► Traefik (:443 in-cluster)
storage.mycloud.com┘                                  │
                                                      ├─ Host: hello.mycloud.com    → deployment "hello"
                                                      ├─ Host: api.mycloud.com      → deployment "api"
                                                      └─ Host: storage.mycloud.com  → deployment "minio"
```

**One ingress controller, many virtual hosts.** Traefik learns these rules from Kubernetes `Ingress` resources (standard) and its richer `IngressRoute` CRDs (featured middleware). This is your **API Gateway** layer.

---

## 2. Prereq check

- ✅ k3s installed ([`01-install-k3s.md`](01-install-k3s.md))
- ✅ Tunnel running ([`02-cloudflare-tunnel.md`](02-cloudflare-tunnel.md))
- ✅ Tunnel hostname `hello.mycloud.com` → `traefik.kube-system.svc.cluster.local:80`

> If the tunnel currently points `hello.mycloud.com` straight at Traefik, and Traefik has no route — that's the "404" we saw. Now we give it a route.

---

## 3. Deploy the `hello` test app

Create `deploy/hello/` (files already in [`deploy/hello/`](../../deploy/hello/)):

**`deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  namespace: apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
        - name: hello
          image: hashicorp/http-echo:latest
          args: ["-listen=:8080", "-text=Welcome to home-cloud 🚀 from pod $(POD_NAME)"]
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
          ports:
            - containerPort: 8080
          resources:
            requests: { cpu: 50m, memory: 32Mi }
            limits:   { cpu: 200m, memory: 128Mi }
          livenessProbe:
            httpGet: { path: /, port: 8080 }
          readinessProbe:
            httpGet: { path: /, port: 8080 }
```

**`service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello
  namespace: apps
spec:
  selector:
    app: hello
  ports:
    - port: 80
      targetPort: 8080
```

**`ingress.yaml`**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello
  namespace: apps
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  rules:
    - host: hello.mycloud.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello
                port:
                  number: 80
```

Apply:

```bash
kubectl create ns apps 2>/dev/null || true
kubectl apply -f deploy/hello/
kubectl rollout status deploy/hello -n apps
```

---

## 4. Verify routing end-to-end

On your machine:

```bash
kubectl get ingress -n apps
# NAME    CLASS   HOSTS               ...
# hello          hello.mycloud.com

kubectl get svc -n apps hello
# NAME    TYPE        CLUSTER-IP    PORT(S)
# hello   ClusterIP   10.43.x.y    80/TCP
```

From your phone / anywhere:

```bash
curl https://hello.mycloud.com/
# Welcome to home-cloud 🚀 from pod hello-6f9f...x (something like that)
```

🎉 **That's the milestone:** `DNS → Cloudflare → tunnel → Traefik → Ingress → Service → Pod`, from the public internet into your Ubuntu box, with zero inbound ports.

---

## 5. TLS: who terminates what?

Two supported models in this project:

| Model | Where TLS terminates | How to set up |
|-------|----------------------|---------------|
| **A. Edge TLS (default)** ✅ | **Cloudflare edge** | Nothing to do here — Cloudflare serves `https://*.mycloud.com` with its cert. Traefik sees plain HTTP on port 80 from the tunnel. |
| **B. Full-strict (end-to-end encryption)** | Cloudflare → re-encrypt → Traefik terminates origin TLS | Cloudflare **SSL/TLS → Full (strict)** + Traefik certs via `cert-manager` (Let's Encrypt DNS-01, works behind the tunnel) |

**Recommendation:** start with **A** (simple, zero work). Move to **B** later with `cert-manager` for defense-in-depth; it's covered in [`04-security/05-zero-trust-exposure.md`](../04-security/05-zero-trust-exposure.md) / roadmap.

---

## 6. Middleware: add rate limiting + security headers (the API-gateway bit)

Traefik middleware run *before* your app — the AWS "API Gateway" behaviors:

**`middleware.yaml`** (namespace `apps`)
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: security-and-limits
  namespace: apps
spec:
  headers:
    customFrameOptionsValue: "SAMEORIGIN"
    contentTypeNosniff: true
    browserXssFilter: true
    referrerPolicy: "strict-origin-when-cross-origin"
  rateLimit:
    average: 50
    burst: 20
```

**Attach it** via an annotation on an ingress, or via `IngressRoute`:

```yaml
ingress:
  metadata:
    annotations:
      traefik.ingress.kubernetes.io/router.middlewares: apps-security-and-limits@kubernetescrd
```

> `certExtractor` note: with edge TLS (model A) the middleware sees HTTP; with Full-strict it sees HTTPS. Keep that in mind when writing header policy.

---

## 7. The `IngressRoute` (Traefik-native, richer) — recommended for real services

Standard `Ingress` is fine; **Traefik CRDs** unlock middleware references, delegation, TCP routes, TLS config. Pattern for every later service:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: hello
  namespace: apps
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`hello.mycloud.com`)
      kind: Rule
      middlewares:
        - name: security-and-limits
          namespace: apps
      services:
        - name: hello
          port: 80
```

> This is the "gateway" style we'll use for Keycloak, MinIO, Vault, Grafana, etc. in [`03-services`](../03-services/README.md).

---

## 8. Multi-service routing (the `*.cloud` pattern)

Now that the pattern is proven, every future service = **3 files**: `deployment.yaml`, `service.yaml`, `ingressroute.yaml` (or one `Ingress`). The table of subdomains from [`00-prerequisites.md`](00-prerequisites.md) becomes real:

| Host | Service |
|------|---------|
| `hello.mycloud.com` | hello test app |
| `auth.mycloud.com` | Keycloak (next) |
| `storage.mycloud.com` | MinIO |
| `secrets.mycloud.com` | Vault |
| `grafana.mycloud.com` | Grafana |

Each simply gets its own route + Service; Traefik does the rest. No new tunnel entries needed (the tunnel already points `*.mycloud.com` at Traefik).

---

## 9. Troubleshooting quick sheet

| Symptom | Fix |
|---------|-----|
| `curl https://hello.mycloud.com/` → 404 | No matching Ingress/IngressRoute yet — check `kubectl get ingress -A` |
| Traefik pod restarting | `kubectl logs -n kube-system deploy/traefik` |
| Middleware not applied | middleware must exist in the namespace referenced (`apps-security-and-limits@kubernetescrd`) |
| Route gives same app on all subdomains | your tunnel `*.mycloud.com` rule forwards everything to Traefik, which *should* be splitting by host — check `Host()` match in route |

---

## 10. Portfolio one-liner

> *"Traefik is my AWS-ALB/API-Gateway equivalent — a single ingress controller routing many subdomains by host to many services, with middleware for rate limiting and security headers, sitting behind the Cloudflare tunnel."*

---

## 🔗 Continue reading

► **[Next section: 🛠️ 03 — Services](../03-services/README.md)** (deploy MinIO, Keycloak, Vault, …)

◄ **[Back to 02 Setup index](README.md)** · [🏠 Repo home](../../README.md)