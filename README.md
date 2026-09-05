<div align="center">

# ☁️ Home-Cloud

### A self-hosted private cloud on a single Ubuntu machine — recreated with AWS-grade reliability, without touching the host OS.

[![License][license-badge]][license]
[![K3s][k3s-badge]][k3s]
[![Cloudflare Tunnel][cloudflare-badge]][cloudflare]

**Turn your local computer into a mini data center.** Run containers, Kubernetes, storage, authentication, and API services — exposed securely to the internet through a Cloudflare Tunnel — all on top of your existing Ubuntu OS, with zero system-package installs, zero firewall edits, and zero host modification.

</div>

---

## 🧭 What is this repository?

This is a **complete, end-to-end, self-contained guide** to building your own private cloud on a single Ubuntu computer. It is written for three different kinds of readers:

| 🎯 Reader | What they want | Start here |
|-----------|----------------|------------|
| 🚀 **Direct setup** | "I want this running NOW, step by step" | [`docs/02-setup`][setup] |
| 🧠 **Understanding** | "I want to know WHY it's built this way" | [`docs/00-understanding`][understanding] |
| 🧐 **Curious** | "I want to browse the full journey" | [`README`][readme] → `docs/` top-down |

**No matter who you are, you will find your place.** Follow the numbered folders in `docs/` — they are ordered like a story, from *concept* to *working demo*.

---

## 🗺️ Repository Map

```
home-cloud/
├── README.md                      ← You are here. Navigation hub.
├── docs/                          ← All documentation (numbered, in order)
│   ├── 00-understanding/          ← Concept, architecture, decisions, constraints
│   ├── 01-skills/                 ← Knowledge & skills required, AWS→self-hosted map
│   ├── 02-setup/                  ← Step-by-step installation (from zero to cluster)
│   ├── 03-services/               ← Deploy the AWS-like services (MinIO, Keycloak...)
│   ├── 04-security/               ← Hardening, secrets, authentication, WAF
│   ├── 05-observability/          ← Logging, metrics, alerting (Loki, Prometheus, Grafana)
│   ├── 06-testing/                ← Verify it works & expose a service to the world
│   ├── 07-iac-gitops/             ← Infrastructure-as-Code & GitOps (Terraform, ArgoCD)
│   └── 08-roadmap/                ← Roadmap, roadmap to AWS-parity, future work
├── scripts/                       ← Reusable helper scripts (bash)
├── deploy/                        ← Kubernetes YAML / Helm values / manifests
├── examples/                      ← Sample services and demo applications
└── LICENSE
```

---

## 📖 How to navigate — pick your path

### 🚀 Path 1 — "I just want it running" (Direct setup)
> You want to go from an empty Ubuntu machine to a secure, publicly-accessible private cloud.

1. **Prereq check** → [`docs/02-setup/00-prerequisites.md`][prereq]
2. **Install k3s** → [`docs/02-setup/01-install-k3s.md`][install-k3s]
3. **Expose via Cloudflare Tunnel** → [`docs/02-setup/02-cloudflare-tunnel.md`][tunnel]
4. **Configure Traefik ingress** → [`docs/02-setup/03-traefik-ingress.md`][traefik]
5. **Deploy your first service** → [`docs/03-services/01-first-service.md`][first-service]
6. **Expose a service to the world** → [`docs/06-testing/02-expose-service.md`][expose]

> ⏱️ **Time to first running pod:** ~1 hour (domain + Cloudflare account required).

---

### 🧠 Path 2 — "I want to understand it deeply" (Understanding)
> You care about *why* this stack was chosen, the trade-offs, and the constraints.

Read the `docs/00-understanding/` folder top-to-bottom:

1. [`01-what-is-a-private-cloud.md`][what-is]
2. [`02-architecture.md`][architecture]
3. [`03-design-decisions.md`][decisions]
4. [`04-constraints.md`][constraints]
5. [`05-aws-parity.md`][aws-parity]

Then dive into the **skills** you'd need: [`docs/01-skills/`][skills]

---

### 🧐 Path 3 — "I'm curious, show me everything"
> You want the full picture, at your own pace.

Just walk the `docs/` folder top to bottom — it's numbered and tells one continuous story:

1. **Understand** → `00-understanding/` — *What & Why*
2. **Learn** → `01-skills/` — *What you need to know*
3. **Build** → `02-setup/` → `03-services/` — *How to build it*
4. **Secure** → `04-security/` → hammer it down
5. **Observe** → `05-observability/` — *watch it in production*
6. **Verify & Expose** → `06-testing/` — *prove it works, put it online*
7. **Automate** → `07-iac-gitops/` — *make it reproducible*
8. **Grow** → `08-roadmap/` — *what's next*

---

## ⚡ The Stack at a Glance

| Layer | Technology | AWS equivalent |
|-------|-----------|----------------|
| **Container runtime & orchestration** | [K3s](https://k3s.io) (lightweight Kubernetes) | EKS / ECS |
| **Ingress / reverse proxy** | [Traefik](https://traefik.io) (bundled with k3s) | ALB / API Gateway |
| **Internet exposure** | [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (zero inbound ports) | CloudFront / Global Accelerator |
| **Object storage** | [MinIO](https://min.io) | S3 |
| **Identity & auth** | [Keycloak](https://www.keycloak.org) / Authentik | IAM / Cognito |
| **Container registry** | [Harbor](https://goharbor.io) / Gitea | ECR |
| **Secrets management** | [HashiCorp Vault](https://www.vaultproject.io) | Secrets Manager |
| **Logging** | [Loki](https://grafana.com/oss/loki/) + Grafana | CloudWatch |
| **Metrics** | [Prometheus](https://prometheus.io) + Grafana | CloudWatch / Managed Prometheus |
| **Serverless / functions** | [OpenFaaS](https://www.openfaas.com) / Knative | Lambda |
| **CI/CD & GitOps** | GitHub Actions + [ArgoCD](https://argoproj.github.io/cd/) | CodePipeline / CodeDeploy |

> 💡 Full AWS-to-self-hosted mapping: [`docs/01-skills/02-aws-to-self-hosted-map.md`][aws-map]

---

## 🔑 Key Design Decision

**The single rule that drives everything in this repository:**

> **"Do not modify the Ubuntu host OS."**

This means no system-package installs, no `ufw`/`iptables` edits, no `/etc/` config changes, no router port-forwarding. Everything we build runs as **containers and pods** in user space.

**How we expose services without touching the network stack:** a **Cloudflare Tunnel**. The cluster opens an *outbound* connection to Cloudflare's edge, so your home IP stays hidden and you need **zero inbound open ports**.

```
Internet → [Cloudflare edge (TLS, DDoS)] → [Cloudflare Tunnel] → [Traefik Ingress in k3s] → [Your Pods]
```

> Learn the full reasoning: [`docs/00-understanding/03-design-decisions.md`][decisions]

---

## ✅ Quick-start checklist

Everything you need to complete the direct setup path:

- [ ] A **domain name** (e.g. `mycloud.com`) — `~$10/yr`
- [ ] A **Cloudflare account** (free tier is enough) — `$0`
- [ ] A machine running **Ubuntu** (this repo assumes Ubuntu)
- [ ] **k3s** → [`02-setup/01-install-k3s.md`][install-k3s]

---

## 📚 Documentation index (full)

| Section | Covers | Reader |
|---------|--------|--------|
| [`00-understanding`][understanding] | What is a private cloud, architecture, decisions, constraints, AWS parity | 🧠 Understanding |
| [`01-skills`][skills] | Knowledge map, AWS→self-hosted mapping, skill checklist, learning path | 🧠 Understanding |
| [`02-setup`][setup] | Prerequisites, install k3s, Cloudflare Tunnel, Traefik ingress | 🚀 Direct setup |
| [`03-services`][services] | MinIO, Keycloak, Harbor, Vault, OpenFaaS, first service | 🚀 Direct setup |
| [`04-security`][security] | Hardening, secrets, auth, WAF/rate-limiting, zero-trust | 🔒 All |
| [`05-observability`][observability] | Logging, metrics, dashboards, alerting | 🚀 Direct setup / 🔒 |
| [`06-testing`][testing] | Verify cluster, smoke tests, expose service publicly | 🚀 Direct setup |
| [`07-iac-gitops`][iacgitops] | Terraform, Ansible, GitOps with ArgoCD | 🚀 Direct setup / Curious |
| [`08-roadmap`][roadmap] | Roadmap to AWS-parity, future work, known limits | 🧐 Curious |

---

## 🤝 Contributing

This is a portfolio / learning project, but contributions, corrections, and improvements are welcome. Open an issue or a pull request.

### How to run the helper scripts
Scripts live in [`scripts/`][scripts]. They are documented in [`scripts/README.md`][scripts-readme].

---

## 📄 License

This repository is licensed under the **MIT License** — see [`LICENSE`][license] for details.

---

<div align="center">

**Built with ☕ on Ubuntu + k3s + Cloudflare Tunnel.**  
*From a personal machine to a private cloud — no OS was (permanently) harmed in the process.*

</div>

<!-- ===== Link definitions ===== -->
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: LICENSE
[k3s-badge]: https://img.shields.io/badge/k3s-v1.29-green.svg
[k3s]: https://k3s.io
[cloudflare-badge]: https://img.shields.io/badge/Cloudflare%20Tunnel-free-blueviolet
[cloudflare]: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

[readme]: README.md
[understanding]: docs/00-understanding/README.md
[what-is]: docs/00-understanding/01-what-is-a-private-cloud.md
[architecture]: docs/00-understanding/02-architecture.md
[decisions]: docs/00-understanding/03-design-decisions.md
[constraints]: docs/00-understanding/04-constraints.md
[aws-parity]: docs/00-understanding/05-aws-parity.md
[skills]: docs/01-skills/README.md
[aws-map]: docs/01-skills/02-aws-to-self-hosted-map.md
[setup]: docs/02-setup/README.md
[prereq]: docs/02-setup/00-prerequisites.md
[install-k3s]: docs/02-setup/01-install-k3s.md
[tunnel]: docs/02-setup/02-cloudflare-tunnel.md
[traefik]: docs/02-setup/03-traefik-ingress.md
[services]: docs/03-services/README.md
[first-service]: docs/03-services/01-first-service.md
[security]: docs/04-security/README.md
[observability]: docs/05-observability/README.md
[testing]: docs/06-testing/README.md
[expose]: docs/06-testing/02-expose-service.md
[iacgitops]: docs/07-iac-gitops/README.md
[roadmap]: docs/08-roadmap/README.md
[scripts]: scripts/README.md
[scripts-readme]: scripts/README.md
