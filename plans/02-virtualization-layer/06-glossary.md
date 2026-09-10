# 📖 06 — Glossary (virtualization layer)

> **Who this is for:** anyone who hits a word they half-know while reading this
> plan. These are the *new* terms virtualization introduces, cross-linked to
> the repo-wide [GLOSSARY](../../docs/GLOSSARY.md).

| Term | Plain-English definition | Where it's used here |
|------|--------------------------|----------------------|
| **System container** | A lighter alternative to a full VM: it reuses the host's **kernel** but gets its own filesystem, processes, users, and network. Roughly "a whole little machine that shares the engine, not the cabin." | LXD's default; the four datacenter instances are system containers ([03 — Architecture](03-architecture.md)). |
| **VM (Virtual Machine)** | A full emulated computer with its **own kernel** (QEMU/KVM runs a real guest OS). Heavier and slower to boot, but the strongest isolation. | Option 2 (libvirt) and LXD's `--vm` escape hatch for hard isolation ([02 — Recommendation](02-recommendation.md)). |
| **Nesting** | Allowing a container to run **its own containers** inside it. k3s runs containerd, so each k3s node container needs `security.nesting=true`. | The key k3s-in-LXD flag ([04 — Implementation](04-implementation.md)). |
| **Project** | LXD's grouping/isolation boundary: a namespace containing instances, networks and storage that can be created/destroyed as one unit. `datacenter/*` is a project. | The `datacenter` project owns all four instances ([03 — Architecture](03-architecture.md)). |
| **Profile** | A named, reusable recipe of config + devices (CPU, memory, disk, NIC, nesting flags) you apply to instances. | `k3s-server` / `k3s-worker` profiles ([04 — Implementation](04-implementation.md)). |
| **Snapshot** | A point-in-time copy of an instance's state+disk, used to backup and roll back. | The backup primitive behind the [Backup/Restore job](05-ops-workflow.md). |
| **Storage pool** | The backing store (dir / zfs / btrfs) where instance disks and snapshots live. | `datacenter-pool` ([03 — Architecture](03-architecture.md)). |
| **Target (systemd)** | A systemd grouping unit that can start/stop a set of services/units together. libvirt option uses `datacenter.target` to batch-toggle VMs. | [Option 2 — libvirt](01-options.md). |

**Repo glossary bridge:** for the even more fundamental words (container,
node, k3s, DNS, tunnel, CGNAT…) see the [full repo GLOSSARY](../../docs/GLOSSARY.md).

---

## 🧭 Navigation

◄ **[Back: 05 — Ops workflow](05-ops-workflow.md)** · [Back: 02 Virtualization Layer](README.md) · [🏠 Repo home](../../README.md)
