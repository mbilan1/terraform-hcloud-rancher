# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — management cluster via terraform-hcloud-ubuntu-rke2
#
# DECISION: Wrapper module with management-optimized defaults.
# Why: The terraform-hcloud-ubuntu-rke2 module is a general-purpose RKE2
#      provisioner. This wrapper fixes variables that are always the same for
#      a Rancher management cluster:
#        - agent_node_count = 0 (Rancher on control plane, no dedicated workers)
#        - harmony_enabled = false (no Harmony, RKE2 built-in ingress for Rancher)
#        - create_dns_record = false (DNS managed by the parent module)
#        - openbao_enabled = false (not needed for management)
#        - save_ssh_key_locally = false (no SSH access needed)
#
# COMPROMISE: The rke2 module was designed as a root module and contains
#      provider {} blocks internally. When used as a child module, OpenTofu
#      emits a deprecation warning but it works. This is a known anti-pattern
#      that will be resolved when the rke2 module extracts provider configs.
# See: docs/ARCHITECTURE.md — Compromise Log #1
# ──────────────────────────────────────────────────────────────────────────────

module "cluster" {
  # DECISION: Local path source for development.
  # Why: The rke2 module is in the same workspace during development.
  #      For production, replace with a git source pinned to a release tag:
  #        source = "git::https://github.com/<owner>/terraform-hcloud-ubuntu-rke2.git?ref=v1.0.0"
  # TODO: Replace with git source when terraform-hcloud-ubuntu-rke2 publishes a tagged release.
  source = "../../../terraform-hcloud-rke2"

  # ── Credentials ──────────────────────────────────────────────────────────
  hcloud_api_token = var.hcloud_api_token
  aws_access_key   = var.aws_access_key
  aws_secret_key   = var.aws_secret_key
  aws_region       = var.aws_region

  # ── Cluster identity ─────────────────────────────────────────────────────
  rke2_cluster_name = var.cluster_name
  cluster_domain    = var.cluster_domain

  # ── Topology (management-optimized) ──────────────────────────────────────
  control_plane_count     = var.control_plane_count
  master_node_server_type = var.control_plane_server_type
  node_locations          = [var.node_location]
  load_balancer_location  = var.load_balancer_location

  # DECISION: No dedicated workers for the management cluster.
  # Why: Rancher, cert-manager, and the Node Driver run on control-plane nodes.
  #      Dedicated workers add cost and complexity without benefit for a
  #      management cluster that runs only Rancher.
  agent_node_count = 0

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

  # DECISION: harmony_enabled = false for management clusters.
  # Why: Harmony deploys OpenEdX ingress (DaemonSet + hostPort). Management
  #      clusters run Rancher, not OpenEdX. RKE2 built-in ingress-nginx is
  #      used instead for Rancher's Ingress resources.
  harmony_enabled = false

  # DECISION: DNS managed by the parent module (not the rke2 child).
  # Why: The parent creates an A-record for rancher_hostname pointing to
  #      the ingress LB. The rke2 module's DNS creates a wildcard record
  #      for Harmony — not applicable here.
  create_dns_record = false

  # DECISION: No SSH key saved to disk.
  # Why: Zero SSH principle — management cluster should not require SSH access.
  #      The rke2 module uses SSH internally for provisioners, but the key
  #      stays in Terraform state only.
  save_ssh_key_locally = false

  # DECISION: OpenBao not needed for management cluster.
  # Why: Secrets management for downstream clusters is handled by Rancher's
  #      built-in encrypted Cloud Credentials. OpenBao would add complexity
  #      without clear benefit for a management-only cluster.
  openbao_enabled = false

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
