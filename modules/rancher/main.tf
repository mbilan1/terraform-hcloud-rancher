# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — admin bootstrap + Node Driver registration
#
# DECISION: L4 (Kubernetes addon) concerns are isolated in this module.
# Why: Clear responsibility boundary — rke2-cluster handles infrastructure,
#      this module handles Rancher admin bootstrap and Node Driver registration.
# See: docs/ARCHITECTURE.md — Phase 2: Rancher Installation
#
# DECISION: cert-manager and Rancher Helm charts are now deployed via RKE2
#      HelmChart CRDs placed in cloud-init (extra_server_manifests in root main.tf),
#      NOT via the Helm provider in this module.
# Why: rke2-core is True Zero-SSH (ADR-002). It does not output kubeconfig.
#      Without kubeconfig, helm/kubernetes providers cannot authenticate to the
#      K8s API server. RKE2 HelmChart CRDs in
#      /var/lib/rancher/rke2/server/manifests/ are installed automatically by
#      the built-in HelmController — no external API access required.
# See: https://docs.rke2.io/helm
#
# What remains in this module:
#   1. rancher2_bootstrap — polls Rancher URL until ready, sets admin password
#   2. kubectl_manifest — NodeDriver + UIPlugin CRDs via Rancher K8s proxy
# ──────────────────────────────────────────────────────────────────────────────

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Rancher Admin Bootstrap                                                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Use rancher2_bootstrap instead of manual API calls.
# Why: The rancher2 provider in bootstrap mode handles the initial admin
#      setup (password, server URL, telemetry) through the official API.
#      This is idempotent — if already bootstrapped, the provider reads
#      the existing state.
# NOTE: telemetry opt-out is not supported by the rancher2_bootstrap resource.
#       It can be configured post-deploy via rancher2_setting if needed.
# WORKAROUND: initial_password must match HelmChart bootstrapPassword.
# Why: The rancher2 provider in bootstrap mode logs in with initial_password
#      (default "admin") before changing it to `password`. But the HelmChart CRD
#      sets bootstrapPassword to var.admin_password, so the initial login with
#      "admin" fails with Unauthorized. Setting initial_password to the same
#      value as bootstrapPassword allows the login to succeed.
# TODO: Remove if rancher2 provider adds auto-detection of Helm bootstrap password.
#
# NOTE: No explicit depends_on for Helm releases — cert-manager and Rancher are
#       installed by RKE2 HelmController via cloud-init manifests. The rancher2
#       provider's built-in polling mechanism retries until Rancher is accessible.
#       Timeout is configured in the provider block (providers.tf: timeout = "30m").
resource "rancher2_bootstrap" "admin" {
  initial_password = var.admin_password
  password         = var.admin_password
}
