#!/usr/bin/env bash
# smoke.sh — lightweight, fast smoke test (for CronJob / CI).
# Exits non-zero if any critical probe fails.
#
# Usage:   ./scripts/smoke.sh
# Doc:     docs/06-testing/03-smoke-and-e2e.md
#
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
API_URL="${API_URL:-https://api.mycloud.com/health}"   # your public API
HELLO_URL="${HELLO_URL:-https://hello.mycloud.com/}"

fail() { echo "✘ $*" >&2; exit 1; }
ok()   { echo "✔ $*"; }

"${KUBECTL}" get nodes --no-headers | grep -q Ready || fail "no Ready node"
ok "node Ready"

running=$("${KUBECTL}" get pods -A --no-headers 2>/dev/null | grep -c Running || true)
[[ "$running" -ge 3 ]] || fail "too few Running pods (${running})"
ok "pods Running (${running})"

code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${HELLO_URL}" || true)
[[ "$code" == "200" ]] || fail "hello URL HTTP ${code} (expected 200)"
ok "hello reachable (HTTP ${code})"

api_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${API_URL}" || true)
[[ "$api_code" == "200" ]] || fail "api health HTTP ${api_code} (expected 200)"
ok "api reachable (HTTP ${api_code})"

echo
echo "SMOKE OK"