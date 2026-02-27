# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — input variables
#
# DECISION: This module receives only L4-specific configuration.
# Why: Infrastructure concerns (servers, networks, LBs) are handled by the
#      rke2-cluster module. This module only installs cert-manager, Rancher,
#      does admin bootstrap, and optionally registers the Hetzner Node Driver.
# ──────────────────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════════
#  Rancher chart configuration
# ═══════════════════════════════════════════════════════════════════════════════

variable "rancher_hostname" {
  description = "Fully qualified domain name for the Rancher UI (e.g. 'rancher.example.com')."
  type        = string
  nullable    = false
}

variable "rancher_version" {
  description = "Rancher Helm chart version."
  type        = string
  nullable    = false
}

variable "admin_password" {
  description = "Initial password for the Rancher 'admin' user."
  type        = string
  nullable    = false
  sensitive   = true
}

variable "tls_source" {
  description = "TLS certificate source for Rancher: 'rancher' (self-signed), 'letsEncrypt', or 'secret'."
  type        = string
  nullable    = false
  default     = "rancher"
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration. Required only when tls_source = 'letsEncrypt'."
  type        = string
  nullable    = false
  default     = ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  cert-manager configuration
# ═══════════════════════════════════════════════════════════════════════════════

variable "cert_manager_version" {
  description = "cert-manager Helm chart version."
  type        = string
  nullable    = false
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Hetzner Node Driver (zsys-studio)
# ═══════════════════════════════════════════════════════════════════════════════

variable "install_hetzner_driver" {
  description = "Install the zsys-studio Hetzner Node Driver and UI Extension."
  type        = bool
  nullable    = false
  default     = true
}

variable "hetzner_driver_version" {
  description = "Version of zsys-studio/rancher-hetzner-cluster-provider."
  type        = string
  nullable    = false
}
