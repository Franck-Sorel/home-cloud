# 🏛️ 03 — Architecture Diagrams

Mermaid diagrams for the cluster, the bundle composition model, and the
pipeline. Rendered versions are in [`assets/`](assets/); the Mermaid source
below each is what to edit.

> Rendered: [architecture.png](assets/architecture.png) ·
> [bundles.png](assets/bundles.png) · [pipeline.png](assets/pipeline.png)

---

## 1. Logical architecture (with `base` + optional bundles)

```mermaid
graph TD
    subgraph Internet
        U[User browser]
    end

    subgraph Edge["Edge (Model A shown)"]
        CF[Cloudflare / ISP edge<br/>TLS + WAF]
    end

    subgraph Home["Your Ubuntu machine (k3s)"]
        subgraph Ingress["Traefik Ingress"]
            MW[security-and-limits<br/>headers + rate-limit]
            FA[protected-gate<br/>forwardAuth → Keycloak]
        end
        subgraph NS1["apps + auth + storage"]
            HELLO[hello]
            KEY[Keycloak]
            MIN[MinIO]
        end
        subgraph NS2["secrets + serverless + monitoring"]
            VAU[Vault]
            FaaS[OpenFaaS]
            GRAF[Grafana + Loki + Prometheus]
        end
        DDNS[DDNS updater CronJob]
        NETPOL[NetworkPolicies<br/>default-deny]
    end

    U --> CF --> Ingress --> HELLO
    Ingress --> KEY
    Ingress --> MIN
    Ingress --> FaaS
    Ingress --> GRAF
    DDNS -.keep DNS in sync.-> CF
    NETPOL -.isolate pods.-> NS1
    NETPOL -.isolate pods.-> NS2
```

## 2. Bundle composition ("choose what you want")

```mermaid
graph LR
    BASE[base : edge + demo<br/>namespace + middleware]
    AUTH[auth : Keycloak + fwd-auth]
    STORAGE[storage : MinIO]
    SECRETS[secrets : Vault]
    SLS[serverless : OpenFaaS]
    REG[registry : Harbor]
    OBS[observability : Grafana/Loki/Prom]
    SEC[security : NetworkPolicies]

    BASE --> AUTH
    BASE --> STORAGE
    BASE --> SECRETS
    BASE --> SLS
    BASE --> REG
    BASE --> OBS
    AUTH --> SEC
    STORAGE --> SEC
    SECRETS --> SEC
    SLS --> SEC
    REG --> SEC
    OBS --> SEC
```

> `security` is a cross-cutting layer (dashed edges show what it hardens).
> `base` is the prerequisite for everything else. All others are independent
> opt-ins.

## 3. The validation & release pipeline

```mermaid
graph TD
    P[push / PR] --> CI[CI - just validate]
    CI --> H[helm lint + render<br/>ddns & cloudflare]
    CI --> SH[shellcheck scripts]
    CI --> YL[yamllint manifests]
    CI --> TF[terraform fmt + validate]

    H --> OK{all pass?}
    SH --> OK
    YL --> OK
    TF --> OK

    OK -- yes --> TAG[tag v0.1.0]
    OK -- no --> FAIL[block merge]
    TAG --> PKG[helm package all bundles]
    PKG --> PUSH[helm push to ghcr.io<br/>OCI charts]
    PUSH --> USR[install any bundle<br/>helm install auth]
```

---

## 4. Secrets flow (nothing plaintext)

```mermaid
sequenceDiagram
    participant U as User
    participant S as Secret (kubectl)
    participant B as Bundle pod
    participant V as Vault (optional)
    U->>S: create Secret (gitignored)
    S->>B: mounted / envFrom at runtime
    opt dynamic creds
        B->>V: request short-lived DB creds
        V-->>B: time-boxed username/password
    end
```

---

► **[Next: Accuracy pipeline & release](04-pipeline.md)** |
◄ [Back to 09 — Bundles](README.md)
