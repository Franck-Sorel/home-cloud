# 06 — Serverless (OpenFaaS — your Lambda)

> **Goal:** Deploy **OpenFaaS** so you can run *functions* (like AWS Lambda) on your cluster, invoked over the public URL and triggered from your apps.

---

## 1. What you get

| AWS | Self-hosted | Notes |
|-----|-------------|-------|
| Lambda | **OpenFaaS** | functions as containers; any language; API gateway; autoscaling to zero |

OpenFaaS wraps your function image in a tiny **faas watchdog** HTTP server. You push a container image, OpenFaaS scales a pod up (and down) per request — the classic "serverless" behavior.

---

## 2. Deploy OpenFaaS

```bash
kubectl create ns serverless
helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update
helm install openfaas openfaas/openfaas \
  -n serverless \
  --set functionNamespace=openfaas-fn \
  --set generateBasicAuth=true
```

> `generateBasicAuth=true` creates a randomly-generated admin password — capture it:
```bash
kubectl -n serverless get secret basic-auth -o jsonpath='{.data.basic-auth-password}' | base64
```

---

## 3. Route through Traefik

`deploy/serverless/faas-ingressroute.yaml`:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: gateway
  namespace: serverless
spec:
  entryPoints: [ web ]
  routes:
    - match: Host(`fn.mycloud.com`) && PathPrefix(`/`)
      kind: Rule
      services:
        - name: gateway
          port: 8080
```

---

## 4. Deploy & invoke a "Hello" function

```bash
# install the faas-cli
curl -sL https://cli.openfaas.com | sh

export OPENFAAS_URL=https://fn.mycloud.com
export OPENFAAS_PASSWORD=$(kubectl -n serverless get secret basic-auth -o jsonpath='{.data.basic-auth-password}' | base64 -d)
echo -n "$OPENFAAS_PASSWORD" | faas-cli login -u admin --password-stdin

# scaffold a python function
faas-cli new hello --lang python3
# faas-cli build -f hello.yml && faas-cli push -f hello.yml   (pushes to your registry from service 05)

faas-cli deploy -f hello.yml
faas-cli list
curl -X POST https://fn.mycloud.com/function/hello -d '{"hello":"home-cloud"}' -H "Content-Type: application/json"
# → {"output":"hello from openfaas 🚀"}
```

> You just reproduced **Lambda**: a function deployed from source, invoked over a public URL, autoscaled by OpenFaaS.

---

## 5. Triggering from your apps

Functions are just HTTP endpoints — your apps, CronJobs, webhooks, and GitHub Actions can all call `https://fn.mycloud.com/function/<name>`. Combine with MinIO (event → function) for a mini "S3 + Lambda" pipeline:

- Enable MinIO bucket notifications → send to OpenFaaS gateway (see MinIO docs "bucket notification with Webhook target").

---

## 6. Hardening

- [ ] Rotate the basic-auth password after setup (or use OIDC provider between gateway + parties)
- [ ] Restrict which functions are public; protect `fn.mycloud.com` with Keycloak forward-auth for anything sensitive
- [ ] Set function timeouts/resources sensibly (default FaaS is generous)
- [ ] Consider **scale-to-zero** (autoscaling) so idle functions don't eat RAM

---

## 7. Portfolio one-liner

> *"OpenFaaS gives me FaaS on k3s — functions deployed from source, exposed at fn.mycloud.com, autoscaled, and callable by my other services — a miniature AWS Lambda."*

---

## 🔗 Continue reading

► **[Next: 07 — tie it together: the app workshop](07-app-workshop.md)**

◄ **[Back to 03 Services index](README.md)** · [🏠 Repo home](../../README.md)