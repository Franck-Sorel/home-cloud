# 00 — Verify the cluster (systematic health checks)

> **Goal:** A repeatable, 10-minute health check that proves the cluster's layers are all alive. Run it any time you've changed something — or before showing the platform off.

---

## 1. The five-layer health check

### L0 — Host
```bash
uptime && free -h && df -h /
kubectl get nodes -o wide                 # STATUS=Ready
kubectl cluster-info                       # control plane healthy
```

### L1 — Control plane + k3s components
```bash
kubectl get pods -n kube-system -o wide    # all Running/Ready
kubectl get svc -n kube-system traefik     # ExternalIP set (servicelb)
```

### L2 — Tunnel
```bash
kubectl get pods -n cloudflared           # cloudflared Running, 1/1
kubectl logs -n cloudflared deploy/cloudflared --tail 10
# look for "Registered tunnel connection" — connections healthy
```

### L3 — TLS/edge
```bash
curl -sv https://hello.mycloud.com/ 2>&1 | grep -E 'subject:|issuer:|HTTP/'
# expect: issuer CN=Cloudflare Inc — valid edge cert; HTTP/2 200
openssl s_client -connect hello.mycloud.com:443 -servername hello.mycloud.com < /dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -subject
```

### L4 — Ingress route
```bash
kubectl get ingressroute -A
kubectl get ingress -A
curl -I https://api.mycloud.com/health     # 200 + our app's headers
curl -I https://storage.mycloud.com/       # 403 (auth) — MinIO answered
```

### L5 — Services
```bash
kubectl get pods -A | grep -v Running      # only Completed/None expected
kubectl get pvc -A                          # all Bound
kubectl get networkpolicies -A             # policies present (if CNI enforced)
```

---

## 2. The "everything green" snapshot for your repo

Create a markdown snapshot (`docs/06-testing/health-check-snapshot.md` in the repo) after a green run:

```markdown
# Health check — 2026-09-05
- Node: Ready · RAM 62% · Disk 41%
- kube-system: 9/9 Running
- cloudflared: 2/2 connections
- hello.mycloud.com: HTTP 200 (Traefik+ingress OK)
- api.mycloud.com/health: HTTP 200 (app OK)
- storage.mycloud.com: HTTP 403 (MinIO alive, auth required)
- auth.mycloud.com: OIDC discovery OK
- secrets.mycloud.com: /v1/sys/health → {"sealed":false}
```

> A dated, green snapshot in git is cheap proof that the platform was healthy at a point in time.

---

## 3. Automate it

Turn each check into a script: [`scripts/healthcheck.sh`](../../scripts/healthcheck.sh) runs all of `L0–L5` and exits non-zero on failure. Hook it into a k8s **CronJob** → alert on failure (via the observability section).

```bash
./scripts/healthcheck.sh
# ✔ Host OK · ✔ k3s OK · ✔ Tunnel OK · ✔ TLS OK · ✔ Routes OK · ✔ Services OK
```

---

## 4. Interpreting common "fails"

| Fail | Meaning | First move |
|------|---------|------------|
| Node `NotReady` | k3s agent down | `sudo systemctl status k3s` |
| Traefik svc no ExternalIP | servicelb didn't bind | `kubectl describe svc traefik -n kube-system` |
| Tunnel 0 connections | cloudflared crashed/creds bad | logs + recreate secret |
| TLS HTTP/2 but issuer wrong | edge TLS drift | re-check Cloudflare certs/SSL-TLS mode |
| Route 404 | no matching route | `kubectl get ingressroute -A`; match host |
| Storage 502 | MinIO not Ready | `kubectl rollout status -n storage` |

---

## 5. Portfolio one-liner

> *"I keep a dated, green health-check snapshot in the repo and a CronJob that re-runs it every 5 minutes — a living proof-of-health for the platform."*

---

## 🔗 Continue reading

► **[Next: 01 — Deploy an example app](01-deploy-example-app.md)**

◄ **[Back to 06 Testing index](README.md)** · [🏠 Repo home](../../README.md)