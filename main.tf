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
# ║  L3: RKE2 Cluster — Hetzner infrastructure via terraform-hcloud-rke2-core   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Auto-generate rancher hostname from ingress LB IP when not provided.
# Why: Enables single `tofu apply` without pre-existing DNS. The LB is created
#      before the server (no server dependencies), so its IP is known when
#      cloud-init templates are rendered. sslip.io resolves hostnames like
#      "rancher.1-2-3-4.sslip.io" → 1.2.3.4 — zero DNS configuration needed.
#      For production, users pass var.rancher_hostname with a real FQDN.
# See: https://sslip.io/
locals {
  effective_hostname = (
    var.rancher_hostname != ""
    ? var.rancher_hostname
    : "rancher.${replace(hcloud_load_balancer.ingress.ipv4, ".", "-")}.sslip.io"
  )
}

# DECISION: Generate HelmChart CRD YAML manifests in root, pass to rke2_cluster.
# Why: cert-manager and Rancher are deployed by RKE2 HelmController from
#      /var/lib/rancher/rke2/server/manifests/. Generating the YAML here
#      (in root) and passing via extra_server_manifests keeps the HelmChart
#      content close to the variable definitions and allows full template
#      flexibility (tls_source, letsEncrypt email, versions).
# See: https://docs.rke2.io/helm — HelmChart CRD documentation
locals {
  # DECISION: Numeric prefix ensures alphabetical processing order.
  # Why: RKE2 HelmController processes manifests alphabetically. cert-manager
  #      MUST be installed before Rancher (Rancher creates Certificate resources
  #      that require cert-manager CRDs + webhook).
  rancher_server_manifests = {
    "00-cert-manager.yaml" = <<-YAML
      apiVersion: helm.cattle.io/v1
      kind: HelmChart
      metadata:
        name: cert-manager
        namespace: kube-system
      spec:
        repo: https://charts.jetstack.io
        chart: cert-manager
        version: "${var.cert_manager_version}"
        targetNamespace: cert-manager
        createNamespace: true
        valuesContent: |-
          crds:
            enabled: true
    YAML

    "01-rancher.yaml" = <<-YAML
      apiVersion: helm.cattle.io/v1
      kind: HelmChart
      metadata:
        name: rancher
        namespace: kube-system
      spec:
        repo: https://releases.rancher.com/server-charts/stable
        chart: rancher
        version: "${var.rancher_version}"
        targetNamespace: cattle-system
        createNamespace: true
        valuesContent: |-
          hostname: ${local.effective_hostname}
          bootstrapPassword: ${var.admin_password}
          replicas: 1
          ingress:
            tls:
              source: ${var.tls_source}
%{if var.tls_source == "letsEncrypt"~}
          letsEncrypt:
            email: ${var.letsencrypt_email}
%{endif~}
    YAML
  }
}

module "rke2_cluster" {
  source = "./modules/rke2-cluster"

  # Cluster identity
  cluster_name = var.cluster_name

  # Topology
  control_plane_count       = var.management_node_count
  control_plane_server_type = var.control_plane_server_type
  node_location             = var.node_location

  # Network
  hcloud_network_cidr = var.hcloud_network_cidr
  subnet_address      = var.subnet_address
  hcloud_network_zone = var.hcloud_network_zone

  # Security
  k8s_api_allowed_cidrs = var.k8s_api_allowed_cidrs

  # RKE2
  rke2_version = var.rke2_version

  # DECISION: Pass HelmChart CRD manifests for L4 bootstrap via cloud-init.
  # Why: Eliminates the need for helm/kubernetes Terraform providers which
  #      require K8s API credentials. RKE2 HelmController handles installation
  #      automatically from files in /var/lib/rancher/rke2/server/manifests/.
  extra_server_manifests = local.rancher_server_manifests
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
  # DECISION: Use node_location for ingress LB placement.
  # Why: load_balancer_location was removed — rke2-core does not create LBs (ADR-003).
  #      Co-locating the ingress LB with nodes minimizes latency.
  location = var.node_location

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

# DECISION: Use label_selector for LB targets.
# Why: rke2-core labels all control plane servers with `cluster=${var.cluster_name}`
#      (see modules/_control_plane/main.tf common_labels). The label_selector
#      automatically includes any new nodes added to the cluster without
#      requiring explicit server ID management.
resource "hcloud_load_balancer_target" "ingress_masters" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  type             = "label_selector"
  label_selector   = "cluster=${var.cluster_name}"
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
  rancher_hostname  = local.effective_hostname
  rancher_version   = var.rancher_version
  admin_password    = var.admin_password
  tls_source        = var.tls_source
  letsencrypt_email = var.letsencrypt_email

  # Hetzner Node Driver
  install_hetzner_driver = var.install_hetzner_driver
  hetzner_driver_version = var.hetzner_driver_version

  # DECISION: Explicit dependency on L3 infrastructure + ingress LB.
  # Why: rancher2_bootstrap polls the Rancher URL via HTTPS.
  #      The ingress LB and its services must be ready before the
  #      bootstrap can succeed. module.rke2_cluster must be complete
  #      so the server is running and RKE2 HelmController can install
  #      cert-manager + Rancher from the manifests directory.
  depends_on = [
    module.rke2_cluster,
    hcloud_load_balancer_service.ingress_https,
  ]
}
