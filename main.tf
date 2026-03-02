# ──────────────────────────────────────────────────────────────────────────────
# Root module — orchestration shim
#
# DECISION: Root module is a thin shim that wires child modules together.
# Why: Follows the same pattern as terraform-hcloud-ubuntu-rke2 — root declares
#      variables/providers, child modules contain all resource logic.
#      Layer boundaries:
#        modules/rke2-cluster/ (L3) — Hetzner infrastructure via terraform-hcloud-ubuntu-rke2
#        modules/rancher/      (L4) — cert-manager, Rancher Helm, bootstrap, Node Driver
#      Root owns: provider config, variable routing, ingress LB, DNS.
# See: docs/ARCHITECTURE.md — Module Architecture
# ──────────────────────────────────────────────────────────────────────────────

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  L3: RKE2 Cluster — Hetzner infrastructure via terraform-hcloud-ubuntu-rke2║
# ╚══════════════════════════════════════════════════════════════════════════════╝

module "rke2_cluster" {
  source = "./modules/rke2-cluster"

  # Credentials
  hcloud_api_token = var.hcloud_api_token

  # Cluster identity
  cluster_name   = var.cluster_name
  cluster_domain = var.rancher_hostname

  # Topology
  control_plane_count       = var.management_node_count
  control_plane_server_type = var.control_plane_server_type
  node_location             = var.node_location
  load_balancer_location    = var.load_balancer_location

  # Network
  hcloud_network_cidr = var.hcloud_network_cidr
  subnet_address      = var.subnet_address
  hcloud_network_zone = var.hcloud_network_zone

  # Security
  ssh_allowed_cidrs         = var.ssh_allowed_cidrs
  k8s_api_allowed_cidrs     = var.k8s_api_allowed_cidrs
  enable_secrets_encryption = var.enable_secrets_encryption

  # RKE2
  kubernetes_version = var.kubernetes_version
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ingress Load Balancer — Rancher UI (HTTP/HTTPS)                           ║
# ║  Created in root because the rke2 module only creates ingress LB when      ║
# ║  harmony_enabled=true, which is not the case for management clusters.      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

locals {
  # DECISION: Use lb11 (smallest) for management cluster ingress.
  # Why: Management traffic is low-volume (Rancher UI + API). lb11 supports
  #      25 targets and 10k concurrent connections — more than enough.
  ingress_lb_type = "lb11"
}

resource "hcloud_load_balancer" "ingress" {
  name               = "${var.cluster_name}-ingress-lb"
  load_balancer_type = local.ingress_lb_type
  location           = var.load_balancer_location

  labels = {
    "cluster-name" = var.cluster_name
    "managed-by"   = "opentofu"
    "role"         = "ingress"
  }
}

resource "hcloud_load_balancer_network" "ingress" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  network_id       = module.rke2_cluster.network_id

  depends_on = [module.rke2_cluster]
}

# DECISION: Use label_selector for LB targets instead of explicit server IDs.
# Why: The rke2 module creates servers internally and does not expose server IDs
#      as outputs. Label selectors target all servers with matching labels,
#      which automatically includes all management cluster nodes.
resource "hcloud_load_balancer_target" "ingress_masters" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  type             = "label_selector"
  label_selector   = "cluster-name=${var.cluster_name}"
  use_private_ip   = true

  depends_on = [hcloud_load_balancer_network.ingress]
}

resource "hcloud_load_balancer_service" "ingress_http" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 80

  health_check {
    protocol = "tcp"
    port     = 80
    interval = 10
    timeout  = 5
    retries  = 3
  }

  depends_on = [hcloud_load_balancer_target.ingress_masters]
}

resource "hcloud_load_balancer_service" "ingress_https" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 443

  health_check {
    protocol = "tcp"
    port     = 443
    interval = 10
    timeout  = 5
    retries  = 3
  }

  depends_on = [hcloud_load_balancer_target.ingress_masters]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  L4: Rancher — cert-manager, Rancher Helm, bootstrap, Node Driver         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

module "rancher" {
  source = "./modules/rancher"

  # Rancher configuration
  rancher_hostname     = var.rancher_hostname
  rancher_version      = var.rancher_version
  cert_manager_version = var.cert_manager_version
  admin_password       = var.admin_password
  tls_source           = var.tls_source
  letsencrypt_email    = var.letsencrypt_email

  # Hetzner Node Driver
  install_hetzner_driver = var.install_hetzner_driver
  hetzner_driver_version = var.hetzner_driver_version

  # Explicit dependency: Phase 2 requires Phase 1 (cluster + ingress LB) complete.
  # The helm/kubernetes/kubectl providers are configured with rke2_cluster outputs,
  # creating an implicit dependency. The explicit depends_on is belt-and-suspenders:
  # ensures the ingress LB is also ready before Rancher starts serving traffic.
  depends_on = [
    module.rke2_cluster,
    hcloud_load_balancer_service.ingress_https,
  ]
}
