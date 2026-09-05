# 05 — Zero-trust exposure (why we use a tunnel, and going further with Cloudflare Access)

> **Goal:** Explain — and then demonstrate — that the cluster needs **no inbound ports** to be reachable, and optionally add Cloudflare Access (Zero Trust) as the final, "even the port doesn't matter" shield.

---

## 1. Why "expose-without-ports" is the right default

| | Open-port model | Tunnel model |
|---|---|---|
| What's reachable | port 443 on your home IP | nothing (no inbound) |
| Attack surface | anyone can port-scan you | only your tunnel hostnames |
| Home IP exposure | yes | no |
| CGNAT / dynamic IP | breaks | irrelevant |
| Router / firewall changes | required | none |
| DDoS (your IP) | you take it | absorbed by Cloudflare |

> Even if you had a static public IP, this project's constraint (`04-constraints.md`) forbids the router/firewall changes anyway. The tunnel is the *only* architecture that satisfies both security **and** the constraint.

---

## 2. Verify "nothing is open" (great portfolio demo)

On your host, check listening sockets — only k3s's control plane ports should be local, **no 80/443 forwarded inbound-to-internet**:

```bash
sudo ss -tlnp | grep -E ':(80|443)\b' || echo "no global 80/443 listener"
ip route get 8.8.8.8        # public egress works, that's all we need
```

> 🔎 **Interview talking point:** "The internet can only reach my services through the tunnel. There is literally nothing listening on my public interface."

---

## 3. Hardening the tunnel itself

- **Credentials** (`tunnel-id.json`, token) live in a k8s Secret, never in git (`.gitignore` + [`07-iac-gitops`](../07-iac-gitops/README.md) secrets handling).
- **Multiple replicas** of `cloudflared` for redundancy (2 pods → 2 connections).
- **Restart policy** `Always`; watch it with a liveness probe; alert in section 05 if the tunnel drops.
- Keep `cloudflared` image pinned (not `latest` blindly); track releases.
- Set the tunnel to the **stricter origin TLS** (Full-strict) once via `cert-manager` (future) if you don't trust edge-to-origin in the clear — see `05` of `03-services`.

---

## 4. Cloudflare Access (Zero Trust) — the everything-wall

Beyond the "tunnel for transport", Cloudflare **Zero Trust Access** adds a *login wall* in front of the tunnel itself. Admin consoles (Keycloak UI, Vault UI, Grafana) should be behind it:

1. Cloudflare dashboard → **Zero Trust → Access → Applications**.
2. Add an **Application**:
   - Type: Self-hosted
   - Domain: `vault.mycloud.com` (and any other admin host)
   - Policy: **Allow** users in your **email list** (or an IdP like GitHub/Google) → session TTL
3. Optional: **Service Auth** (mTLS) so only specific client certs reach the tunnel for API calls.

Result: **even knowing the URL, a stranger gets a Cloudflare login page, not your app** — with no changes to your origin.

> 📌 Note: CF Access also provides the **B2B identity** story (login with GitHub/Google) — and it still works layered *with* Keycloak if you want both.

---

## 5. The new-style vs old-style tunnel (future-proof)

Cloudflare is moving tunnel auth toward a **service-token** model (token secrets issued per tunnel) rather than long-lived credentials JSON. This repo documents the classic `credentials-file` flow (still supported) and flags migration in [`08-roadmap`](../08-roadmap/README.md). Keep the token out of git either way.

---

## 6. Security model summary (what you actually get)

```
Cloudflare:    WAF · TLS · Bot Fight · Access wall · Rate rules
Tunnel:        no inbound port · origin hidden · no IP leak
Traefik:       rate limit · forward-auth · headers
k3s:           RBAC · NetworkPolicies · secrets scrubbed · non-root containers
```

Every layer above the trusting-to-nothing principle. A break at *any one* layer doesn't expose the cluster.

---

## 7. Portfolio one-liner

> *"My stack is zero-trust by construction: the cluster accepts no inbound traffic at all — only outbound tunnels — and Cloudflare Access can add an explicit login wall in front of even the right hostname."*

---

## 🔗 Continue reading

► **[Next: 06 — Hardening checklist](06-hardening-checklist.md)** — before you go live

◄ **[Back to 04 Security index](README.md)** · [🏠 Repo home](../../README.md)