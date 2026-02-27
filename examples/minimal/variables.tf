# ──────────────────────────────────────────────────────────────────────────────
# Minimal example — input variables
# ──────────────────────────────────────────────────────────────────────────────

variable "hcloud_api_token" {
  description = "Hetzner Cloud API token for the management project (read/write access required)"
  type        = string
  sensitive   = true
}

variable "rancher_hostname" {
  description = "Fully qualified domain name for the Rancher UI (e.g. 'rancher.example.com'). Must resolve to the ingress LB IPv4."
  type        = string
}

variable "admin_password" {
  description = "Initial password for the Rancher 'admin' user. Minimum 12 characters."
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration. Only required when tls_source = 'letsEncrypt'."
  type        = string
  default     = ""
}
