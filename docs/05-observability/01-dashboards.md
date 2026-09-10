# 01 — Dashboards (Grafana)

> **Goal:** A working Grafana at `grafana.mycloud.com`, connected to your data sources — the single screen where the entire private cloud's health lives.

---

## 1. Deploy Grafana

```bash
kubectl create ns monitoring
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana \
  -n monitoring \
  -f deploy/observability/grafana-values.yaml
```
`deploy/observability/grafana-values.yaml` (in repo) — key settings:
```yaml
adminPassword: <change-me>        # via Secret in real deployments
service.port: 80
persistence.enabled: true
persistence.storageClassName: local-path
datasources:                      # we'll add Loki + Prometheus after those exist
  datasources.yaml:
    apiVersion: 1
    datasources: []
ingress:
  enabled: false                  # we route via Traefik IngressRoute
```

Route it: `deploy/observability/grafana-ingressroute.yaml`
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints: [ web ]
  routes:
    - match: Host(`grafana.mycloud.com`)
      kind: Rule
      middlewares:
        - name: security-and-limits
          namespace: apps
      services:
        - name: grafana
          port: 80
```

Verify:
```bash
kubectl rollout status deploy/grafana -n monitoring
curl -I https://grafana.mycloud.com/login   # 200
admin / (from secret)
```

> 🔐 **Protect it:** `grafana.mycloud.com` should be behind Cloudflare Access or Keycloak forward-auth — it's your ops cockpit.

---

## 2. Connect data sources (once they exist)

In Grafana → **Connections → Data sources**:

| Datasource | URL internal | Purpose |
|------------|--------------|---------|
| Prometheus | `http://prometheus.monitoring.svc.cluster.local:9090` | metrics (from doc 02) |
| Loki | `http://loki.monitoring.svc.cluster.local:3100` | logs (from doc 03) |

---

## 3. Import ready-made dashboards

- Node exporter: **dashboard ID 1860** (`node-exporter-full`)
- k8s cluster: **dashboard ID 315** (cluster monitoring)
- Data sources mainly for k3s: Grafana.com k3s dashboards (search "k3s")
- Traefik (optional, by ecosystem tags)

Then create a **Home-CLoud Overview** dashboard (projects like this are 50% "it works", 50% "here's proof it works").

---

## 4. Alerts from dashboards

Set a simple alert in Grafana (panel → **Alert**): `node_filesystem_avail_bytes < 10GB` once disk is tight. Full alerting lives with Alertmanager in doc 02.

---

## 5. Portfolio one-liner

> *"Grafana is my CloudWatch — one screen showing node health, pod metrics, ingress traffic and logs, with alerts wired to Alertmanager."*

---

## 🔗 Continue reading

► **[Next: 02 — Metrics (Prometheus)](02-metrics.md)**

◄ **[Back to 05 Observability index](README.md)** · [🏠 Repo home](../../README.md)