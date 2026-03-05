# ──────────────────────────────────────────────────────────────────────────────
# Provider configurations — root-level only
#
# DECISION: All providers configured exclusively in the root module.
# Why: OpenTofu best practice — child modules declare required_providers for
#      version constraints only, but never contain provider {} blocks.
#      rke2-core is a proper module — no internal provider blocks.
# See: docs/ARCHITECTURE.md — Provider Flow
#
# DECISION: Only two providers: hcloud + rancher2.
# Why: cert-manager, Rancher, NodeDriver, and UIPlugin are ALL deployed via
#      RKE2 cloud-init manifests (HelmChart CRDs + raw YAML placed in
#      /var/lib/rancher/rke2/server/manifests/). This eliminates the need
#      for helm, kubernetes, and kubectl Terraform providers entirely.
#      rke2-core is True Zero-SSH (ADR-002) with no kubeconfig output.
# See: https://docs.rke2.io/helm
# ──────────────────────────────────────────────────────────────────────────────

# ── Hetzner Cloud ────────────────────────────────────────────────────────────
provider "hcloud" {
  token = var.hcloud_api_token
}

# ── Rancher2 (bootstrap mode) ────────────────────────────────────────────────
# DECISION: Single rancher2 provider in bootstrap mode.
# Why: The only rancher2 resource is rancher2_bootstrap (sets admin password,
#      server URL, telemetry). Bootstrap mode only needs the Rancher API URL —
#      no auth token required.
# NOTE: insecure = true because during initial bootstrap, Rancher uses a
#       self-signed cert. The bootstrap mode polls until Rancher is ready.
# DECISION: timeout = "6m" as a reasonable initial bootstrap timeout.
# Why: cert-manager and Rancher are installed by RKE2 HelmController after
#      the initial server boots. This can take several minutes depending on
#      image pulls and CRD readiness. The rancher2 provider retries until
#      the API is accessible or the timeout expires.
provider "rancher2" {
  api_url   = "https://${local.effective_hostname}"
  insecure  = true
  bootstrap = true
  timeout   = "6m"
}

# ── Rancher2 (admin mode — post-bootstrap) ────────────────────────────────────
# DECISION: Second provider alias for resources that need admin auth.
# Why: rancher2 in bootstrap mode only supports rancher2_bootstrap.
#      Post-bootstrap resources (node_driver, settings, etc.) need a token-based
#      provider. The token comes from rancher2_bootstrap.admin.token output.
# NOTE: This provider depends on module.rancher completing first (bootstrap
#       produces the token). OpenTofu resolves this dependency automatically.
provider "rancher2" {
  alias     = "admin"
  api_url   = "https://${local.effective_hostname}"
  token_key = module.rancher.admin_token
  insecure  = true
}
