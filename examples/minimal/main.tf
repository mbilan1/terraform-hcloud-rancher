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
#   1. The rancher_hostname output shows the auto-generated sslip.io URL
#      (or your custom hostname if rancher_hostname is set)
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
  # DECISION: Hostname left empty for auto-generation via sslip.io.
  # Why: Auto-generates "rancher.<LB-IP>.sslip.io" from the ingress LB IP,
  #      enabling single `tofu apply` without pre-existing DNS.
  #      For production, set rancher_hostname to a real FQDN.
  # NOTE: admin_password left empty — auto-generated. See rancher_admin_password output.

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
  node_location             = "hel1"

  # ── RKE2 config ──────────────────────────────────────────────────────────────
  rke2_config = <<-EOT
    etcd-snapshot-schedule-cron: "0 */6 * * *"
    etcd-snapshot-retention: 10
  EOT

  # ── CIS hardening (opt-in) ───────────────────────────────────────────────
  # Set enable_cis = true for RKE2 CIS profile (etcd user, kernel params,
  # PSA restricted). Works with both stock ubuntu-24.04 and Packer-built snapshots.
  # For full host-level CIS L1, additionally use a Packer snapshot built with
  # enable_cis_hardening=true (see packer-hcloud-rke2 repo).
  # enable_cis = true

  # ── Firewall (BYO) ─────────────────────────────────────────────────────────
  firewall_ids = [hcloud_firewall.management.id]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Firewall — management cluster (BYO per ADR-006)                           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Firewall created in the example, not in the module.
# Why: ADR-006 — firewalls are BYO. Hetzner firewalls are account-level
#      singletons with per-server attachment. The module accepts firewall_ids;
#      consumers create and manage firewall rules externally.
# NOTE: Hetzner firewalls only filter PUBLIC interface traffic. Private network
#       traffic (used by LBs with use_private_ip=true) bypasses firewalls entirely.
resource "hcloud_firewall" "management" {
  name = "rancher-mgmt"

  labels = {
    "cluster-name" = "rancher"
    "managed-by"   = "opentofu"
    "role"         = "management"
  }

  # ICMP — allow ping for diagnostics
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # K8s API — needed for kubectl access (no CP LB in single-node setup)
  # WARNING: This opens the K8s API to the entire internet for dev/test simplicity.
  # For production, restrict source_ips to your operator IP(s) or VPN CIDR,
  # e.g. source_ips = ["203.0.113.10/32"].
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # NOTE: Ports 80/443 are NOT opened on the server's public IP.
  # Why: The ingress LB routes to servers via private network (use_private_ip=true).
  #      Private network traffic bypasses Hetzner firewalls entirely.
  #      Only the LB's public IP needs to be reachable on 80/443.
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "rancher_url" {
  description = "Rancher UI URL"
  value       = module.rancher_management.rancher_url
}

output "rancher_hostname" {
  description = "Effective Rancher hostname (auto-generated from LB IP if not provided)"
  value       = module.rancher_management.rancher_hostname
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

output "rancher_admin_password" {
  description = "Rancher admin password (auto-generated)"
  value       = module.rancher_management.rancher_admin_password
  sensitive   = true
}
