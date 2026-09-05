# 02 — Metrics (Prometheus + Alertmanager)

> **Goal:** Collect every metric that matters (node, pods, ingress, apps), store it in Prometheus, and **page you when something breaks** via Alertmanager.

---

## 1. Deploy the kube-prometheus stack (one chart, everything)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f deploy/observability/prometheus-values.yaml
```
`deploy/observability/prometheus-values.yaml` (in repo) — key settings:
```yaml
grafana.enabled: false        # we run our own Grafana (doc 01)
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          resources:
            requests: { storage: 10Gi }
alertmanager:
  enabled: true
  # (config with receivers below)
```

What lands in `monitoring`:
- **Prometheus** (scraper + storage + PromQL)
- **Alertmanager** (routes alerts → receivers)
- **node-exporter** (DaemonSet: `/metrics` on every node)
- **kube-state-metrics** (pod/deploy/ns metrics)
- ServiceMonitors for the above + standard k8s targets

---

## 2. Verify metrics flowing

```bash
kubectl get pods -n monitoring
kubectl port-forward svc/kube-prometheus-kube-prometheus-prometheus -n monitoring 9090 &
curl localhost:9090/api/v1/query --data-urlencode 'query=up' | jq .
#  ["up","1"]  →  targets healthy
```

In Grafana: add **Prometheus** datasource (`http://kube-prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090`) → explore `node_cpu_seconds_total`, `kube_pod_container_status_restarts_total`.

---

## 3. Your app's metrics (expose a `/metrics`)

Make the demo API (`03-services/01`) or `mynotes-app` expose Prometheus-style metrics (`myapi_requests_total{route=...}`, `myapi_latency_seconds_bucket`). Simple library: Python `prometheus-client`, Go `promhttp`, Node `prom-client`.

Add a **ServiceMonitor**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapi
  namespace: apps
spec:
  selector:
    matchLabels: { app: myapi }
  endpoints:
    - port: http        # service port name
      path: /metrics
```
Prometheus auto-scrapes it (kube-prometheus includes a default `prometheus-operator` ServiceMonitor for everything). `up{job="...myapi"}` should go `1`.

---

## 4. Alerting — the "wake me up" part

Alertmanager these examples in `deploy/observability/alertmanager-values.yaml`:

```yaml
alertmanager:
  config:
    global:
      smtp_smarthost: smtp.example:587
      smtp_from: homecloud@example.com
      smtp_auth_username: ...
      smtp_auth_password: ...
    route:
      group_by: ['alertname']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      receiver: 'ops'
    receivers:
      - name: 'ops'
        email_configs:
          - to: you@example.com
```
> Telegram / Slack webhooks are also supported — Telegram is nice for a single-person "ops inbox".

Example **Prometheus rules**: add to the chart:
```yaml
prometheus:
  prometheusSpec:
    rules:
      - groups:
        - name: home-cloud
          rules:
            - alert: PodDown
              expr: kube_pod_container_status_running == 0
              for: 2m
              labels: { severity: critical }
              annotations:
                summary: "Pod {{ $labels.pod }} down"
            - alert: NodeDiskWillFill
              expr: (1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) > 0.9 and ON(instance) node_filesystem_size_bytes{fstype=~"ext4|xfs"} > 0
              for: 5m
              severity: critical
            - alert: HighRate429
              expr: rate(traefik_requests_total{code=~"429"}[5m]) > 20
              for: 5m
              severity: warning
```

Test an alert honestly:
```bash
kubectl scale deploy hello -n apps --replicas=0   # trigger PodDown
# wait ~3m → email/Telegram
kubectl scale deploy hello -n apps --replicas=2   # cleared
```

---

## 5. Keep an eye on the node

Node exporter gives: CPU, RAM, disk (critical on a single box), network, load, uptime. Panel ideas:
- `((sum(node_cpu_seconds_total{mode="idle"}) - sum(rate(node_cpu_seconds_total{mode="idle"}[5m]))) / sum(node_cpu_seconds_total{mode="idle"})) * 100`
- `(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100`
- `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100`

---

## 6. Portfolio one-liner

> *"kube-prometheus-stack gives me Prometheus + Alertmanager + node & pod metrics; my APIs expose ServiceMonitors. An alert — pod down, disk filling, 429s — pages me over Telegram, my self-hosted CloudWatch."*

---

## 🔗 Continue reading

► **[Next: 03 — Logs (Loki)](03-logs.md)**

◄ **[Back to 05 Observability index](README.md)** · [🏠 Repo home](../../README.md)