# 🧭 00 — Navigation: where to go, no matter your level

> This is your travel map. Read it once, pick your lane, and jump straight in.
> Don't read the whole repo top-down — that's the fastest way to get lost.
>
> Everything below is cross-linked, so you can always hop back here.

## First, are you a beginner or advanced?

| | 🟢 **Beginner** | 🔵 **Advanced / curious** |
|---|---|---|
| You know | little about K8s / DNS / Docker | the basics; you want the *whys* and the *how* |
| Start with | [What's a private cloud](01-what-is-a-private-cloud.md) → [Setup](../02-setup/README.md) | [02-architecture](02-architecture.md) → [Design decisions](03-design-decisions.md) |
| Meet weird words? | **[GLOSSARY](../GLOSSARY.md)** is open in the other tab | skim the same glossary for our exact meanings |

> **New to all this?** The shortcut: `docs/GLOSSARY.md` is your translator,
> `docs/02-setup/` is your "do these in order" list. Read the section's
> `README.md` first each time — every one explains its audience.

---

## The fast paths

### 🚀 "I want it running, step by step"
```
docs/02-setup/00-prerequisites    → 01-install-k3s → 02-cloudflare-tunnel → 03-traefik-ingress
docs/03-services/01-first-service → deploy the hello service
docs/06-testing/02-expose-service → put it on the internet
```
→ Or skip reading and just pick bundles: [09-bundles](../09-bundles/README.md)

### 🧠 "I want to understand the design"
```
docs/00-understanding/  (read top to bottom: 01→05)
docs/07-iac-gitops/     (how it becomes reproducible)
docs/08-roadmap/        (where it's heading, known limits)
```

### 🧩 "I want to pick what to deploy for MY cloud"
```
docs/09-bundles/01-bundles         (the catalog)
docs/09-bundles/02-networking-models
just deploy base auth storage
```

### 🔒 "I'm about to expose something to the internet"
```
docs/04-security/01-authentication → 02-rbac → 04-waf → 06-hardening-checklist
```

### 💰 "I want this free"
```
docs/09-bundles/02-networking-models   (the $0 DDNS path: deSEC/Dynu + Let's Encrypt)
```

---

## The full map, with levels

> `🟢` beginner · `🟡` intermediate · `🔴` advanced. **Prereq** = what to know first.

| # | Section | Takes you from… to… | Level | Prereq |
|---|---------|---------------------|-------|--------|
| [00](README.md) Understanding | "what's a private cloud" → "full architecture" | 🟡 | none |
| [01](../01-skills/README.md) Skills | "what do I need to know" → "a learning path" | 🟢 | none |
| [02](../02-setup/README.md) Setup | empty Ubuntu → running cluster + public URL | 🟢 | a domain, Cloudflare acct |
| [03](../03-services/README.md) Services | fill the cluster with AWS-like services | 🟡 | 02 setup |
| [04](../04-security/README.md) Security | unsafe → hardened, zero-trust | 🟡🔴 | a public service |
| [05](../05-observability/README.md) Observability | blind → watched (logs/metrics/dashboards) | 🟡 | 02 setup |
| [06](../06-testing/README.md) Testing | untested → verified + backed up | 🟡 | 02–03 |
| [07](../07-iac-gitops/README.md) IaC & GitOps | manual → all code + PR = deploy | 🔴 | 02–06 |
| [08](../08-roadmap/README.md) Roadmap | current → AWS-parity plan | 🔴 | the rest |
| [09](../09-bundles/README.md) **Bundles** | reading docs → **choosing packages** | 🟢🟡 | 02 setup base |

---

## Legend for every doc page

Every `README.md` and content doc follows the same skeleton so you always know
where you are:

```
# Title
> one-line "who is this for"
| What's in this section |  ← a table of contents (each row links out)
(optional) ASCII diagram of the flow
Key concepts (with links to the GLOSSARY)
Step-by-step or deep-dive
Next / Back links   ← always at the bottom
```

---

## You are never more than 2 clicks from help

| Need | Link |
|------|------|
| A word defined | [GLOSSARY](../GLOSSARY.md) |
| Repo home & stack | [README](../../README.md) |
| The architecture drawing | [09-bundles/03-architecture](../09-bundles/03-architecture.md) |
| The bundle you can `just deploy` | [09-bundles/01-bundles](../09-bundles/01-bundles.md) |

## 🔭 Forward-looking plans (not "docs", but "what's next")

Living **plans**, separate from the numbered docs, for infra/CI folks:

| Plan | What it is |
|------|-----------|
| [01-e2e-validation](../../plans/01-e2e-validation/README.md) | A real-cluster "apply everything" workflow — which stacks work together vs not |
| [02-virtualization-layer](../../plans/02-virtualization-layer/README.md) | Running the datacenter (multi-node k3s) on LXD vs libvirt vs Docker — decision + ops |
| [03-public-private-split](../../plans/03-public-private-split/README.md) | Keep this "wrap/guidance" repo public; move real workloads + versions to a private repo |

---

## 🧭 Section navigation

- [0️⃣ Understanding](README.md) · [1️⃣ Skills](../01-skills/README.md) ·
  [2️⃣ Setup](../02-setup/README.md) · [3️⃣ Services](../03-services/README.md) ·
  [4️⃣ Security](../04-security/README.md) · [5️⃣ Observability](../05-observability/README.md) ·
  [6️⃣ Testing](../06-testing/README.md) · [7️⃣ IaC/GitOps](../07-iac-gitops/README.md) ·
  [8️⃣ Roadmap](../08-roadmap/README.md) · [9️⃣ Bundles](../09-bundles/README.md)

◄ **[Back to repository home](../../README.md)**
