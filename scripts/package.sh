#!/usr/bin/env bash
# package.sh — build every bundle chart into .tgz packages for release.
#
# Usage:   ./scripts/package.sh [dist-dir]
# Env:     DIST (default dist/)
#
# Produces one .tgz per bundle that can be pushed to an OCI registry
# (helm push), or distributed as a tarball. The `home-cloud` aggregator is
# packaged with its bundle dependencies vendored so it is self-contained.
#
# Doc: docs/09-bundles/04-pipeline.md
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DIST="${DIST:-${1:-dist}}"
mkdir -p "$DIST"

charts=(base auth storage secrets serverless registry observability security)
for c in "${charts[@]}"; do
  echo "→ packaging bundles/$c"
  helm package "bundles/$c" --destination "$DIST" >/dev/null
done

echo "→ vendoring deps + packaging aggregator"
(cd bundles/home-cloud && helm dependency update . >/dev/null 2>&1)
helm package bundles/home-cloud --destination "$DIST" >/dev/null

echo
echo "✔ packages written to $DIST:"
ls -1 "$DIST"/*.tgz
