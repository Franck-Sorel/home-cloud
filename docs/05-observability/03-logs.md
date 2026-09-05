# 03 — Logs (Loki)

> **Goal:** All logs — k8s events, container stdout, Traefik access logs, your apps — in one place, queryable with LogQL, visualized in Grafana. Your CloudWatch Logs.

---

## 1. Deploy Loki (small single binary, fine for home)

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki \
  -n monitoring \
  -f deploy/observability/loki-values.yaml
```
`deploy/observability/loki-values.yaml` (in repo) — key settings:
```yaml
deploymentMode: SingleBinary     # home scale = one instance
persistence:
  enabled: true
  storageClassName: local-path
  size: 10Gi
limitsConfig:
  retention_period: 720h        # keep 30 days
```

Confirm:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
# register in Grafana datasource: http://loki.monitoring.svc.cluster.local:3100
```

---

## 2. Send everything to Loki

### A. Kubernetes pod logs — via Promtail (DaemonSet)

```yaml
# deploy/observability/promtail-values.yaml
config:
  clients:
    - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push
  snippets:
    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs: [{ role: pod }]
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
        pipeline_stages:
          - { regex: 'level=(\w+)', labels: ['level'] }
```
```bash
helm install promtail grafana/promtail \
  -n monitoring \
  -f deploy/observability/promtail-values.yaml
```

### B. Traefik access logs → Loki

Traefik logs to stdout; Promtail picks container logs up already. For structured access logs, enable Traefik's access-log JSON (k3s values override): set
```yaml
traefik.yaml:
  accessLog:
    format: json
```
in `k3s` (or tap through an env var) — see `deploy/observability/traefik-values-patch.md`.

> k3s bundles Traefik — to override its args, either re-install Traefik from the official chart in `kube-system` or run a second ingress class. Simplest: rely on **Promtail's JSON parsing** of whatever stdout Traefik already emits (default formats parse fine in LogQL with `| json`).

### C. Your apps
Just write structured logs to stdout (`logger.info(json)`). Promtail labels them by pod; in Loki you can `{namespace="apps"} |= "ERROR"`.

---

## 3. Querying with LogQL (your Log Insights)

In Grafana → Explore → datasource Loki:

```logql
# all logs in a namespace, last 30m
{namespace="apps"}
# errors
{namespace="apps"} |= "ERROR"
# pod-specific, with a filter
{namespace="apps"} |= "myapi" |= "timeout" != "retry"
# level extraction
{namespace="apps"} | json | level="error"
# count webhook calls, last 1h
sum(rate({namespace="apps",app="myapi"} | json | request_path="/webhook"[1h]))
```

---

## 4. Good practice: centralize Traefik + auth events too

| Source | Why |
|--------|-----|
| Traefik access logs | who hit what, status codes, latency — the gateway's "CloudTrail" |
| kube-apiserver audit logs | *who* changed *what* in the cluster (enable k3s audit policy — `08-roadmap`/hardening) |
| Keycloak logs | sign-in events, brute-force attempts |
| Vault logs | secret-access auditing |

Each just needs its container logs already streamed by Promtail — so mostly **you don't do extra wiring**, you query.

---

## 5. Retention & cost

- Set `retention_period` per your disk budget (30d ≈ fine at home)
- Promtail drops labels you strip → fewer streams → cheaper Loki (still free at this scale, it's Open Source, but clean queries stay fast)
- `chunk_target_size` / `max_chunk_age` tuning only if disk/Loki gets heavy (roadmap)

---

## 6. Portfolio one-liner

> *"Every log — kube, gateway, auth, app — lands in Loki and is queryable from Grafana with LogQL; my CloudWatch Logs replacement, with a 30-day retention baked in."*

---

## 🔗 Continue reading

► **[Next section: 🧪 06 — Testing & Exposure](../06-testing/README.md)** — prove it works, then show it to the world

◄ **[Back to 05 Observability index](README.md)** · [🏠 Repo home](../../README.md)