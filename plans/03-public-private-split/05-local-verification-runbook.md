# 05 — Local Verification Runbook (LXD + k3s, mirroring the CI workflow)

> **Why this exists.** The `foundation` GitHub Action keeps failing at the very
> first network call inside the LXD container: `curl` to `get.k3s.io` times out
> (`exit 28`). Diagnostics show DNS resolves but **no outbound TCP** — the runner
> host isn't forwarding/NAT-ing the LXD bridge. We can't fix a runner we don't
> control. So we **prove the steps on the local datacenter host first**, where the
> host firewall/NAT **should** just work, then promote the verified steps back
> into the workflow.
>
> The commands below are the **exact** ones from `.github/workflows/foundation.yml`
> (same project, network, storage, profile, launch, k3s install, join, verify),
> preceded by the host-prep that the LinsNotes guide proves is required. Each
> section shows the workflow step it corresponds to.

**This runbook touches the host** (installs/init LXD, may remove Docker, turns
off swap, launches containers). Run it **on the datacenter host**, not inside a
container.

---

## 0. Preflight survey (READ-ONLY) — know what you're working with

The guide's Step 1. Nothing changes the system here.

```bash
lsb_release -a
free -h; nproc; df -h /
ip -brief addr; ip route
swapon --show; grep -i swap /etc/fstab
which docker && docker --version || echo "docker: absent"
snap list docker 2>/dev/null
sudo nft list ruleset
sudo vgs; sudo lvs
lxc version            # if "Server: unreachable" -> LXD daemon not initialized yet
```

Observed on **this** host (so the runbook is tailored):

| Check | Value | Implication |
|-------|-------|-------------|
| LXD snap | `5.21.7` installed, daemon **inactive** | must run `lxd init` |
| swap | `/swap.img` 8G, **active** | kubelet refuses to start → must disable |
| Docker | `29.7.2` installed (bridges down) | the guide's #1 conflict → forward-policy / backend risk → decide |

RAM `93Gi` is ample; sizing below is CI-faithful but small enough to be safe.

---

## 1. Host prep — resolve the three blockers (falls under workflow's "Install LXD + init")

### 1a. Docker: the article's biggest conflict (decision required)

Docker sets the kernel **FORWARD policy to `drop`** and can push LXD onto the
legacy `xtables` firewall backend instead of `nftables`. Both break container
egress — the *same* symptom CI shows. For a clean lab the guide removes Docker
entirely:

```bash
# BACK UP anything you keep in Docker first — volumes disappear with it!
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null
sudo snap remove docker     # if installed as a snap
```

**Alternative if you must keep Docker:** don't remove it; instead verify in
section 4 that (a) `lxc info` reports `firewall: nftables`, and (b) the `FORWARD`
chain allows `datacenter-net` traffic. A stopped Docker with no rules is usually
fine, but a running one is a gamble.

### 1b. Swap off — kubelet hard-requires it

```bash
sudo swapoff /swap.img
sudo sed -i '/swap.img/ s/^/#/' /etc/fstab
grep -i swap /etc/fstab     # swap line should now start with '#'
swapon --show               # should print nothing
free -h                     # Swap should read 0B
```

### 1c. LXD init + host userns (mirrors workflow's "Install LXD + init")

```bash
# Ubuntu 24.04 restricts unprivileged user namespaces by default; LXD needs them.
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
# make it stick across reboots (workflow does it per-run; on the host persist it):
sudo tee /etc/sysctl.d/99-lxd-userns.conf >/dev/null <<<"kernel.apparmor_restrict_unprivileged_userns=0"

sudo lxd init --minimal     # zfs/btrfs pool + default lxdbr0 bridge
sudo usermod -aG lxd "$USER"   # manage LXD without sudo; log out/in or: newgrp lxd
lxc version                 # now "Server: 5.21.x" — daemon reachable
```

> The guide: on a fresh Ubuntu the firewall allows everything by default, so
> LXD's own `table inet lxd` NAT just works. This is why local **should** work
> where CI doesn't. `lxc info | grep -iA2 firewall` should report `nftables`.

---

## 2. Project, network, storage, profiles (workflow: "Create project, network, storage, profiles")

```bash
export PROJECT=datacenter
export NET=datacenter-net
export POOL=datacenter-pool
export IMAGE=ubuntu:24.04

Project() { sudo lxc "$@" --project "$PROJECT"; }
Project project create "$PROJECT" 2>/dev/null || true
sudo lxc network create "$NET" --type bridge --project "$PROJECT" \
  ipv4.address=10.10.0.1/24 ipv4.nat=true ipv6.address=none 2>/dev/null || true
sudo lxc storage create "$POOL" dir --project "$PROJECT" 2>/dev/null || true

# New project's default profile is EMPTY -> copy the main profile in.
sudo lxc profile show default --project default | sudo lxc profile edit default

sudo lxc profile create dc-base --project "$PROJECT" 2>/dev/null || true
sudo lxc profile set dc-base --project "$PROJECT" "limits.cpu=1"
sudo lxc profile set dc-base --project "$PROJECT" "limits.memory=1GiB"
sudo lxc profile set dc-base --project "$PROJECT" "security.nesting=true"
# k3s needs to load kernel modules (br_netfilter, overlay) via modprobe in
# ExecStartPre; an unprivileged container can't (no CAP_SYS_MODULE), so the
# server crash-loops. Privileged is required for k3s-in-LXD (article Part 2
# "the privileged profile"). Lab-only, not a security boundary.
sudo lxc profile set dc-base --project "$PROJECT" "security.privileged=true"
sudo lxc profile set dc-base --project "$PROJECT" "linux.kernel_modules=ip_tables,ip6_tables,overlay"
```

> **Gotcha (verified painful):** do **NOT** add `linux.sysctl.*` keys to the
> profile (neither `kernel.apparmor_restrict_unprivileged_userns` nor
> `net.ipv6.conf.all.disable_ipv6`). LXD's go-lxc rejects them:
> `Failed to set LXC config: <key>`. The userns fix belongs on the *host*
> (1c); the ipv6 disable is done *inside* the container at runtime (section 6).

---

## 3. Launch k3s server + workers (workflow: "Launch k3s server + workers")

```bash
W=2    # number of workers; mirror the workflow default
sudo lxc launch "$IMAGE" k3s-server --project "$PROJECT" --profile dc-base \
  --config "limits.cpu=2" --config "limits.memory=2GiB" \
  --device "root,size=20GiB" --storage "$POOL" --network "$NET"
i=1
while [ "$i" -le "$W" ]; do
  sudo lxc launch "$IMAGE" "k3s-worker$i" --project "$PROJECT" --profile dc-base \
    --config "limits.cpu=1" --config "limits.memory=1GiB" \
    --device "root,size=15GiB" --storage "$POOL" --network "$NET"
  i=$((i+1))
done
sudo lxc list --project "$PROJECT"
```

---

## 4. Connectivity probe (workflow: "Test container connectivity")

This is the step that fails in CI. **Locally it must ALL pass.** It isolates
whether the host forwards/NATs the bridge.

> **CI-only prerequisite (Docker's FORWARD policy).** GitHub runners run Docker,
> which sets the kernel `FORWARD` policy to `DROP` and only allows its own bridge
> (`172.17.0.0/16`). LXD container egress is *forwarded* traffic, so it gets
> dropped → in-container `curl` times out. The workflow opens the LXD bridge
> explicitly (right after creating the network, before k3s install):
> ```bash
> sudo iptables -I FORWARD -i "$NET" -j ACCEPT
> sudo iptables -I FORWARD -o "$NET" -j ACCEPT
> ```
> **Never restart Docker** — it rewrites these rules on start. We only insert our
> own rules on top. On a clean local host (no Docker) this is unnecessary; the
> probe below confirms egress either way.

```bash
echo "=== HOST: default route ==="; ip route
echo "=== HOST: NAT rules for 10.10.0.0/24 ==="
sudo iptables -t nat -L -n | grep -E '10\.10\.0|MASQUERADE' || echo "NO NAT RULES"
echo "=== HOST: FORWARD policy ==="; sudo iptables -L FORWARD -n | head -10

sudo lxc exec --project "$PROJECT" k3s-server -- bash -c '
  echo "=== CONTAINER: IPv6 status ==="; sysctl net.ipv6.conf.all.disable_ipv6 || true
  echo "=== CONTAINER: default route ==="; ip route
  echo "=== CONTAINER: ping 8.8.8.8 (ICMP via NAT) ==="
  ping -4 -c 2 -W 3 8.8.8.8 || echo "PING FAIL"
  echo "=== CONTAINER: reach host bridge gw 10.10.0.1:53 ==="
  timeout 3 bash -c "echo > /dev/tcp/10.10.0.1/53" && echo "host:53 reachable" || echo "host:53 FAIL"
  echo "=== CONTAINER: curl http://example.com (port 80) ==="
  curl -4 -v --max-time 10 http://example.com -o /dev/null 2>&1 | tail -4 || echo "HTTP FAIL"
  echo "=== CONTAINER: curl https://1.1.1.1 (IP, no DNS) ==="
  curl -4 -v --max-time 10 https://1.1.1.1 -o /dev/null 2>&1 | tail -4 || echo "HTTPS-IP FAIL"
  echo "=== CONTAINER: curl get.k3s.io (IPv4, max 60s) ==="
  curl -4 -sfL --max-time 60 -o /tmp/k3s-install.sh https://get.k3s.io && wc -c /tmp/k3s-install.sh \
    || echo "CURL FAIL rc=$?"
'
```

**PASS =** `ping` replies who's there, `host:53 reachable`, HTTP/HTTPS succeed,
`wc -c` shows a non-zero installer byte count. Any FAIL means the host firewall
is in the way → re-check section 1a/1b (Docker forward policy, `nftables` backend).

---

## 5. Install k3s server (workflow: "Install k3s server")

```bash
# -c 4 returns "IP (iface)" e.g. "10.10.0.159 (eth0)" — strip the iface
SERVER_IP=$(sudo lxc list --project "$PROJECT" --format csv -c 4,n | awk -F, '/k3s-server/{print $1; exit}' | sed 's/ .*//')
echo "SERVER_IP=$SERVER_IP"

sudo lxc exec --project "$PROJECT" k3s-server -- bash -c "
  set -euxo pipefail
  sysctl -w net.ipv6.conf.all.disable_ipv6=1 || true     # belt-and-suspenders
  curl -4 -sfL --max-time 120 -o /tmp/k3s-install.sh https://get.k3s.io   # separate download = visible
  echo 'install script bytes:'; wc -c /tmp/k3s-install.sh
  INSTALL_K3S_EXEC='server --disable=traefik --node-ip=$SERVER_IP --tls-san=$SERVER_IP --tls-san=localhost --flannel-iface=eth0' \
  K3S_KUBECONFIG_MODE=644 sh /tmp/k3s-install.sh
"

for i in $(seq 1 120); do
  if sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml; kubectl get node k3s-server 2>/dev/null | grep -q Ready'; then
    echo "server Ready"; break
  fi
  echo "waiting server... ($i)"; sleep 5
done
# FAIL LOUDLY if the server never became Ready — otherwise the agent join hangs
# forever (k3s service is Type=notify with TimeoutStartSec=0).
sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml; kubectl get node k3s-server 2>/dev/null | grep -q Ready' \
  || { echo "k3s server never became Ready — see Diagnose"; exit 1; }

sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'cat /var/lib/rancher/k3s/server/node-token' | tr -d '\n' > /tmp/token
echo "K3S_TOKEN=$(cat /tmp/token)"
```

**Success looks like:** the script prints `install script bytes: NNNNN` (non-zero),
then `[INFO] ... Finding release ... Downloading binary` lines, then within the
poll loop `server Ready`.

**If it hangs silently again:** you've reproduced the CI bug locally. Run the
section-4 probe again; a silent install = empty stdin = curl got nothing, which
still points at host egress, NOT at k3s.

---

## 6. Join workers (workflow: "Join workers (parallel)")

Workers are independent → join them in **parallel** (bash background jobs; LXD
state must persist in a single job, so no cross-job matrix). Each join is wrapped
in `timeout` because k3s's `systemctl start` blocks forever (`Type=notify`,
`TimeoutStartSec=0`) if the agent can't reach the server — a timeout turns a
silent hang into a loud failure.

```bash
W=2
pids=()
for i in $(seq 1 "$W"); do
  (
    set -euo pipefail
    WIP=$(sudo lxc list --project "$PROJECT" --format csv -c 4,n | awk -F, "/k3s-worker$i/{print \$1; exit}" | sed 's/ .*//')
    echo "joining k3s-worker$i at $WIP"
    timeout 300 sudo lxc exec "k3s-worker$i" --project "$PROJECT" -- bash -c "
      sysctl -w net.ipv6.conf.all.disable_ipv6=1 || true
      curl -4 -sfL https://get.k3s.io | \
        K3S_URL='https://${SERVER_IP}:6443' K3S_TOKEN='${K3S_TOKEN}' K3S_NODE_NAME='k3s-worker$i' \
        INSTALL_K3S_EXEC='--node-ip=$WIP --flannel-iface=eth0' sh -s -
    "
  ) &
  pids+=("$!")
done
FAIL=0
for p in "${pids[@]}"; do wait "$p" || FAIL=1; done
[ "$FAIL" = "0" ] || { echo "one or more workers failed to join"; exit 1; }
```

---

## 7. Verify cluster (workflow: "Verify cluster (all nodes Ready)")

```bash
W=2
sudo lxc file pull k3s-server/etc/rancher/k3s/k3s.yaml --project "$PROJECT" k3s.yaml
sed -i "s/127.0.0.1/${SERVER_IP}/" k3s.yaml
export KUBECONFIG=$PWD/k3s.yaml
kubectl cluster-info
for i in $(seq 1 60); do
  N=$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready || true)
  echo "ready=$N/$((1+W)) (iter $i)"; [ "$N" -ge "$((1+W))" ] && break; sleep 5
done
kubectl get nodes -o wide
kubectl get pods -A -o wide
[ "$(kubectl get nodes --no-headers | grep -c Ready)" -ge "$((1+W))" ] && echo "ALL NODES READY ✅"
```

---

## 8. Toggle + snapshot sanity (workflow: "Toggle + snapshot sanity")

```bash
sudo lxc snapshot k3s-server snap-ci --project "$PROJECT"
sudo lxc restore k3s-server snap-ci --project "$PROJECT"
sudo lxc stop --all --project "$PROJECT"
sudo lxc start k3s-server --project "$PROJECT"
sleep 15
export KUBECONFIG=$PWD/k3s.yaml
kubectl get nodes -o wide || true
echo "FOUNDATION GREEN ✅"
```

---

## 9. Promote verified steps back to CI

Once sections 2–8 pass locally with **no** firewall fixes needed, the workflow's
k3s/project/profile steps are proven correct — the CI-only blocker is the runner's
egress. What to change in `.github/workflows/foundation.yml`:

1. **Keep** the `lxd init` + host `userns` sysctl (already there).
2. **Keep** the runtime in-container `disable_ipv6` + `curl -4` (works everywhere).
3. **Remove** the if-only-for-CI workarounds once a runner that NATs is available
   (or document that `foundation` is *verified-locally*, not *CI-runnable*).
4. Reset config to CI sizing via `workflow_dispatch` inputs as before.

The local run is the source of truth for the k3s install/join/verify commands;
the CI workflow should reproduce them byte-for-byte.

---

## Cleanup / reset (if you need to start over)

```bash
lxc stop --all --project datacenter 2>/dev/null
lxc delete --all --project datacenter 2>/dev/null
lxc project delete datacenter 2>/dev/null
# swap back on (if you turned it off for the lab):
# sudo fallocate -l 8G /swap.img && sudo mkswap /swap.img && sudo swapon /swap.img
```
