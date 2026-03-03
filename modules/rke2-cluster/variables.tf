# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — input variables
#
# DECISION: Expose only the variables relevant for a management cluster.
# Why: rke2-core has a clean flat API. The wrapper reduces it further:
#      - hcloud_api_token removed: rke2-core uses providers from root (proper module)
#      - cluster_domain removed: rke2-core is Zero-SSH, no cert-manager, no DNS
#      - load_balancer_location removed: rke2-core does not create LBs (ADR-003)
#      - ssh_allowed_cidrs removed: rke2-core is Zero-SSH (ADR-002)
#      - k8s_api_allowed_cidrs removed: firewalls are BYO (ADR-006)
#      - enable_secrets_encryption removed: not exposed by rke2-core
#      - kubernetes_version renamed to rke2_version: matches rke2-core API
# See: /home/mbilan/workdir/rke2-hetzner-architecture/decisions/adr-002-true-zero-ssh.md
# ──────────────────────────────────────────────────────────────────────────────

# ── Cluster identity ─────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "Identifier prefix for all resources"
  type        = string
  nullable    = false
}

# ── Topology ─────────────────────────────────────────────────────────────────

variable "control_plane_count" {
  description = "Number of control-plane nodes (1 or 3+)"
  type        = number
  default     = 1
  nullable    = false
}

variable "control_plane_server_type" {
  description = "Hetzner server type for control-plane nodes"
  type        = string
  default     = "cx43"
  nullable    = false
}

variable "node_location" {
  description = "Primary Hetzner datacenter location"
  type        = string
  default     = "hel1"
  nullable    = false
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "hcloud_network_cidr" {
  description = "Private network CIDR"
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "subnet_address" {
  description = "Subnet CIDR for cluster nodes"
  type        = string
  default     = "10.0.1.0/24"
  nullable    = false
}

variable "hcloud_network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "eu-central"
  nullable    = false
}

# ── RKE2 ─────────────────────────────────────────────────────────────────────

variable "rke2_version" {
  description = "RKE2 release tag to deploy (e.g. 'v1.32.2+rke2r1'). Empty = stable channel."
  type        = string
  default     = "v1.32.2+rke2r1"
  nullable    = false
}

# DECISION: extra_server_manifests passed through from root module.
# Why: Allows root module to inject HelmChart CRDs (cert-manager, Rancher) into
#      the cloud-init manifests directory. RKE2 HelmController installs them
#      automatically — no direct K8s API access from Terraform needed.
# See: providers.tf — helm/kubernetes providers removed in favor of this approach
variable "extra_server_manifests" {
  description = "Map of filename => YAML placed in /var/lib/rancher/rke2/server/manifests/. RKE2 HelmController auto-installs these."
  type        = map(string)
  default     = {}
  nullable    = false
}
