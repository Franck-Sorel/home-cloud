# 🎓 Learning Guide — Running k3s inside LXD containers (the hard-won recipe)

> **What this is.** A teaching guide capturing the entire debugging journey of
> getting **k3s to run inside LXD containers — on a GitHub-hosted runner**. It is
> the "why" behind every step, including the false leads we chased. If you are
> setting this up on your own machine, use the *runbook* for the commands; use
> this guide to actually *understand* why each piece exists.

**Companion docs:**
- Commands & steps → [`plans/03-public-private-split/05-local-verification-runbook.md`](../../plans/03-public-private-split/05-local-verification-runbook.md)
- CI blocker log (concise) → [`plans/03-public-private-split/06-ci-foundation-findings.md`](../../plans/03-public-private-split/06-ci-foundation-findings.md)
- Original inspiration: the LinsNotes *"k3s + LXD"* series (Part 1 host prep, Part 2 the five nodes).

---

## The big picture

We split this project into a **public "wrap" repo** (guidance + Helm wrapper
charts) and a **private "deploy" repo** (real workloads, versions, secrets). The
virtualization foundation — **LXD containing k3s** — is the layer everything sits
on. To trust it, we want to *prove it works first* — ideally in CI on a standard
GitHub-hosted runner, *before* trusting it on the real datacenter host.

That sounds simple. It was not. This guide is the story of the 6 real blockers we
hit and the single root principle that explains almost all of them.

---

## The single idea that explains everything

> **A container is not a real machine.** k3s normally sets itself up on a real
> Ubuntu server — loading kernel modules, writing kernel settings, reading the
> kernel log. Inside an LXD container, all five k3s nodes share **one** host
> kernel, and a container is **not allowed to change the kernel**. k3s's own
> setup then fails silently or confusingly, and every failure *looks* unrelated.

So the whole job is: **give the container back the small set of "real-machine"
abilities it needs, one at a time.** Each of our blockers is exactly one of those
abilities being denied.

---

## The recipe (everything, at a glance)

| Ability k3s needs | Blocker on the runner | Fix |
|-------------------|-----------------------|-----|
| Outbound internet via the bridge (NAT) | Docker sets kernel `FORWARD` policy to `DROP` | **Remove Docker** |
| Load kernel modules (`br_netfilter`, `overlay`) | container lacks `CAP_SYS_MODULE` | `security.privileged=true` |
| Run its own containerd (containers-in-container) | denied by default | `security.nesting=true` |
| Read the kernel log device | runner exposes **no `/dev/kmsg`** | symlink `/dev/kmsg → /dev/null` at runtime |
| **Write** kernel sysctls (`/proc/sys`) | `/proc`,`/sys` read-only | `lxc.mount.auto=proc:rw sys:rw` |
| Installed box, `systemctl` works | nested-quote bugs in the install script | `lxc exec --env` + **quoted heredoc** |
| Download the ~60 MB binary | flaky on runners | retry up to 5× |

If you're asking "do I really need **all** of those?" — yes. Each one was a real
crash we hit, in this exact order.

---

## The 6 blockers, taught one by one

### 1. The container can't reach the internet: Docker's `FORWARD` policy

**Symptom:** the very first `curl https://get.k3s.io` inside the container times
out (`exit 28`). DNS resolves (that's *input* to the host's dnsmasq), but TCP
connections die.

**Why:** a container's outbound traffic is **forwarded through the host**. Docker
sets the kernel's `FORWARD` policy to `DROP` and only adds allow-rules for *its
own* `172.17.0.0/16` bridge — not for LXD's bridge. So LXD's container egress is
dropped.

**Fix:** remove Docker entirely (like the article's Part 1 Step 2). This also stops
LXD from silently falling back to the legacy `xtables` firewall backend.

> **Lesson:** this is userspace. Removing Docker is a *prerequisite*, but the next
> blockers are kernel-level and Docker-removal alone won't touch them.

### 2. It can't load kernel modules: `security.privileged`

**Symptom:** the k3s server crash-loops — `Active: activating (auto-restart)`.
The `ExecStartPre` runs `modprobe br_netfilter` / `modprobe overlay`, which a
container can't do (no `CAP_SYS_MODULE`).

**Fix:** `security.privileged=true`. This maps "root inside" to "root outside" —
the classic k3s-in-LXD requirement (article Part 2).

> ⚠️ **Security note:** privileged + no isolation means *anything that escapes a
> node owns the host*. Fine for a lab you own; never for shared/production.

### 3 & 4. No `/dev/kmsg`: the runner's kernel hides it

**Symptom (3):** `open /dev/kmsg: no such file or directory`. The LXD profile
`unix-char` device that *should* pass the host's `/dev/kmsg` in never materializes
— because **the runner host exposes no `/dev/kmsg` to nested LXD at all**.

**Symptom (4):** if you force it with `mknod /dev/kmsg c 1 11`, you get
`operation not permitted` — the device cgroup blocks opening the kernel char
device.

**Fix:** `ln -sf /dev/null /dev/kmsg`. A symlink to `/dev/null` (always openable)
lets the kubelet open it and read EOF. It's not a real kernel log, but the kubelet
doesn't need the *contents* — it just needs a readable node.

> **Lesson:** this is the moment you realize the GitHub runner is *not* a host you
> control. On your own machine the profile device works; on a shared runner it
> doesn't, so you use the symlink workaround.

### 5. "Unit k3s.service could not be found" — it was OUR quoting

**Symptom:** `systemctl start k3s` fails; `Unit k3s.service could not be found`;
then `syntax error: unexpected end of file`; then `attempt: unbound variable`.
These looked like a missing service, but the service file existed.

**Why:** we were passing a multi-line script to the container with
`bash -c "..."`. Inside that, inner double quotes terminated the outer string,
`\$` escapes fought the outer shell's `set -u`, and different layers each expanded
variables. The result was a broken command that k3s never actually got.

**Fix:** stop fighting quoting. Pass `SERVER_IP` as a **real env var**
(`lxc exec --env SERVER_IP=...`) and feed the script body as a **quoted heredoc**
(`<<'EOF'`). The outer shell expands *nothing* inside; the container's bash
expands only what it should.

> **Lesson (this is the expensive one):** a "unit not found" while the file
> exists is a red flag that the *command that creates/starts it* is broken, not
> systemd. When debugging, question the mechanism that delivers your commands
> before the software that runs them.

### 6. `Failed to start ContainerManager` — `/proc/sys` is read-only

**Symptom:** k3s starts up (controllers initializing), then:
```
Failed to start ContainerManager" err="[open /proc/sys/vm/overcommit_memory:
read-only file system, open /proc/sys/kernel/panic: read-only file system ...]"
```

**Why:** the kubelet must **write** a few kernel sysctls when it starts. In an LXD
container `/proc` and `/sys` are read-only by default.

**Fix:** `lxc.mount.auto=proc:rw sys:rw` in the profile's `raw.lxc`.

> **Lesson:** notice this blocker only *appeared after we fixed the quoting* —
> debugging is peeling layers; each fix reveals the next, and you must keep going.

---

## False leads we chased (so you don't)

| Theory | Why it was a dead end |
|--------|----------------------|
| "It's IPv6 — DNS returns AAAA-only" | Half-true, but forcing IPv4 / disabling IPv6 did **not** fix egress; the real cause was Docker's `FORWARD`-DROP. |
| "`mknod` will create `/dev/kmsg`" | Created the node, but the device cgroup forbade opening it (`EPERM`). |
| "Removing Docker will fix everything" | Needed, but the `/dev/kmsg` + `/proc/sys` issues are kernel-level, untouched by Docker removal. |
| "systemd isn't PID 1 inside the container" | `ps -p 1` showed it **is** systemd; the real issue was our broken install command. |
| "AppArmor `unconfined` is required" | We trialed it; it didn't help and added risk — the mount fix was the real one. |

---

## A few mechanical gotchas (kept from the runbook)

- `lxc list -c 4` returns `IP (iface)` e.g. `10.10.0.159 (eth0)` — **strip the
  ` (eth0)` suffix** (`sed 's/ .*//'`) or `--node-ip` gets an invalid value.
- Profile-level `linux.sysctl.*` keys fail with `Failed to set LXC config` — put
  the userns fix on the **host**, not the profile.
- The 60 MB k3s binary download from GitHub is flaky on runners → **retry**.
- Keep the worker joins **parallel** (bash background jobs; `parallel` can't
  express a dynamic worker count).

---

## How to think about k3s-in-LXD going forward

1. **Start with a real host** (the article's way) and only then ask whether a
   *shared runner* can reproduce it.
2. **Every kernel-ish denial** (`/dev/*`, `/proc/sys`, modules) has a LXD
   profile/runtime answer. Collect them like a checklist.
3. **The local runbook is the truth** for the datacenter host; CI now proves the
   same recipe works on a constrained runner.

The good news: once you accept the "one shared kernel, give back what k3s needs"
frame, each of these becomes unsurprising — and the whole recipe fits on one page
(above).
