# 03 — Smoke & E2E tests

> **Goal:** Make "it works" repeatable — automated smoke and end-to-end tests you run after every deploy, in CI if you want. This is your CodeDeploy-style verification.

---

## 1. The test tiers

| Tier | What | Runs |
|------|------|------|
| **Smoke** | cluster up, key pods ready, tunnel up, route reachable | every 5 min (CronJob), or before release |
| **E2E** | actual app flow through the public URL (login → call → storage → db) | on every deploy / CI |
| **Chaos-lite** | kill a pod → it comes back; kill tunnel → it reconnects | periodic / before demos |

---

## 2. Smoke tests (script + CronJob)

`scripts/smoke.sh` (in repo) — asserts in order:

```bash
kubectl get nodes | grep -q Ready
kubectl get pods -A | grep -c Running > 3
curl -sf https://hello.mycloud.com/ > /dev/null
curl -sf https://api.mycloud.com/health > /dev/null
curl -sf https://storage.mycloud.com/ > /dev/null || true   # 403 is OK (auth)
echo "SMOKE OK"
```

Run as a CronJob every 5 minutes (and alert if it fails):

```yaml
# deploy/testing/smoke-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: smoke
  namespace: monitoring
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: smoke
              image: ghcr.io/<you>/smoke:latest   # or alpine+kubectl curl
              command: ["./smoke.sh"]
```

Prometheus alert `KubeJobFailed` already fires for failing CronJobs (section 05 has an example rule).

---

## 3. E2E test (the app flow)

`examples/mynotes-app/tests/e2e.sh` does the full loop *publicly*:

```bash
# 1. auth
JWT=$(curl -s -X POST https://auth.mycloud.com/realms/mynotes/protocol/openid-connect/token \
        -u mynotes-client:secret \
        -d grant_type=password -d username=test@home -d password=... | jq -r .access_token)

# 2. api (jwt required)
curl -s -H "Authorization: Bearer $JWT" https://api.mycloud.com/notes | jq length
# 3. create note
curl -s -X POST -H "Authorization: Bearer $JWT" https://api.mycloud.com/notes -d '{"title":"e2e"}'
# 4. storage: upload to MinIO
curl -s -X POST -H "Authorization: Bearer $JWT" https://api.mycloud.com/files \
      -F file=@tests/sample.txt
# 5. confirm the object exists via S3 (mc)
mc ls homecloud/mynotes | grep sample.txt
echo "E2E OK"
```

> Run from **CI** too (GitHub Actions `workflow_dispatch` or after push → the `07-iac-gitops` section wires it). If the E2E fails a release, your GitOps "promotion to live" can prevent the merge.

---

## 4. Chaos-lite (the "AWS-grade" resilience claim)

```bash
# kill the app pods → they self-heal
kubectl delete pods -n apps -l app=sample-api
kubectl wait --for=condition=Ready pod -l app=sample-api -n apps --timeout=60s
curl -s https://sample.mycloud.com/health   # 200 again

# kill the tunnel → auto-reconnect
kubectl delete pod -n cloudflared -l app=cloudflared
sleep 45
curl -s https://hello.mycloud.com/          # 200 again (new connection registered)
```

Log the results in `docs/06-testing/chaos-lite-results.md` — dated + green. That's your "self-healing" proof.

---

## 5. Portfolio one-liner

> *"A smoke CronJob checks the platform every 5 minutes; an end-to-end test walks login→API→storage over the public URL on every deploy; chaos-lite drills prove pods and tunnels self-heal."*

---

## 🔗 Continue reading

► **[Next: 04 — Backup & restore drill](04-backup-restore.md)**

◄ **[Back to 06 Testing index](README.md)** · [🏠 Repo home](../../README.md)