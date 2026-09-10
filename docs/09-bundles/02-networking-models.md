# 🌐 02 — Networking Models ($0 DDNS vs Cloudflare)

The private cloud supports **two** ways to get services on the internet. Pick
one in `base` (`mode: ddns` or `mode: cloudflare`).

> 🟢 **DNS refresher before you dive in** (full list in the [GLOSSARY](../GLOSSARY.md#1-networking--dns-)):
> - **FQDN / subdomain / TLD** — your full address (`hello.mycloud.com` = host +
>   subdomain `hello` + TLD `.com`).
> - **DDNS** — automatically re-pointing a DNS record to your **public IP** when
>   broadband changes it (this is what the `ddns-updater` pod does).
> - **ACME / Let's Encrypt / DNS-01** — the free, automated way to prove you own
>   a domain (by writing a `TXT` record) and get a **wildcard** cert covering
>   every `*.mycloud.com` subdomain.
> - **CGNAT** — when your ISP hides you behind a shared private IP; **DDNS
>   can't reach you** then, so you need a **tunnel** (Model B).

| | **$0 DDNS** (default) | **Cloudflare Tunnel** (optional) |
|---|---|---|
| Cost | **$0** (free DDNS + Let's Encrypt) | **$0** on Cloudflare free tier |
| DNS | deSEC.io or Dynu (`ddns-updater` pod) | Cloudflare zone (Terraform-managed) |
| TLS | Let's Encrypt via Traefik **DNS-01** (wildcard) | terminated at Cloudflare edge |
| Open inbound ports | yes — router **port-forwards 80/443** | **none** |
| Home IP exposed | yes | hidden |
| Works behind CGNAT | no | **yes** |
| Needs a router/ISP you control | yes | no |

---

## Model A — $0 DDNS (recommended when you can port-forward)

```
                        your home router (port-forward 80 + 443)
   Internet ──► ┌───────────────────────────────┐
                │         your public IP         │
                └────────────────┬───────────────┘
                                 ▼
                    ┌────────────────────────────┐
                    │  Traefik (k3s)              │
                    │  ACME DNS-01 → deSEC/Dynu   │   ← wildcard *.mycloud.com
                    │  terminates TLS             │      via Let's Encrypt
                    └─────────────┬──────────────┘
                                  ▼
                     hello · keycloak · minio · vault · grafana …
                                  ▲
                DDNS updater pod (CronJob) keeps DNS ⇄ public IP in sync
                (deSEC.io / Dynu, via DynDNS2 in the `base` bundle)
```

**Why this wins at $0**: no per-feature platform, no dependency on any single
vendor; Traefik's ACME library (LEGO) speaks deSEC *and* Dynu natively, so a
real wildcard certificate is obtainable for free — the same DNS-01 that keeps
you off HTTP-only pages.

**Provider guidance (your source):**
- **deSEC.io** — full zone management + free `*.dedyn.io` subdomain; ideal for
  reverse-proxy wildcard certs. Periodically pauses new signups; forces DNSSEC.
- **Dynu** — reliable multi-subdomain DDNS, 4 free domains with wildcard.
- If you can stretch to a **cheap domain (~$2–5/yr) on Cloudflare**, that
  removes every limitation — but it's optional.

**Gotcha**: if your ISP uses **CGNAT**, port-forwarding is impossible → use
Model B.

---

## Model B — Cloudflare Tunnel (no open ports / CGNAT)

```
   Internet ──► Cloudflare edge (TLS, DDoS, WAF)
                     ▲
                     │ outbound, always-on encrypted connection
                     │ (no inbound ports; your IP stays hidden)
                     ▼
                 cloudflared pod (k3s) ──► Traefik ──► services
```

Declared as code in `terraform/cloudflare/` (zone, tunnel hostnames, WAF) and
run as the `cloudflared` Deployment in the `base` bundle (`mode: cloudflare`).

---

## A cheap private-LAN bonus (baseline, both models)

For resolutions inside your house, run a LAN DNS server (**AdGuard Home** or
**Technitium**). Give your services friendly hostnames (e.g. `hello.homelab.lan`)
and (AdGuard) block ads at the network level — independent of how the public
internet reaches you.

---

## Which should you choose?

| Your situation | Choose |
|---------------|--------|
| I can port-forward, want zero cost and least vendor lock-in | **Model A** (ddns) |
| I'm behind CGNAT, or don't want my home IP public | **Model B** (cloudflare) |
| I already have a domain on Cloudflare | **Model B** (or Model A with deSEC) |
| I want ad-blocking + local names too | add AdGuard/Technitium to either |

---

► **[Next: Architecture diagrams](03-architecture.md)** |
◄ [Back to 09 — Bundles](README.md)
