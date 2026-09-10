# Cloudflare Terraform

Declares the *edge* half of home-cloud as code — the zone records, the tunnel
hostnames and the WAF rules — so `terraform apply` reproduces the entire
public side of the architecture from this repo.

> Doc: [`docs/07-iac-gitops/01-terraform.md`](../../docs/07-iac-gitops/01-terraform.md)

```
terraform/cloudflare/
├── main.tf            the zone, tunnel hostnames, WAF ruleset
├── vars.tf            variables with sensible defaults
├── terraform.tfvars.example   ← copy to terraform.tfvars (gitignored)
└── .sops.yaml         (optional) encrypt terraform.tfvars
```

## Quick start

```bash
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars   # put your CLOUDFLARE_API_TOKEN + zone in it
terraform init
terraform plan
terraform apply
```

## SECURITY

- `terraform.tfvars` (contains your API token) is **gitignored** — never commit it.
- Prefer environment variables when running CI:
  `export CLOUDFLARE_API_TOKEN=...`
- Optionally commit an *encrypted* `terraform.tfvars` via SOPS
  ([`docs/07-iac-gitops/03-secrets-in-git.md`](../../docs/07-iac-gitops/03-secrets-in-git.md)).

---

## When you DON'T need this (the $0 path)

This Terraform is only for the **Cloudflare Tunnel** network model. If you use
the **$0 DDNS** model instead (deSEC.io/Dynu + Let's Encrypt + a router
port-forward), there is **no edge infra to manage as code** — the DDNS updater
runs *inside* the cluster (see the `base` bundle) and Traefik issues wildcard
certs via DNS-01. See
[`docs/09-bundles/02-networking-models.md`](../../docs/09-bundles/02-networking-models.md).