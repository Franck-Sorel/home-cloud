# 📜 Scripts

Reusable helper scripts for the private cloud. Each is a thin, documented wrapper around the guides in [`docs/02-setup`](../docs/02-setup/README.md) and [`docs/06-testing`](../docs/06-testing/README.md).

> **Usage rule:** always read the corresponding doc first. Scripts assume you already ran the manual steps (they are convenience + verification, not replace-the-manual).

---

## Available scripts

| Script | Purpose | Doc |
|--------|---------|-----|
| [`install-cloudflared.sh`](install-cloudflared.sh) | Download/install `cloudflared` CLI client on the host (not the pod) | [`docs/02-setup/02-cloudflare-tunnel.md`](../docs/02-setup/02-cloudflare-tunnel.md) |
| [`healthcheck.sh`](healthcheck.sh) | Five-layer health check (host → cluster → tunnel → TLS → routes → services) | [`docs/06-testing/00-verify-cluster.md`](../docs/06-testing/00-verify-cluster.md) |
| [`smoke.sh`](smoke.sh) | Lightweight smoke test for use in CronJobs / CI | [`docs/06-testing/03-smoke-and-e2e.md`](../docs/06-testing/03-smoke-and-e2e.md) |
| [`backup.sh`](backup.sh) | Trigger a Velero backup schedule and verify it completed | [`docs/06-testing/04-backup-restore.md`](../docs/06-testing/04-backup-restore.md) |

---

## Before you run

```bash
chmod +x scripts/*.sh
./scripts/healthcheck.sh
```

Scripts exit non-zero on failure (suitable for CI/CronJob alerting).

---

## Adding a script

1. Put it in `scripts/` with a `set -euo pipefail` header.
2. Reference the doc section it automates in a header comment.
3. Update this README table.
4. Never put secrets in scripts — read them from env/k8s Secrets.

---

◄ **[Back to repository home](../README.md)**