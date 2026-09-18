#!/usr/bin/env bash
# verify-local.sh — run the EXACT `foundation` workflow steps on the local host.
#
# Faithful mirror of .github/workflows/foundation.yml (steps 2–8). Use this to
# prove the LXD+k3s steps work on your datacenter host (where bridge NAT works)
# before promoting them back into CI.
#
# PREREQUISITES (host-prep, see 05-local-verification-runbook.md §1):
#   * Docker removed OR confirmed not blocking (nftables backend + FORWARD allows)
#   * swap OFF, lxd snap installed + `lxd init` run, host userns sysctl set
#
# Usage:   sudo ./verify-local.sh [workers=2]
# NOTE:    run with sudo (lxc commands in the workflow use sudo). This script
#          only creates containers in a throwaway `datacenter` project — it does
#          NOT touch your other LXD state beyond that project's resources.
set -euo pipefail

W="${1:-2}"
PROJECT="${PROJECT:-datacenter}"
NET="${NET:-datacenter-net}"
POOL="${POOL:-datacenter-pool}"
IMAGE="${IMAGE:-ubuntu:24.04}"

LXC() { sudo lxc "$@" --project "$PROJECT"; }

echo "=== [2] Create project, network, storage, profiles ==="
LXC project create "$PROJECT" 2>/dev/null || true
sudo lxc network create "$NET" --type bridge --project "$PROJECT" ipv4.address=10.10.0.1/24 ipv4.nat=true ipv6.address=none 2>/dev/null || true
sudo lxc storage create "$POOL" dir --project "$PROJECT" 2>/dev/null || true
sudo lxc profile show default --project default | sudo lxc profile edit default
sudo lxc profile create dc-base --project "$PROJECT" 2>/dev/null || true
sudo lxc profile set dc-base --project "$PROJECT" "limits.cpu=1"
sudo lxc profile set dc-base --project "$PROJECT" "limits.memory=1GiB"
sudo lxc profile set dc-base --project "$PROJECT" "security.nesting=true"
sudo lxc profile set dc-base --project "$PROJECT" "security.privileged=true"
sudo lxc profile set dc-base --project "$PROJECT" "linux.kernel_modules=ip_tables,ip6_tables,overlay"

echo "=== [3] Launch k3s server + workers ==="
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

echo "=== [4] Test container connectivity (DNS + outbound HTTPS) ==="
echo "=== HOST: default route ==="; ip route
echo "=== HOST: NAT rules for 10.10.0.0/24 ==="
sudo iptables -t nat -L -n | grep -E '10\.10\.0|MASQUERADE' || echo "NO NAT RULES"
echo "=== HOST: FORWARD policy ==="; sudo iptables -L FORWARD -n | head -10
if ! sudo lxc exec --project "$PROJECT" k3s-server -- bash -c '
    echo "=== CONTAINER: IPv6 status ==="; sysctl net.ipv6.conf.all.disable_ipv6 || true
    echo "=== CONTAINER: default route ==="; ip route
    echo "=== CONTAINER: ping 8.8.8.8 ==="
    ping -4 -c 2 -W 3 8.8.8.8 || echo "PING FAIL"
    echo "=== CONTAINER: reach gw 10.10.0.1:53 ==="
    timeout 3 bash -c "echo > /dev/tcp/10.10.0.1/53" && echo "host:53 reachable" || echo "host:53 FAIL"
    echo "=== CONTAINER: curl http://example.com ==="
    curl -4 -v --max-time 10 http://example.com -o /dev/null 2>&1 | tail -4 || echo "HTTP FAIL"
    echo "=== CONTAINER: curl https://1.1.1.1 ==="
    curl -4 -v --max-time 10 https://1.1.1.1 -o /dev/null 2>&1 | tail -4 || echo "HTTPS-IP FAIL"
    echo "=== CONTAINER: curl get.k3s.io ==="
    curl -4 -sfL --max-time 60 -o /tmp/k3s-install.sh https://get.k3s.io && wc -c /tmp/k3s-install.sh \
      || echo "CURL FAIL rc=$?"
' ; then
  echo "!! connectivity check failed — fix host firewall before continuing"
  exit 1
fi

echo "=== [5] Install k3s server ==="
SERVER_IP=$(sudo lxc list --project "$PROJECT" --format csv -c 4,n | awk -F, '/k3s-server/{print $1; exit}' | sed 's/ .*//')
echo "server ip: $SERVER_IP"
if ! sudo lxc exec --project "$PROJECT" k3s-server -- bash -c "
    set -euxo pipefail
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 || true
    curl -4 -sfL --max-time 120 -o /tmp/k3s-install.sh https://get.k3s.io
    echo 'install script bytes:'; wc -c /tmp/k3s-install.sh
    INSTALL_K3S_EXEC='server --disable=traefik --node-ip=$SERVER_IP --tls-san=$SERVER_IP --tls-san=localhost --flannel-iface=eth0' \
    K3S_KUBECONFIG_MODE=644 sh /tmp/k3s-install.sh
"; then
  echo "!!!! server install FAILED — dumping diagnostics (mirrors CI Diagnose step)"
  sudo lxc exec --project "$PROJECT" k3s-server -- systemctl status k3s --no-pager -l || true
  sudo lxc exec --project "$PROJECT" k3s-server -- journalctl -u k3s --no-pager -n 150 || true
  sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'ls -la /var/lib/rancher/k3s/ 2>/dev/null; tail -100 /var/lib/rancher/k3s/k3s.log 2>/dev/null' || true
  sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'ls -la /etc/rancher/k3s/ 2>/dev/null' || true
  exit 1
fi

for i in $(seq 1 60); do
  if sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml; kubectl get node k3s-server 2>/dev/null | grep -q Ready'; then
    echo "server Ready"; break
  fi
  echo "waiting server... ($i)"; sleep 5
done
# fail loudly if the server never became Ready (else the agent join hangs forever)
sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml; kubectl get node k3s-server 2>/dev/null | grep -q Ready' \
  || { echo "k3s server never became Ready"; exit 1; }

K3S_TOKEN=$(sudo lxc exec --project "$PROJECT" k3s-server -- bash -c 'cat /var/lib/rancher/k3s/server/node-token' | tr -d '\n')
echo "token acquired"

echo "=== [6] Join workers (parallel, with timeout) ==="
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

echo "=== [7] Verify cluster (all nodes Ready) ==="
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
[ "$(kubectl get nodes --no-headers | grep -c Ready)" -ge "$((1+W))" ]

echo "=== [8] Toggle + snapshot sanity ==="
sudo lxc snapshot k3s-server snap-ci --project "$PROJECT"
sudo lxc restore k3s-server snap-ci --project "$PROJECT"
sudo lxc stop --all --project "$PROJECT"
sudo lxc start k3s-server --project "$PROJECT"
sleep 15
export KUBECONFIG=$PWD/k3s.yaml
kubectl get nodes -o wide || true
echo "FOUNDATION GREEN ✅"
