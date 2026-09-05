# 04 — Backup & restore (Velero + restic) — and *prove it*

> **Goal:** Back up the cluster and its data, and — critically — **run a real restore drill**. A backup nobody has restored is a lie; a portfolio with a DR drill is rare and impressive.

---

## 1. What to back up

| What | Tool | Target |
|------|------|--------|
| Kubernetes objects (deployments, secrets, configs, CRDs) | **Velero** | MinIO bucket (`s3://backups/velero`) |
| Persistent data (buckets, DBs, vault data) | **restic** (via velero node-agent or CronJob) | MinIO bucket |

> The cloud backups **itself** into MinIO — the self-hosted S3 equivalent doing the AWS Backup job.

---

## 2. Deploy Velero

```bash
kubectl create ns velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update
helm install velero vmware-tanzu/velero \
  -n velero \
  --set-file credentials.secretContents.cloud=deploy/backup/minio-cloud-creds \
  --set configuration.backupStorageLocation.name=default \
  --set configuration.backupStorageLocation.bucket=backups \
  --set configuration.backupStorageLocation.config.s3Url=https://storage.mycloud.com \
  --set configuration.volumeSnapshotLocation.name=default \
  --set configuration.volumeSnapshotLocation.config.s3Url=https://storage.mycloud.com \
  --set snapshotsEnabled=true \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:v1.9.0 \
  --set initContainers[0].volumeMounts[0].name=plugins \
  --set initContainers[0].volumeMounts[0].mountPath=/plugins
```

> Because MinIO is S3-compatible, we use the *AWS* Velero plugin pointed at our endpoint. That's the parity trick paying off twice.

---

## 3. Scheduled backups

```bash
velero schedule create daily-backup --schedule="0 2 * * *" \
  --ttl=720h \
  --include-namespaces=apps,storage,auth,secrets,registry
```
Verify a backup appears:
```bash
velero get backups
velero backup describe daily-backup
```
**restic for volumes** (install node-agent per namespace you want volume snapshots of):
```bash
velero install --uploader-type restic ...   # or follow the CLI node-agent setup
```
Any PV data (MinIO buckets, Keycloak DB, Vault storage) gets a filesystem snapshot. For this project's persistence under `$HOME/k3s-data`, restic copying files to MinIO is the pragmatic net.

---

## 4. The restore drill (DO THIS — it's the proof)

Once a month (or before showing off), run a **disaster rehearsal**:

```bash
# 1. simulate disaster: delete everything
kubectl delete ns apps storage auth secrets registry

# 2. restore from backup
velero restore create --from-backup daily-backup-latest
velero restore describe --details <restore-name>

# 3. assert services are back
kubectl get ns
curl -s https://api.mycloud.com/health
curl -s https://sample.mycloud.com/health
mc ls homecloud/backups      # objects survived
```

> ⚠️ Realistic note: restore **in place** works for objects; volume data restores into storage from restic snapshots. A *full* test on a scratch minikube cluster is the gold standard — document it in `docs/06-testing/restore-drill-log.md` (dates, what worked, what didn't, RTO measured).

---

## 5. Metrics to brag about (honestly)

| Metric | How to report |
|--------|---------------|
| **RPO** (how much data at risk) | scheduled backups nightly → RPO ≈ 24h (or your interval) |
| **RTO** (how long to recover) | measured restore drill time, e.g. "45 min restore+verify" |

Put both numbers in the repo's `docs/06-testing/restore-drill-log.md` — that's real ops documentation.

---

## 6. Portfolio one-liner

> *"Velero backs the cluster into MinIO nightly; restic snapshots volumes; I run monthly restore drills and publish RTO in the repo. Backups are not hypothetical — they've been tested."*

---

## 🔗 Continue reading

► **[Next: 05 — Incident response runbook](05-incident-response.md)**

◄ **[Back to 06 Testing index](README.md)** · [🏠 Repo home](../../README.md)