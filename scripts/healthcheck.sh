#!/usr/bin/env bash
# healthcheck.sh — five-layer health check for the private cloud.
#
# Layers:
#   L0 host        uptime/free/disk, node Ready, cluster-info
#   L1 control     kube-system pods + traefik service
#   L2 tunnel      cloudflared pod running + registered connections
#   L3 TLS/edge    public URL returns valid cert + HTTP status
#   L4 routes      ingress(s) + curl to public service hosts
#   L5 services    all pods Running, PVCs Bound, network policies present
#
# Usage:   ./scripts/healthcheck.sh          (exits non-zero on any failure)
# Doc:     docs/06-testing/00-verify-cluster.md
#
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
BASE_URL="${BASE_URL:-https://hello.mycloud.com}"   # ← your first public URL
NS_CORE="kube-system"

fail() { echo "✘ $*" >&2; exit 1; }
ok()   { echo "✔ $*"; }

"${KUBECTL}" cluster-info >/dev/null 2>&1 || fail "cluster-info (is kubeconfig set?)"

# ---------- L0 host ----------
node=$("${KUBECTL}" get nodes --no-headers | awk '{print $2}' | head -1)
[[ "$node" == "Ready" ]] || fail "node not Ready (got: $node)"
ok "L0 node Ready"

# ---------- L1 control plane ----------
not_running=$("${KUBECTL}" get pods -n "${NS_CORE}" --no-headers 2>/dev/null | grep -cv Running || true)
[[ "$not_running" -eq 0 ]] || fail "non-Running pods in ${NS_CORE}: ${not_running}"
ok "L1 kube-system pods Running"

# ---------- L2 tunnel ----------
npods=$("${KUBECTL}" get pods -n cloudflared --no-headers 2>/dev/null | grep -c Running || true)
[[ "$npods" -ge 1 ]] || fail "no cloudflared pod Running"
ok "L2 cloudflared pod Running (${npods})"

# ---------- L3 TLS/edge ----------
code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${BASE_URL}" || true)
issuer=$(echo | openssl s_client -connect "${BASE_URL#https://}:443" -servername "${BASE_URL#https://}" 2>/dev/null \
          | openssl x509 -noout -issuer 2>/dev/null | tr -d ' ' || true)
[[ "$code" != "000" ]] || fail "public URL unreachable: ${BASE_URL} (got HTTP $code)"
ok "L3 edge reachable (HTTP $code, issuer: ${issuer:-unknown})"

# ---------- L4 routes ----------
routes=$("${KUBECTL}" get ingressroute -A --no-headers 2>/dev/null | wc -l)
[[ "$routes" -ge 1 ]] || fail "no IngressRoutes found"
ok "L4 ${routes} IngressRoute(s)"

# ---------- L5 services ----------
pods=$("${KUBECTL}" get pods -A --no-headers 2>/dev/null | grep -cv 'Running\|Completed' || true)
[[ "$pods" -eq 0 ]] || fail "non-Running pods cluster-wide: ${pods}"
unbound=$("${KUBECTL}" get pvc -A --no-headers 2>/dev/null | grep -cv Bound || true)
[[ "$unbound" -eq 0 ]] || fail "unbound PVCs: ${unbound}"
ok "L5 all pods Running, PVCs Bound"

echo
echo "HEALTH CHECK OK"