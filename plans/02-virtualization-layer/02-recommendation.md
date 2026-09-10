# ✅ 02 — Recommendation: LXD

> **Who this is for:** the operator who wants one clear call — "build the
> datacenter with *this*, not those others" — plus the exact conditions under
> which the decision flips.

## The call

> **Use LXD**, arranged as a project named `datacenter` running four instances
> (k3s server + two workers + DNS box). It is the only option that is
> **native to Ubuntu**, gives you **honest multi-node k3s**, and toggles the
> whole datacenter off with a single command that returns **all** RAM/CPU to
> your daily work.

Here is every requirement from [01 — Options](01-options.md), and how LXD
satisfies it — plus the honest gotchas you must not skip.

---

## Requirement-by-requirement rationale

### 1. Doesn't disturb daily work — ✅ per-instance caps + stopped = zero

LXD enforces the repo's *"don't touch the host"* rule in both directions:
- **Running:** each instance is fenced by `limits.cpu` and `limits.memory`, so
  k3s can never eat the whole machine out from under your daily work. Oversub
  only if you *want* to.
- **Stopped:** `system containers` are processes + namespaces on the host
  kernel. `lxc stop` kills the process tree and the kernel reclaims the memory
  **instantly** — there is no guest kernel left to keep resident (unlike a VM,
  where a stopped guest still has QEMU overhead and slower cold starts).
  Stop `datacenter/*` and the host is exactly as free as before you started.

### 2. Tear down on demand — ✅ `lxc stop datacenter/*`

One wildcard, one command. Delete is equally trivial (`lxc delete`) if you want
the whole thing gone and stripped of its disks.

### 3. Start on demand — ✅ `lxc start datacenter/*`

Containers boot in ~1–2 seconds (no BIOS, no kernel boot). VM start is slower,
which is exactly why this plan puts the *frequently toggled* cluster in
containers.

### 4. Isolation — 🔵 good (and upgradable to strong)

Containers share the host kernel, so isolation is "very good" but not
"hardware wall." For a home lab that's the right trade: it's far safer than
`docker --privileged` (option 3) but lighter than full VMs (option 2).
Because LXD speaks **both** container and VM, you can upgrade *one* instance
to `--vm` (e.g. a worker that will handle GPU) without abandoning the layer.

### 5. Does k3s work — ✅ (needs the two nesting flags)

k3s runs its own containerd inside the container, which in turn expects to
mount cgroups and namespaces. Inside a shared-kernel container k3s needs:

```yaml
security.nesting: "true"
linux.sysctl.kernel.apparmor_restrict_unprivileged_userns: "0"
```

> **Gotcha — remember both.** Miss `security.nesting` and k3s pods crash with
> cgroup/mount errors; on Ubuntu 24.04 the apparmor sysctl is the *second*
> flag that stops `unprivileged_userns` from being restricted. Put them in the
> profile (see [04 — Implementation](04-implementation.md)) so you set them
> once, not per-instance.
>
> **Escape hatch:** a **LXD VM** (`--vm`) needs none of this — it has a real
> kernel. If the nesting flags ever fight you, run k3s in a `--vm` and move on.

### 6. Persistence — ✅ disks + snapshots

Instance state lives on LXD's storage pool (a host filesystem/dir or a
dedicated disk). `stop/start` never touches it; a lost container is recoverable
from `lxc snapshot` (see [05 — Ops](05-ops-workflow.md)).

### 7. GPU passthrough — 🔵 nice-to-have (not this machine's job)

LXD supports GPU pass-through but it's more fiddly than libvirt/KVM. The
datacenter's gateway/Traefik runs in k3s (software routing), so **no host GPU
is needed here at all**. If you later want a heavy GPU worker, that's the cue
to fall back to libvirt (below).

### 8. Web UI — 🔵 prefer the CLI + `just`

LXD has no Canonical web console out of the box; you manage it with `lxc` (and
the ops recipes in this plan). Community UIs exist (LXD-UI, Cockpit) but the
CLI is fast, scriptable, and pairs with `just` recipes. If a web console is a
hard requirement, that's a point for libvirt/virt-manager instead.

### 9. Setup effort — 🟢 low, and it composes cleanly

snap → `lxd init` → project → profiles → launch. Everything else in the repo
(the Helm bundles) is unchanged: it just deploys into whatever node serves as
the control-plane endpoint.

### 10. Native to Ubuntu — ✅

LXD is the Canonical project for exactly this job, ships as a snap, and
respects the repo's "don't `apt install` a pile of system packages" posture
(it's one snap + a daemon).

### 11. Multi-node support — ✅

Four containers of ~50 MB overhead each, instant boot, per-node limits — this
is *the* option built for running several machines quietly on one box.

### 12. Cost — $0

Open source on your own hardware; snap is free.

---

## When to fall back

| If you want… | Use… | Why |
|--------------|------|-----|
| A **tiny, throwaway single-node** demo, least possible ceremony | **Docker Compose** (option 3) | It's one `rancher/k3s` container; accept `privileged` + single-node trade-offs |
| **GPU passthrough** or **hardest isolation** for a particular node | **libvirt + KVM** (option 2) | Mature PCI/GPU passthrough and a full virtual device model, plus a GUI |
| Everything, forever, owning the machine | **Proxmox** (rejected) | It wants to be the OS; conflicts with "Ubuntu host untouched" |

**Sizing sanity check (gotcha).** Four instances ≈
`k3s-server 8 GiB` + `worker1 6 GiB` + `worker2 6 GiB` + `dns 1 GiB` ≈ **21 GiB
RAM** *if everything runs at once*. On a 16 GiB laptop it still works because
LXD lets you leave workers **stopped** (the point of this plan) or reduce caps
— but don't promise "everything always on" beyond your physical RAM. Same for
CPU (server `4` + worker1 `2` + worker2 `2` + dns `1` = 9 vCPU by default).

**Disk on the host filesystem (gotcha).** The storage pool is a directory on
your root disk by default. A "disk-full" event on the host is the top
operational risk — see the [Disk full runbook](05-ops-workflow.md).

**"Stopped frees instantly" is real, but it is *not* a sleep-wake.** LXD
`stop` is a clean teardown; services boot fresh on `start`. If you wanted
suspend/resume (processes paused), that's a different feature (`snapshot` +
`restore`), not stop/start — know the difference so expectations land right.

---

## 🧭 Navigation

► **[Next: 03 — Architecture](03-architecture.md)**

◄ **[Back: 01 — Options compared](01-options.md)** · [Back: 02 Virtualization Layer](README.md)
