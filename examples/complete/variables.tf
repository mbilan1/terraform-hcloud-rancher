# ──────────────────────────────────────────────────────────────────────────────
# Complete example — input variables
# ──────────────────────────────────────────────────────────────────────────────

variable "hcloud_api_token" {
  description = "Hetzner Cloud API token for the management project (read/write access required)"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Initial Rancher admin password (min 12 characters)"
  type        = string
  sensitive   = true
}

variable "rancher_hostname" {
  description = "FQDN for Rancher (e.g. 'rancher.example.com'). Must have a DNS A record pointing to the ingress LB IP."
  type        = string
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate registration"
  type        = string
}

variable "hcloud_image" {
  description = "Hetzner image — stock 'ubuntu-24.04' or Packer snapshot ID (e.g. '12345678') for CIS-hardened image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "operator_cidrs" {
  description = "CIDRs allowed to access K8s API (port 6443). Default: office/VPN only."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

# ── etcd S3 backup (optional) ─────────────────────────────────────────────────

variable "etcd_s3_endpoint" {
  description = "S3-compatible endpoint for etcd snapshots (e.g. 'fsn1.your-objectstorage.com'). Empty = local snapshots only."
  type        = string
  default     = ""
}

variable "etcd_s3_bucket" {
  description = "S3 bucket name for etcd snapshots"
  type        = string
  default     = ""
}

variable "etcd_s3_access_key" {
  description = "S3 access key for etcd snapshots"
  type        = string
  sensitive   = true
  default     = ""
}

variable "etcd_s3_secret_key" {
  description = "S3 secret key for etcd snapshots"
  type        = string
  sensitive   = true
  default     = ""
}

variable "etcd_s3_region" {
  description = "S3 region for etcd snapshots (e.g. 'eu-central')"
  type        = string
  default     = "eu-central"
}
