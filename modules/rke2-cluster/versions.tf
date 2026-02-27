# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — version constraints
#
# NOTE: This module wraps terraform-hcloud-ubuntu-rke2 which declares its own
#       required_providers internally. No duplicate provider declarations here
#       to avoid version conflicts.
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"
}
