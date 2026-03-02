# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — version constraints
#
# NOTE: rke2-core is a proper module — it declares required_providers but NOT
#       provider {} blocks. Providers are configured in the root module and
#       passed down via implicit inheritance. No provider declarations here.
# See: docs/ARCHITECTURE.md — Provider Flow
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  # DECISION: Align with rke2-core minimum OpenTofu version.
  # Why: rke2-core requires >= 1.8.0 for for_each on module calls and
  #      the random_password resource used for cluster_token generation.
  required_version = ">= 1.8.0"
}
