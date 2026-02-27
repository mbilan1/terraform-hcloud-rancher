# ──────────────────────────────────────────────────────────────────────────────
# Rancher child module — Hetzner Node Driver + UI Extension
#
# DECISION: Install NodeDriver via kubectl_manifest, not rancher2_node_driver.
# Why: rancher2_node_driver resource may not support all required fields
#      (whitelistDomains, addCloudCredential annotation). Raw manifest gives
#      full control over the CRD spec and metadata annotations.
# See: docs/ARCHITECTURE.md — Phase 3: Hetzner Integration
#
# DECISION: Conditional installation via count = var.install_hetzner_driver.
# Why: Operators who manage the Node Driver separately (e.g. via Fleet, or
#      upgrading independently) can set install_hetzner_driver = false.
# ──────────────────────────────────────────────────────────────────────────────

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  NodeDriver CRD — registers zsys-studio binary as a Rancher node driver   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "kubectl_manifest" "hetzner_node_driver" {
  count = var.install_hetzner_driver ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "management.cattle.io/v3"
    kind       = "NodeDriver"
    metadata = {
      name = "hetzner"
      annotations = {
        # NOTE: This annotation tells Rancher which credential field to populate
        # when the user adds Cloud Credentials for Hetzner.
        "privateCredentialFields" = "apiToken"
      }
    }
    spec = {
      active             = true
      addCloudCredential = true
      displayName        = "Hetzner"
      # DECISION: Point to the upstream zsys-studio release artifacts.
      # Why: Using GitHub release URLs ensures integrity (checksummed by GoReleaser)
      #      and avoids maintaining a separate artifact mirror.
      url              = "https://github.com/zsys-studio/rancher-hetzner-cluster-provider/releases/download/v${var.hetzner_driver_version}/docker-machine-driver-hetzner_${var.hetzner_driver_version}_linux_amd64.tar.gz"
      whitelistDomains = ["api.hetzner.cloud"]
    }
  })

  depends_on = [rancher2_bootstrap.admin]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UIPlugin CRD — installs Hetzner UI extension for Rancher dashboard       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Install the UI Extension via UIPlugin CRD (catalog.cattle.io/v1).
# Why: Alternative is manual installation through Rancher UI → Extensions.
#      The CRD approach is fully automated and idempotent within tofu apply.
# See: docs/ARCHITECTURE.md — Compromise Log #6
resource "kubectl_manifest" "hetzner_ui_extension" {
  count = var.install_hetzner_driver ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "catalog.cattle.io/v1"
    kind       = "UIPlugin"
    metadata = {
      name      = "hetzner-node-driver"
      namespace = "cattle-ui-plugin-system"
    }
    spec = {
      plugin = {
        name    = "hetzner-node-driver"
        version = var.hetzner_driver_version
        # NOTE: This points to the pre-built UI extension tarball from the same
        # zsys-studio release. The extension provides cloud-credential and
        # machine-config forms in the Rancher dashboard.
        endpoint = "https://github.com/zsys-studio/rancher-hetzner-cluster-provider/releases/download/v${var.hetzner_driver_version}/hetzner-node-driver-${var.hetzner_driver_version}.tgz"
        noCache  = false
        noAuth   = true
      }
    }
  })

  depends_on = [rancher2_bootstrap.admin]
}
