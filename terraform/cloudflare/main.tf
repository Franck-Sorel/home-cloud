provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

variable "cloudflare_api_token"  { sensitive = true }
variable "cloudflare_account_id" {}
variable "zone"                  { default = "mycloud.com" }
variable "tunnel_id"             {}
variable "ingress_service"       { default = "http://traefik.kube-system.svc.cluster.local:80" }

data "cloudflare_zone" "this" {
  name = var.zone
}

resource "cloudflare_tunnel" "home_cloud" {
  account_id = var.cloudflare_account_id
  name       = "home-cloud"
  secret     = var.tunnel_secret   # (see vars.tf)
}

locals {
  # One hostname per subdomain/service — add yours here.
  public_hosts = [
    "hello.mycloud.com",
    "api.mycloud.com",
    "storage.mycloud.com",
  ]
}

resource "cloudflare_tunnel_config" "home_cloud" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.home_cloud.id

  config {
    dynamic "ingress_rule" {
      for_each = toset(locals.public_hosts)
      content {
        hostname = ingress_rule.value
        service  = var.ingress_service
      }
    }
    ingress_rule {
      service = "http_status:404"   # catch-all rule (must be last)
    }
  }
}

resource "cloudflare_ruleset" "home_cloud_waf" {
  zone_id = data.cloudflare_zone.this.id
  kind    = "zone"
  phase   = "http_request_firewall_managed"
  name    = "Home Cloud managed WAF"

  rules {
    action      = "execute"
    expression  = "true"
    description = "OWASP Core Ruleset"
    action_parameters {
      ruleset = "efb7b8c949ac4650a09736fc376e9aee"  # OWASP CRS id on Cloudflare
    }
  }
}