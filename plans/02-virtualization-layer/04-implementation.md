# 🔧 04 — Implementation (LXD, step by step)

> **Who this is for:** the operator who wants the exact commands from *empty
> Ubuntu* to a running, persistent multi-node k3s cluster you can stop/start
> with one command. It pairs with the ops recipes in
> [05 — Ops workflow](05-ops-workflow.md).

The recommended topology is [03 — Architecture](03-architecture.md). This
document turns it into commands.

---

## Phase 0 — Prerequisites

One Ubuntu 24.04 machine with:

- a user with `sudo`,
- at least **16 GiB RAM** / **8+ vCPU** to run more than a couple of nodes at
  once (see sizing gotcha in [02 — Recommendation](02-recommendation.md)),
- free disk for the storage pool.

> **Do not** run `lxd init` as root's interactive defaults if you want
> isolation from daily work — the suggested values below are the point.

---

## Phase 1 — Install LXD (snap)

```bash
sudo snap install lxd
sudo lxd init --minimal        # sensible single-host defaults
sudo usermod -aG lxd "$USER"   # your user may manage LXD without sudo
newgrp lxd                     # apply the group now
lxc version
```

`lxd init --minimal` is enough for a homelab. The full interview (`lxd init`)
also works; the only profile-level choice worth making early is recorded in
the profiles below rather than at init time.

---

## Phase 2 — Create the `datacenter` project + network + pool

```bash
# 1. project = isolation/naming boundary, inherited by everything in it
lxc project create datacenter

# 2. a private bridge for cluster-internal traffic (see 03-architecture)
lxc network create datacenter-net \
    --project datacenter \
    ipv4.address=10.10.0.1/24 \
    ipv4.nat=true \
    ipv6.address=none \
    --type=bridge

# 3. one storage pool; snapshots/restores live here
lxc storage create datacenter-pool dir   # or: zfs / btrfs if available
```

> Keeping the network and pool **inside** the project means `lxc stop
> datacenter/*` and the project-bound assets all stay together and are
> discarded/restored as one unit.

---

## Phase 3 — Profiles (codify CPU/mem/disk/nesting once)

Profiles are reusable named recipes. Write the two below to disk
(`k3s-server.profile.yml`, `k3s-worker.profile.yml`) and apply them.

```yaml
# k3s-server.profile.yml — control-plane node
description: k3s server in the datacenter project
name: k3s-server
config:
  security.nesting: "true"
  security.privileged: "false"
  linux.sysctl.kernel.apparmor_restrict_unprivileged_userns: "0"
  limits.cpu: "4"
  limits.memory: 8GiB
  limits.disk: 50GiB
devices:
  eth0:
    name: eth0
    network: datacenter-net
    type: nic
  root:
    path: /
    pool: datacenter-pool
    type: disk
```

```yaml
# k3s-worker.profile.yml — one of the workers
description: k3s worker in the datacenter project
name: k3s-worker
config:
  security.nesting: "true"
  security.privileged: "false"
  linux.sysctl.kernel.apparmor_restrict_unprivileged_userns: "0"
  limits.cpu: "2"
  limits.memory: 6GiB
  limits.disk: 50GiB
devices:
  eth0:
    name: eth0
    network: datacenter-net
    type: nic
  root:
    path: /
    pool: datacenter-pool
    type: disk
```

Register and use them:

```bash
lxc profile create k3s-server --project datacenter
cat k3s-server.profile.yml | lxc profile edit k3s-server --project datacenter
lxc profile create k3s-worker --project datacenter
cat k3s-worker.profile.yml | lxc profile edit k3s-worker --project datacenter
```

> `worker2` gets more disk; give it a second root via a storage volume or merge
> the profile with a `--disk=100GiB` override at launch.

---

## Phase 4 — Launch the four instances

```bash
# server (control plane)
lxc launch ubuntu:24.04 k3s-server --project datacenter \
    --profile k3s-server

# workers (clone the worker profile; worker2 overrides disk)
lxc launch ubuntu:24.04 k3s-worker1 --project datacenter --profile k3s-worker
lxc launch ubuntu:24.04 k3s-worker2 --project datacenter --profile k3s-worker \
    --disk=100GiB

# DNS box (Pi-hole) — attach to BOTH the cluster net and the LAN/management bridge
lxc launch ubuntu:24.04 dns --project datacenter \
    --profile default \
    -c limits.cpu=1 -c limits.memory=1GiB -c limits.disk=5GiB \
    -n lxdbr0 -n datacenter-net
```

Verify:

```bash
lxc list --project datacenter
lxc exec k3s-server --project datacenter -- ubuntu      # login, then set up k3s
```

---

## Phase 5 — Hostnames & static IPs (deterministic joining)

Fix `hostnamectl set-hostname` inside each instance, and pin static leases so
the k3s join never depends on DHCP timing:

```bash
lxc exec k3s-server  --project datacenter -- hostnamectl set-hostname k3s-server
lxc exec k3s-worker1 --project datacenter -- hostnamectl set-hostname k3s-worker1
lxc exec k3s-worker2 --project datacenter -- hostnamectl set-hostname k3s-worker2
lxc exec dns        --project datacenter -- hostnamectl set-hostname dns

# pin each to a stable IP on datacenter-net (server=.1 w1=.2 w2=.3 dns=.4)
lxc network set datacenter-net --project datacenter \
    ipv4.address 10.10.0.1/24   # or use per-device ipv4.address=10.10.0.X
```

---

## Phase 6 — Install k3s (server + join tokens)

```bash
# 6a. SERVER
lxc exec k3s-server --project datacenter -- bash -c '
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable=traefik" sh -
  cat /var/lib/rancher/k3s/server/node-token   # ← copy this JOIN TOKEN
'
```

```bash
# 6b. WORKERS — repeat replacing TOKEN / node-ip per worker
lxc exec k3s-worker1 --project datacenter -- bash -c '
  curl -sfL https://get.k3s.io | \
  K3S_URL="https://10.10.0.1:6443" \
  K3S_TOKEN="<JOIN-TOKEN>" \
  K3S_NODE_NAME="k3s-worker1" \
  sh -
'
# same for k3s-worker2 with K3S_NODE_NAME="k3s-worker2"
```

> `--disable=traefik` on the server avoids a control-plane-only traefik; the
> real ingress runs on `worker1` (see [03 — Architecture](03-architecture.md)).

```bash
# 6c. VERIFY — from the server
lxc exec k3s-server --project datacenter -- bash -c '
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  kubectl get nodes            # expect 3 nodes: Ready
  kubectl get pods -A          # healthy add-ons
'
# copy the kubeconfig out to your workstation for `just deploy`:
lxc file pull k3s-server/etc/rancher/k3s/k3s.yaml --project datacenter k3s.yaml
```

---

## Phase 7 — Pi-hole (DNS)

```bash
lxc exec dns --project datacenter -- bash -c '
  curl -sSL https://install.pi-hole.net | bash     # or apt install pihole
  # bind to 10.10.0.4 / the LAN bridge; set router DHCP to hand out 10.10.0.4
'
```

---

## Phase 8 — Persisting the cluster across `lxc stop/start`

Stop/start **is** the persistence model: state lives on disk in the pool and
survives both. The join is stable because hostnames + IPs are static.

```bash
# STOP the whole datacenter instantly (returns all RAM/CPU to the host):
lxc stop datacenter/* --project datacenter
#      ^ wildcard across the project = one command for every instance

# START it all back up (server first, so workers find it):
lxc start k3s-server --project datacenter
sleep 10                # let etcd + api settle
lxc start k3s-worker1 k3s-worker2 dns --project datacenter
kubectl get nodes       # all back, state intact
```

> **Gotcha:** start the **server first**, then workers, so the join isn't a
> race. And remember: `stop` is a clean teardown (fresh boot on start); it is
> **not** suspend/resume. To keep in-memory process state, take a *snapshot*
> and `restore` it instead (Phase 9 / ops recipe).

---

## Phase 9 — Snapshot (the backup primitive)

```bash
lxc snapshot k3s-server --project datacenter snap-001
lxc snapshot k3s-worker2 --project datacenter data-before-upgrade

# restore (annihilates current state, back to snapshot):
lxc restore k3s-server snap-001 --project datacenter
```

Snapshots make the [Backup/Restore ops job](05-ops-workflow.md) a two-liner.

---

## Reference: one-file "reset" (tear everything down)

```bash
lxc stop datacenter/* --project datacenter
lxc delete datacenter/* --project datacenter
lxc project delete datacenter
lxc network delete datacenter-net   # and storage as you prefer
```

---

## 🧭 Navigation

► **[Next: 05 — Ops workflow](05-ops-workflow.md)**

◄ **[Back: 03 — Architecture](03-architecture.md)** · [Back: 02 Virtualization Layer](README.md)
