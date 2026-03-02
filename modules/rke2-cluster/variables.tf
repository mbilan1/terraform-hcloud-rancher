# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — input variables
#
# DECISION: Expose only management-relevant variables from terraform-hcloud-ubuntu-rke2.
# Why: The rke2 module has ~20 variables (post-minimization). A management cluster
#      only needs a subset. Variables like cloud_provider_external and
#      save_ssh_key_locally are hardcoded in main.tf because they have fixed
#      values for a management cluster.
# ──────────────────────────────────────────────────────────────────────────────

# ── Credentials ──────────────────────────────────────────────────────────────

variable "hcloud_api_token" {
  description = "Hetzner Cloud API token for the management project"
  type        = string
  sensitive   = true
}

# ── Cluster identity ─────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "Identifier prefix for all resources"
  type        = string
}

variable "cluster_domain" {
  description = "Base DNS domain for the cluster (e.g. 'rancher.example.com'). Required by the upstream rke2 module for DNS and cert-manager config."
  type        = string
  nullable    = false
}

# ── Topology ─────────────────────────────────────────────────────────────────

variable "control_plane_count" {
  description = "Number of control-plane nodes (1 or 3+)"
  type        = number
  default     = 1
}

variable "control_plane_server_type" {
  description = "Hetzner server type for control-plane nodes"
  type        = string
  default     = "cx43"
}

variable "node_location" {
  description = "Primary Hetzner datacenter location"
  type        = string
  default     = "hel1"
}

variable "load_balancer_location" {
  description = "Hetzner datacenter for the control-plane load balancer"
  type        = string
  default     = "hel1"
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "hcloud_network_cidr" {
  description = "Private network CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address" {
  description = "Subnet CIDR for cluster nodes"
  type        = string
  default     = "10.0.1.0/24"
}

variable "hcloud_network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "eu-central"
}

# ── Security ─────────────────────────────────────────────────────────────────

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "k8s_api_allowed_cidrs" {
  description = "CIDR blocks allowed for K8s API access"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "enable_secrets_encryption" {
  description = "Enable Kubernetes Secrets encryption at rest in etcd"
  type        = bool
  default     = true
}

# ── RKE2 ─────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "RKE2 release tag to deploy"
  type        = string
  default     = "v1.34.4+rke2r1"
}
