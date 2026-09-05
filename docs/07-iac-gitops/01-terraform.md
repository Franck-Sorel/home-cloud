# 01 — Terraform for Cloudflare (DNS, tunnel, WAF as code)

> **Goal:** Manage the *Cloudflare half* of the architecture with Terraform — zone, tunnel hostnames, WAF, rate rules — so the edge config is code, reviewable and reproducible like everything else.

---

## 1. Why Terraform here

We said "no touching the OS" for the host. The Cloudflare side is **not** on the host — so Terraform is the natural IaC tool: `terraform apply` reproduces your entire edge in minutes from a repo, matching your k8s GitOps.

> Optional alternative: **Ansible** on the host for the *one* bootstrap step (k3s install). Perfectly fine; this doc covers the edge + a tiny bit of the host.

---

## 2. Setup

```bash
brew install terraform   # or download from releases; only a CLI tool
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars   # fill in your CLOUDFLARE_API_TOKEN + zone id
terraform init
terraform validate
terraform plan
terraform apply           # does the whole edge
```

`terraform/cloudflare/main.tf` (in repo) — the core:

```hcl
terraform {
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
  }
}

variable "cloudflare_api_token" { sensitive = true }
variable "zone"                 { default = "mycloud.com" }
variable "tunnel_id"            { }          # from your existing tunnel
variable "ingress_service"      { default = "http://traefik.kube-system.svc.cluster.local:80" }

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "this" { name = var.zone }

resource "cloudflare_tunnel_route" "dns" {
  zone_id = data.cloudflare_zone.this.id
  account_id = "<your-account-id>"
  cidr   = "10.0.0.0/8"        # internal route for the tunnel
  tunnel_id = var.tunnel_id
  comment = "home-cloud tunnel"
}

# ONE hostname per Service (paperwork-free: feature of the tunnel)
locals { hostnames = {
  hello   = {}, api = {}, storage = {}, auth = {}, secrets = {}, grafana = {}
}}
resource "cloudflare_tunnel_config" "home_cloud" {
  account_id = "<your-account-id>"
  tunnel_id  = var.tunnel_id
  config {
    ingress_rule {
      hostname = "hello.mycloud.com"
      service  = var.ingress_service
    }
    # ... add the rest from `locals`
    ingress_rule { service = "http_status:404" }   # catch-all palindrome
  }
}
```

> 🧾 terraform.tfvars (with token) is gitignored; the repo holds only the `.example`. See [`03-secrets-in-git.md`](03-secrets-in-git.md).

---

## 3. Add WAF as code

```hcl
resource "cloudflare_ruleset" "home_waf" {
  zone_id = data.cloudflare_zone.this.id
  kind    = "zone"
  phase   = "http_request_firewall_managed"
  name    = "Home Cloud managed rules"
  rules {
    action = "execute"
    expression = "true"
    description = "OWASP Core Ruleset"
    action_parameters {
      ruleset = "efb7b8c949ac4650a09736fc376e9aee"   # owasp core set id
    }
  }
}
```

`terraform plan` shows you *exactly* what will change; `terraform destroy` removes the whole edge if you ever reset. **That's reproducibility.**

---

## 4. Enabling GitOps for the edge too

- Put `terraform/cloudflare/` in this repo.
- A GitHub Action can run `terraform plan` on every PR (comment the diff) and `terraform apply` on merge to `main`.
- The edge becomes a *PR-reviewable artifact* — same as the cluster (next doc).

---

## 5. Portfolio one-liner

> *"The Cloudflare edge — DNS, tunnel hostnames, WAF — is declared in Terraform and applied from CI on merge. My infrastructure is code, not clicking."*

---

## 🔗 Continue reading

► **[Next: 02 — GitOps with ArgoCD](02-gitops-argocd.md)**

◄ **[Back to 07 IaC & GitOps index](README.md)** · [🏠 Repo home](../../README.md)