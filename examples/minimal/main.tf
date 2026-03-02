# ──────────────────────────────────────────────────────────────────────────────
# Minimal example — single-node Rancher management cluster on Hetzner Cloud
#
# Usage:
#   export TF_VAR_hcloud_api_token="your-hetzner-api-token"
#   export TF_VAR_admin_password="your-rancher-admin-password"
#   tofu init
#   tofu plan
#   tofu apply
#
# After apply:
#   1. Point your DNS to the ingress_lb_ipv4 output
#   2. Open the rancher_url output in a browser
#   3. Log in with admin / $TF_VAR_admin_password
#   4. Create Cloud Credentials for downstream Hetzner projects
#   5. Provision downstream RKE2 clusters via Rancher UI
#
# See: docs/ARCHITECTURE.md — Downstream Cluster Provisioning
# ──────────────────────────────────────────────────────────────────────────────

module "rancher_management" {
  source = "../.."

  # ── Credentials ──────────────────────────────────────────────────────────────
  hcloud_api_token = var.hcloud_api_token

  # ── Rancher configuration ───────────────────────────────────────────────────
  rancher_hostname = var.rancher_hostname
  admin_password   = var.admin_password

  # DECISION: Use self-signed TLS for minimal example.
  # Why: Does not require a real domain, valid email, or public DNS.
  #      For production, set tls_source = "letsEncrypt" with a valid email.
  tls_source = "rancher"

  # ── Infrastructure defaults ─────────────────────────────────────────────────
  # WORKAROUND: Using cpx42 (AMD next-gen, 8 vCPU, 16 GB) instead of cx43 (Intel).
  # Why: cx43 and cpx41 are out of stock / discontinued in EU locations.
  #      cpx42 has equivalent specs (8 cores, 16 GB) and is the current AMD offering.
  # TODO: Revert to cx43 when Intel stock stabilizes.
  cluster_name              = "rancher"
  management_node_count     = 1
  control_plane_server_type = "cpx42"
  node_location             = "nbg1"
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "rancher_url" {
  description = "Rancher UI URL"
  value       = module.rancher_management.rancher_url
}

output "ingress_lb_ipv4" {
  description = "Point your DNS A-record for rancher_hostname to this IP"
  value       = module.rancher_management.ingress_lb_ipv4
}

output "initial_master_ipv4" {
  description = "Public IP of the initial master node"
  value       = module.rancher_management.initial_master_ipv4
}

output "rancher_admin_token" {
  description = "Rancher admin API token (sensitive)"
  value       = module.rancher_management.rancher_admin_token
  sensitive   = true
}
