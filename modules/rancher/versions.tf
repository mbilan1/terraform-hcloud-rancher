# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — required providers
#
# DECISION: Only rancher2 provider — kubectl removed.
# Why: NodeDriver and UIPlugin are now deployed via raw YAML manifests in
#      cloud-init (RKE2 deploy controller). The only operation requiring a
#      Terraform provider is rancher2_bootstrap (admin password setup).
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 13.0.0"
    }
  }
}
