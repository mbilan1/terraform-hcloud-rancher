# ──────────────────────────────────────────────────────────────────────────────
# Root module — orchestration facade
#
# DECISION: Root module is a thin facade that wires child modules together.
# Why: Follows the same composable-primitive pattern as terraform-hcloud-rke2-core.
#      Layer boundaries:
#        modules/rke2-cluster/  (L3) — Hetzner infrastructure via rke2-core
#        Ingress LB resources   (L3) — BYO ingress load balancer (ADR-003)
#        modules/rancher/       (L4) — Rancher admin bootstrap
#      All L4 software (cert-manager, Rancher, NodeDriver, UIPlugin) is deployed
#      via RKE2 HelmChart CRDs and raw manifests in cloud-init.
# See: docs/ARCHITECTURE.md — Module Architecture
# ──────────────────────────────────────────────────────────────────────────────

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Admin Password — auto-generate if not provided                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Auto-generate admin_password when empty (default).
# Why: Eliminates the interactive prompt during `tofu apply`. Operators get the
#      password from `tofu output -raw rancher_admin_password`. For CI/CD, pass
#      via TF_VAR_admin_password. random_password is from hashicorp/random, already
#      a transitive dependency via rke2-core.
resource "random_password" "admin" {
  count   = var.admin_password == "" ? 1 : 0
  length  = 24
  special = true
}

locals {
  effective_admin_password = (
    var.admin_password != ""
    ? var.admin_password
    : random_password.admin[0].result
  )
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  BYO Ingress LB + Hostname Resolution                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: BYO pattern for ingress LB — inline for_each gating.
# Why: The LB resource itself must be created BEFORE rke2_cluster because the
#      auto-generated hostname (from LB IP) is embedded in cloud-init manifests
#      passed to rke2_cluster. A submodule would create a cycle:
#        ingress_lb.ipv4 → hostname → manifests → rke2_cluster → network_id → ingress_lb
#      Keeping the LB resource inline breaks the cycle: the LB is created
#      independently, then the network attachment (which needs rke2_cluster's
#      network_id) is created with an explicit depends_on.
# See: /home/mbilan/workdir/rke2-hetzner-architecture/decisions/adr-003-dual-load-balancer.md
locals {
  # DECISION: Derive create flag from both create_ingress_lb and existing_ipv4.
  # Why: Same pattern as rke2-core _network module — the presence of an existing
  #      resource signal skips creation.
  create_ingress_lb = var.create_ingress_lb && var.existing_ingress_lb_ipv4 == ""

  # DECISION: Effective IP comes from created LB or existing LB.
  # Why: Consumers always get a valid IP regardless of BYO mode.
  effective_lb_ipv4 = (
    local.create_ingress_lb
    ? hcloud_load_balancer.ingress["main"].ipv4
    : var.existing_ingress_lb_ipv4
  )
}

# DECISION: Auto-generate rancher hostname from ingress LB IP when not provided.
# Why: Enables single `tofu apply` without pre-existing DNS. The LB is created
#      before the server (no server dependencies), so its IP is known when
#      cloud-init templates are rendered. sslip.io resolves hostnames like
#      "rancher.1-2-3-4.sslip.io" → 1.2.3.4 — zero DNS configuration needed.
#      For production, users pass var.rancher_hostname with a real FQDN.
#      When using BYO LB (create_ingress_lb=false), auto-generation uses
#      existing_ingress_lb_ipv4 instead.
# See: https://sslip.io/
locals {
  effective_hostname = (
    var.rancher_hostname != ""
    ? var.rancher_hostname
    : "rancher.${replace(local.effective_lb_ipv4, ".", "-")}.sslip.io"
  )
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Cloud-Init Manifests — L4 Software Stack                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Generate ALL L4 manifests in root, pass to rke2_cluster via cloud-init.
# Why: cert-manager, Rancher, NodeDriver, and UIPlugin are all deployed by RKE2
#      from /var/lib/rancher/rke2/server/manifests/. Generating the YAML here
#      (in root) keeps manifest content close to variable definitions and enables
#      full template flexibility. This eliminates the need for helm, kubernetes,
#      and kubectl Terraform providers entirely — only hcloud + rancher2 remain.
# See: https://docs.rke2.io/helm — HelmChart CRD documentation
locals {
  # DECISION: Numeric prefix ensures alphabetical processing order.
  # Why: RKE2 processes manifests alphabetically. cert-manager MUST install
  #      before Rancher (Rancher creates Certificate resources that require
  #      cert-manager CRDs + webhook). NodeDriver/UIPlugin CRDs only exist
  #      after Rancher starts — the deploy controller retries failed manifests
  #      until Rancher registers its CRDs (management.cattle.io, catalog.cattle.io).
  rancher_server_manifests = merge(
    {
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
            bootstrapPassword: ${local.effective_admin_password}
            replicas: 1
            ingress:
              tls:
                source: ${var.tls_source}
%{if var.tls_source == "letsEncrypt"~}
            letsEncrypt:
              email: ${var.letsencrypt_email}
%{endif~}
      YAML
    },

    # DECISION: NodeDriver + UIPlugin deployed via raw manifests in cloud-init.
    # Why: Eliminates the alekc/kubectl third-party provider entirely. The RKE2
    #      deploy controller applies raw manifests from the manifests directory
    #      and retries on failure. NodeDriver (management.cattle.io/v3) and
    #      UIPlugin (catalog.cattle.io/v1) CRDs only exist after Rancher starts,
    #      so initial applies fail but succeed on retry once Rancher registers
    #      its CRDs. This is consistent with how cert-manager + Rancher are
    #      deployed (all via cloud-init, no external K8s API access needed).
    # COMPROMISE: Version changes to hetzner_driver_version only take effect on
    #      new server creation (user_data changes are ignored on existing servers).
    #      This is the same limitation as cert-manager/Rancher version changes.
    #      For in-place updates, operators can manually place manifests on disk
    #      or use the Rancher API.
    # See: /home/mbilan/workdir/rke2-hetzner-architecture/investigations/inv-002-hetzner-machine-driver.md
    var.install_hetzner_driver ? {
      "10-hetzner-node-driver.yaml" = yamlencode({
        apiVersion = "management.cattle.io/v3"
        kind       = "NodeDriver"
        metadata = {
          name = "hetzner"
          annotations = {
            # NOTE: This annotation tells Rancher which credential field to
            # populate when the user adds Cloud Credentials for Hetzner.
            "privateCredentialFields" = "apiToken"
          }
        }
        spec = {
          active             = true
          addCloudCredential = true
          displayName        = "Hetzner"
          url                = "https://github.com/zsys-studio/rancher-hetzner-cluster-provider/releases/download/v${var.hetzner_driver_version}/docker-machine-driver-hetzner_${var.hetzner_driver_version}_linux_amd64.tar.gz"
          whitelistDomains   = ["api.hetzner.cloud"]
        }
      })

      "11-hetzner-ui-extension.yaml" = yamlencode({
        apiVersion = "catalog.cattle.io/v1"
        kind       = "UIPlugin"
        metadata = {
          name      = "hetzner-node-driver"
          namespace = "cattle-ui-plugin-system"
        }
        spec = {
          plugin = {
            name     = "hetzner-node-driver"
            version  = var.hetzner_driver_version
            endpoint = "https://github.com/zsys-studio/rancher-hetzner-cluster-provider/releases/download/v${var.hetzner_driver_version}/hetzner-node-driver-${var.hetzner_driver_version}.tgz"
            noCache  = false
            noAuth   = true
          }
        }
      })
    } : {}
  )
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  L3: RKE2 Cluster — Hetzner infrastructure via terraform-hcloud-rke2-core ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

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

  # DECISION: Pass ALL L4 manifests (HelmCharts + raw CRDs) via cloud-init.
  # Why: Eliminates the need for helm/kubernetes/kubectl Terraform providers.
  #      RKE2 HelmController installs cert-manager + Rancher from HelmChart CRDs.
  #      RKE2 deploy controller applies NodeDriver + UIPlugin raw manifests
  #      (with retry for CRDs that don't exist yet).
  extra_server_manifests = local.rancher_server_manifests
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  L3: Ingress Load Balancer — BYO pattern with for_each gating (ADR-003)   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Ingress LB follows the BYO pattern from rke2-core using for_each.
# Why: Production teams may pre-provision load balancers with specific IPs,
#      use external LB solutions, or share an LB across services.
#      create_ingress_lb = true (default) creates the LB; set to false and
#      provide existing_ingress_lb_ipv4 to use a pre-existing LB.
# NOTE: The LB resource itself has NO dependency on module.rke2_cluster.
#       Only the network attachment and targets depend on rke2_cluster
#       (they need network_id). This avoids a dependency cycle:
#         LB IP → hostname → manifests → rke2_cluster → network → LB network
# See: /home/mbilan/workdir/rke2-hetzner-architecture/decisions/adr-003-dual-load-balancer.md

resource "hcloud_load_balancer" "ingress" {
  for_each = local.create_ingress_lb ? { main = true } : {}

  name               = "${var.cluster_name}-ingress-lb"
  load_balancer_type = "lb11"
  location           = var.node_location

  labels = {
    "cluster-name" = var.cluster_name
    "managed-by"   = "opentofu"
    "role"         = "ingress"
  }
}

# NOTE: Network attachment depends on rke2_cluster (needs network_id).
# The LB itself is created independently above.
resource "hcloud_load_balancer_network" "ingress" {
  for_each = hcloud_load_balancer.ingress

  load_balancer_id = each.value.id
  network_id       = module.rke2_cluster.network_id

  depends_on = [module.rke2_cluster]
}

# DECISION: Use label_selector for LB targets.
# Why: rke2-core labels all control plane servers with `cluster=${var.cluster_name}`.
#      The label_selector automatically includes any new nodes added to the cluster
#      without requiring explicit server ID management.
resource "hcloud_load_balancer_target" "ingress" {
  for_each = hcloud_load_balancer_network.ingress

  load_balancer_id = hcloud_load_balancer.ingress["main"].id
  type             = "label_selector"
  label_selector   = "cluster=${var.cluster_name}"
  use_private_ip   = true
}

resource "hcloud_load_balancer_service" "http" {
  for_each = hcloud_load_balancer_target.ingress

  load_balancer_id = hcloud_load_balancer.ingress["main"].id
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
}

resource "hcloud_load_balancer_service" "https" {
  for_each = hcloud_load_balancer_target.ingress

  load_balancer_id = hcloud_load_balancer.ingress["main"].id
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
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  L4: Rancher — admin bootstrap only                                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Rancher module reduced to only rancher2_bootstrap.
# Why: cert-manager + Rancher are deployed via HelmChart CRDs in cloud-init.
#      NodeDriver + UIPlugin are deployed via raw manifests in cloud-init.
#      The only L4 operation requiring a Terraform provider is the initial
#      admin bootstrap (set password, server URL, telemetry).
#      This eliminates alekc/kubectl entirely — providers: hcloud + rancher2 only.
module "rancher" {
  source = "./modules/rancher"

  # Rancher configuration
  rancher_hostname = local.effective_hostname
  admin_password   = local.effective_admin_password

  # DECISION: Explicit dependency on L3 infrastructure + ingress LB services.
  # Why: rancher2_bootstrap polls the Rancher URL via HTTPS.
  #      The ingress LB services must be ready before the bootstrap can succeed.
  #      module.rke2_cluster must be complete so the server is running and
  #      RKE2 HelmController can install cert-manager + Rancher from manifests.
  depends_on = [
    module.rke2_cluster,
    hcloud_load_balancer_service.https,
  ]
}
