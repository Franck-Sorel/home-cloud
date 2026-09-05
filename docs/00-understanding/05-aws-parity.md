# 05 — AWS parity

> **Goal of this document:** Map every relevant AWS service to its self-hosted counterpart, explain the mapping, and show how far you can realistically get toward "AWS-grade" on a single machine.

---

## 1. The parity principle

AWS is not one product — it's a **portfolio of managed services** layered on shared primitives: virtual machines, containers, object storage, identity, networking, and monitoring. A private cloud reproduces the *behavior* of those services using self-hosted software, and gets "AWS-grade" reliability from:

- standard practices: health checks, rolling restarts, backups, monitoring, alerts
- declarative control: Kubernetes reconciling desired state forever (self-healing)
- an edge (Cloudflare) taking over the parts you can't do at home: TLS, DDoS, WAF, global edge

> **Honest framing:** You can reach *architecture parity* (same patterns, same APIs to a large degree) and *best-practice parity*. You cannot reach *scale parity* (millions of requests/s, SLA-99.99%) on one box — and that's fine, the portfolio value is in the patterns.

---

## 2. Service-by-service mapping table

| AWS service | Self-hosted equivalent | Runs as | Parity notes |
|-------------|------------------------|---------|--------------|
| **EC2** (VMs) | Pods / containers | Pods | Equivalent unit of compute; k8s = your "EC2 fleet" abstraction |
| **ECS / EKS** (containers) | **k3s** | k3s server + agents | Same Kubernetes API, same YAML/Helm |
| **EBS** (block storage) | local-path-provisioner PV / Longhorn | PVs | Data under `$HOME/k3s-data`; Longhorn = distributed EBS-like w/ snapshots |
| **S3** (object storage) | **MinIO** | Pod | **100% S3 API compatible** — SDKs/tools (awscli, boto3, rclone) work unchanged |
| **EFS** (file storage) | NFS pod / Rook-Ceph | Pods | NFS provisioner available via Helm |
| **IAM** (identity) | **Keycloak / Authentik** | Pod | OIDC/SAML; role/RBAC mapping via k8s RBAC |
| **Cognito** (user pools) | **Keycloak** | Pod | Login, social, MFA |
| **Route 53** (public DNS) | Cloudflare DNS | Managed | Tunnel hostnames managed automatically |
| **Route 53** (internal DNS) | **CoreDNS** | k3s component | In-cluster service discovery |
| **ALB / NLB** (ELB) | **Traefik** + klipper-lb | k3s components | ALB ≈ Traefik L7; NLB ≈ klipper-lb LoadBalancer |
| **API Gateway** | **Traefik** (routes, middlewares, rate-limit) | k3s component | Host/path routing, auth forwarding, throttling |
| **CloudFront / Global Accelerator** | **Cloudflare Tunnel + edge** | Managed | CDN, DDoS, edge TLS |
| **Lambda** (serverless) | **OpenFaaS / Knative** | Pods | Container-based functions, scale-to-zero possible |
| **ECR** (registry) | **Harbor / Gitea** | Pods | Harbor has scanning + replication; Gitea adds git |
| **Secrets Manager / KMS** | **HashiCorp Vault** | Pod | Dynamic secrets + transit encryption |
| **CodePipeline / CodeDeploy** | **GitHub Actions + ArgoCD** | External + pod | GitOps is the modern equivalent; PR-driven |
| **CloudWatch Logs** | **Loki + Grafana** | Pods | LogQL ≈ Log Insights |
| **CloudWatch Metrics / Alarms** | **Prometheus + Alertmanager + Grafana** | Pods | k8s-exporter covers Node/Pod/Service metrics |
| **CloudTrail** (audit) | kube-apiserver audit logs + Traefik access logs | k3s/ingress | Enable audit logging → send to Loki |
| **X-Ray** (tracing) | **Jaeger / OpenTelemetry** | Pods | OTel Collector; optional at this scale |
| **AWS Backup** | **Velero + restic** | Pods | Velero = cluster backup; restic = data backup/cron |
| **WAF / Shield** | **Cloudflare WAF** + Traefik rate-limit | Managed edge + pod | Edge WAF rules, managed rulesets, IP rules |
| **SQS / SNS** (messaging) | **NATS / Redis Streams / RabbitMQ** | Pods | NATS JetStream = lightweight, k8s-native |
| **RDS / DynamoDB** | **PostgreSQL / Redis** (as pods) | Pods | Operator-managed (e.g. CloudNativePG, Zalando) |
| **Managed Grafana** | **Grafana OSS** | Pod | Same dashboards/alerts, self-hosted |

---

## 3. What "AWS-grade" actually means here (and what it doesn't)

**We DO get the patterns:**
- ✅ Declarative, self-healing infrastructure (k8s reconciliation)
- ✅ Health checks + rolling deployments + zero-downtime release strategy
- ✅ Secret management, least-privilege RBAC, network policies
- ✅ Centralized logs, metrics, alerts, dashboards
- ✅ Backup/restore procedures & tested disaster recovery
- ✅ GitOps: infrastructure described in code, drive by pull-requests
- ✅ TLS everywhere, fronted by a globally-distributed edge

**We do NOT get:**
- ❌ Multi-AZ redundancy (unless adopting the roadmap multi-node plan)
- ❌ Elastic horizontal scaling (single node = limited by its resources)
- ❌ A 99.99% SLA (home power/internet is not SLA-backed)
- ❌ Managed patching, managed control-plane HA
- ❌ Global low-latency presence — edge is Cloudflare's, but origins sit at home

> **The honest one-liner to tell recruiters:**
> *"I built a private cloud with the same architecture patterns as AWS — Kubernetes, ingress gateway, S3-compatible storage, OIDC identity, secrets management, observability, and GitOps — running on a single-box k3s cluster, reached through a zero-trust tunnel. It's not AWS-scale, but it's AWS-shaped."*

---

## 4. Parity ladder (milestones, small → large)

| Rung | What you've replicated | Proof |
|------|------------------------|-------|
| 1 | Containers + orchestration (EKS-ish) | 2+ replicas behind a Service, rolling updates |
| 2 | Ingress/API gateway (ALB/API GW) | `storage.api...` / `api...` routes via Traefik |
| 3 | Object storage (S3) | MinIO reachable via S3 SDK from outside |
| 4 | Identity (IAM/Cognito) | SSO login via Keycloak protecting a service |
| 5 | Secrets (Secrets Manager) | App reads dynamic secret from Vault |
| 6 | Observability (CloudWatch) | Logs+metrics dashboard; alert fires when pod goes down |
| 7 | Registry + CI/CD + GitOps | Pushing an image → ArgoCD deploys it automatically |
| 8 | Backups & DR (AWS Backup) | `velero backup` restores the cluster in a test |
| 9 | Serverless (Lambda) | OpenFaaS function invoked over the public URL |
| 10 | HA / DR (multi-node, worst reality) | 2-node k3s, service survives a node loss |

> Each rung maps to a doc: rungs 1–2 → [`02-setup`](../02-setup/README.md), 3–7 → [`03-services`](../03-services/README.md) + [`04-security`](../04-security/README.md) + [`07-iac-gitops`](../07-iac-gitops/README.md), 8–9 → [`06-testing`](../06-testing/README.md) + [`08-roadmap`](../08-roadmap/README.md).

---

## 5. Reference architecture (what the "AWS-shaped" cluster looks like)

```
                    ┌────────────── Cloudflare (edge) ──────────────┐
                    │  DNS · DDoS · WAF · TLS · Zero-Trust Access   │
                    └──────────────────────┬────────────────────────┘
                                           │ tunnel (outbound)
┌────────────────── k3s SINGLE NODE ───────┴──────────────────────────────────┐
│  SYSTEM NAMESPACES                       │ SERVICE NAMESPACES                │
│  kube-system: Traefik, CoreDNS,          ├── auth:    Keycloak               │
│    servicelb, local-path, metrics        ├── storage: MinIO (S3)             │
│  default: cloudflared (tunnel)           ├── secrets: Vault                  │
│  monitoring: Prometheus, Loki, Grafana   ├── registry: Harbor                │
│  gitops: ArgoCD (optional)               ├── serverless: OpenFaaS            │
│  backups: Velero + restic cron            ├── apps:    my-api, my-web        │
└──────────────────────────────────────────┴───────────────────────────────────┘
```

---

## 6. Decisions you'll see echoed elsewhere

- [`01-skills/02-aws-to-self-hosted-map.md`](../01-skills/02-aws-to-self-hosted-map.md) — the table above + learning links per service
- [`02-architecture.md`](02-architecture.md) — the layers these services live in
- [`08-roadmap`](../08-roadmap/README.md) — what a "fuller" AWS parity would require (HA nodes, managed DNS-resilience, etc.)

---

## 🔗 Continue reading

► **[Next section: 01 — Skills](../01-skills/README.md)**

◄ **[Back to 00 Understanding index](README.md)** · [🏠 Repo home](../../README.md)