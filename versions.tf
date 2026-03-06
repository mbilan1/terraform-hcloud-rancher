# ──────────────────────────────────────────────────────────────────────────────
# Provider version constraints — central registry
#
# DECISION: Exact version pins for reproducible deployments.
# Why: Pessimistic constraints (~>) can silently pick up patch releases that
#      introduce provider bugs. Exact pins ensure every apply uses the same
#      binary. Cost: manual version bumps.
#      Acceptable for a module that provisions production infrastructure.
# See: docs/ARCHITECTURE.md — Provider Flow
#
# DECISION: Only two providers: hcloud + rancher2.
# Why: cert-manager, Rancher, NodeDriver, and UIPlugin are all deployed via
#      RKE2 cloud-init manifests (HelmChart CRDs + raw YAML). This eliminates
#      the need for helm, kubernetes, and kubectl providers entirely.
#      The only L4 provider needed is rancher2 for the initial admin bootstrap.
# See: providers.tf for rationale
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  # DECISION: Align required_version with rke2-core minimum OpenTofu version.
  # Why: rke2-core requires >= 1.8.0 for for_each on module calls and
  #      OpenTofu 1.8+ features used in control_plane submodule.
  required_version = ">= 1.8.0"

  required_providers {
    # ── L3: Infrastructure provider ───────────────────────────────────────────
    # NOTE: rke2-core is a proper module — it declares hcloud in its own versions.tf
    #       but does NOT configure a provider {} block. Provider configuration
    #       flows down from the root module (standard OpenTofu pattern).

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "= 1.60.1"
    }

    # ── L4: Rancher management provider ───────────────────────────────────────
    # NOTE: Used only for rancher2_bootstrap (initial admin password + token).
    #       Bootstrap mode — no auth token required, just polls the Rancher URL.

    rancher2 = {
      source  = "rancher/rancher2"
      version = "= 13.1.4"
    }

    # ── Utility: random_password for auto-generated admin password ────────────
    # NOTE: Also a transitive dependency via rke2-core (cluster token).

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# VERSION REGISTRY
#
# Keep this table in sync with the required_providers block above.
# Run `tofu init -upgrade` only with explicit approval.
#
# | Provider              | Source                  | Version   | Updated    |
# |-----------------------|-------------------------|-----------|------------|
# | hcloud                | hetznercloud/hcloud     | 1.60.1    | 2026-02-26 |
# | rancher2              | rancher/rancher2        | 13.1.4    | 2026-02-26 |
# | kubectl (REMOVED)     | alekc/kubectl           | -         | 2026-03-04 |
# | helm (REMOVED)        | hashicorp/helm          | -         | 2026-03-02 |
# | kubernetes (REMOVED)  | hashicorp/kubernetes    | -         | 2026-03-02 |
# ──────────────────────────────────────────────────────────────────────────────
