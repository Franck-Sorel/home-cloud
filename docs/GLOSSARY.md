# 📖 Glossary — every term, explained plainly

> This is the whole project's **translator**. Every unfamiliar word you bump
> into in these docs is defined here, in plain English, grouped by area.
>
> - **Who it's for:** everyone — beginners read it to get unstuck, advanced
>   users skim it to confirm the exact meaning we use.
> - **How to use it:** Ctrl/Cmd-F a term, or read the section that matches
>   where you're stuck.
> - **Legend:** `🟢` = beginner concept you'll meet first · `🔵` = intermediate
>   · `🔴` = advanced.

---

## 1. Networking & DNS 🟢

The foundation this whole cloud hangs on: turning `mycloud.com` into the right
IP address, and getting traffic to the right machine.

| Term | Plain-English definition |
|------|--------------------------|
| **DNS (Domain Name System)** | The internet's phonebook — translates human-readable names (`mylab.duckdns.org`) into IP addresses (`203.0.113.42`). |
| **FQDN (Fully Qualified Domain Name)** | The complete name including all labels: `mylab.duckdns.org` (host + subdomain + TLD). |
| **TLD (Top-Level Domain)** | The last part: `.org`, `.com`, `.io`, `.eu.org`. |
| **Subdomain** | A name under a domain: `mylab` in `mylab.duckdns.org`. |
| **Record** | One entry in a DNS zone. Types: A (IPv4), AAAA (IPv6), CNAME (alias), TXT (text, e.g. SPF, DKIM), MX (mail), NS (nameserver), SOA (zone metadata), SRV (service discovery). |
| **Zone** | A chunk of DNS namespace you manage. E.g., the zone `duckdns.org` contains all `*.duckdns.org` records. |
| **Authoritative nameserver** | The server that owns the *definitive* answer for a zone. It's the source of truth. |
| **Recursive resolver** | A DNS server that chases the answer on behalf of a client (goes from root → TLD → authoritative). Your ISP's DNS or a local Pi-hole acting as a resolver. |
| **Forwarding / Upstream** | When your local DNS server can't answer, it "forwards" the query to another DNS server (e.g. `1.1.1.1` or `9.9.9.9`). |
| **TTL (Time To Live)** | How long (seconds) a DNS answer is cached before re-querying. Lower TTL = faster propagation of changes but more load. |
| **Propagation** | The time for a DNS change to become visible worldwide (limited by TTLs on upstream caches). |
| **DDNS / Dynamic DNS** | Automatically updating a DNS record when your public IP changes (common with home broadband). |
| **DNSSEC** | A cryptographic signature system that proves DNS responses are authentic (prevents spoofing). Adds complexity — not all resolvers handle it well. |
| **DoH (DNS over HTTPS)** | Encrypting DNS queries inside HTTPS (port 443). Hides what you're looking up from your ISP. |
| **DoT (DNS over TLS)** | Same idea as DoH but over a dedicated TLS connection (port 853). |
| **DoQ (DNS over QUIC)** | Encrypted DNS over the QUIC protocol (UDP-based, lower latency). |
| **Sinkhole / DNS sinkhole** | Returning a fake/blocked IP (usually `0.0.0.0` or `127.0.0.1`) for ad/malware domains, so the connection never leaves your network. |
| **Blocklist / Gravity** | A list of known-bad domains. Pi-hole calls its blocklist engine "Gravity." |
| **Reverse proxy** | A server (Traefik, Caddy, Nginx) that receives external traffic and routes it to internal services by hostname. Needs a public DNS name + TLS cert. |
| **ACME / Let's Encrypt** | Automated protocol for issuing free TLS certificates. **DNS-01** challenge proves you control the domain by creating a TXT record. |
| **Wildcard certificate** | A single cert that covers `*.mylab.dedyn.io` and all its subdomains. |
| **NS delegation** | Telling the parent zone "use these nameservers for this subdomain". Required for `eu.org` or running your own zone. |
| **AXFR (Zone Transfer)** | Copying an entire zone from one nameserver to another (used for secondary/backup servers). |
| **Split-horizon DNS** | Returning different answers depending on the client's source (e.g. internal clients get `192.168.1.10`, external clients get your public IP). |
| **RPZ (Response Policy Zone)** | A way to inject blocking/redirect rules into a recursive resolver (used by Technitium, BIND). |
| **Cron job** | A scheduled task (e.g. "run this curl every 5 minutes to update DDNS"). |
| **Port forwarding** | Telling your router: "when traffic arrives on port 443, send it to `192.168.1.50:443`." Required to expose a homelab service publicly. |
| **CGNAT (Carrier-Grade NAT)** | When your ISP assigns you a private IP (e.g. `100.64.x.x`) instead of a public one. **DDNS won't work** in this case — you need a tunnel (Tailscale, Cloudflare Tunnel, WireGuard on a VPS). |
| **Tunnel** | An outbound, encrypted connection from your network to a public edge (Cloudflare) or peer, so no inbound port is needed. |
| 🔴 **LEGO** | The ACME client library built into Traefik. It knows how to solve DNS-01 challenges against many DNS providers (incl. deSEC.io and Dynu). |

**DNS terms you'll meet in the networking docs:** FQDN, TLD, subdomain, record,
zone, DDNS, propagation, TTL, wildcard certificate, ACME/DNS-01, CGNAT, tunnel,
reverse proxy, port forwarding.

---

## 2. Containers & the cluster (Kubernetes / K3s) 🟢

The "operating system" your services live in.

| Term | Plain-English definition |
|------|--------------------------|
| **Container** | A lightweight, isolated package containing your app + its dependencies, so it runs the same anywhere. |
| **Image** | The read-only template a container is created from (stored in a registry). |
| **Container registry** | A place to store/pull images (Harbor locally; Docker Hub / ghcr.io hosted). |
| **Kubernetes (K8s)** | The industry-standard orchestrator that runs, scales and recovers containers. |
| **K3s** | A lightweight Kubernetes for resource-constrained machines — the version this project bundles. |
| **Pod** | The smallest deployable unit in Kubernetes — one or more containers that share a network namespace. Roughly "one app instance". |
| **Namespace** | A named grouping/separation of resources inside a cluster (like folders). We use one per capability: `apps`, `storage`, `auth`… |
| **Deployment** | The object that declares "run N replicas of this pod and keep them running". |
| **Replica / Replicas** | How many copies of a pod run. More replicas = more availability/scaling. |
| **Service** | A stable network name + load balancer in front of a set of pods, so clients don't care about individual pod IPs. |
| **Ingress** | The rules for routing external traffic to internal Services by host/path. |
| **IngressRoute** | Traefik's richer, purpose-built version of Ingress (includes TLS + middlewares). |
| **Middleware (Traefik)** | A reusable rule applied to a route (security headers, rate-limiting, auth). |
| **ConfigMap** | A place to store non-secret config (env vars, files) that pods mount/read. |
| **Secret** | Like a ConfigMap but for sensitive values (base64-encoded; store the real secret elsewhere/Vault). |
| **CronJob** | A Kubernetes object that runs a job on a schedule (we use one to update DDNS). |
| **NetworkPolicy** | A firewall rule between pods/namespaces; default-deny means "deny unless allowed". |
| **Node** | A machine (physical/VM) in the cluster that runs pods. |
| **PVC (PersistentVolumeClaim)** | A request for durable storage your pod can use (survives restarts). |
| **kubectl** | The command-line client to talk to a Kubernetes cluster. |
| **Probe** | A health check on a container (liveness = "is it alive?", readiness = "is it ready for traffic?"). |
| **Helm** | The package manager for Kubernetes. It bundles manifests as a "chart". |
| **Chart** | A packaged Helm application — files + templates that render into Kubernetes manifests. |
| **Values / `values.yaml`** | The configuration knobs a chart reads (we expose `domain`, `tls.enabled`, etc.). |
| **Release** | A single installed *instance* of a chart. |
| 🔴 **RBAC (Role-Based Access Control)** | Rules for "who/what may do what" inside Kubernetes. |

---

## 3. Networking the cluster out (Traefik + TLS) 🟡

| Term | Plain-English definition |
|------|--------------------------|
| **EntryPoint** | A port that Traefik listens on (`web`=80, `websecure`=443). |
| **certResolver** | A named ACME resolver inside Traefik that issues certs for routes. |
| **DNS-01 challenge** | Proves you own a domain by placing a `_acme-challenge` TXT record; enables **wildcard** certs. |
| **HTTP-01 challenge** | Proves ownership by serving a token over port 80; no wildcard. |
| 🔴 **cert-manager** | A Kubernetes add-on that issues certs (we use Traefik's built-in ACME instead for the $0 path, so no cert-manager needed). |
| 🔴 **ForwardAuth** | A Traefik middleware that asks a separate login service ("is this user authed?") before letting traffic through. |

---

## 4. The services (AWS counterparts) 🟡

Each bundle maps to an AWS service. The tool name is "self-hosted"; the column
is "what it's the free version of".

| Tool | What it is | AWS analog |
|------|------------|-----------|
| **MinIO** | S3-compatible object storage (buckets/objects). | S3 |
| **Keycloak** | Identity provider: logins, OIDC/SAML, SSO, MFA. | IAM / Cognito |
| **OAutH2/OIDC/SSO** | Auth standards; OIDC issues a signed **JWT** across apps so you log in once. | — |
| **HashiCorp Vault** | Issues secrets on demand (esp. short-lived DB credentials). | Secrets Manager / KMS |
| **OpenFaaS** | Run small code "functions" without managing servers. | Lambda |
| **Harbor** | Self-hosted container image registry. | ECR |
| **Grafana** | The dashboard UI for all your metrics/logs in one screen. | CloudWatch Dashboards |
| **Prometheus** | Scrapes and stores time-series metrics, drives Grafana + alerts. | CloudWatch Metrics |
| **Loki** | Centralized log storage (with Grafana). | CloudWatch Logs |
| 🔴 **Alertmanager** | Sends alerts (email/Telegram) when a metric breaches a rule. | CloudWatch Alarms/SNS |
| 🔴 **Velero** | Backs up/restores the whole cluster. We script triggering + verifying it. | — |

---

## 5. Tooling the repo gives you 🟢

| Tool / file | What it is |
|-------------|-----------|
| **`justfile` / `just`** | A command runner (like `make`): `just validate`, `just deploy base`, `just package`. |
| **`scripts/*.sh`** | Small bash helpers; each automates/verifies a doc's steps. |
| **`just validate` / `validate.sh`** | The **accuracy pipeline**: lints every chart/script/manifest/terraform. |
| **Bundle** | A self-contained Helm chart = one deployable capability (e.g. `auth`, `storage`). |
| **Aggregator chart** | The `home-cloud` chart that lets you enable *which* bundles you want. |

---

## 6. Infrastructure-as-Code & GitOps 🟡

| Term | Plain-English definition |
|------|--------------------------|
| **Terraform** | Declarative tool that turns code into cloud resources (we use it for the Cloudflare edge: zone, tunnel, WAF). |
| **Provider** | A Terraform plugin for a specific platform (e.g. `cloudflare/cloudflare`). |
| **IaC (Infrastructure as Code)** | Describing infrastructure in files instead of clicking a console. |
| **Git** | Version control: tracks every change to files. |
| **Repository / repo** | The folder of a project under Git. |
| **Commit** | A saved snapshot of changes with a message. |
| **Branch** | A separate line of development off `main`. |
| **Pull Request (PR)** | A proposed change to be reviewed before merging. |
| **GitOps** | The idea that "Git is the single source of truth" — a tool keeps the cluster matching what's in git. |
| **ArgoCD** | A GitOps tool: watches git and auto-applies the desired state to the cluster. |
| **SOPS** | Encrypts secret values at rest so you *can* commit them safely. |
| **age** | The simple file-encryption tool SOPS uses (you keep the private key secret). |
| 🔴 **Kustomize** | A Kubernetes-native way to patch/base-manifest sets (alternative to Helm). |
| 🔴 **OCI registry / OCI chart** | Publishing Helm charts to a container registry (we push to `ghcr.io`). |

---

## 7. CI/CD (the pipeline) 🟡

| Term | Plain-English definition |
|------|--------------------------|
| **CI (Continuous Integration)** | Automatically checking every change (we run `just validate`). |
| **CD (Continuous Delivery/Deployment)** | Automatically building/publishing releases. |
| **GitHub Actions** | GitHub's built-in CI/CD runner. |
| **Workflow** | A file of automation in `.github/workflows/`. |
| **Job / Step** | A workflow's units of work (a job is a machine + steps run on it). |
| **Runner** | The machine GitHub Actions runs a job on (`ubuntu-latest`). |
| **shellcheck** | A linter that finds bugs in bash scripts. |
| **yamllint** | A linter for YAML files. |
| **`helm lint` / `helm template`** | Validate a chart's structure / render its output. |
| **`terraform validate` / `fmt`** | Check terraform config is valid / consistently formatted. |

---

## How this maps to the docs

| Stuck on… | Jump to |
|-----------|---------|
| A DNS word | this page, **[§ 1](#1-networking--dns-)**, or [networking models](09-bundles/02-networking-models.md) |
| A Kubernetes/container word | **[§ 2](#2-containers--the-cluster-kubernetes--k3s-)** |
| What a service does | **[§ 4](#4-the-services-aws-counterparts-)**, or [bundle catalog](09-bundles/01-bundles.md) |
| A `just` / script command | **[§ 5](#5-tooling-the-repo-gives-you-)** |
| Git/Terraform/GitOps | **[§ 6](#6-infrastructure-as-code--gitops-)**, or [07-iac-gitops](07-iac-gitops/README.md) |
| The pipeline | **[§ 7](#7-cicd-the-pipeline-)**, or [09-bundles/04-pipeline](09-bundles/04-pipeline.md) |

◄ **[Back to repository home](../README.md)**
