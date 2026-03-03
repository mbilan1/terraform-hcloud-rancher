# ──────────────────────────────────────────────────────────────────────────────
# Minimal example — input variables
# ──────────────────────────────────────────────────────────────────────────────

variable "hcloud_api_token" {
  description = "Hetzner Cloud API token for the management project (read/write access required)"
  type        = string
  sensitive   = true
}

# NOTE: admin_password is no longer required — the module auto-generates one.
# Override: export TF_VAR_admin_password="your-password" (min 12 chars)
