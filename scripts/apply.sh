#!/usr/bin/env bash
# apply.sh — install one or more bundles into the running cluster.
#
# The "choose what you want, not how" entry point. Renders each selected bundle
# chart and installs it with Helm.
#
# Usage:
#   ./scripts/apply.sh base                 # base only
#   ./scripts/apply.sh base auth storage    # several
#   ./scripts/apply.sh home-cloud auth=1 storage=1   # via aggregator (key=1 enables)
#
# Env:
#   DOMAIN (default mycloud.com)
#   MODE   (default ddns; "cloudflare" for the no-open-ports path)
#
# Doc: docs/09-bundles/01-bundles.md
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DOMAIN="${DOMAIN:-mycloud.com}"
MODE="${MODE:-ddns}"
# Optional: pass connector on/off to the base bundle, e.g. CONNECTORS=false
CONNECTORS="${CONNECTORS:-}"

declare -A CHART=(
  [base]=bundles/base
  [auth]=bundles/auth
  [storage]=bundles/storage
  [secrets]=bundles/secrets
  [serverless]=bundles/serverless
  [registry]=bundles/registry
  [observability]=bundles/observability
  [security]=bundles/security
)

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <bundle> [<bundle> ...]" >&2
  echo "available: ${!CHART[*]}" >&2
  exit 1
fi

for name in "$@"; do
  case "$name" in
    home-cloud)
      echo "→ aggregator: enabling selected capabilities (default base+security)"
      helm upgrade --install home-cloud bundles/home-cloud \
        --namespace apps --create-namespace
      ;;
    *)
      [[ -v CHART[$name] ]] || { echo "unknown bundle: $name" >&2; exit 1; }
      echo "→ install bundle: $name (mode=$MODE, domain=$DOMAIN)"
      args=(--set "domain=$DOMAIN" --set "mode=$MODE")
      if [[ -n "$CONNECTORS" ]]; then args+=(--set "connectors.enabled=$CONNECTORS"); fi
      helm upgrade --install "home-cloud-$name" "${CHART[$name]}" "${args[@]}"
      ;;
  esac
done

echo
echo "✔ bundles applied: $*"
echo "  next: ./scripts/healthcheck.sh   (or 'just healthcheck')"
