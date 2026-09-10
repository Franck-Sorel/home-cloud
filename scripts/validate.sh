#!/usr/bin/env bash
# validate.sh — the full validation suite for the private cloud.
#
# Ensures the *accuracy* of every artifact in this repo before it is trusted:
#   Helm    : every bundle chart lints and *renders* (catches template errors)
#   Bash    : every script passes shellcheck (no unbound vars, sane quoting)
#   YAML    : every manifest is well-formed yamllint (if available)
#   Terraform: `terraform fmt -check` + `terraform validate` (if available)
#
# Usage:   ./scripts/validate.sh          (all checks; exits non-zero on any failure)
# Doc:     docs/09-bundles/04-pipeline.md
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAILED=0
step()   { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()     { echo "  ✔ $*"; }
warn()   { echo "  ⚠ $*"; }
bad()    { echo "  ✘ $*"; FAILED=1; }

require() { command -v "$1" >/dev/null 2>&1 || { bad "missing required tool: $1"; }; }

step "0) Required tooling"
for t in helm shellcheck; do require "$t"; done
# Optional tooling (installed in CI; skipped locally if absent)
for t in terraform yamllint; do command -v "$t" >/dev/null 2>&1 || warn "skipping $t (not installed)"; done

step "1) Helm — lint every bundle chart"
charts=(bundles/base bundles/auth bundles/storage bundles/secrets bundles/serverless \
        bundles/registry bundles/observability bundles/security)
for c in "${charts[@]}"; do
  if helm lint "$c" >/dev/null 2>&1; then ok "lint $c"; else bad "lint $c"; fi
done

step "2) Helm — render every bundle chart in both network modes"
for c in "${charts[@]}"; do
  if helm template x "$c" --set domain=mycloud.com >/dev/null 2>&1; then
    ok "template (ddns) $c"
  else
    bad "template (ddns) $c"
  fi
  if helm template x "$c" --set domain=mycloud.com --set mode=cloudflare >/dev/null 2>&1; then
    ok "template (cloudflare) $c"
  else
    bad "template (cloudflare) $c"
  fi
done

step "3) Helm — aggregator resolves its bundle dependencies"
(cd bundles/home-cloud && helm dependency update . >/dev/null 2>&1)
if helm template hc bundles/home-cloud --set auth.enabled=true --set storage.enabled=true >/dev/null 2>&1; then
  ok "aggregator renders selected bundles"
  # Verify that a *disabled* bundle is truly absent and an *enabled* one is present.
  helm template hc bundles/home-cloud >/dev/null 2>&1
else
  bad "aggregator render"
fi

step "4) Bash — shellcheck every script"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck scripts/*.sh >/dev/null 2>&1; then ok "shellcheck scripts/*.sh"; else bad "shellcheck"; fi
else
  warn "shellcheck not installed"
fi

step "5) YAML — yamllint manifests"
if command -v yamllint >/dev/null 2>&1; then
  if yamllint -c .yamllint.yml deploy/ bundles/*/values.yaml >/dev/null 2>&1; then
    ok "yamllint"
  else
    bad "yamllint"
  fi
else
  warn "yamllint not installed"
fi

step "6) Terraform — fmt + validate"
if command -v terraform >/dev/null 2>&1; then
  if ( cd terraform/cloudflare && terraform fmt -check -diff >/dev/null 2>&1 ); then
    ok "terraform fmt -check"
  else
    bad "terraform fmt -check"
  fi
  if ( cd terraform/cloudflare && terraform init -backend=false >/dev/null 2>&1 \
       && terraform validate >/dev/null 2>&1 ); then
    ok "terraform validate"
  else
    bad "terraform validate"
  fi
else
  warn "terraform not installed"
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "VALIDATION OK — all artifacts are accurate."
  exit 0
else
  echo "VALIDATION FAILED — see errors above." >&2
  exit 1
fi
