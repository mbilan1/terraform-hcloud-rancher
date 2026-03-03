# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — L3 infrastructure via terraform-hcloud-rke2-core
#
# DECISION: Replaced terraform-hcloud-ubuntu-rke2 (v1) with terraform-hcloud-rke2-core (v2).
# Why: rke2-core follows the composable primitive architecture:
#        - Zero-SSH design — no SSH provisioners, no remote-exec
#        - Pure L3 (no addons, no kubeconfig, no HCCM) — correct scope for this module
#        - Proper module design — uses providers from root, no internal provider {} blocks
#        - for_each over count — stable node identity
# See: /home/mbilan/workdir/rke2-hetzner-architecture/decisions/adr-002-true-zero-ssh.md
#
# DECISION: Source is a local path to sibling repository.
# Why: rke2-core lives at the same workdir level. Local path avoids git fetch
#      on every init and keeps development cycle fast. Replace with a git URL
#      or registry source when both repos are ready for a stable release.
# TODO: Switch to git tag reference when rke2-core publishes v1.0.0
#        source = "git::https://github.com/mbilan1/terraform-hcloud-rke2-core.git?ref=v1.0.0"
# ──────────────────────────────────────────────────────────────────────────────

module "cluster" {
  source = "../../../terraform-hcloud-rke2-core"

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

  # ── RKE2 ─────────────────────────────────────────────────────────────────
  rke2_version = var.rke2_version

  # DECISION: Pass server manifests for HelmChart CRD-based L4 bootstrap.
  # Why: cert-manager + Rancher are installed by RKE2 HelmController from
  #      manifest files placed in cloud-init. This eliminates the need for
  #      helm/kubernetes providers to have direct K8s API credentials.
  extra_server_manifests = var.extra_server_manifests

  # DECISION: delete_protection hardcoded to true for management clusters.
  # Why: The management cluster runs Rancher, which manages ALL downstream clusters.
  #      Accidental deletion is catastrophic. Hardcoding true prevents the
  #      rke2-core advisory check from firing in tests and enforces a sensible
  #      production default. Users who need to destroy must disable protection
  #      manually via the Hetzner Cloud console.
  delete_protection = true
}
