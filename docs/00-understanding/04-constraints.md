# 04 — Constraints

> **Goal of this document:** Lay out every hard constraint that shapes this project, why it exists, how it influences the architecture, and where the *honest* boundaries are.

---

## 1. The master constraint

> ### "I keep the Ubuntu OS, and I do NOT modify it."

Interpreted concretely for this project:

| ❌ Off-limits (modifications we avoid) | ✅ Allowed (what we stay within) |
|----------------------------------------|--------------------------------|
| `apt install` / `snap install` of system packages | Running user-space binaries (e.g. k3s binary) |
| Editing `/etc/` config files | Writing into `/home/$USER/` directories |
| Changing `ufw` / `iptables` / nftables rules | Running containers/pods with their own network namespaces |
| Installing kernel modules globally | Using already-present kernel features (namespaces, cgroups, overlayfs, veth) |
| Adding/removing `systemd` units (beyond a documented minimal k3s service) | Running processes in the foreground / as your own user |
| Modifying host network config (`/etc/hosts`, interfaces, routing) | Containerd/runc user-space networking |
| Router port-forwarding / static IP requirements | Cloudflare Tunnel outbound connection |

> ⚠️ **The honest footnote:** "Don't touch the OS" is a *goal*, and staying inside it is possible to a remarkably high degree — but it is not *literally 100%*. K3s itself registers one small systemd unit and stores state under `/var/lib/rancher`. That is the single documented, minimal, well-scoped host touch. Think of this project's constraint as: **"No modification beyond the absolute minimum required to run a container runtime + k3s — and even that minimum is fully documented."**

---

## 2. Why this constraint exists (your real motivation)

1. **Portfolio honesty** — being able to say *"I ran a cloud platform purely on userspace containers"* is a strong, defensible statement.
2. **OS safety** — no risk of breaking your daily Ubuntu machine's boot, networking, or packages.
3. **Reproducibility** — a documented, minimal recipe is something you (and recruiters) can re-run anywhere.
4. **Separation of concerns** — your machine keeps working as a normal desktop; the cloud is an *invisible* extra layer of containers.

---

## 3. What the constraint forces architecturally

Because we refuse to touch the host network stack, **we cannot accept inbound connections in the traditional sense** (no opening port 80/443 on the host, no DNAT/port-forward). This one fact dictates the entire external path:

```
No inbound ports  ⟹  we must use an outbound tunnel  ⟹  Cloudflare Tunnel
```

And because we refuse system packages, **everything the cloud needs must arrive as containers/images**:

```
No apt install  ⟹  every AWS-ish service is a pod  ⟹  k3s + containerd + Helm
```

In short: **the constraint == the architecture.** That is why "Cloudflare Tunnel + k3s pods" is not one option among many — it's the *deduced* solution.

---

## 4. Derived constraints (knock-on effects)

| Derived constraint | Consequence | Mitigation |
|-------------------|-------------|------------|
| Persistence must not rely on OS partitions | Pods are ephemeral; host `/etc` is off-limits | Use **PVs / local-path-provisioner** → data under `/home/$USER/k3s-data` |
| No system-wide DNS change | Only CoreDNS *inside* the cluster resolves cluster names | Outside clients use public DNS (Cloudflare-managed) |
| No host firewall modification | The host's firewall stays as-is; services rely on sidecar isolation | Everything scoped inside k3s; public traffic only enters via the tunnel |
| No host cron | Scheduled jobs (backups, renewals) shouldn't touch host crontab | Use **Kubernetes CronJobs** (in-cluster) |
| No host monitoring agent | CloudWatch-like visibility can't be a host package | **Prometheus + node-exporter as DaemonSet/pods** |
| No host-level backup tool | Backups run outside/alongside, not as system service | **Velero / restic via CronJob or dedicated pod** |
| Static IP cannot be required | Home ISP may provide dynamic/CGNAT | Tunnel is fully outbound, so it simply doesn't care |
| Generative installs must be repeatable | Setup shouldn't be one-off manual `apt` hand-rolling | **Terraform + Helm + ArgoCD** encode the exact state |

---

## 5. Boundary cases & honest disclaimers

**What "did not happen" even though it's a container:**
- Docker/containerd images, even "rootless", still use kernel namespaces the host provides — that's *using* the kernel, not *modifying* it. We're fine here.

**What k3s needs from the host (the documented minimum):**
- access to kernel features: `overlay`, `veth`, `bridge`, `iptables_nat` (all standard on a stock Ubuntu kernel — no module install required on modern kernels)
- a systemd unit or manual launch of `k3s server` (documented)

**What we do NOT claim:**
- ❌ We don't claim "zero host processes" — k3s itself is a host process; its *workloads* are containers.
- ❌ We don't claim "zero risk" — any internet-exposed service is a target (see [`04-security`](../04-security/README.md)).

---

## 6. The constraint, restated as a policy for all docs

> **Every command, manifest, and script in this repository will:**
> 1. Not require `sudo` except for the single, documented k3s install step.
> 2. Not modify `/etc`, system packages, kernel config, or the firewall.
> 3. Not require router or DNS-provider changes beyond Cloudflare-managed tunnel hostnames.
> 4. Put all persistent data under a documented path in the user's home directory.
> 5. Be reproducible: expressed as Kubernetes manifests / Helm charts / Terraform where practical.

This makes the project **provably portable**: the same `k3s` stack runs identically on a laptop, a VPS, or a cluster of Raspberry Pis — with zero extra OS surgery.

---

## 7. Constraints quick-reference card

```
┌───────────────────────────────────────────────────────────┐
│  CONSTRAINTS (this project)                               │
│  ─────────────────────────────────────────                │
│  • No apt/snap system installs                            │
│  • No /etc modifications                                  │
│  • No ufw/iptables/router changes                         │
│  • No kernel module installs                              │
│  • No host crontab / systemd (except one k3s unit)        │
│  • No requirement of a public/static IP                   │
│  • Everything pods/PVs/Helm/Terraform                     │
│  • All persistent data under $HOME/k3s-data               │
│  • Public reachability ONLY via Cloudflare Tunnel         │
└───────────────────────────────────────────────────────────┘
```

---

## 🔗 Continue reading

► **[Next: 05 — AWS parity](05-aws-parity.md)**

◄ **[Back to 00 Understanding index](README.md)** · [🏠 Repo home](../../README.md)