# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — input variables
#
# DECISION: Expose only management-relevant variables from terraform-hcloud-ubuntu-rke2.
# Why: The rke2 module has ~30 variables. A management cluster only needs a subset.
#      Variables like harmony_enabled, agent_node_count, and openbao_enabled are
#      hardcoded in main.tf because they have fixed values for a management cluster.
# ──────────────────────────────────────────────────────────────────────────────

# ── Credentials ──────────────────────────────────────────────────────────────

variable "hcloud_api_token" {
  description = "Hetzner Cloud API token for the management project"
  type        = string
  sensitive   = true
}

variable "aws_access_key" {
  description = "AWS access key for Route53 (passed through to rke2 module)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_secret_key" {
  description = "AWS secret key for Route53 (passed through to rke2 module)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_region" {
  description = "AWS region for Route53"
  type        = string
  default     = "eu-central-1"
}

# ── Cluster identity ─────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "Identifier prefix for all resources"
  type        = string
}

variable "cluster_domain" {
  description = "Domain for the management cluster (typically the Rancher hostname)"
  type        = string
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
