# 03 — Network policies (pod segmentation)

> **Goal:** Stop a compromised pod from becoming a free-roaming foothold. Default-deny between namespaces, then whitelist the few paths your services actually use.

---

## 1. Why

By default, any pod can reach any other pod. A single weak service (say, a Redis without auth) is then a pivot point. **NetworkPolicies** make the cluster behave like AWS **Security Groups**: allow *only* declared traffic.

> k3s default CNI is **flannel**, which has NO network-policy enforcement. To use NetworkPolicies you must run a CNI that enforces them — e.g. **Cilium** or **Calico**. See the swap steps in `08-roadmap`/CNI section. We document the target policy set here; applying it requires that CNI.

---

## 2. The default-deny pattern

**`00-default-deny.yaml`** (applies cluster-namespace-wide):
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-apps
  namespace: apps
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  # with no ingress/egress rules → deny everything by default
```

> ⚠️ Apply namespace-by-namespace (one per namespace), otherwise you lock *yourself* out — ingress/service/traefik need explicit allow rules first (below).

---

## 3. Allowing what's legit

### A. Traefik → service route (`Ingress`)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-traefik-ingress
  namespace: apps
spec:
  podSelector: { matchLabels: { app: myapi } }
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: kube-system }
        - podSelector:
            matchLabels: { app: traefik }
      ports:
        - port: 8080
```

### B. app → MinIO (`Egress`)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: myapi-to-minio
  namespace: apps
spec:
  podSelector: { matchLabels: { app: myapi } }
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: storage } }
          podSelector: { matchLabels: { app: minio } }
      ports: [ { port: 9000 }, { port: 9001 } ]
```

### C. myapi → Vault, myapi → Postgres, myapi → CoreDNS
Same pattern; don't forget **CoreDNS** (myapi needs `:53` to resolve names!) and, if your apps are behind the gateway, **Traefik** in `kube-system` again.

> Full manifest set in [`deploy/security/network-policies/`](../../deploy/security/network-policies/).

---

## 4. Ordering — the safe sequence

1. Install the enforcing CNI (Cilium/Calico) **first** — without it, policies literally do nothing and you get a false sense of security.
2. Add **allow** rules for all real paths.
3. Add default-deny per namespace.
4. Test each app (`curl` across namespaces from inside a pod) *before* locking it down.

```bash
# test from inside a pod
kubectl exec -n apps deploy/myapi -- curl -s http://minio.storage.svc.cluster.local:9000
# expected after deny: connection refused / timeout
```

---

## 5. Debugging policies

| Symptom | Likely cause |
|---------|--------------|
| App can't reach DB after adding deny | Egress rule missing / wrong namespace selector |
| Public route breaks | Traefik has no Ingress allow → gateway can't reach `:8080` |
| DNS fails | missing Egress to CoreDNS (`kube-system`, `:53`) |
| Seems to work anyway | CNI may not enforce — verify `kubectl get netpol` AND CNI status |

Quick check:
```bash
kubectl get networkpolicies -A
kubectl describe networkpolicy -n apps
```

---

## 6. Portfolio one-liner

> *"I segment the cluster with NetworkPolicies — default-deny per namespace with explicit allow rules for Traefik, MinIO, Vault and DNS, the same security-group model AWS uses between services."*

---

## 🔗 Continue reading

► **[Next: 04 — WAF & rate limiting](04-waf-and-rate-limiting.md)**

◄ **[Back to 04 Security index](README.md)** · [🏠 Repo home](../../README.md)