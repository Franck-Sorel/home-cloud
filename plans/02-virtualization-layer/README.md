# 🖥️ 02 — Virtualization Layer (the "datacenter")

> **Who this is for:** the operator who wants the Helm bundles in this repo to
> run on a *real multi-node* k3s cluster on one Ubuntu machine — a set of
> Raspberry-Pi-style "physical" nodes that can be switched on/off as one unit,
> freeing every byte of RAM/CPU the moment they're stopped.

Everything else in this repo (`docs/09-bundles/`, `bundles/`) assumes "you
already have a k3s cluster." This plan answers the missing question: **what
physically runs that cluster?**

The answer this plan recommends is **LXD** — Ubuntu's own system-container /
VM hypervisor — arranged as a project called `datacenter` containing one k3s
**server** + two k3s **workers** + a Pi-hole-style DNS box, toggled on/off with
two commands.

```
┌────────────────────────── YOUR UBUNTU HOST ──────────────────────────┐
│                                                                      │
│   LXD  (hypervisor, runs as a snap/daemon)                           │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │  Project: datacenter                                          │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────┐ │   │
│   │  │ k3s-server  │  │ k3s-worker1 │  │ k3s-worker2 │  │dns  │ │   │
│   │  │ (control)   │  │ (traefik)   │  │ (apps/data) │  │ ⁴  │ │   │
│   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──┬──┘ │   │
│   │         └────────────────┴───────┬────────┴─────────────┘    │   │
│   │            one k3s cluster, one private LXD network          │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   lxc stop datacenter/*   ↔  lxc start datacenter/*                  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## ⚡ Decision summary

| Decision | Choice |
|----------|--------|
| Hypervisor | **LXD** (system containers + optional VMs) |
| Why (one line) | Native to Ubuntu, ~50 MB/instant-boot overhead, built-in **project** isolation, and a one-command stop that frees **all** RAM/CPU — exactly the "toggle the datacenter off" goal. |
| Cluster | k3s server + 2 workers across 4 LXD instances (incl. DNS box) |
| Fallbacks | Docker Compose (tiny single-node) · libvirt/KVM (GPU passthrough / hard isolation) |

Full reasoning: **[02 — Recommendation](02-recommendation.md)**.

---

## 📖 What's in this plan

| # | Document | Covers |
|---|----------|--------|
| [01](01-options.md) | Options compared | LXD vs libvirt+KVM vs Docker Compose+nested-KVM, plus rejected paths (Proxmox, VPS, Tailscale/CF tunnel) |
| [02](02-recommendation.md) | Recommendation | Why LXD wins requirement-by-requirement + when to fall back |
| [03](03-architecture.md) | Target topology | The `datacenter` project, 4 instances, networking/storage, k3s join, DNS |
| [04](04-implementation.md) | Implementation | Step-by-step LXD setup: snap, init, project, profiles, k3s, toggle |
| [05](05-ops-workflow.md) | Ops workflows | Runbook of jobs (start/stop/status/backup/upgrade) → `just` recipes |
| [06](06-glossary.md) | Glossary | system container, nesting, project, profile, snapshot, pool, target |

---

## 🧭 Why virtualize at all? (30-second answer)

The bundles in this repo are Helm charts meant for **Kubernetes**, and k8s
wants **nodes** — distinct machines with their own kernel, hostname, and IP.
A real multi-node cluster is the difference between "a demo" and "a home data
center." But you only have **one physical computer**.

Virtualization lets one computer *pretend to be several*, each with its own
RAM/CPU limits, so:

- **Multi-node k3s** is honest, not faked (`kubectl get nodes` shows 3 machines).
- **Per-instance limits** keep the cluster from starving your daily work.
- **Stopped = zero cost** — because the machines are `lxc stop`ped, not left
  running, they release every byte of RAM/CPU instantly.

```
One Ubuntu computer ──► virtualization layer ──► many "physical" nodes
                     (this plan, LXD)            (k3s + DNS, still this repo)
```

---

## 🧭 Navigation

► **[Next: 01 — Options compared](01-options.md)**

◄ **[Back to repository home](../../README.md)** — the top-level map of this repo.

---

## 🧭 Also in the story

These plan files belong to the *virtualization* track of the "roadmap to a real
home datacenter" idea explored in [`docs/08-roadmap/`](../../docs/08-roadmap/README.md),
and they plug into the bundles model in [`docs/09-bundles/`](../../docs/09-bundles/README.md).
