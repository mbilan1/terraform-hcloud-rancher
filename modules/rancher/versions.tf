# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — required providers
#
# DECISION: Exact version pins (=) for reproducible deployments.
# Why: Aligned with root module pin strategy. Prevents silent patch-level
#      drift between root and child module provider constraints.
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "= 13.1.4"
    }
  }
}
