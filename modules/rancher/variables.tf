# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — input variables
#
# DECISION: This module receives only bootstrap-specific configuration.
# Why: Infrastructure concerns (servers, networks, LBs) are handled by the
#      rke2-cluster and _ingress_lb modules. cert-manager, Rancher Helm,
#      NodeDriver, and UIPlugin are all deployed via cloud-init manifests
#      generated in root main.tf. This module only performs admin bootstrap.
# ──────────────────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════════
#  Rancher bootstrap configuration
# ═══════════════════════════════════════════════════════════════════════════════

variable "admin_password" {
  description = "Initial password for the Rancher 'admin' user."
  type        = string
  nullable    = false
  sensitive   = true
}
