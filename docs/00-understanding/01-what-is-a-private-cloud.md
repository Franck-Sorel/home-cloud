# 01 — What is a private cloud?

> **Goal of this document:** Give you the mental model you need before touching a single command. You will understand *what* a private cloud is, *why* AWS works the way it does, and *how* that can be recreated on a single local machine.

---

## 1. The big picture

A **cloud** is, at its heart, just a **pool of compute, storage, and networking** that can be carved up and rented out on demand — plus a layer of services on top that make that pool useful to developers (authentication, storage, containers, databases, monitoring, …).

AWS *looks* magical, but every one of its services runs on the same primitives you have on your desk:

| AWS capability | Underlying primitive |
|----------------|---------------------|
| EC2 (virtual servers) | Virtualization (VMs) on physical servers |
| EKS / ECS (containers) | Container runtimes + orchestration |
| S3 (object storage) | Software-defined storage |
| IAM (identity) | An authentication/authorization server |
| API Gateway | A reverse proxy with routing & policy |
| Lambda | A function scheduler |
| CloudWatch | Log/metric collection + dashboards |

> **The insight:** AWS is *not* magic hardware. It is **a lot of standard Linux software**, wrapped in control planes, redundancy, and billing. You can run the **same kind of software** on your own machine — you just have to be responsible for the parts AWS handles for you (redundancy, uptime, patching, backup).

---

## 2. What we are going to build

A **self-hosted private cloud** on a single Ubuntu machine that provides the AWS-like building blocks:

| What | AWS name | What we'll run |
|------|----------|----------------|
| Object storage bucket | S3 | **MinIO** |
| Identity & access (login, SSO, MFA) | IAM / Cognito | **Keycloak** |
| Container orchestration | EKS | **k3s** |
| API gateway / load balancer | ALB / API Gateway | **Traefik** |
| Secrets storage | Secrets Manager | **HashiCorp Vault** |
| Container image registry | ECR | **Harbor / Gitea** |
| Serverless functions | Lambda | **OpenFaaS / Knative** |
| Logging & monitoring | CloudWatch | **Loki + Grafana, Prometheus** |
| DNS | Route 53 | **CoreDNS (internal) + your registrar (external)** |

> The *orchestrator* that holds all of this together is **Kubernetes** — specifically **k3s**, a single-binary, lightweight distribution designed for edge/IoT machines, perfect for a laptop or small server.

---

## 3. The shape of the system

```
Internet
   │
   │  ① You type  api.mycloud.com
   ▼
② Cloudflare Edge  ──  TLS termination · DDoS protection · WAF
   │
   │  ③ Encrypted outbound "tunnel" connection (no ports opened inbound!)
   ▼
④ Traefik Ingress (in k3s)  ──  routes by hostname & path
   │
   ├──► MinIO      (storage.mycloud.com)
   ├──► Keycloak   (auth.mycloud.com)
   ├──► Vault      (secrets.mycloud.com)
   └──► my-api     (api.mycloud.com)
```

The key trick is **step ③**: instead of *opening a port* in your router to let traffic in (insecure, needs a public IP, breaks under CGNAT), an agent called **cloudflared** runs *inside* your cluster and makes a **long-lived outbound connection to Cloudflare's edge**. When a request arrives at Cloudflare for your domain, Cloudflare forwards it *down that already-open tunnel* to your cluster. **Your machine never needs a public IP and never opens an inbound port.**

---

## 4. What "do not touch the OS" really means

The constraint is:

> **Everything runs in containers/pods. The Ubuntu OS underneath stays as it was.**

Why this matters and what it forces — see [`04-constraints.md`](04-constraints.md). The short version:

- ✅ Allowed: running container runtimes, pulling images, starting pods, running user-space processes, writing to your own home directory.
- ❌ Avoided: `apt install` of system packages, editing `/etc/`, restarting `systemd` services, modifying `ufw`/`iptables`, installing kernel modules globally, changing host network config.

> ⚠️ **Honest caveat up front:** K3s itself needs a few host-level requirements (a user-space container runtime, and for some features a small systemd unit to keep it alive). We document the *minimal, well-scoped* touches and treat everything else as off-limits. There is a spectrum between "literally zero changes" and "modifying the OS" — we stay as close to zero as is practical and honest.

---

## 5. Why this is a great portfolio project

Building this end-to-end demonstrates, to any recruiter looking at your GitHub:

- **Cloud-native fundamentals** — containers, Kubernetes, ingress, deployments, rolling updates
- **Networking** — DNS, TLS, reverse proxying, zero-trust tunnels
- **Security** — least-privilege, secrets management, auth protocols (OIDC), WAF
- **Production mindset** — observability, backups, IaC, GitOps
- **Infrastructure engineering** — the ability to run "production-grade" software at home

It is the difference between someone who can write an API and someone who can *run* a platform.

---

## 6. What this is *not*

Be honest with expectations:

- ❌ It is **not** an AWS clone — no elastic scaling to thousands of nodes, no managed redundancy, no SLA.
- ❌ It is **not** production-grade for anyone but yourself/family/portfolio traffic. A single home machine is a *single point of failure*.
- ❌ It is **not** "no OS touch at all" — k3s and containers need some minimal host prerequisites. We keep them documented and minimal.

✅ It **is** a legit, working, secure-by-design mini-cloud with the *same architecture patterns* as AWS — which is exactly what makes it portfolio-worthy.

---

## 🔗 Continue reading

► **[Next: 02 — Architecture](02-architecture.md)**

◄ **[Back to 00 Understanding index](README.md)** · [🏠 Repo home](../../README.md)