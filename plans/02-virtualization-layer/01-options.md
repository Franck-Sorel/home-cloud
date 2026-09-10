# 🆚 01 — Options Compared

> **Who this is for:** the decision-maker who wants to see all three candidate
> hypervisors scored against the same requirement list *before* committing.

We keep one requirement list fixed and score every option against it:

| Requirement | What it really means |
|-------------|----------------------|
| **Doesn't disturb daily work** | per-instance CPU/RAM caps; when stopped → **zero** host resource use |
| **Tear down on demand** | one command frees the whole datacenter |
| **Start on demand** | one command brings it back, state intact |
| **Isolation** | how strongly one node is protected from the host & its siblings |
| **Does k3s work** | can a k3s server + workers actually run + join here? |
| **Persistence** | does data survive stop/start (and crash)? |
| **GPU passthrough** | nice-to-have: pass a physical GPU into a node |
| **Web UI** | is there a GUI to manage the layer? |
| **Setup effort** | how much work to go from zero to running |
| **Native to Ubuntu** | fits the repo's "Ubuntu, no host changes" rule |
| **Multi-node support** | realistically host server + ≥2 workers + DNS on one box |
| **Cost** | license / cloud spend (all three are $0 on your own hardware) |

---

## Option 1 — LXD (Canonical system containers + VMs)

System containers via `lxd` (snap) with **projects** as the isolation boundary.

```bash
snap install lxd
lxc project create datacenter
lxc profile copy default datacenter
lxc launch ubuntu:24.04 k3s-server --project datacenter \
    --profile datacenter --cpu=4 --memory=8GiB --disk=50GiB
lxc stop datacenter/*   # whole datacenter off, instantly
```

| Requirement | Verdict | Notes |
|-------------|---------|-------|
| Doesn't disturb daily work | ✅ | `limits.cpu`/`limits.memory` per instance; `stop` frees everything |
| Tear down on demand | ✅ | `lxc stop datacenter/*` (or delete) |
| Start on demand | ✅ | `lxc start datacenter/*`; containers boot in ~1–2 s |
| Isolation | 🔵 | containers share host kernel (lighter but weaker than VM); use LXD **VMs** when you need hard isolation |
| Does k3s work | ✅ | k3s-in-container needs `security.nesting=true` + an apparmor sysctl; k3s-in-VM works out of the box |
| Persistence | ✅ | state is on-disk in the project; survives stop/start, snapshots available |
| GPU passthrough | 🔵 | pass-through is possible but fiddlier than libvirt/KVM |
| Web UI | 🔵 | no first-party GUI; use community UIs (LXD UI, Cockpit) or the API/CLI |
| Setup effort | 🟢 | one `snap`, one `lxd init` interview, projects make it clean |
| Native to Ubuntu | ✅ | developed by Canonical, packaged as a snap |
| Multi-node support | ✅ | run as many instances as fit; containers are tiny (~50 MB, instant boot) |
| Cost | $0 | open source on your hardware |

**Best at:** multi-node k3s at lowest overhead, native to Ubuntu, clean
stop/start, project-based isolation.

---

## Option 2 — libvirt + KVM + systemd target

Classic QEMU/KVM through libvirt, with a `datacenter.target` to batch-toggling.

```bash
apt install libvirt-daemon-system qemu-kvm virt-manager
virsh define k3s-server.xml
# a datacenter.target unit + libvirt-vm@.service template so that:
systemctl start datacenter.target   # starts every VM
systemctl stop datacenter.target    # stops every VM
```

| Requirement | Verdict | Notes |
|-------------|---------|-------|
| Doesn't disturb daily work | ✅ | `virsh` VMs take what you give them; stopped = 0 |
| Tear down on demand | ✅ | `systemctl stop datacenter.target` |
| Start on demand | ✅ | `systemctl start datacenter.target`; VMs boot in 10–15 s (full kernel) |
| Isolation | ✅ | full hardware virtualization — strongest of the three |
| Does k3s work | ✅ | k3s in a VM needs **no** special config |
| Persistence | ✅ | `vm define` on disk; `virsh snapshot` / block backups |
| GPU passthrough | ✅ | the mature route — PCI/GPU passthrough is well documented |
| Web UI | ✅ | `virt-manager` GUI is built in |
| Setup effort | 🔴 | most moving parts: apt packages, XML domain defs, systemd units |
| Native to Ubuntu | ✅ | all in Ubuntu's repos |
| Multi-node support | ✅ | many VMs; each ~200 MB + slower per-boot |
| Cost | $0 | open source on your hardware |

**Best at:** GPU passthrough and maximum isolation; if you ever need
containers too, you must bolt LXD on separately (no built-in project concept).

---

## Option 3 — Docker Compose + nested KVM

Run k3s as a **single privileged container** with `/dev/kvm`:

```yaml
k3s:
  image: rancher/k3s:v1.31.1-k3s1
  privileged: true
  volumes:
    - /dev/kvm:/dev/kvm
```

```bash
docker compose up -d   # down, start, stop
```

| Requirement | Verdict | Notes |
|-------------|---------|-------|
| Doesn't disturb daily work | 🔵 | compose `stop` frees the container's RAM, but it's one big box, no per-link limits |
| Tear down on demand | ✅ | `docker compose down` |
| Start on demand | ✅ | `docker compose up -d` |
| Isolation | 🔴 | `privileged: true` = essentially the host; weakest isolation |
| Does k3s work | ✅ | single-node k3s works; **not** honestly multi-node (one container) |
| Persistence | 🔵 | volumes survive; but state tied to one container world |
| GPU passthrough | 🔵 | possible via `--device` but awkward |
| Web UI | 🔵 | Docker-with-GUI adds Portainer (not included by default) |
| Setup effort | 🟢 | least setup of the three |
| Native to Ubuntu | 🔵 | docker isn't Canonical-first but runs fine; user-space only |
| Multi-node support | ❌ | realistically one node only — no isolation to run 4 independent machines |
| Cost | $0 | open source on your hardware |

**Best at:** a throwaway single-node demo; lowest effort — not a real
multi-node "datacenter."

---

## Side-by-side decision table

| Requirement | **LXD** | **libvirt + KVM** | **Docker Compose + nest** |
|-------------|:-------:|:-----------------:|:-------------------------:|
| Tear down on demand | ✅ | ✅ | ✅ |
| Start on demand | ✅ (instant) | ✅ (10–15 s) | ✅ |
| Does k3s work | ✅ (nesting flag) | ✅ (no flags) | ✅ (single-node only) |
| Honest multi-node | ✅ | ✅ | ❌ |
| Isolation | 🔵 medium | ✅ strong | 🔴 weak |
| GPU passthrough | 🔵 | ✅ | 🔵 |
| Native to Ubuntu | ✅ | ✅ | 🔵 |
| Setup effort | 🟢 low | 🔴 high | 🟢 low |
| Web UI | 🔵 (community) | ✅ (`virt-manager`) | 🔵 (add Portainer) |
| Persistence | ✅ + snapshots | ✅ + snapshots | 🔵 volumes |

---

## ⚠️ Alternatives the user already weighed (see `docs/08-roadmap/02-alternatives-considered.md`)

These are deliberately **not** part of this plan, but they belong in the
memory so nobody re-proposes them:

| Considered | Verdict | Where documented |
|------------|---------|------------------|
| **Proxmox VE** | Not chosen — great hypervisor (LXC+QEMU in one), but it wants to *own the machine* as its own OS (Debian + its web console); conflicts with the repo's "Ubuntu host untouched" rule and adds a second management plane | [street-smart notes](../../docs/08-roadmap/02-alternatives-considered.md) |
| **VPS instead of home** | Not chosen for *this* job — it's the right move when you get a small cloud budget and want no-Cloudflare control; this plan keeps the cluster at home | [VPS + WireGuard row](../../docs/08-roadmap/02-alternatives-considered.md) |
| **Tailscale / Cloudflare Tunnel** | Not a virtualization alternative at all — they solve **outbound exposure/CGNAT**, orthogonal to "what runs the nodes"; the bundles already use Cloudflare Tunnel for exposure | [Exposure paths](../../docs/08-roadmap/02-alternatives-considered.md) and [networking models](../../docs/09-bundles/02-networking-models.md) |
| **Docker Compose** | Rejected for *multi-node* (option 3 here) but kept as the tiny/single-node fallback | [Orchestration row](../../docs/08-roadmap/02-alternatives-considered.md) |

---

## 🧭 Navigation

► **[Next: 02 — Recommendation](02-recommendation.md)**

◄ **[Back: 02 Virtualization Layer](README.md)** · [🏠 Repo home](../../README.md)
