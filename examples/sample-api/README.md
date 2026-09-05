# sample-api

A minimal, real HTTP API you can deploy in 5 minutes to prove the whole
ingress+tunnel path works end-to-end. It's the "from the docs to your cluster"
example for [`docs/03-services/01`](../../docs/03-services/01-first-service.md)
and [`docs/06-testing/01`](../../docs/06-testing/01-deploy-example-app.md).

```
examples/sample-api/
├── Dockerfile
├── app.py              (or app.js / main.go — see below)
├── requirements.txt
├── k8s/                (deployment, service, ingressroute, serviceMonitor)
└── README.md
```

---

## Run it

```bash
# build & push to your private registry (from deploy/03-services/05)
docker build -t registry.mycloud.com/library/sample-api:v1 .
docker push registry.mycloud.com/library/sample-api:v1

# manifest image: registry.mycloud.com/library/sample-api:v1
kubectl apply -f k8s/

curl https://api.mycloud.com/           # {"service":"sample-api","version":"v1"}
curl https://api.mycloud.com/health     # 200
curl https://api.mycloud.com/metrics    # prometheus output
```

---

## The app (`app.py`, Python)

```python
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)
REQUESTS = Counter("sample_api_requests_total", "Requests", ["route"])
LATENCY  = Histogram("sample_api_latency_seconds", "Latency", ["route"])

@app.route("/")
def index():
    REQUESTS.labels(route="/").inc()
    return jsonify(service="sample-api", version="v1")

@app.route("/health")
def health():
    REQUESTS.labels(route="/health").inc()
    return jsonify(status="ok")

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

> The Python/Node/Go variants live alongside in this folder; pick your language.