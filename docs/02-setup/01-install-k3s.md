# 01 — Install k3s

> **Goal:** A running single-node Kubernetes cluster on your Ubuntu machine, via k3s. This is the **single documented OS-touch** of the whole project. Everything after this is containers.

---

## 1. What we're about to do

```
k3s binary                  → /usr/local/bin/k3s
k3s systemd unit            → k3s.service (the documented minimal host touch)
working/state files         → program runs, data under /var/lib/rancher/k3s & $HOME/k3s-data
```

No host packages installed beyond k3s itself. No `/etc` edits by us. No firewall/router changes. The kernel features k3s needs (overlay, namespaces, veth, iptables-nat) ship **already enabled** in a stock Ubuntu kernel.

---

## 2. Install k3s (official script)

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
```

What this does:
- Installs the k3s binary to `/usr/local/bin/k3s`
- Creates & starts the `k3s` systemd service (control plane **and** agent on the same node)
- Bundles in: `containerd`, `CoreDNS`, `local-path-provisioner`, `metrics-server`, `servicelb` (klipper), and **Traefik** (our ingress)
- Writes your kubeconfig to `/etc/rancher/k3s/k3s.yaml`

> ✅ The only privileged action in this entire project. Non-`sudo` should suffice for everything that follows (except `kubectl` may read the kubeconfig).

Check status:

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 30 --no-pager
```

---

## 3. Install kubectl (the driver's seat)

```bash
sudo apt-get install -y kubectl        # or: kubectl via snap on 24.04
kubectl version --client
```

**Configure access without sudo** — point kubectl at the kubeconfig (still root-owned, but readable):

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
kubectl get nodes
```

> Expect output like `NAME=<host> STATUS=Ready`. If `get nodes` fails, verify `KUBECONFIG`:
> ```bash
> export KUBECONFIG=~/.kube/config
> echo $KUBECONFIG
> ```

---

## 4. Verify the cluster (the "it works" moment)

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

✅ You should see:

| Namespace | Pod | Purpose |
|-----------|-----|---------|
| `kube-system` | `traefik-*` | the ingress controller (layer 3) |
| `kube-system` | `coredns-*` | in-cluster DNS (layer 4) |
| `kube-system` | `metrics-server-*` | node/pod metrics |
| `kube-system` | `svclb-traefik-*` | gives Traefik a stable LoadBalancer address |
| `kube-system` | `local-path-provisioner-*` | creates PVs under `/var/lib/rancher/k3s/storage` | stateful apps survive reboots |

If a pod is `CrashLoopBackOff`/`ImagePullBackOff`, run:
```bash
kubectl describe pod -n kube-system <pod>
kubectl logs -n kube-system <pod>
```

---

## 5. Check the "gotchas" that bite people

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| kubeconfig permissions | `kubectl` refuses config | the `chown`/`chmod` above |
| DNS not propagating | `pods` resolve each other slowly | restart CoreDNS or check CNI pods |
| Swapped default systemd | `systemd` not used | this project uses systemd; note in roadmap if your desktop uses another init |
| RAM low | k3s refuses to start a pod | set pod resource limits (see `03-services`) |
| Traefik listens on 80/443 | you want those free | default fine — cloudflared will only hit the service IP later |

---

## 6. Apply the constraint: persistent storage under $HOME

k3s default *local-path* volumes live under `/var/lib/rancher/k3s/storage` — acceptable but outside `$HOME`. For clean separation and backup-ability, configure the local-path provisioner to use `$HOME/k3s-data`:

Create `deploy/local-path-storage.yaml` in this repo (see [`deploy/`](../../deploy/README.md)):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: local-path-storage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: local-path-provisioner
  namespace: local-path-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: local-path-provisioner
  template:
    metadata:
      labels:
        app: local-path-provisioner
    spec:
      serviceAccountName: local-path-provisioner
      containers:
        - name: local-path-provisioner
          image: rancher/local-path-provisioner:v0.0.24
          command:
            - local-path-provisioner
            - --debug
            - start
            - --config
            - /etc/config/config.json
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config/
          env:
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config/
              # (full reference in the repo's deploy/local-path-storage.yaml)
```

> ⚠️ This file is a *reference/skeleton* — the full working manifest lives under [`deploy/local-path-storage.yaml`](../../deploy/). The key line to change: set `nodePathMap[].paths[]` to `"/home/$USER/k3s-data"`.

Apply & verify:
```bash
kubectl apply -f deploy/local-path-storage.yaml
kubectl get sc
#  NAME                 PROVISIONER             RECLAIMPOLICY
#  local-path           rancher.io/local-path   Delete
```

> You may also keep the default `local-path` storage class — both work. The point is that **all persistent data lives under `$HOME/k3s-data`**, satisfying the constraint in [`04-constraints.md`](../00-understanding/04-constraints.md).

---

## 7. Smoke test: run a hello pod

```bash
kubectl run smoke --image=nginx --restart=Never
kubectl wait --for=condition=Ready pod/smoke --timeout=60s
kubectl delete pod smoke
```

If that exits 0: **your cluster is healthy.** Move on.

---

## 8. What just happened, in one sentence for your portfolio

> *"k3s gave me a full Kubernetes control plane + ingress (Traefik) + storage + DNS in a single binary and a single systemd unit — the one and only OS-level touch in the entire platform."*

---

## 🔗 Continue reading

► **[Next: 02 — Cloudflare Tunnel](02-cloudflare-tunnel.md)**

◄ **[Back to 02 Setup index](README.md)** · [🏠 Repo home](../../README.md)