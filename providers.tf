# ──────────────────────────────────────────────────────────────────────────────
# Provider configurations — root-level only
#
# DECISION: All providers configured exclusively in the root module.
# Why: OpenTofu best practice — child modules declare required_providers for
#      version constraints only, but never contain provider {} blocks.
#      rke2-core is a proper module — no internal provider blocks (unlike the
#      previous terraform-hcloud-ubuntu-rke2 which was designed as a root module).
# See: docs/ARCHITECTURE.md — Provider Flow
#
# DECISION: L4 providers (helm, kubernetes, kubectl) use initial_master_ipv4
#      as the API endpoint with insecure TLS validation.
# Why: rke2-core is Zero-SSH and does not output kubeconfig (by design, ADR-002).
#      Kubeconfig for operator use is retrieved from Rancher UI post-bootstrap.
#      The helm/kubernetes/kubectl providers communicate directly with the RKE2
#      API server during the bootstrap phase when only a self-signed cert exists.
# WORKAROUND: insecure = true / TLS skip is required because the RKE2 API
#      server uses a self-signed cert at bootstrap time.
# TODO: Evaluate replacing helm/kubernetes/kubectl providers with RKE2 HelmChart
#      CRDs via cloud-init (place manifests in /var/lib/rancher/rke2/server/manifests/)
#      to eliminate the dependency on direct K8s API access entirely.
# ──────────────────────────────────────────────────────────────────────────────

# ── Hetzner Cloud ────────────────────────────────────────────────────────────
provider "hcloud" {
  token = var.hcloud_api_token
}

# ── Helm (cert-manager + Rancher chart installation) ─────────────────────────
# NOTE: Provider config references initial_master_ipv4 from module.rke2_cluster.
#       OpenTofu defers initialization until a helm_release resource is evaluated.
# DECISION: Use attribute syntax (kubernetes = {}) for Helm provider v3.
# Why: Helm provider v3 changed kubernetes config from a block to an attribute.
provider "helm" {
  kubernetes = {
    host     = "https://${module.rke2_cluster.initial_master_ipv4}:6443"
    insecure = true
  }
}

# ── Kubernetes (direct resource management) ──────────────────────────────────
provider "kubernetes" {
  host     = "https://${module.rke2_cluster.initial_master_ipv4}:6443"
  insecure = true
}

# ── kubectl (raw YAML manifest application) ──────────────────────────────────
# DECISION: Use alekc/kubectl for raw manifest application.
# Why: NodeDriver and UIPlugin CRDs require fields not exposed by the kubernetes
#      provider. kubectl_manifest supports arbitrary YAML.
provider "kubectl" {
  host             = "https://${module.rke2_cluster.initial_master_ipv4}:6443"
  insecure         = true
  load_config_file = false
}

# ── Rancher2 (bootstrap mode) ────────────────────────────────────────────────
# DECISION: Single rancher2 provider in bootstrap mode.
# Why: For MVP, the only rancher2 resource is rancher2_bootstrap (sets admin
#      password, server URL, telemetry). Bootstrap mode only needs the Rancher
#      API URL — no auth token required.
# NOTE: insecure = true because during initial bootstrap, cert-manager is
#       provisioning the TLS certificate and it may not yet be trusted.
# TODO: Add a second rancher2 provider (normal mode) when post-bootstrap
#       resources are needed (rancher2_cloud_credential, rancher2_cluster_v2, etc.)
provider "rancher2" {
  api_url   = "https://${var.rancher_hostname}"
  insecure  = true
  bootstrap = true
}
