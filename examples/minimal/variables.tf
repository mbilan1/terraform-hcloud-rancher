# ──────────────────────────────────────────────────────────────────────────────
# Minimal example — input variables
# ──────────────────────────────────────────────────────────────────────────────

variable "hcloud_api_token" {
  description = "Hetzner Cloud API token for the management project (read/write access required)"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Initial password for the Rancher 'admin' user. Minimum 12 characters."
  type        = string
  sensitive   = true
}
