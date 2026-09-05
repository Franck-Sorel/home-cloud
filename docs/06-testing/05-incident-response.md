# 05 — Incident response runbook

> **Goal:** A written, practiced plan for "the site is down" — because the diff between a hobby and a platform is *how you behave when it breaks*. This is your SRE muscle.

---

## 1. The runbook (copy into `docs/06-testing/runbook-oncall.md`)

### T-0: Acknowledge
- Alert fires (`PodDown`, `HighRate429`, smoke failure, UptimeRobot down)
- **Say it out loud**: "The public URL is degraded." Document current time + first symptom.

### T-5: Classify
| Class | Meaning | Response |
|-------|---------|----------|
| **P1** | public URL broken | drop everything, fix |
| **P2** | degraded (high latency/errors) | next-work-slot, but timeboxed |
| **P3** | cosmetic/non-blocking | backlog |

### T-10: Diagnose (top suspects for this architecture)
```bash
# 1. is it YOUR machine? 
ssh home && uptime && librechecker 2>/dev/null; echo; systemctl status k3s --no-pager | head
# 2. is the cluster up? 
kubectl get nodes
# 3. is the tunnel up?
kubectl get pods -n cloudflared && kubectl logs -n cloudflared deploy/cloudflared --tail 20
# 4. is Traefik routing?
kubectl logs -n kube-system deploy/traefik --tail 50
# 5. is the app crash-looping?
kubectl get pods -n apps
```

### T-20: Fix (the fastest safe move first)
```bash
# Most likely fixes, cheapest first:
kubectl rollout undo deploy/sample-api -n apps           # bad release
kubectl scale deploy/sample-api -n apps --replicas=2     # scaling shock
kubectl delete pod -n cloudflared -l app=cloudflared     # stale tunnel
sudo systemctl restart k3s                               # last resort, host touch — log it
```

> Every fix goes into the **runbook log**: symptom, diagnosis, action, result, time.

### T-30: Verify + communicate
- `./scripts/healthcheck.sh` green
- `curl https://sample.mycloud.com/health` 200
- Write the **post-mortem** (2 paragraphs): what happened, what will prevent it next time.

---

## 2. The 5 most likely incidents (pre-written)

| # | Incident | Typical cause | Fix |
|---|----------|---------------|-----|
| 1 | `502 / connection refused` on a public route | app pod not Ready or scaled to 0 | `rollout undo` / `kubectl scale` |
| 2 | Intermittent timeouts | tunnel dropped | delete cloudflared pod (re-registers) |
| 3 | `429` everything | rate-limit threshold too low | raise middleware `average`/`burst` |
| 4 | Node `NotReady` | machine reboot / k3s service died | `sudo systemctl restart k3s` |
| 5 | `403` unexpectedly on MinIO route | credentials rotated | check MinIO secret alignment |

---

## 3. Postmortem template (`docs/06-testing/postmortem-TEMPLATE.md`)

```markdown
# Postmortem — <date> — <title>
## Impact
- duration, URL(s) affected, users affected (≈ you)
## Timeline
| time | event |
## Root cause (1 line)
## What worked
## What didn't
## Actions (owner + date)
- [ ] …
```

> A single good postmortem in the repo is worth more than a dozen dashboards in an interview.

---

## 4. Portfolio one-liner

> *"I keep a written runbook with pre-built fix sequences for the five likeliest failures, practice it in chaos drills, and write a two-paragraph postmortem after every incident."*

---

## 🔗 Continue reading

► **[Next section: ♾️ 07 — IaC & GitOps](../07-iac-gitops/README.md)** — make all of this reproducible from code

◄ **[Back to 06 Testing index](README.md)** · [🏠 Repo home](../../README.md)