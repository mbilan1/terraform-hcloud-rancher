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
  # DECISION: Require >= 1.7.0 for alignment with terraform-hcloud-ubuntu-rke2.
  # Why: The rke2 module uses `removed {}` blocks which require >= 1.7.0.
  #      Using the same floor version ensures compatibility when used as a child.
  required_version = ">= 1.7.0"

  required_providers {
    # ── L3: Infrastructure providers ──────────────────────────────────────────
    # NOTE: Version MUST match terraform-hcloud-ubuntu-rke2 to avoid conflicts
    #       when the rke2 module is used as a child (both declare hcloud).

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "= 1.60.1"
    }

    # ── L4: Kubernetes management providers ───────────────────────────────────
    # NOTE: These are NOT used by terraform-hcloud-ubuntu-rke2.
    #       They are new to this module for cert-manager, Rancher, and CRD install.

    helm = {
      source  = "hashicorp/helm"
      version = "= 3.1.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.0.1"
    }

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
# | helm                  | hashicorp/helm          | 3.1.1     | 2026-02-26 |
# | kubernetes            | hashicorp/kubernetes    | 3.0.1     | 2026-02-26 |
# | kubectl               | alekc/kubectl           | 2.1.3     | 2026-02-26 |
# | rancher2              | rancher/rancher2        | 13.1.4    | 2026-02-26 |
# ──────────────────────────────────────────────────────────────────────────────
