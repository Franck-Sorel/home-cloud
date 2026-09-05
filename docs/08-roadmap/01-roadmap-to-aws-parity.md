# 01 — Roadmap to AWS parity

> **Goal:** The concrete milestones that take you from "single-node private cloud (AWS-*shaped*)" to "genuinely resilient multi-node private cloud (more AWS-*grade*)." Each line has a definition-of-done.

---

## The milestone ladder

### Phase A — Foundations (the section 02–06 build) ✅
- [x] k3s single node, tunnel, Traefik, first public service
- [x] MinIO, Keycloak, Vault, registry, serverless, observability
- [x] Security hardening, backups, smoke/E2E, runbook

*Done when:* the docs in 00–06 are green and a live URL is public.

### Phase B — Resiliency (the big next push) 🚧

| # | Milestone | Definition of done |
|---|-----------|--------------------|
| B1 | **UPS + graceful shutdown** | graceful `k3s` drain on power-loss; RPO/RTO documented |
| B2 | **Postgres for Keycloak/Vault** | no embedded H2; DB creds via Vault dynamic secrets |
| B3 | **Cilium (NetworkPolicy enforcement)** | a `default-deny`-first policy set actually enforced |
| B4 | **Mutli-node HA k3s** | 2nd machine joins (agent or server); a node can be lost with zero downtime |
| B5 | **Longhorn (distributed storage)** | PVs replicated 3x; node loss doesn't lose data |
| B6 | **cert-manager + Full-strict** | origin TLS between Cloudflare and Traefik; no cleartext legs |
| B7 | **GitOps full adoption** | ArgoCD + Terraform + SOPS; a PR moves the platform (sections 07 done) |

> **Milestones B1–B7 are the honest gap between "portfolio demo" and "I'd actually run my backup/VPN on this."**

### Phase C — AWS-service coverage extras 🧩

| AWS | Add | Why |
|-----|-----|-----|
| SQS/SNS | NATS JetStream | event pipelines, async apps |
| RDS HA | CloudNativePG (Patroni) | PostgreSQL HA via Vault creds |
| Route 53 failover | Cloudflare **DNS failover + health checks** | route to a 2nd tunnel/VPS if home dies |
| Global edge | Cloudflare **Argo/Arid cargo + cache** | speed up static assets |
| Athena/Analytics | Druid/ClickHouse (or keep MinIO + Parquet) | log analytics at the edge of scope |

### Phase D — "Full AWS-grade" ambitions 🌟
- **Multiple exit nodes**: 2 VPS tunnels (Hetzner/DO) for tunnel-level HA
- **Active/active**: two k3s sites + DNS failover (overkill at home, but *great* to have attempted)
- **Managed povider parity**: auto-updates (Renovate/Dependabot), canary via Argo Rollouts, SLOs/SLIs dashboards

---

## Suggested sequencing (with effort)

```
Now ───────────────────────────────────────────────► 6 months
  B1  B2  B6  B7 | B3  B5  B4 | B4' (3-node)  B4'' (DNS failover)
  <~2 weeks>      <~1 mo>       <~2-4 mo>
```

B1/B2/B6 (2 wks) — low effort, high credibility.  
B3/B5/B4 (1 mo) — the "real resiliency" blockers.  
B4'/D (2-4 mo) — genuinely fits a "cloud on home hardware" story.

---

## Every milestone's exit criteria (template)

```markdown
## Milestone B4 — Multi-node HA
- [ ] second machine running k3s agent
- [ ] workloads scheduled across nodes (nodeSelector spread)
- [ ] `kubectl drain <node1>` → apps keep serving on node2 (no downtime)
- [ ] DNS/tunnel continues to hit the surviving node
- [ ] documented in `docs/08-roadmap/` with a dated test log
```

> Track each on the repo's `docs/08-roadmap/progress.md` (a table with status columns). Public, dated, honest → strong portfolio signal.

---

## 🔗 Continue reading

► **[Next: 02 — Alternatives considered](02-alternatives-considered.md)**

◄ **[Back to 08 Roadmap index](README.md)** · [🏠 Repo home](../../README.md)