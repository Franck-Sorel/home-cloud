# 02 — Expose a service to the world

> **Goal:** Take one service running inside your private cloud and make it **publicly reachable, over HTTPS, at `https://<service>.mycloud.com`** — with monitoring and a rollback plan. This is the project's "achievement unlocked" moment, and the exact recipe for every service after it.

---

## 0. The formula (memorize this)

> **A public service = 1 Service + 1 IngressRoute (Traefik) + 1 tunnel binding + 1 security pass.**

Nothing about exposing a service requires a port, a router, or the host OS. The tunnel already forwards `*.mycloud.com` → Traefik; Traefik just needs a route to your Service.

---

## 1. Prerequisites (from earlier sections)

- ✅ k3s running — [`02-setup/01`](../02-setup/01-install-k3s.md)
- ✅ Cloudflare Tunnel to `traefik.kube-system.svc.cluster.local:80` — [`02-setup/02`](../02-setup/02-cloudflare-tunnel.md)
- ✅ Traefik routing validated (hello) — [`02-setup/03`](../02-setup/03-traefik-ingress.md)
- ✅ A service deployed (e.g. `sample-api` from [`01-deploy-example-app.md`](01-deploy-example-app.md))
- ✅ Security pass done (at minimum rate-limit + headers, ideally Keycloak forward-auth) — [`04-security`](../04-security/README.md)

> 🪜 **Different scale of exposure, same recipe:**
> - *Local only* (skip tunnel binding) → reach it at `ClusterIP:port` while tethered to the machine.
> - *Private internet* (you + whitelisted IPs) → tunnel + `ipWhiteList` middleware.
> - **Public internet** (this doc) → tunnel + route + WAF + rate limit.

---

## 2. The checklist before you go public

- [ ] Service has **liveness/readiness probes** (bad release gets rolled back automatically)
- [ ] Resource **limits** set (a runaway pod won't OOM the box)
- [ ] A **rate-limit + security-headers middleware** attached
- [ ] Cloudflare **WAF + bot fighting** on (free tier)
- [ ] An **Alertmanager rule** fires if the new route goes 5xx (section 05)
- [ ] **Backups** exist for anything stateful on that route (section 06 doc 04)

> If you're exposing an *admin console* (Keycloak UI, Grafana, Vault, MinIO console): **do not** make it public — put it behind Cloudflare Access or internal-only. Public = user-facing apps + APIs.

---

## 3. The exposure recipe (10 minutes)

### Step 1 — confirm the Service exists and works internally
```bash
kubectl get svc -n apps sample-api
kubectl port-forward -n apps svc/sample-api 8080:80 &
curl localhost:8080/health        # healthy internally
```

### Step 2 — create the IngressRoute
`deploy/apps/sample-api/ingressroute.yaml`:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: sample-api
  namespace: apps
spec:
  entryPoints: [ web ]        # web = port 80 (from the tunnel); cloudflare terminates TLS
  routes:
    - match: Host(`sample.mycloud.com`)
      kind: Rule
      middlewares:
        - name: security-and-limits     # rate-limit + headers middleware
          namespace: apps
      services:
        - name: sample-api
          port: 80
```
```bash
kubectl apply -f deploy/apps/sample-api/ingressroute.yaml
```

### Step 3 — bind the hostname at the tunnel
Add a public hostname in Cloudflare Zero Trust (Networks → Tunnels → your tunnel → Public Hostname):
- **Subdomain:** `sample` · **Domain:** `mycloud.com`
- **Service:** `HTTP` → `traefik.kube-system.svc.cluster.local:80`

> (Or the CLI equivalent: `cloudflared tunnel route dns home-cloud sample.mycloud.com`).
> This is the only "new" piece per service: the DNS/binding at Cloudflare. Everything else was already built once.

### Step 4 — verify from everywhere
```bash
# local
curl -s https://sample.mycloud.com/health

# external check (run from another machine / phone / a public checker)
curl -s https://sample.mycloud.com/health
# → {"status":"ok","host":"sample-api-abc-xyz"}

# global reachability
curl -s "https://check-host.net" -H "content-type: application/json" -d '{"nodes":["us","eu"],"request":{"URL":"https://sample.mycloud.com/health"}}'
```
🎉 **It's live.** DNS → Cloudflare edge → tunnel → Traefik → Service → Pod, all over HTTPS, zero inbound ports.

---

## 4. Verifying it's *actually* reachable globally (not just luck)

| Test | Command | What passing means |
|------|---------|--------------------|
| DNS resolution | `dig +short sample.mycloud.com` → cloudflare IP | DNS correct |
| TLS handshake | `openssl s_client -connect sample.mycloud.com:443 -servername sample.mycloud.com` | edge cert valid |
| Response | `curl -sI https://sample.mycloud.com/health` → `HTTP/2 200` | route works |
| Latency | `time curl -s https://sample.mycloud.com/health` | your tunnel round-trip |
| Uptime | set up UptimeRobot/Cloudflare health check on the URL | proof over time |

> **UptimeRobot** (free): create an HTTPS monitor on `/health`, 5-min interval. It emails you when your public service is down — the cheapest "we have monitoring" claim.

---

## 5. Now, rollback & release hygiene (AWS-grade behavior)

Since we want "as reliable and clean as AWS":

```bash
# A bad release? Undo instantly:
kubectl rollout history deploy/sample-api -n apps
kubectl rollout undo deploy/sample-api -n apps

# Scale, then add a route version to A/B:
kubectl scale deploy/sample-api -n apps --replicas=3
```

Release discipline:
1. Build → tag image (semver) → push to registry
2. `kubectl set image` (or GitOps PR in section 07)
3. Watch `kubectl rollout status` + Grafana for the new version
4. If 5xx spikes → `rollout undo`

---

## 6. When it looks broken (5-minute debugging)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ERR_NAME_NOT_RESOLVED` | no tunnel hostname | add it in CF Zero Trust / CLI |
| `ERR_SSL_PROTOCOL_ERROR` | SSL/TLS mode mismatch | CF → SSL/TLS → Full (strict) |
| `502` | Traefik can't reach Service | service port/selector mismatch; `kubectl get ep sample-api` |
| `503`/connection refused | pod not Ready or no replicas | `kubectl get pods`, check readiness |
| `404` | no route rules match | `kubectl get ingressroute -A`, host spelling |
| `429` | rate-limit middleware (by design) | check `rateLimit` threshold; verify real IP is used |
| intermittent | tunnel CPU/pod churn | add 2nd cloudflared replica; check tunnel logs |

---

## 7. The "go public" ceremony (do it right the first time)

When you're happy:

```
□ kubectl rollout status deploy/sample-api -n apps      # green
□ curl https://sample.mycloud.com/health → 200
□ curl -sI https://sample.mycloud.com/ → 200
□ Grafana: alert rule LiveServiceDown active
□ UptimeRobot monitor created
□ Loki: logs flowing for namespace apps
□ Cloudflare WAF managed rules ON
□ ./scripts/healthcheck.sh → all green
```

Then **commit the snapshot** to the repo (`docs/06-testing/live-service.md`) with the URL, date, and screenshot. That file is your portfolio's proof that a real service runs on your home cloud.

---

## 8. Portfolio one-liner

> *"I exposed a service to the public internet from a local k3s cluster over zero-trust tunnels — HTTPS-terminated at Cloudflare, rate-limited and WAF'd, monitored end-to-end, with a tested instant-rollback path. The URL is live today."*

---

## 🔗 Continue reading

► **[Next: 03 — Smoke & E2E tests](03-smoke-and-e2e.md)** — make it repeatable

◄ **[Back to 06 Testing index](README.md)** · [🏠 Repo home](../../README.md)