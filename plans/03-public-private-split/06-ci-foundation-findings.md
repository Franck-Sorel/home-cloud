# 06 — CI `foundation` workflow: why k3s-in-LXD fails on a hosted runner

> **What this is.** The `foundation` workflow tries to prove the LXD+k3s
> virtualization layer inside a GitHub-hosted `ubuntu-latest` runner *before*
> trusting it on the datacenter host. This document records every blocker we hit,
> the exact symptom + fix, and the alternative hypotheses we still have to test.
> The user has **no self-hosted runners**, so the runner-side kernel restrictions
> below are the hard constraint.

## Bottom line

The **LXD + container-network layer works in CI** (containers create, bridge
`datacenter-net` comes up, DNS + outbound HTTPS via NAT all pass). The failure is
entirely inside the **k3s node startup**, which trips multiple *runner-kernel*
restrictions. k3s-in-LXD is validated via the **local runbook**
([05](05-local-verification-runbook.md) + `verify-local.sh`) on the real host; CI
can at best smoke the LXD/network layer.

## The 5 blockers (chronological)

| # | Blocker | Symptom | Fix | Status |
|---|---------|---------|-----|--------|
| 1 | Docker sets kernel `FORWARD` policy to `DROP`, only NATs `172.17.0.0/16` | in-container `curl get.k3s.io` times out (`exit 28`) | `iptables -I FORWARD -i/-o datacenter-net -j ACCEPT` | ✅ |
| 2 | `modprobe br_netfilter`/`overlay` in `ExecStartPre` fail (no `CAP_SYS_MODULE`) | server crash-loops (`activating auto-restart`) | `security.privileged=true` | ✅ |
| 3 | `/dev/kmsg` profile `unix-char` passthrough | kubelet `open /dev/kmsg: no such file or directory` | N/A — **runner kernel exposes no `/dev/kmsg` to LXD** | ❌ |
| 4 | `/dev/kmsg` via `mknod c 1 11` | kubelet `open /dev/kmsg: operation not permitted` (device cgroup) | N/A | ❌ |
| 5 | k3s `systemd start k3s` fails; `systemctl status k3s` → `Unit k3s.service could not be found` | service/unit unwritable or systemd not functioning in the nested container | **under investigation (this doc)** | ⚠️ |

## Blocker 3/4 — `/dev/kmsg` (kernel/device, not Docker)

- Removing Docker does **not** fix it: Docker is userspace; the missing
  `/dev/kmsg` is a **host-kernel** device-exposure problem. Verified: after the
  "Remove Docker" step, connectivity passed but kubelet still hit
  `no such file or directory`.
- Best workaround on the runner: `ln -sf /dev/null /dev/kmsg` inside the
  container — `/dev/null` is always accessible, so the kubelet opens it and
  reads EOF, bypassing both missing-device and device-cgroup issues.

## Blocker 5 — k3s service doesn't start / unit not found (hypotheses to verify)

A nested LXD container on a hosted runner is effectively running inside a
**user namespace**, and systemd may not be truly PID 1, so `systemctl` can't
manage k3s.service even though `/etc/systemd/system/k3s.service` exists.
Candidate fixes to test:

1. **Confirm the container init.** `ps -p 1 -o comm=` must be `systemd`. If not
   (or if `systemctl` says *"System has not been booted with systemd"*), the
   service approach is dead on this host.
2. **`systemctl daemon-reload`** after the installer writes the unit — systemd
   may not have rescanned.
3. **`ExecStartPre` noise.** The unit has `ExecStartPre` checks
   (`nm-cloud-setup.service`, `modprobe br_netfilter`, `modprobe overlay`).
   The `-` prefix ignores modprobe, but a missing `nm-cloud-setup.service` can
   still error on some systemd versions.
4. **Run k3s as a foreground process** (bypass systemd), with the user-namespace
   feature gate (k3s issue #4249):
   ```bash
   /usr/local/bin/k3s server \
     --kubelet-arg=feature-gates=KubeletInUserNamespace=true \
     --kube-controller-manager-arg=feature-gates=KubeletInUserNamespace=true \
     --kube-apiserver-arg=feature-gates=KubeletInUserNamespace=true \
     --disable=traefik --node-ip=<IP> --tls-san=<IP> --tls-san=localhost \
     --flannel-iface=eth0
   ```
   Run it with `nohup ... &` (or as a `Type=simple` systemd unit created
   manually) so it survives the step. **This is the most promising bypass** given
   blocker 5.

## Quick in-container diagnostics for the next run

```bash
lxc exec k3s-server -- ps -p 1 -o comm=          # is it systemd?
lxc exec k3s-server -- systemctl is-system-running 2>&1 || true   # is systemd up?
lxc exec k3s-server -- ls -la /etc/systemd/system/k3s.service
lxc exec k3s-server -- systemctl daemon-reload && systemctl start k3s
lxc exec k3s-server -- journalctl -u k3s.service --no-pager -n 50
```

## Decision path (self-hosted runners OFF the table)

- If **foreground k3s + `KubeletInUserNamespace`** gets a node to `Ready` inside
  the runner → the workflow can bypass the systemd service and we have a real CI
  gate. **Best case.**
- If the runner still blocks it → the workflow is re-purposed to validate only
  the **LXD + network** layer (which passes) and document that k3s-in-LXD is a
  local-only gate.
