# 🔁 05 — Ops Workflow (running the datacenter)

> **Who this is for:** anyone who has to operate the thing day-to-day — a
> runbook of discrete jobs (start-all, stop-all, backup, upgrade…) each given
> as *start → verify → commands*, plus the `just`-style recipes they map to.

Every job here is a **start / verify / commands** trio so you always know when
you've finished. The final section shows how each maps to a future `just`
recipe set (this repo already uses `just` — see the [justfile](../../justfile)).

---

## The jobs

| Job | One-liner | Purpose |
|-----|-----------|---------|
| **start-all** | `lxc start k3s-server…; lxc start k3s-worker* dns` | bring the whole datacenter up (server first) |
| **stop-all** | `lxc stop datacenter/*` | free all RAM/CPU instantly |
| **status** | `lxc list` + `kubectl get nodes` | what's running, is the cluster healthy |
| **add-worker** | launch + `k3s agent` join | scale out |
| **backup** | `lxc snapshot` each instance | point-in-time restore point |
| **restore** | `lxc restore` a snapshot | roll back |
| **upgrade-k3s** | drain nodes, re-run `get.k3s.io` | bump k3s safely |
| **disk-full** | inspect + snapshot + prune | survive host disk exhaustion |

---

## Runbook

### 1. `start-all`

| Step | Action |
|------|--------|
| Start | `lxc start k3s-server --project datacenter` then `sleep 10` then `lxc start k3s-worker1 k3s-worker2 dns --project datacenter` |
| Verify | `kubectl get nodes`, `kubectl get pods -A`, then `lxc list --project datacenter` |

Commands:

```bash
# stop-all / start-all in one shot (adjust order for server-first)
lxc stop  datacenter/* --project datacenter
lxc start k3s-server --project datacenter && sleep 10 \
  && lxc start k3s-worker1 k3s-worker2 dns --project datacenter
```

> **`just` mapping:**
> `dc-start: @lxc start k3s-server … \n\t@sleep 10 \n\t@lxc start k3s-worker…`

### 2. `status`

| Step | Action |
|------|--------|
| Start | nothing to start — read-only |
| Verify | the output *is* the status |

Commands:

```bash
lxc list --project datacenter                     # all four, state column
lxc exec k3s-server --project datacenter -- \
  kubectl get nodes -o wide --kubeconfig /etc/rancher/k3s/k3s.yaml
```

### 3. `add-worker`

| Step | Action |
|------|--------|
| Start | get a fresh join token: `lxc exec k3s-server -- … cat /var/lib/rancher/k3s/server/node-token` |
| Verify | `kubectl get nodes` shows the new node `Ready` |

Commands:

```bash
lxc launch ubuntu:24.04 k3s-worker3 --project datacenter --profile k3s-worker
TOKEN=$(lxc exec k3s-server --project datacenter -- \
  cat /var/lib/rancher/k3s/server/node-token)
lxc exec k3s-worker3 --project datacenter -- bash -c \
  'curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.1:6443 \
   K3S_TOKEN='"$TOKEN"' K3S_NODE_NAME=k3s-worker3 sh -'
```

### 4. `backup` / `restore`

| Step | Action |
|------|--------|
| Start | `timestamp=$(date +%s)`; snapshot every instance |
| Verify | `lxc snapshot list k3s-server --project datacenter`; confirm disks fit on pool |

Commands:

```bash
for i in k3s-server k3s-worker1 k3s-worker2 dns; do
  lxc snapshot "$i" --project datacenter "snap-$(date +%s)"
done

# restore one:
lxc restore k3s-worker2 snap-1726000000 --project datacenter
```

> For disaster recovery beyond the pool, export:
> `lxc export k3s-server --project datacenter k3s-server.tar.gz` and keep the
> file off-host.

### 5. `upgrade-k3s`

| Step | Action |
|------|--------|
| Start | drain each worker (cordon), upgrade, uncordon — server last |
| Verify | `kubectl get nodes` all `Ready`; `kubectl version` on target |

Commands:

```bash
# per worker
kubectl cordon k3s-worker1
kubectl drain k3s-worker1 --ignore-daemonsets --delete-emptydir-data
lxc exec k3s-worker1 --project datacenter -- bash -c \
  'curl -sfL https://get.k3s.io | INSTALL_K3S_BIN=/usr/local/bin/k3s \
   sh -s -- agent --server https://10.10.0.1:6443 --token …'
kubectl uncordon k3s-worker1
# do the server last, rolling: restart worker agents, then server
```

### 6. `disk-full`

| Step | Action |
|------|--------|
| Start | `df -h /` on host; `lxc info` disk usage per instance |
| Verify | freed space; no instance left read-only |

Commands:

```bash
df -h /                                   # host pool
lxc list --project datacenter             # spot oversized instances
# free: prune old snapshots
lxc snapshot delete k3s-worker2 snap-1726000000 --project datacenter
# or export + delete + re-import a heavy instance
```

> Disk-full is the **top operational risk** because the pool defaults to a dir
> on the root disk — handle it before it hits.

---

## Backing a `just` recipe set

Each job becomes a `just` recipe in the same spirit as the existing
[`justfile`](../../justfile). Sketch (not yet added to the repo):

```just
# --- datacenter (virtualization layer) ------------------------------------
dc-list:        # show instances + status
    @lxc list --project datacenter

dc-start:       # bring up the whole datacenter (server first)
    @lxc start k3s-server --project datacenter
    @sleep 10
    @lxc start k3s-worker1 k3s-worker2 dns --project datacenter

dc-stop:        # stop everything, free RAM/CPU now
    @lxc stop datacenter/* --project datacenter

dc-status:      # instances + cluster health
    @lxc list --project datacenter
    @lxc exec k3s-server --project datacenter -- \
        kubectl get nodes --kubeconfig /etc/rancher/k3s/k3s.yaml

dc-backup:      # snapshot every instance
    @for i in k3s-server k3s-worker1 k3s-worker2 dns; do \
        lxc snapshot "$$i" --project datacenter "snap-$$(date +%s)"; \
    done

dc-restore name snapshot:
    @lxc restore {{name}} {{snapshot}} --project datacenter

dc-add-worker name:
    @lxc launch ubuntu:24.04 {{name}} --project datacenter --profile k3s-worker
```

> Recipes follow the repo's `just` conventions (bash shell, `@` echo-suppressed
> commands). Wire them into the real `justfile` only when this plan is accepted.

---

## 🧭 Navigation

► **[Next: 06 — Glossary](06-glossary.md)**

◄ **[Back: 04 — Implementation](04-implementation.md)** · [Back: 02 Virtualization Layer](README.md)
