# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — admin bootstrap only
#
# DECISION: L4 (Kubernetes addon) concerns are isolated in this module.
# Why: Clear responsibility boundary — rke2-cluster handles infrastructure,
#      this module handles Rancher admin bootstrap.
# See: docs/ARCHITECTURE.md — Phase 2: Rancher Installation
#
# DECISION: cert-manager, Rancher, NodeDriver, and UIPlugin are ALL deployed
#      via RKE2 cloud-init manifests (HelmChart CRDs + raw YAML) generated
#      in root main.tf and passed to rke2-cluster via extra_server_manifests.
# Why: rke2-core is True Zero-SSH (ADR-002). It does not output kubeconfig.
#      Without kubeconfig, helm/kubernetes/kubectl providers cannot authenticate.
#      RKE2's HelmController + deploy controller handle installation from
#      /var/lib/rancher/rke2/server/manifests/ — no external API access required.
#      This eliminates ALL K8s providers — only hcloud + rancher2 remain.
# See: https://docs.rke2.io/helm
#
# What remains in this module:
#   1. rancher2_bootstrap — polls Rancher URL until ready, sets admin password
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
