# 06 — CI `foundation` workflow: running k3s-in-LXD on a hosted runner

> **What this is.** The `foundation` workflow proves the LXD+k3s virtualization
> layer inside a GitHub-hosted `ubuntu-latest` runner. This document is the
> blocker log and the **winning recipe** that gets it fully green.

## Bottom line

**RESOLVED ✅ (2026-09-21).** The `foundation` workflow passes **end-to-end** on a
GitHub-hosted runner: LXD containers launch, a k3s server + 2 workers boot, all 3
nodes go `Ready` (`ready=3/3`), coredns/local-path/metrics-server run, and
snapshot/toggle sanity succeeds — **no self-hosted runner required.**

## The winning recipe (dc-base profile + install)

| Piece | Where | Why |
|-------|-------|-----|
| Remove Docker | "Remove Docker" step | stops `FORWARD`-DROP + xtables backend (Part 1 Step 2) |
| `security.privileged=true` | `dc-base` | kubelet can load `br_netfilter`/`overlay` |
| `security.nesting=true` | `dc-base` | k3s runs its own containerd |
| `raw.lxc = lxc.mount.auto=proc:rw sys:rw` | `dc-base` | **kubelet must WRITE `/proc/sys`** |
| `ln -sf /dev/null /dev/kmsg` | install/join | runner exposes no `/dev/kmsg` |
| `lxc exec --env` + quoted heredoc | install | avoids nested-quote breakage |
| 5x retry on binary download | install | 60MB github.com download is flaky |

## The 6 blockers (chronological, all resolved)

| # | Blocker | Symptom | Fix |
|---|---------|---------|-----|
| 1 | Docker sets `FORWARD` policy `DROP` + forces xtables | `curl get.k3s.io` times out (`exit 28`) | Remove Docker |
| 2 | `modprobe br_netfilter`/`overlay` fail (no `CAP_SYS_MODULE`) | server crash-loops | `security.privileged=true` |
| 3 | `/dev/kmsg` profile passthrough | `open /dev/kmsg: no such file` | runtime `ln -sf /dev/null /dev/kmsg` |
| 4 | `/dev/kmsg` via `mknod` | `operation not permitted` (device cgroup) | abandon; use symlink instead |
| 5 | k3s `systemctl start` / "unit not found", bash syntax errors | broken install command quoting | `lxc exec --env` + quoted heredoc |
| 6 | kubelet `Failed to start ContainerManager` | `/proc/sys` read-only | `lxc.mount.auto=proc:rw sys:rw` |

## Key learnings

- **`/dev/kmsg` is a kernel/device issue, NOT Docker.** Removing Docker alone
  doesn't fix it — the runner host simply exposes no `/dev/kmsg` to nested LXD.
  The symlink-to-`/dev/null` workaround is what gets past it.
- **Nested-quote pitfalls.** Passing a multi-line script via `bash -c "..."`
  with inner double quotes, `\$escapes`, and outer `set -u` breaks in confusing
  ways (`unit not found`, `syntax error`, `unbound variable`). Passing the IP as
  a real env var (`lxc exec --env`) and using a quoted heredoc (`<<'EOF'`)
  eliminates the entire class of bugs.
- **CPU/RAM sizing:** CI uses 2GiB server + 1GiB workers; the local datacenter
  host should use the real sizing (see the runbook).

These exact steps are mirrored for the datacenter host in
[05-local-verification-runbook.md](05-local-verification-runbook.md) +
[verify-local.sh](verify-local.sh).
