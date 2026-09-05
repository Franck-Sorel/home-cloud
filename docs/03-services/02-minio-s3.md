# 02 — MinIO (S3-compatible object storage)

> **Goal:** Deploy MinIO — your self-hosted **S3** — on the cluster, expose it at `storage.mycloud.com`, and verify with the actual `aws`/`boto3` S3 tooling.

---

## 1. What you get

| AWS | Self-hosted | Notes |
|-----|-------------|-------|
| S3 | **MinIO** | 100% S3 API compatible: `aws s3`, `boto3`, `rclone`, `mc` all work against it |

It runs as a pod, writes to a **PersistentVolume** (→ `$HOME/k3s-data`). You can later add replicas + erasure-coding for durability (see `08-roadmap`).

---

## 2. Deploy (2 options)

### Option A — Helm (recommended)
```bash
kubectl create ns storage

helm repo add minio https://operator.min.io/
helm repo update
helm install minio minio/minio \
  -n storage \
  -f deploy/storage/minio-values.yaml
```
`deploy/storage/minio-values.yaml` (in repo):
```yaml
resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { cpu: 1, memory: 2Gi }
persistence:
  size: 20Gi
  storageClass: local-path
ingress:
  enabled: false          # we manage routing via Traefik IngressRoute
consoleIngress:
  enabled: false
service:
  type: ClusterIP
environment:
  MINIO_ROOT_USER: <your-user>
  MINIO_ROOT_PASSWORD: <your-password>   # change me! or use a Secret
```

### Option B — Plain YAML (works, more explicit)
Reference manifests: `deploy/storage/minio-deployment.yaml`, `minio-service.yaml`, `minio-pvc.yaml`. Same result: a `minio` StatefulSet/Deployment + Service `minio.storage.svc.cluster.local:9000`.

---

## 3. Route it through Traefik

`deploy/storage/minio-ingressroute.yaml`:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: minio
  namespace: storage
spec:
  entryPoints: [ web ]
  routes:
    - match: Host(`storage.mycloud.com`) && PathPrefix(`/`)
      kind: Rule
      middlewares:
        - name: security-and-limits
          namespace: apps
      services:
        - name: minio
          port: 9000
  # (console at port 9001 via a separate IngressRoute if you like:
  #  Host(`storage-console.mycloud.com`) → port 9001)
```
> Remember the tunnel already routes `*.mycloud.com` → Traefik, so only this IngressRoute is needed. Verify with:
> ```bash
> curl -I https://storage.mycloud.com/   # should get a MinIO XML listing / 403 (auth)
> ```

---

## 4. Verify with real S3 tooling

### Using the MinIO client: `mc`
```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc && sudo mv mc /usr/local/bin/
mc alias set homecloud https://storage.mycloud.com <root-user> <root-password>
mc mb homecloud/backups
mc cp somefile homecloud/backups/
mc ls homecloud/backups/
```

### Using the actual AWS CLI (proves S3-parity)
```bash
export AWS_ACCESS_KEY_ID=<root-user>
export AWS_SECRET_ACCESS_KEY=<root-password>
aws --endpoint-url https://storage.mycloud.com s3 mb s3://backups
aws --endpoint-url https://storage.mycloud.com s3 cp myfile s3://backups/
aws --endpoint-url https://storage.mycloud.com s3 ls
```

🎉 **A real S3-compatible bucket, reached over the public HTTPS URL.** Applications written for S3 "just work" — that's the AWS-parity proof.

---

## 5. "Buckets" & lifecycle (aws-like knobs you get)

- **Versioning**: `mc version enable homecloud/backups`
- **Lifecycle** (expire/transition): MinIO supports S3 lifecycle policies on the console/API
- **Retention**: object locking (WORM) on the console
- **Policy (bucket/IAM-like)**: MinIO console → Identity/Access → Policies (they mimic S3 policies JSON)

> These features are how you later back up the whole cluster (Velero → this MinIO — see [`06-testing/04-backup-restore.md`](../06-testing/04-backup-restore.md)).

---

## 6. Hardening reminders (full guide in section 04/05)

- [ ] Change the default `MINIO_ROOT_*` (never use "minioadmin/minioadmin")
- [ ] Put credentials in a **Secret**, not the chart values
- [ ] Enable TLS at Traefik (Full-strict) or rely on Cloudflare edge (fine for now)
- [ ] Restrict the console to an internal auth-protected subdomain, not public
- [ ] Add a `NetworkPolicy` later to limit which pods can reach MinIO

---

## 7. Portfolio one-liner

> *"I run an S3-compatible object store (MinIO) behind my Traefik gateway; the AWS CLI and boto3 speak to it over the public HTTPS endpoint with zero code changes — true API-level S3 parity."*

---

## 🔗 Continue reading

► **[Next: 03 — Keycloak (IAM/Cognito)](03-keycloak-iam.md)**

◄ **[Back to 03 Services index](README.md)** · [🏠 Repo home](../../README.md)