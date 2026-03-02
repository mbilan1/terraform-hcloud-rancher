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
# DECISION: hcloud declared in root even though the rke2-cluster child module
#      has its own hcloud provider configuration internally.
# Why: The root module creates the ingress LB directly. This resource needs
#      the provider configured in the root scope.
#      The rke2-cluster child module uses its OWN hcloud instance internally
#      (anti-pattern inherited from terraform-hcloud-ubuntu-rke2 which was
#      designed as a root module, not a child).
#
# DECISION: AWS provider removed.
# Why: Route53 DNS management was removed. DNS is now the operator's
#      responsibility — point the A-record for rancher_hostname to the
#      ingress_lb_ipv4 output.
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  # DECISION: Align required_version with rke2-core minimum OpenTofu version.
  # Why: rke2-core requires >= 1.8.0 for for_each on module calls and
  #      OpenTofu 1.8+ features used in control_plane submodule.
  required_version = ">= 1.8.0"

  required_providers {
    # ── L3: Infrastructure providers ──────────────────────────────────────────
    # NOTE: rke2-core is a proper module \u2014 it declares hcloud in its own versions.tf
    #       but does NOT configure a provider {} block. Provider configuration
    #       flows down from the root module (standard OpenTofu pattern).
    #       There are no more version conflicts with a second hcloud declaration.

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "= 1.60.1"
    }

    # ── L4: Kubernetes management providers ───────────────────────────────────
    # NOTE: helm and kubernetes providers REMOVED — cert-manager and Rancher are
    #       now deployed via RKE2 HelmChart CRDs placed in cloud-init manifests.
    #       Only kubectl (via Rancher proxy) and rancher2 (bootstrap mode) remain.
    # See: providers.tf for rationale

    kubectl = {
      source  = "alekc/kubectl"
      version = "= 2.1.3"
    }

    # ── Rancher management ────────────────────────────────────────────────────

    rancher2 = {
      source  = "rancher/rancher2"
      version = "= 13.1.4"
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
# | kubectl               | alekc/kubectl           | 2.1.3     | 2026-02-26 |
# | rancher2              | rancher/rancher2        | 13.1.4    | 2026-02-26 |
# | helm (REMOVED)        | hashicorp/helm          | -         | 2026-03-02 |
# | kubernetes (REMOVED)  | hashicorp/kubernetes    | -         | 2026-03-02 |
# ──────────────────────────────────────────────────────────────────────────────
