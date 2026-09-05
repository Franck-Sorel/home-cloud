# 00 — Prerequisites

> **Goal:** Confirm every account, domain, and tool you need before you install anything. Do this checklist once and the rest of setup is smooth.

---

## 1. The hardware baseline

| Requirement | Why | Minimum |
|-------------|-----|---------|
| Ubuntu machine | The whole stack runs on it | 22.04 LTS or 24.04 LTS recommended |
| RAM | k3s + MinIO + Keycloak + Traefik + observability | **8 GB** (16 GB comfortable) |
| CPU | linear scaling of everything | 4+ cores recommended |
| Disk | container images, PVCs, logs | **50 GB free** at least; 100+ GB comfortable |
| Power | uptime (with UPS if possible) | nothing special |

> 💡 This is your *desktop* — k3s idles light and the whole cluster coexists with your daily use. See [`01-skills/04-learning-path.md`](../01-skills/04-learning-path.md) to tune down if your machine is small.

---

## 2. The accounts (create before starting)

| Account | Used for | Cost | Create at |
|---------|----------|------|-----------|
| **Domain registrar** | Own `mycloud.com` | ~$10/yr | Namecheap / Cloudflare Registrar / GoDaddy |
| **Cloudflare** | DNS, tunnel, TLS, WAF — *the* edge | Free | [dash.cloudflare.com](https://dash.cloudflare.com) |
| **GitHub** | repo like this one, Actions, ArgoCD source | Free | [github.com](https://github.com) |
| **Docker Hub** (optional) | pulling common images | Free | [hub.docker.com](https://hub.docker.com) |

**Domain tip (free option):** you can start with a free subdomain from a free-domain provider (e.g. DuckDNS `yourname.duckdns.org`) or use a `*.yourname.duckdns.org` wildcard to test Cloudflare Tunnels before spending money. Most portfolio builds buy a real domain — it looks better and gives wildcard subdomains (`*.mycloud.com`).

---

## 3. Domain added to Cloudflare (10 minutes)

1. Create a Cloudflare account.
2. **Add site** → type `mycloud.com` → choose the **Free** plan.
3. Cloudflare shows you **two nameservers**, e.g.:
   ```
   aria.ns.cloudflare.com
   brad.ns.cloudflare.com
   ```
4. Go to your **registrar**, set the domain's nameservers to those two values.
5. Back in Cloudflare, wait for *"Active"* (a few minutes–hours). Run a check:
   ```
   dig +short NS mycloud.com
   ```
   The result must be your two Cloudflare nameservers.

> ⚠️ **Do not** add an A record pointing at your home yet — we handle reachability via the **tunnel**, which adds records for you.

---

## 4. Confirm the golden tools

| Tool | Check | If missing |
|------|-------|------------|
| `curl` | `curl --version` | `sudo apt install curl` — *it's fine, this is on PATH, not a system service* (or just use wget) |
| `wget` | `wget --version` | `sudo apt install wget` |
| `docker` | `docker --version` | *(optional)* we use containerd via k3s; docker only if you want local image builds |
| `helm` | `helm version` | not needed yet — we install it in [`03-services`](../03-services/README.md) |
| `kubectl` | `kubectl version --client` | installed **after** k3s in [`01-install-k3s.md`](01-install-k3s.md) |

> 📝 These are *developer tools* in your `$PATH`, not system packages/services. Installing `curl` isn't "touching the OS" in the sense this project means (no system service, no `/etc`, no firewall/network change).

---

## 5. Decide your naming scheme

Choose a subdomain per service. A clean convention:

| Subdomain | Service |
|-----------|---------|
| `auth.mycloud.com` | Keycloak |
| `storage.mycloud.com` | MinIO |
| `secrets.mycloud.com` | Vault |
| `registry.mycloud.com` | Harbor |
| `grafana.mycloud.com` | Grafana |
| `api.mycloud.com` | your API |
| `*.mycloud.com` | (optional wildcard next) |

> Write this table down in a file in your repo (`examples/domains.md`). It's your "DNS naming convention" — a real ops artifact.

---

## 6. Preflight sanity checks

```bash
# Ubuntu version
cat /etc/os-release | grep PRETTY_NAME

# Free RAM & disk
free -h
df -h /

# Kernel networking modules present (Linux namespaces/cgroups - default on modern kernels)
uname -r
```

All green → continue to [`01-install-k3s.md`](01-install-k3s.md).

---

## 🔗 Continue reading

► **[Next: 01 — Install k3s](01-install-k3s.md)**

◄ **[Back to 02 Setup index](README.md)** · [🏠 Repo home](../../README.md)