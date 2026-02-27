# ──────────────────────────────────────────────────────────────────────────────
# Provider configurations — root-level only
#
# DECISION: All providers configured exclusively in the root module.
# Why: OpenTofu best practice — child modules declare required_providers for
#      version constraints only, but never contain provider {} blocks.
#      Exception: the rke2-cluster child module sources terraform-hcloud-ubuntu-rke2
#      which was designed as a root module and contains its own provider {} blocks.
#      This is a known anti-pattern inherited from the rke2 module's architecture.
# See: docs/ARCHITECTURE.md — Provider Flow
#
# DECISION: L4 providers (helm, kubernetes, kubectl, rancher2) configured using
#      kubeconfig outputs from module.rke2_cluster.
# Why: These providers need cluster credentials to communicate with the K8s API.
#      The rke2 module produces these credentials after Phase 1 completes.
#      OpenTofu defers provider initialization until the first resource needs it,
#      so the cyclic appearance (output feeds provider config) resolves naturally
#      through the dependency graph.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # WORKAROUND: Keep AWS provider auth logic centralized (mirrors rke2 module pattern).
  # Why: The AWS provider eagerly validates credentials during init. When Route53
  #      is unused, dummy values prevent init failures without real AWS credentials.
  aws_dns_is_enabled = var.route53_zone_id != ""

  aws_access_key_effective = (!local.aws_dns_is_enabled && var.aws_access_key == "") ? "unused" : var.aws_access_key
  aws_secret_key_effective = (!local.aws_dns_is_enabled && var.aws_secret_key == "") ? "unused" : var.aws_secret_key
  aws_skip_validation      = !local.aws_dns_is_enabled
}

# ── Hetzner Cloud ────────────────────────────────────────────────────────────
# NOTE: This provider instance is used by root-level resources only (ingress LB,
#       DNS-related data sources). The rke2-cluster child module configures its
#       OWN hcloud provider internally with the same token.
provider "hcloud" {
  token = var.hcloud_api_token
}

# ── AWS (Route53 DNS management) ─────────────────────────────────────────────
# DECISION: Provide dummy credentials when Route53 is unused.
# Why: The AWS provider validates credentials eagerly at init time. Without
#      dummy values, operators who don't use Route53 would need to export
#      AWS_* environment variables or the plan fails before reaching any
#      AWS resource. The skip_* flags disable unnecessary API calls entirely.
provider "aws" {
  region     = var.aws_region
  access_key = local.aws_access_key_effective
  secret_key = local.aws_secret_key_effective

  skip_credentials_validation = local.aws_skip_validation
  skip_requesting_account_id  = local.aws_skip_validation
  skip_metadata_api_check     = local.aws_skip_validation
}

# ── Helm (cert-manager + Rancher chart installation) ─────────────────────────
# NOTE: Provider config uses outputs from module.rke2_cluster. OpenTofu defers
#       initialization until a helm_release resource is evaluated in the plan.
# DECISION: Use attribute syntax (kubernetes = {}) for Helm provider v3.
# Why: Helm provider v3 changed kubernetes config from a block to an attribute.
provider "helm" {
  kubernetes = {
    host                   = module.rke2_cluster.cluster_host
    client_certificate     = module.rke2_cluster.client_cert
    client_key             = module.rke2_cluster.client_key
    cluster_ca_certificate = module.rke2_cluster.cluster_ca
  }
}

# ── Kubernetes (direct resource management) ──────────────────────────────────
provider "kubernetes" {
  host                   = module.rke2_cluster.cluster_host
  client_certificate     = module.rke2_cluster.client_cert
  client_key             = module.rke2_cluster.client_key
  cluster_ca_certificate = module.rke2_cluster.cluster_ca
}

# ── kubectl (raw YAML manifest application) ──────────────────────────────────
# DECISION: Use alekc/kubectl for raw manifest application.
# Why: NodeDriver and UIPlugin CRDs require fields not exposed by the kubernetes
#      provider. kubectl_manifest supports arbitrary YAML.
provider "kubectl" {
  host                   = module.rke2_cluster.cluster_host
  client_certificate     = module.rke2_cluster.client_cert
  client_key             = module.rke2_cluster.client_key
  cluster_ca_certificate = module.rke2_cluster.cluster_ca
  load_config_file       = false
}

# ── Rancher2 (bootstrap mode) ────────────────────────────────────────────────
# DECISION: Single rancher2 provider in bootstrap mode.
# Why: For MVP, the only rancher2 resource is rancher2_bootstrap (sets admin
#      password, server URL, telemetry). Post-bootstrap resources (cloud credentials,
#      cluster templates) are out of scope for now. Bootstrap mode only needs
#      the Rancher API URL — no auth token required.
# NOTE: insecure = true because during initial bootstrap, cert-manager is
#       provisioning the TLS certificate and it may not yet be trusted.
# TODO: Add a second rancher2 provider (normal mode) when post-bootstrap
#       resources are needed (rancher2_cloud_credential, rancher2_cluster_v2, etc.)
provider "rancher2" {
  api_url   = "https://${var.rancher_hostname}"
  insecure  = true
  bootstrap = true
}
