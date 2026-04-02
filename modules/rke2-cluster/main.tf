# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — L3 infrastructure via terraform-hcloud-rke2-core
#
# DECISION: Replaced terraform-hcloud-ubuntu-rke2 (v1) with terraform-hcloud-rke2-core (v2).
# Why: rke2-core follows the composable primitive architecture:
#        - Zero-SSH design — no SSH provisioners, no remote-exec
#        - Pure L3 (no addons, no kubeconfig, no HCCM) — correct scope for this module
#        - Proper module design — uses providers from root, no internal provider {} blocks
#        - for_each over count — stable node identity
# See: https://github.com/mbilan1/rke2-hetzner-architecture/blob/main/decisions/adr-002-true-zero-ssh.md
#
# DECISION: Source pinned to git tag for reproducible builds.
# Why: Using a tagged git reference ensures consumers get a known-good version.
#      For local development, temporarily override with a local path:
#        source = "../../../terraform-hcloud-rke2-core"
# ──────────────────────────────────────────────────────────────────────────────

module "cluster" {
  # DECISION: Source pinned to commit hash for supply chain security (CKV_TF_1).
  # Tag: v0.2.2 — HA etcd join fix (node-ip via Hetzner metadata)
  source = "git::https://github.com/mbilan1/terraform-hcloud-rke2-core.git?ref=076187879d1297e37685203f868d3f8c632893f7"

  # ── Cluster identity ─────────────────────────────────────────────────────
  cluster_name = var.cluster_name

  # ── Topology ─────────────────────────────────────────────────────────────
  # DECISION: Build control_plane_nodes map from count + type + location.
  # Why: rke2-core uses map(object) for stable node identity (for_each).
  #      The wrapper keeps a simple count API to avoid exposing the internal
  #      map structure to the root module consumer.
  control_plane_nodes = {
    for i in range(var.control_plane_count) : "cp-${i}" => {
      server_type = var.control_plane_server_type
      location    = var.node_location
    }
  }

  # ── Location & Network ───────────────────────────────────────────────────
  hcloud_location     = var.node_location
  hcloud_network_zone = var.hcloud_network_zone
  hcloud_network_cidr = var.hcloud_network_cidr
  subnet_address      = var.subnet_address

  # ── OS Image ─────────────────────────────────────────────────────────────
  hcloud_image = var.hcloud_image

  # ── RKE2 ─────────────────────────────────────────────────────────────────
  rke2_version = var.rke2_version
  rke2_config  = var.rke2_config
  enable_cis   = var.enable_cis

  # ── SSH Key (BYO passthrough) ───────────────────────────────────────────
  ssh_key_ids = var.ssh_key_ids

  # ── Firewall (BYO passthrough) ──────────────────────────────────────────
  firewall_ids = var.firewall_ids

  # DECISION: Pass server manifests for HelmChart CRD-based L4 bootstrap.
  # Why: cert-manager + Rancher are installed by RKE2 HelmController from
  #      manifest files placed in cloud-init. This eliminates the need for
  #      helm/kubernetes providers to have direct K8s API credentials.
  extra_server_manifests = var.extra_server_manifests

  # DECISION: delete_protection passed through from parent module.
  # Why: Production clusters need protection (default true), but dev/test
  #      environments need fast teardown without manual Hetzner API calls.
  delete_protection = var.delete_protection
}
