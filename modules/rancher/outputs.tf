# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — outputs
#
# DECISION: Expose admin token for downstream provisioning.
# Why: After tofu apply, the operator needs the admin token for the rancher2.admin
#      provider alias. Rancher URL is constructed in root outputs.tf from
#      local.effective_hostname — not duplicated here.
# ──────────────────────────────────────────────────────────────────────────────

output "admin_token" {
  description = "Rancher admin API token for programmatic access. Treat as a secret."
  value       = rancher2_bootstrap.admin.token
  sensitive   = true
}
