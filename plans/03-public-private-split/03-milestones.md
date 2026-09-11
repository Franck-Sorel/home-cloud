# 🔀 03 — Milestones (step-by-step, fine-tuned)

> **Who this is for:** the executor. Follow in order; **do not start M*n+1* until
> M*n* is fully operational and its gate passes.** This is the "fine-tuned
> strategy": small, additive, always-keep-public-green milestones that never
> break the existing work while the private repo grows.

---

## Everything uses the same loop
1. Open the milestone's branch.
2. Make the **minimal** change (public changes are small and reversible; private is additive).
3. Run the relevant gates.
4. `git commit` + `git push` (public PR; private PR).
5. Human review at each gate before proceeding.

---

## M0 — Private scaffold + virtualization foundation
**Goal:** the empty-but-looping private repo and a **corrected, verified** LXD →
**3-node k3s (server + 2 workers) + 1 DNS box** base, fully documented, before any
workload.

**Private work**
- Create `private-home-cloud` (private GitHub repo). Add `README`, `.github/workflows/e2e-private.yml` (stub), `.sops.yaml` (age public key; **no private key in repo**).
- Add `versions.lock` and the **corrected** LXD bring-up (findings already applied):
  - `sudo snap install lxd` (**default `5.21/stable`**; do NOT use `latest/stable`).
  - `sudo lxd init` (zfs/btrfs pool on root disk, `lxdbr0`).
  - `lxc project create datacenter` + `lxc project switch datacenter`.
  - **Copy the default project's profile in** (new project default profile is empty → else `No root device`):
    `lxc profile show default --project default | lxc profile edit default`
  - Create `dc-base` profile: `limits.cpu=2`, `limits.memory=4GiB`, `security.nesting=true`,
    `linux.sysctl.kernel.apparmor_restrict_unprivileged_userns=0`.
  - Launch (correct flags). **All `lxc launch` commands run on the HOST.** Replace
    `${SERVER_RAM}` below with the concrete number (see Sizing): 8GiB on a ≥32GiB host,
    else 6GiB.
    ```
    lxc launch ubuntu:24.04 k3s-server -p dc-base -c limits.cpu=4 -c limits.memory=${SERVER_RAM} -d root,size=32GiB
    lxc launch ubuntu:24.04 k3s-worker1 -p dc-base -c limits.cpu=2 -c limits.memory=${WORKER_RAM} -d root,size=24GiB
    lxc launch ubuntu:24.04 k3s-worker2 -p dc-base -c limits.cpu=2 -c limits.memory=${WORKER_RAM} -d root,size=24GiB
    lxc launch ubuntu:24.04 dns        -p dc-base -c limits.cpu=1 -c limits.memory=1GiB -d root,size=16GiB
    ```
  - Toggle uses `lxc start/stop --all --project datacenter` (**not** `datacenter/*`).
  - **Sizing (run on the HOST):** `SERVER_RAM=8GiB` + `WORKER_RAM=4GiB`×2 + dns 1GiB =
    **17GiB total** — only if host ≥32GiB; if host =16GiB, set `SERVER_RAM=6GiB`,
    `WORKER_RAM=3GiB` (=13GiB) and do not run all four simultaneously as the daily
    default.
- k3s (run **inside** the `k3s-server` container): `curl -sfL https://get.k3s.io |
  INSTALL_K3S_EXEC="server --disable=traefik" sh -` (version from `versions.lock`).
  Workers join from **inside** each worker container with
  `K3S_URL=https://10.10.0.1:6443` + `K3S_TOKEN`.
- Pi-hole in the `dns` container (LAN + `datacenter-net`).
- Docs: `lxd/README.md` + `k3s/*.sh` fully written and verified on the real machine.

**Gates (M0)**
- `kubectl get nodes` → **3 Ready** (`k3s-server`, `k3s-worker1`, `k3s-worker2`).
- Toggle works: `lxc stop --all --project datacenter` frees RAM; `lxc start --all --project datacenter` brings all 3 back Ready with state intact.
- Snapshot + restore works: `lxc snapshot k3s-server snap-001` then `lxc restore k3s-server snap-001`.
- Public repo **unchanged** and `just validate` still green.
- **STOP for review.**

---

## M1 — storage → MinIO (first REAL workload)
**Goal:** MinIO actually running on the LXD k3s, meeting the public `storage` wrap, fully operational.

**Public (minimal)**
- No contract change (`storage/minio:9000`, `storage/minio-console:9001` already the wrap targets).
- Optionally extend `bundles/storage/templates/NOTES.txt` to document the contract (no workload, no version).

**Private**
- `charts/minio/`: `StatefulSet` (pinned image from `versions.lock`), data **PVC**, Services `minio:9000` + `minio-console:9001`, init **Job** creating bucket `notes`.
- SOPS-encrypted root user/pass in `secrets/minio.sops.yaml`.

**Gates (M1) — private e2e on LXD k3s**
- `kubectl -n storage get pods` → MinIO `Running`.
- `mc alias set homecloud http://storage.mycloud.com admin '***' && mc ls homecloud/notes` lists the bucket (via the public IngressRoute).
- Traefik logs show **no** `storage/minio` service-not-found.
- Public glue `e2e` still green; `just validate` green.
- **STOP for review.**

---

## M2 — secrets → Vault
- `charts/vault/`: real Vault (pinned), `secrets/vault:8200` meeting contract, dev or HA(+raft PVC).
- Smoke: `vault status` → sealed/unsealed OK; enable DB engine + issue one short-lived DB cred.
- Gate = Vault `Running`, `vault status`, `mc`/app can read a secret, no `secrets/vault` service-not-found. Public stays green.

---

## M3 — auth → Keycloak + oauth2-proxy (+ Postgres)
- `charts/keycloak/`: Postgres + `keycloak:8080`; realm + client bootstrap (init Job).
- `charts/oauth2-proxy/`: `auth/oauth2-proxy:80` (the `protected-gate` forwardAuth target).
- Smoke: admin login issues a token; a test service routed through `protected-gate` returns 401 without, 200 with a session.
- Gate = Keycloak+oauth2 Running, token flow works, no `auth/keycloak` service-not-found.

---

## M4 — observability → kube-prometheus-stack + Loki
- `charts/observability/`: kube-prometheus-stack (Prom, Grafana, Alertmanager) + Loki + promtail; `monitoring/grafana:80`; **ServiceMonitors** for `hello` and the real services; Grafana **Loki datasource** prewired.
- Smoke: Grafana health 200; Prometheus target up for `hello`; Loki query returns logs.
- Gate = stack Running, dashboards + datasource respond, no `monitoring/grafana` service-not-found.

---

## M5 — registry → Harbor (+ Postgres + Redis)
- `charts/harbor/`: Harbor (portal/core/registry) + Postgres + Redis; `registry/harbor-portal:80`; **imagePullSecrets** so other bundles pull from it.
- Smoke: `docker login harbor.mycloud.com`, `docker push/pull` a test image.
- Gate = Harbor Running, push/pull works, no `registry/harbor-portal` service-not-found.

---

## M6 — serverless → OpenFaaS
- `charts/openfaas/`: gateway + faas-netes + `openfaas-fn` namespace; `serverless/gateway:8080`.
- Smoke: `faas-cli login`, deploy a `hello` function, invoke → response.
- Gate = gateway Running, function deploys + invokes, no `serverless/gateway` service-not-found.

---

## M7 — Cross-wiring, private full E2E, and public version-guidance
- **Private:** wire services together (registry as image source, storage + auth + secrets behind an app), then a **full private e2e** that runs every M1–M6 maybe-smoke together.
- **Public (the version-remediation list from [02 — Inventory](02-inventory.md)):** remove/paraphrase concrete engine pins → generic guidance; adjust `README` badge and e2e inputs to "CI-only / non-authoritative."
- Gate: public `validate` + glue `e2e` green with genericized inputs; private full e2e green; final review.

---

## Rollback rule (all milestones)
- Every public change is a small, single-purpose commit → `git revert` restores the exact prior state.
- Private milestones are additive; a broken private milestone is reverted/released independently and never blocks the public repo.
- The frozen contracts (§ contract table) are the one cross-repo invariant — any change is a paired PR in both repos reviewed together.

---

## Navigation

► **[Next: 04 — Risks & conflicts](04-risks-and-conflicts.md)** · ◄ [Back to README](README.md)
