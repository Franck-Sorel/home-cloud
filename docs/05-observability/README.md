# 📈 05 — Observability

> **This section is for readers who want the "production-grade" half of the promise: logs, metrics, dashboards, and alerting — your CloudWatch.**
> You can't claim reliability you can't see. After this section you can *watch* the private cloud and get woken up when it breaks.

---

## 📖 What's in this section

| # | Document | Covers |
|---|----------|--------|
| 01 | [`01-dashboards.md`](01-dashboards.md) | Install Grafana + connect datasources, your "one screen" ops view |
| 02 | [`02-metrics.md`](02-metrics.md) | Prometheus + node-exporter: node, pod, ingress, and app metrics + alerts |
| 03 | [`03-logs.md`](03-logs.md) | Loki: centralized logs from k8s, Traefik, apps; LogQL queries |

---

## 📚 The observability stack

| AWS | Self-hosted | Job |
|-----|-------------|-----|
| CloudWatch Logs / Metrics | **Loki** (logs) + **Prometheus** (metrics) | the raw signals |
| CloudWatch Dashboards | **Grafana** | one screen for all signals |
| CloudWatch Alarms / SNS | **Alertmanager** → email/Telegram | the "call me when it breaks" |
| CloudTrail | **k8s audit logs** → Loki | the "who did what" audit trail |

```
                   Prometheus ──► Alertmanager ──► (email / Telegram / webhook)
        │                ▲
applications/exporters ──┘                 ┌──────────────►  Grafana ──► you
        │                                  │
        └──► Loki ◄── k8s, Traefik, apps ──┘
```

---

## 🔗 Continue reading

► **[Next: 01 — Dashboards (Grafana)](01-dashboards.md)**

◄ **[Back to repository home](../../README.md)**

---

## 🧭 Navigation

- [🏠 Repository home](../../README.md)
- [🧠 00 — Understanding](../00-understanding/README.md)
- [💡 01 — Skills](../01-skills/README.md)
- [🚀 02 — Setup](../02-setup/README.md)
- [🛠️ 03 — Services](../03-services/README.md)
- [🔒 04 — Security](../04-security/README.md)
- [📈 05 — Observability](README.md)
- [🧪 06 — Testing](../06-testing/README.md)
- [♾️ 07 — IaC & GitOps](../07-iac-gitops/README.md)
- [🗺️ 08 — Roadmap](../08-roadmap/README.md)