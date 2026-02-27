# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — outputs
#
# DECISION: Expose Rancher URL and admin token for downstream provisioning.
# Why: After tofu apply, the operator needs the Rancher URL and an admin token
#      to create Cloud Credentials and provision downstream clusters via UI.
# ──────────────────────────────────────────────────────────────────────────────

output "rancher_url" {
  description = "Rancher UI URL (HTTPS)"
  value       = "https://${var.rancher_hostname}"
}

output "admin_token" {
  description = "Rancher admin API token for programmatic access. Treat as a secret."
  value       = rancher2_bootstrap.admin.token
  sensitive   = true
}
