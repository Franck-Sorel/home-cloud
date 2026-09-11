# 🔀 04 — Migration safety (risks, conflicts, fine-tuning rules)

> **Who this is for:** the reviewer and anyone debugging a migration step. This
> page collects the rules that keep the move conflict-free and reversible, and
> the specific risks with their mitigations.

---

## The fine-tuning rules (non-negotiable)

1. **Never rename a public contract.** Namespaces, `Service` names/ports, `IngressRoute`
   names, and `Middleware` names are frozen. Private charts target them by name.
2. **Public CI stays green.** `just validate` and the glue `e2e` must pass after every
   public change. If a milestone would break it, that milestone is misplanned.
3. **Public changes are minimal & additive.** No surgery on the wrap; add contract
   docs / genericize later (M7) only.
4. **Private is additive and isolated.** Each private chart is self-contained and
   independently reversible; a failing private PR never blocks the public repo.
5. **Versions/secrets never leak.** Only the private repo holds exact versions + SOPS
   secrets; the public repo holds placeholders and generic guidance.
6. **One cross-repo invariant = the contract table.** Changing it requires a paired PR
   in both repos, reviewed together.

---

## Risk register

| Risk | Where | Mitigation |
|------|-------|------------|
| Public wrap + private workload disagree on Service name/port | seam | Freeze contracts (imutable table); private charts validated in private CI against them |
| Renaming a namespace/Svc breaks the running cluster | public/private | Rule 1; never rename; if forced, paired PR + both CI green |
| Version pin removal (M7) breaks public CI | public | Do it LAST; keep CI inputs but mark "CI-only"; run `just validate` + glue e2e before/after |
| Private heavy services exhaust RAM/disk on your machine | LXD | M0 sizing rule (32GiB for all-four; trim on 16–32); monitor disk-full; not suspend/resume |
| LXD commands drift from docs | LXD | Use corrected 2026 commands (snap `5.21/stable`, `-c/-d` flags, `--all --project`, copy default profile); shut into private `bring-up.sh` |
| SOPS/age secret mixup | secrets | Private age key never committed; `.sops.yaml` public key only; CI decrypts with a secret |
| Traefik/service 404/502 recurs on real cluster | ingress | Already solved in the guides: one-type middleware (`security-headers`+`security-limits`) + `allow-ingress-from-traefik` + our own Traefik v3 (not bundled) |
| Private charts drift from upstream versions | private | `versions.lock` is the single source; each private PR bumps deliberately |
| Public e2e reveals private engine versions | public | M7 genericizes; GH Actions marks inputs as demonstration-only |

---

## Rollback procedure

- **Public:** each public change is one small commit → `git revert <sha>`; verify
  `just validate` + glue e2e green after revert.
- **Private:** `git revert` the milestone commit (or `git reset` on the branch) and
  re-release; the separate private chart means other milestones are unaffected.
- **Cluster (LXD):** `lxc snapshot <instance> pre-milestone` before a risky change;
  `lxc restore` if needed (M0 already proves snapshot/restore).

---

## Definition of "operational" (used by every milestone gate)

A bundle/feature is done only when **all** hold:

- Real workload `Running` (`kubectl -n <ns> get pods`).
- Its public contract `Service` (name:port) resolves; Traefik logs show **no**
  `<ns>/<svc>` service-not-found for it.
- A **functional** smoke passes (not just "object exists"):
  - MinIO → `mc ls`
  - Vault → `vault status` + a dynamic credential
  - Keycloak → token + OIDC rule
  - Observability → Grafana health + a Loki/Prometheus query
  - Harbor → push/pull
  - OpenFaaS → deploy + invoke a function
- The corresponding CI (public glue, or private real) is green.

---

## Navigation

◄ [Back to README](README.md)
