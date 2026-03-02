# ──────────────────────────────────────────────────────────────────────────────
# Provider configurations — root-level only
#
# DECISION: All providers configured exclusively in the root module.
# Why: OpenTofu best practice — child modules declare required_providers for
#      version constraints only, but never contain provider {} blocks.
#      rke2-core is a proper module — no internal provider blocks.
# See: docs/ARCHITECTURE.md — Provider Flow
#
# DECISION: cert-manager and Rancher are deployed via RKE2 HelmChart CRDs
#      placed in cloud-init (extra_server_manifests), NOT via Helm provider.
# Why: rke2-core is True Zero-SSH (ADR-002). There is no kubeconfig output
#      and no SSH access to retrieve it. Direct K8s API access from Terraform
#      is therefore impossible without credentials. HelmChart CRDs in
#      /var/lib/rancher/rke2/server/manifests/ are installed automatically by
#      RKE2's built-in HelmController — no external API access needed.
# See: https://docs.rke2.io/helm
#
# DECISION: kubectl provider points to Rancher proxy (not direct K8s API).
# Why: After Rancher bootstraps, the admin API token is available. The Rancher
#      proxy at /k8s/clusters/local accepts this Bearer token for K8s API
#      operations. This avoids the need for kubeconfig entirely.
# ──────────────────────────────────────────────────────────────────────────────

# ── Hetzner Cloud ────────────────────────────────────────────────────────────
provider "hcloud" {
  token = var.hcloud_api_token
}

# ── kubectl (raw YAML manifest application via Rancher proxy) ────────────────
# DECISION: Use Rancher's K8s proxy endpoint for kubectl operations.
# Why: NodeDriver and UIPlugin CRDs are created AFTER rancher2_bootstrap
#      completes. At that point, the admin token is available. The Rancher
#      proxy at /k8s/clusters/local authenticates via Bearer token — no
#      kubeconfig or client certificates needed.
# NOTE: Provider config references module.rancher.rancher_admin_token which
#       is only known after rancher2_bootstrap. OpenTofu defers provider
#       initialization until kubectl_manifest resources are evaluated.
provider "kubectl" {
  host             = "https://${local.effective_hostname}/k8s/clusters/local"
  insecure         = true
  load_config_file = false
  token            = module.rancher.admin_token
}

# ── Rancher2 (bootstrap mode) ────────────────────────────────────────────────
# DECISION: Single rancher2 provider in bootstrap mode.
# Why: For MVP, the only rancher2 resource is rancher2_bootstrap (sets admin
#      password, server URL, telemetry). Bootstrap mode only needs the Rancher
#      API URL — no auth token required.
# NOTE: insecure = true because during initial bootstrap, Rancher uses a
#       self-signed cert. The bootstrap mode polls until Rancher is ready.
# DECISION: timeout = "30m" to accommodate HelmChart CRD installation time.
# Why: cert-manager and Rancher are installed by RKE2 HelmController after
#      the initial server boots. This can take 10–20 minutes depending on
#      image pulls and CRD readiness. The rancher2 provider retries until
#      the API is accessible or the timeout expires.
provider "rancher2" {
  api_url   = "https://${local.effective_hostname}"
  insecure  = true
  bootstrap = true
  timeout   = "30m"
}
