# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — required providers
#
# DECISION: Declare required_providers for all providers used in this module.
# Why: OpenTofu requires child modules to declare which providers they use
#      so it can correctly pass through provider configurations from the root.
#      The root module configures all provider {} blocks; this module only
#      declares version constraints.
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 13.0.0"
    }
  }
}
