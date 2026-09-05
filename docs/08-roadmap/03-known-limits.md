# 03 — Known limits (honest boundaries)

> **Goal:** Say clearly what this platform *doesn't* do — so a future employer or collaborator never thinks you (or the stack) overpromise. Honesty about limits is itself a signal.

---

## Reality limits (can't fix at home)

| Limit | Why | Current posture |
|-------|-----|-----------------|
| **Single point of failure** | one machine (power/disk/network) | UPS; document RPO/RTO; roadmap B4 for multi-node |
| **Home-ISP reliability** | cable fiber, monthly IP changes, upstream outages | tunnel survives IP changes; UptimeRobot + alerts; fallback VPS (roadmap D) |
| **Scale** | finite CPU/RAM/disk on a single box | resource limits, monitored usage, honest capacity notes |
| **No AWS-grade SLA/latency** | you're not AWS | "best-effort, monitored" label; alerts on drift |
| **Not a managed platform** | no auto-patching, no support team | you = support (docs + runbook make that viable) |

## Design-constraint limits (by choice)

| Limit | Why | Worked around by |
|-------|-----|------------------|
| Networking CNI enforcement | k3s default flannel has **no** NetworkPolicy enforcement | swap to Cilium for a default-deny policy set (roadmap B3); currently documented as a gap |
| Single-node HA | one-box k3s = control plane + worker same node | roadmap B4 + Longhorn (B5) |
| "No OS touch" ceiling | k3s itself needs that one systemd unit | documented, minimal, scoped; everything else is containers |
| Cloudflare dependency | tunneling + DNS + WAF live at the edge with them | free tier is generous; VPS route documented as the alternative |
| Home router / CGNAT | some ISPs also block even egress/privacy issues | tunnel typically transparent; document + fallback if it bites |

## Cloud/tooling-specific caveats

| Caveat | Note |
|--------|------|
| Cloudflare tunnel **token vs credentials JSON** | new-style tokens being pushed; repo uses classic flow + flags migration |
| MinIO single-pod mode = **no distributed erasure** | fine for backups; document before relying on it for "production" |
| Keycloak H2 by default | embedded DB is demo-grade; roadmap B2 upgrades to Postgres |
| Vault is **sealed on restart** unless you auto-unseal | unseal keys in password manager; roadmap B2/bootstrapping for reliability |
| OpenFaaS scale-to-zero may recall cold-warm times | acceptable at home scale; document latency for cold functions |

---

## The honest two-paragraph "limits" statement (copy-paste for README/about)

> "Home-Cloud reproduces the *architecture patterns* of AWS — Kubernetes, ingress gateway, S3-compatible storage, OIDC identity, secrets management, observability, GitOps — but it is not AWS. It runs on a single box (or two, with the HA roadmap), so it is a single-ish point of failure subject to home power and internet. It does not offer elastic scale or an SLA. **What it offers is the same operational discipline**: declared-as-code, git-deployed, monitored, alerting, backed up, and *tested-in-restore*."

---

## 🔗 Back up to the top

► **[Back to 08 Roadmap index](README.md)** · [🏠 Repo home](../../README.md)