# =============================================================================
# justfile — the one command you need for the private cloud.
#
#   just                    # list everything you can do
#   just doctor             # check tooling
#   just validate           # full accuracy check (helm + shell + yamllint + tf)
#   just apply base auth    # deploy just the bundles you chose
#   just package            # build release tarballs
#   just publish            # push bundles as OCI packages to ghcr.io
#
# Version/help: see docs/09-bundles/04-pipeline.md
# =============================================================================

set positional-arguments
set shell := ["bash", "-c"]

# --- configuration -----------------------------------------------------------
# Override on the CLI:  just apply base domain=cloud.example.com mode=cloudflare
DOMAIN   := env_var_or_default("DOMAIN", "mycloud.com")
MODE     := env_var_or_default("MODE", "ddns")            # ddns | cloudflare
REGISTRY := env_var_or_default("REGISTRY", "ghcr.io/Franck-Sorel")
VERSION  := env_var_or_default("VERSION", "0.1.0")

# --- default: show help -------------------------------------------------------
default:
    @just --list

# --- tooling ------------------------------------------------------------------
# Verify the tools this repo relies on are installed.
doctor:
    @echo "tooling check:"
    @for t in helm shellcheck terraform yamllint kubectl just; do \
        if command -v "$$t" >/dev/null 2>&1; then echo "  ✔ $$t"; \
        else echo "  ✘ $$t (missing)"; fi; \
    done

# Vendored deps for the aggregator chart (bundles/home-cloud/charts).
deps:
    @cd bundles/home-cloud && helm dependency update .

# --- accuracy pipeline ---------------------------------------------------------
# Full validation: helm lint + render (ddns & cloudflare), shellcheck, yamllint, terraform.
alias v := validate

validate:
    @./scripts/validate.sh

# Quick lint only (helm + shell), skips heavy terraform.
lint:
    @echo "helm lint:"
    @for c in bundles/base bundles/auth bundles/storage bundles/secrets bundles/serverless \
              bundles/registry bundles/observability bundles/security; do \
        helm lint "$$c" || exit 1; \
    done
    @echo "shellcheck:"; shellcheck scripts/*.sh

# --- deploy (the UX: choose what you want) -------------------------------------
# just deploy base auth storage        → those three bundles only
# just deploy base                     → base only
deploy bundles:
    @DOMAIN="{{DOMAIN}}" MODE="{{MODE}}" ./scripts/apply.sh {{bundles}}
    @DOMAIN="{{DOMAIN}}" MODE="{{MODE}}" ./scripts/apply.sh {{bundles}}

# --- packaging & release -------------------------------------------------------
# Build release tarballs for every bundle into dist/.
package:
    @./scripts/package.sh

# Publish every bundle + the aggregator as OCI charts to $REGISTRY.
# Requires:  helm registry login ghcr.io -u <user>   (PAT with write:packages)
publish:
    @./scripts/package.sh
    @set -e; for f in dist/*.tgz; do \
        echo "→ push $$f"; \
        helm push "$$f" oci://{{REGISTRY}}; \
    done

# --- operators ------------------------------------------------------------------
healthcheck:
    @./scripts/healthcheck.sh

smoke:
    @./scripts/smoke.sh

backup:
    @./scripts/backup.sh
