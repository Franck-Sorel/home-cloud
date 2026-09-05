# 02 — AWS ↔ self-hosted map

> **Goal of this document:** The full row-by-row mapping of AWS services → self-hosted equivalents, *with rationale and learning links*. This is the "translation dictionary" of the whole project.

---

## The master table

| # | AWS service | Purpose | Self-hosted equivalent | How it runs | Why this choice |
|---|-------------|---------|------------------------|-------------|-----------------|
| 1 | **EC2** | VMs | Pods (containers) | k3s | Pods are the AWS EC2 "unit" here; k8s gives you the fleet control plane |
| 2 | **EKS / ECS** | Container orchestration | **K3s** | single binary | Lightweight, CNCF K8s; bundles Traefik + storage |
| 3 | **EBS** (block) | Persistent disk | **local-path provisioner / Longhorn** | k3s bundled / Helm | PV under `$HOME/k3s-data`; Longhorn for snapshots later |
| 4 | **S3** | Object storage | **MinIO** | pod | 100% S3 API — boto3/awscli/rclone work unchanged |
| 5 | **EFS** (file) | Shared filesystem | NFS server pod / Rook-Ceph | pod | Only needed if apps require shared POSIX FS |
| 6 | **IAM** | Identity/roles/policies | **Keycloak / Authentik** | pod | OIDC/SAML, MFA, SSO; k8s RBAC = IAM policies for cluster |
| 7 | **Cognito** | User pools | **Keycloak** | pod | Login, social providers, MFA |
| 8 | **Route 53** (public) | DNS | **Cloudflare DNS** | Cloudflare-managed | tunnel hostnames handled automatically |
| 9 | **Route 53** (internal) | Service discovery | **CoreDNS** | k3s bundled | resolves `*.svc.cluster.local` |
| 10 | **ALB** (L7 LB) | HTTP routing/LB | **Traefik** | k3s bundled | host/path routing + middleware |
| 11 | **NLB** (L4 LB) | TCP/UDP LB | **klipper-lb (servicelb)** | k3s bundled | stable LocalLB IP without MetalLB |
| 12 | **API Gateway** | API management | **Traefik** (routes, rate-limits, auth) | k3s bundled | gateway patterns via middleware |
| 13 | **CloudFront / Edge** | CDN, WAF, TLS at edge | **Cloudflare + Tunnel** | Cloudflare-managed | DDoS, TLS, WAF, global edge — for free |
| 14 | **Lambda** | Serverless functions | **OpenFaaS / Knative** | pods | container functions, scale to zero |
| 15 | **ECR** | Container registry | **Harbor / Gitea** | Helm | Harbor: scanning + replication; Gitea: registry + git |
| 16 | **Secrets Manager / KMS** | Secrets + encryption | **HashiCorp Vault** | pod + operator | dynamic secrets, leases, transit encryption |
| 17 | **CodePipeline / CodeDeploy** | CI/CD | **GitHub Actions + ArgoCD** | external + pod | pull-based GitOps; PR = deploy |
| 18 | **CloudWatch Logs** | Centralized logs | **Loki + Grafana** | Helm | LogQL querying, cheap at home scale |
| 19 | **CloudWatch Metrics** | Metrics/alerts | **Prometheus + Alertmanager** | kube-prometheus-stack | standard k8s monitoring |
| 20 | **CloudWatch Dashboards** | Visualization | **Grafana** | Helm | dashboards + alerts + SSO via Keycloak |
| 21 | **CloudTrail** | API auditing | **k8s audit logs + Traefik access logs** | k3s + ingress | ship to Loki |
| 22 | **X-Ray** | Tracing | **Jaeger + OpenTelemetry** | Helm | optional at this scale; OTel anything later |
| 23 | **AWS Backup** | Backups | **Velero + restic** | Helm + CronJobs | cluster backup + data backup, *tested* restore |
| 24 | **WAF / Shield** | Web firewall/DDoS | **Cloudflare WAF** + **Traefik rate-limit** | edge + pod | managed rulesets at edge; layer-7 throttling in-cluster |
| 25 | **SQS / SNS** | Messaging | **NATS JetStream / Redis Streams / RabbitMQ** | Helm | lightweight, k8s-native |
| 26 | **RDS / DynamoDB** | Managed databases | **PostgreSQL / Redis (operator-managed)** | pods (CloudNativePG, Zalando) | mature operators give RDS-like automation |
| 27 | **Managed Grafana/Prom** | Managed observability | **Grafana OSS + Prometheus OSS** | Helm | same features, self-hosted |

---

## Notes on the trickiest mappings

### S3 → MinIO
The killer feature is **API compatibility**: your existing `boto3`, `aws s3`, `rclone`, `mc` (MinIO client), and S3 wordpress plugins all point at `storage.mycloud.com` with custom endpoint config and *work*. That is true AWS-parity without changing your app code.

### IAM → Keycloak + k8s RBAC
Two subsystems:
- **Human/application identity (IAM/Cognito):** Keycloak issues JWTs (OIDC), handles SSO/MFA/social login. Traefik *forward-auth* middleware can require a valid session or JWT before traffic reaches a service.
- **Cluster-level authorization (IAM roles):** Kubernetes **RBAC** — `Role`, `RoleBinding`, `ClusterRole` — controls what a *service account* can do to the cluster. That's your "IAM Policy" analog for the control plane.

### Lambda → OpenFaaS
OpenFaaS gives `faas-cli` auth, an API gateway, and functions as containers behind a watchdog. Because functions are just containers, any language works. Scale-to-zero is available but rarely needed at home.

### Route 53 ↔ two halves
- **Public:** Cloudflare DNS + Tunnel. Create a tunnel with hostname `api.mycloud.com` and Cloudflare adds/manages the record automatically. No manual A-record fiddling.
- **Internal:** CoreDNS resolves service names inside the cluster (`minio.storage.svc.cluster.local`).

---

## What still needs real infrastructure (honest gaps)

Even with a perfect mapping, some *managed* properties cannot be replicated on one home machine:

| Managed property | Reality at home | Mitigation |
|------------------|-----------------|------------|
| Multi-AZ redundancy | Single machine = single point of failure | roadmap: multi-node k3s; UPS |
| Elastic scale-out | Fixed physical resources | right-size + document capacity |
| SLA / uptime guarantees | Home power/ISP | monitoring + alerts + honest reporting |
| Managed patching | You patch (containers help: `kubectl rollout`) | keep base images updated |

---

## 🔗 Continue reading

► **[Next: 03 — Skills checklist](03-skills-checklist.md)**

◄ **[Back to 01 Skills index](README.md)** · [🏠 Repo home](../../README.md)