# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — cert-manager + Rancher Helm + admin bootstrap
#
# DECISION: L4 (Kubernetes addon) concerns are isolated in this module.
# Why: Clear responsibility boundary — rke2-cluster handles infrastructure,
#      this module handles everything that runs INSIDE the cluster:
#      cert-manager for TLS, Rancher for management UI, admin bootstrap.
# See: docs/ARCHITECTURE.md — Phase 2: Rancher Installation
# ──────────────────────────────────────────────────────────────────────────────

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  cert-manager — TLS certificate management                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Install cert-manager via Helm, not via raw manifests.
# Why: Helm manages CRD lifecycle (install + upgrade), namespace creation,
#      and dependency ordering within the chart. The crds.enabled=true flag
#      installs CRDs as part of the chart, which is simpler than a separate
#      kubectl apply of the CRD manifest.
#
# WORKAROUND: count = var.skip_cert_manager ? 0 : 1
# Why: When used together with the rke2-cluster module, cert-manager is already
#      deployed by the rke2 addons module. Deploying it again causes a Helm
#      "cannot re-use a name that is still in use" error. skip_cert_manager=true
#      disables this resource when rke2-cluster already owns cert-manager.
resource "helm_release" "cert_manager" {
  count = var.skip_cert_manager ? 0 : 1
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = var.cert_manager_version

  # NOTE: crds.enabled installs CRDs as part of the Helm release.
  # This means CRDs are managed by Helm and will be upgraded with the chart.
  # DECISION: Use list-of-objects syntax for Helm provider v3.
  # Why: Helm provider v3 changed `set` from block syntax to attribute syntax.
  set = [
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]

  # DECISION: Wait for cert-manager webhook to be ready before proceeding.
  # Why: Rancher creates Certificate resources during installation. If
  #      cert-manager webhook is not ready, the admission webhook rejects
  #      those resources with a connection timeout.
  wait          = true
  wait_for_jobs = true
  timeout       = 300
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Rancher — management server Helm chart                                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  namespace        = "cattle-system"
  create_namespace = true
  version          = var.rancher_version

  # DECISION: Use list-of-objects syntax for Helm provider v3.
  # Why: Helm provider v3 changed `set` from block syntax to attribute syntax.
  # DECISION: Dynamic Helm values based on tls_source.
  # Why: Supports three TLS modes:
  #   - "rancher" (default): Rancher generates its own self-signed CA.
  #     Simplest for development/testing. Browser shows security warning.
  #   - "letsEncrypt": cert-manager ACME. Requires valid email + public DNS.
  #     Best for production with a real domain.
  #   - "secret": Operator provides a pre-existing TLS secret.
  #     For organizations with their own PKI.
  set = concat(
    [
      {
        name  = "hostname"
        value = var.rancher_hostname
      },
      {
        name  = "bootstrapPassword"
        value = var.admin_password
      },
      {
        name  = "ingress.tls.source"
        value = var.tls_source
      },
    ],
    # NOTE: letsEncrypt.email is only added when tls_source = "letsEncrypt".
    # Passing it for other modes is harmless but confusing in Helm values.
    var.tls_source == "letsEncrypt" ? [
      {
        name  = "letsEncrypt.email"
        value = var.letsencrypt_email
      },
    ] : [],
  )

  # WORKAROUND: force_update = true — allows upgrading a release that is in
  # "failed" state. The initial install may be marked failed by Helm if the
  # wait timeout is hit (e.g. nginx webhook not yet ready), even though all
  # pods are actually running. force_update lets the next apply proceed as
  # an upgrade instead of blocking with "cannot re-use a name that is still
  # in use".
  wait          = true
  wait_for_jobs = true
  timeout       = 600
  force_update  = true

  depends_on = [helm_release.cert_manager]
}


# DECISION: Use rancher2_bootstrap instead of manual API calls.
# Why: The rancher2 provider in bootstrap mode handles the initial admin
#      setup (password, server URL, telemetry) through the official API.
#      This is idempotent — if already bootstrapped, the provider reads
#      the existing state.
# NOTE: telemetry opt-out is not supported by the rancher2_bootstrap resource.
#       It can be configured post-deploy via rancher2_setting if needed.
# WORKAROUND: initial_password must match Helm bootstrapPassword.
# Why: The rancher2 provider in bootstrap mode logs in with initial_password
#      (default "admin") before changing it to `password`. But our Helm chart
#      already sets bootstrapPassword to var.admin_password, so the initial
#      login with "admin" fails with Unauthorized. Setting initial_password
#      to the same value as bootstrapPassword allows the login to succeed.
# TODO: Remove if rancher2 provider adds auto-detection of Helm bootstrap password.
resource "rancher2_bootstrap" "admin" {
  initial_password = var.admin_password
  password         = var.admin_password

  depends_on = [helm_release.rancher]
}
