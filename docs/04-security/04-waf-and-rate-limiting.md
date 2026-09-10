# 04 — WAF & rate limiting

> **Goal:** Put abuse protection in front of and inside the stack — Cloudflare WAF at the edge (*Shield* parity) and Traefik rate-limit middlewares at the gateway (your API-gateway throttling).

---

## 1. The two layers

```
Cloudflare edge  ── WAF rules · Bot Fight Mode · rate limiting ──► tunnel ──► Traefik ── rateLimit middleware ──► app
        (block malicious global, DDoS, bots)                       (per-service throttle, per-IP)
```

---

## 2. Cloudflare (edge) — do this now

In the Cloudflare dashboard → your domain → **Security**:

| Feature | Setting | Why |
|---------|---------|-----|
| **WAF → Managed rules** | enable OWASP Core + Cloudflare Managed (free tier allows) | known-bad payloads blocked before reaching you |
| **Security Level** | `High` (or `I'm Under Attack`) | CAPTCHA on suspicious requests |
| **Bot Fight Mode** | ON (free) | blocks obvious bots |
| **Rate limiting rules** (new: *Rate limiting rules API*) | create rule: 100 req/10s per IP → block 10 min, applied to `*.mycloud.com` | first layer of flood defense |
| **Bot Analytics** | keep an eye | visibility |

> ⚠️ Because Cloudflare terminates TLS, the app sees `X-Forwarded-For` from Cloudflare, and your **CF proxies those headers**. Make sure your *app* trusts only Cloudflare's edge (verify the real client-IP from CF headers, not the raw socket) — otherwise header spoofing is possible. Traefik's `trustForwardHeader` should be set only when behind CF.

---

## 3. Traefik rate limiting (gateway)

Per-service middleware in the applicable namespace:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: api-ratelimit
  namespace: apps
spec:
  rateLimit:
    average: 20        # per-second average per source IP
    burst: 10          # short burst allowance
    sourceCriterion:
      ipStrategy:
        depth: 1       # use the CF-provided client IP
```
Attach to the API's `IngressRoute`:
```yaml
middlewares:
  - name: api-ratelimit
```
> Prefer **sourceCriterion with depth 1** + `trustForwardHeader` so the limiting is keyed on the real visitor IP, not the tunnel's.

---

## 4. Extra protective middlewares (cheap wins)

| Middleware | Purpose |
|------------|---------|
| `headers` | `Content-Security-Policy`, `X-Frame-Options`, `HSTS`, `nosniff` (we saw in `02-setup/03`) |
| `ipWhiteList/ipBlockList` | allow only your IPs for admin routes |
| `retry` + `timeout` | resilience (not security, but keeps gateways healthy) |
| `compress` | bandit-friendly (still, don't compress large secrets) |

---

## 5. Layered defense when the bot still gets through

1. CF blocks the obvious brute → 2. Traefik throttles the sneaky-but-steady → 3. Keycloak MFA stops credential stuffing → 4. Vault leases limit blast radius → 5. Loki logs + Grafana alert you (section 05).

**That is the whole point of defense-in-depth.**

---

## 6. Verify your rules work

```bash
# burst 30 requests fast — expect 429 from Traefik after ~average
for i in $(seq 1 40); do
  curl -s -o /dev/null -w "%{http_code}\n" https://api.mycloud.com/health
done | sort | uniq -c
# → many 200, then 429
```

For CF: check **Security → Events** shows blocked requests; try a obviously-bad path:
```bash
curl -s "https://api.mycloud.com/?q=<script>alert(1)</script>" -o /dev/null -w "%{http_code}\n"
# CF WAF may 403 it before it ever reaches you
```

---

## 7. Portfolio one-liner

> *"The edge runs Cloudflare WAF, bot-fighting and rate rules; inside, Traefik throttles per-service with per-IP limits using the CF client IP — the same two-tier API-gateway protection AWS offers with Shield + API Gateway throttling."*

---

## 🔗 Continue reading

► **[Next: 05 — Zero-trust exposure](05-zero-trust-exposure.md)**

◄ **[Back to 04 Security index](README.md)** · [🏠 Repo home](../../README.md)