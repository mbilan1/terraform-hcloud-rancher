# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — management cluster via terraform-hcloud-ubuntu-rke2
#
# DECISION: Wrapper module with management-optimized defaults.
# Why: The terraform-hcloud-ubuntu-rke2 module is a general-purpose RKE2
#      provisioner. This wrapper fixes variables that are always the same for
#      a Rancher management cluster:
#        - cloud_provider_external = false (no HCCM for management clusters)
#        - save_ssh_key_locally = false (no SSH access needed)
#
# COMPROMISE: The rke2 module was designed as a root module and contains
#      provider {} blocks internally. When used as a child module, OpenTofu
#      emits a deprecation warning but it works. This is a known anti-pattern
#      that will be resolved when the rke2 module extracts provider configs.
# See: docs/ARCHITECTURE.md — Compromise Log #1
# ──────────────────────────────────────────────────────────────────────────────

module "cluster" {
  # DECISION: Git source pinned to main branch.
  # Why: Public GitHub repository is the single source of truth.
  #      Pin to a release tag when available for reproducibility:
  #        source = "git::https://github.com/mbilan1/terraform-hcloud-ubuntu-rke2.git?ref=v1.0.0"
  source = "git::https://github.com/mbilan1/terraform-hcloud-ubuntu-rke2.git"

  # ── Credentials ──────────────────────────────────────────────────────────
  hcloud_api_token = var.hcloud_api_token

  # ── Cluster identity ─────────────────────────────────────────────────────
  rke2_cluster_name = var.cluster_name

  # ── Topology (management-optimized) ──────────────────────────────────────
  control_plane_count     = var.control_plane_count
  master_node_server_type = var.control_plane_server_type
  node_locations          = [var.node_location]
  load_balancer_location  = var.load_balancer_location

  # ── Network ──────────────────────────────────────────────────────────────
  hcloud_network_cidr = var.hcloud_network_cidr
  subnet_address      = var.subnet_address
  hcloud_network_zone = var.hcloud_network_zone

  # ── Security ─────────────────────────────────────────────────────────────
  ssh_allowed_cidrs         = var.ssh_allowed_cidrs
  k8s_api_allowed_cidrs     = var.k8s_api_allowed_cidrs
  enable_secrets_encryption = var.enable_secrets_encryption

  # ── RKE2 ─────────────────────────────────────────────────────────────────
  kubernetes_version = var.kubernetes_version

  # ── Fixed for management cluster ─────────────────────────────────────────

  # DECISION: No SSH key saved to disk.
  # Why: Zero SSH principle — management cluster should not require SSH access.
  #      The rke2 module uses SSH internally for provisioners, but the key
  #      stays in Terraform state only.
  save_ssh_key_locally = false

  # DECISION: cloud_provider_external = false for management clusters.
  # Why: When true, RKE2 adds a NoSchedule taint
  #      (node.cloudprovider.kubernetes.io/uninitialized=true) that blocks ALL
  #      pods until a Cloud Controller Manager removes it. Management clusters
  #      run Rancher only — no HCCM is deployed (it's a Helmfile L4 concern for
  #      workload clusters). The taint causes a deadlock: CoreDNS, ingress, and
  #      all helm jobs stay Pending forever.
  # See: docs/ARCHITECTURE.md — Deployment Flow
  cloud_provider_external = false
}
