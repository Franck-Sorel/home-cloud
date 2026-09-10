# 🧰 04 — How to Extend

> **Who this is for:** the contributor who wants to add a **new bundle** or a
> **new cross-stack assertion** to the E2E story without breaking the runbook.

Everything here assumes you've read [01 — the plan](01-plan.md) and the repo's
bundle conventions ([`docs/09-bundles/01-bundles.md`](../../docs/09-bundles/01-bundles.md)).

---

## Add a new *assertion* (cheap, most common)

The assertions live inside the two heredoc bash scripts in
[`e2e.yml`](../../.github/workflows/e2e.yml):

- **Phase 1** script (`e2e-phase1.sh` heredoc) → checks A–E,
- **Phase 3** script (`e2e-phase3.sh` heredoc) → checks F.

Each check is a small function `return`-ing 0/1 plus a `run_check "<name>"
<func>` line. To add one:

```bash
assert_new_link(){
  kubectl ...   # your probe
  ...
  # return 1 with a specific message on failure
}
run_check "X1 my new cross-stack link"  assert_new_link
```

That's it — the `run_check` helper already:

- prints a granular `✔/✘ <name>` line,
- records a **JUnit** `<testcase>` (with `<failure>` on red),
- writes to the phase results file for the run summary,
- flips the job red only if any check fails (so *passing* additions don't break the run).

**Gotcha:** the check body is inside a single-quoted heredoc (`<<'PH1EOF'`), so
**no** variables are expanded at write time; the script reads `$RUNNER_TEMP`
itself at runtime. Keep the body at the block's indentation (YAML block-scalar
lines must be indented ≥ the first content line — a line at column 0 is a YAML
error). After editing, re-run `shellcheck` on the extracted body and
`yamllint -c .yamllint.yml .github/workflows/e2e.yml`.

---

## Add a *new bundle* to the E2E

1. **Add the bundle** to `bundles/<name>/` following the existing pattern (a
   `Chart.yaml`, a `values.yaml`, a namespace template, and optionally a
   routing/middleware/NetworkPolicy template). Register it in
   `scripts/apply.sh`'s `CHART` map and in the `justfile`.
2. **Add it to the aggregator** `bundles/home-cloud/Chart.yaml` as a dependency
   with a `<name>.enabled` condition, plus a section in its `values.yaml`, then
   `cd bundles/home-cloud && helm dependency update`.
3. **Update the aggregator render/lint** so `scripts/validate.sh` covers it.
4. **In `e2e.yml`**:
   - phase 1: add `<name>` to the `apply.sh` opt-in step and to the
     `assert_namespaces` list in the phase-1 script,
   - phase 3: add `--set <name>.enabled=...` to the aggregator install and a
     presence/absence check in `assert_enabled_present` / `assert_disabled_absent`,
   - decide whether your bundle's `tls.enabled` should be disabled in CI (it
     almost always should — no DNS).
5. If your bundle's *actual workload* comes from an upstream chart, document it
   in [02 — What works](02-what-works.md) as glue-proven / workload-media.

---

## Keep the report honest

- Add a row to [02 — What works](02-what-works.md) (what installs today) and
  [03 — What doesn't work](03-what-doesnt.md) (what still needs a real host or
  is only presence-checked).
- Never let an assertion claim a heavy workload is "serving" when CI only put
  a namespace/route there.

---

## 🧭 Navigation

◄ **[Back: 03 — What doesn't work](03-what-doesnt.md)** · [Back: 01 E2E Validation](README.md) · [🏠 Repo home](../../README.md)
