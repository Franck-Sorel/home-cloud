# 02 — Cloudflare Tunnel

> **Goal:** Give your local cluster a public HTTPS URL (`https://hello.mycloud.com`) with **zero inbound ports**, **zero router config**, and **zero host firewall changes** — using a Cloudflare Tunnel.

---

## 1. Why a tunnel (30-second version)

```
Traditional (rejected):   public IP → port-forward → host:443 → k8s   [needs router/firewall/IP, exposes home IP]
Cloudflare Tunnel (this): machine ──outbound──► Cloudflare edge ◄──user── api.mycloud.com
```

Your machine *calls out* to Cloudflare once and keeps the connection open. Users hitting `api.mycloud.com` reach you **through that existing outbound connection**. Nothing is ever listening inbound. No `ufw` change, no `/etc`, no router.

> Deep dive: [`00-understanding/02-architecture.md`](../00-understanding/02-architecture.md), [`00-understanding/03-design-decisions.md`](../00-understanding/03-design-decisions.md).

---

## 2. Install `cloudflared` and create a tunnel (on your machine, one-time)

> The *long-lived daemon* will run as a **k3s pod** (no host service). You only use the client below to create/manage the tunnel.

```bash
# Left as an install-helper script in this repo:
#   scripts/install-cloudflared.sh
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cloudflared
chmod +x /tmp/cloudflared
sudo mv /tmp/cloudflared /usr/local/bin/cloudflared
cloudflared --version
```

Log in (opens a browser; grants token):

```bash
cloudflared tunnel login
```

Create & name your tunnel:

```bash
cloudflared tunnel create home-cloud
# Written: ~/.cloudflared/<tunnel-id>.json
cloudflared tunnel list
```

---

## 3. Write the tunnel config file

Create `deploy/cloudflared/config.yml` (repo file [`deploy/cloudflared/config.yml`](../../deploy/cloudflared/config.yml)):

```yaml
tunnel: <YOUR_TUNNEL_ID>          # from `cloudflared tunnel list`
credentials-file: /etc/cloudflared/<tunnel-id>.json

ingress:
  - hostname: hello.mycloud.com
    service: http://traefik.kube-system.svc.cluster.local:80
  - hostname: "*.mycloud.com"     # (optional) wildcard → still goes through Traefik
    service: http://traefik.kube-system.svc.cluster.local:80
  - service: http_status:404      # catch-all: must be last
```

Because DNS and TLS live at Cloudflare, `cloudflared` simply forwards HTTP to **Traefik** inside the cluster — Traefik decides *which* service by Host header. (This is why we don't need per-service hostnames in the tunnel config.)

> ⚠️ If you have a very fresh tunnel, `cloudflared` must be authenticated; the pod uses the **token** stored in a Secret (next step). Do not commit the credentials JSON.

---

## 4. Create the Secret & deploy the pod

Create the Kubernetes Secret from your credentials+tunnel files (on the host, in the `default` namespace):

```bash
kubectl create namespace cloudflared
kubectl create secret generic cloudflared --from-file=config.yml=deploy/cloudflared/config.yml

# credentials JSON (do NOT commit):
kubectl create secret generic cloudflared-credential \
  --from-file=credentials.json=$HOME/.cloudflared/<tunnel-id>.json \
  -n cloudflared
```

Deploy the pod (file: [`deploy/cloudflared/deployment.yaml`](../../deploy/cloudflared/deployment.yaml)):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config.yml
            - tunnel
            - home-cloud
          env:
            - name: TUNNEL_TOKEN       # (if using token auth)
              valueFrom:
                secretKeyRef:
                  name: cloudflared
                  key: tunnel-token
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/
              readOnly: true
      volumes:
        - name: config
          secret:
            secretName: cloudflared
```

Apply and wait for Ready:

```bash
kubectl apply -f deploy/cloudflared/deployment.yaml
kubectl rollout status deploy/cloudflared -n cloudflared
kubectl logs -n cloudflared deploy/cloudflared --tail 50
```

You should see a log line like `Registered tunnel connection` / `Registered tunnel connection connIndex=0`.

---

## 5. Map the domain (Cloudflare Zero Trust dashboard OR DNS route)

> There are two equivalent ways — the modern Zero Trust dashboard path is what Cloudflare now recommends.

### Option A — Zero Trust dashboard (recommended, cloud-managed)

1. [one.dash.cloudflare.com](https://one.dash.cloudflare.com) → **Networks → Tunnels** → your tunnel → **Configure → Public Hostname**.
2. **Add a public hostname**:
   - Subdomain: `hello` · Domain: `mycloud.com`
   - Service: Type `HTTP` → URL `traefik.kube-system.svc.cluster.local:80`
3. Cloudflare creates the DNS record for you. Propagation is quick (Cloudflare-internal).

### Option B — via the CLI (equivalent)

```bash
cloudflared tunnel route dns home-cloud hello.mycloud.com
```

> Both end up with `hello.mycloud.com` → your tunnel. Choose the UI path if you prefer clicking; the CLI if you like keeping things in code.

---

## 6. Verify the tunnel end-to-end

From any internet-connected machine (or your phone):

```bash
curl -vk https://hello.mycloud.com/
```

- Expect an HTTP response from **Traefik** (likely a `404` — that's *expected*: Traefik has no route yet, but the TLS + tunnel work).
- `curl -v` output should show the TLS certificate is valid (issued/terminated by Cloudflare) and you reached the cluster.

> ℹ️ A 404 from Traefik = **success** at this stage: you got through DNS → edge → tunnel → Traefik. Routing to an actual service is the very next doc.

---

## 7. Common troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ERR_NAME_NOT_RESOLVED` | DNS record not created yet | check Zero Trust → tunnel hostname; wait / re-add |
| `ERR_CERT_AUTHORITY_INVALID` | TLS hiccup at edge | Cloudflare SSL/TLS setting → set to **Full (strict)** |
| Pod `CrashLoopBackOff` | our credentials secret wrong | `kubectl describe pod -n cloudflared`; re-create secret; check `cloudflared tunnel info` |
| Tunnel registry error | tunnel ID mismatch in config.yml | match `cloudflared tunnel list` output |
| `connection error` | token/credential mismatch | re-run `cloudflared tunnel login` + recreate secret |

---

## 8. Portfolio one-liner

> *"The cluster is reachable over a zero-trust tunnel: no inbound ports, no router changes, no host firewall edits — a request is DNS'd to Cloudflare's edge and carried over an outbound connection into my k3s cluster."*

---

## 🔗 Continue reading

► **[Next: 03 — Traefik ingress routing](03-traefik-ingress.md)**

◄ **[Back to 02 Setup index](README.md)** · [🏠 Repo home](../../README.md)