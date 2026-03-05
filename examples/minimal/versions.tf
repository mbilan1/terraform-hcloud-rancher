# ──────────────────────────────────────────────────────────────────────────────
# Minimal example — provider configuration
#
# DECISION: Example configures hcloud provider directly for BYO firewall.
# Why: The firewall is created in the example per ADR-006 (BYO Firewall).
#      This requires the example to configure the hcloud provider, even though
#      the module also configures it internally for its own resources.
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_api_token
}
