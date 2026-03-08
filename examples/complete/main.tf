# ──────────────────────────────────────────────────────────────────────────────
# Complete Example — HA Rancher management cluster on Hetzner Cloud
#
# This example demonstrates a production-ready deployment:
# - 3-node HA control plane (etcd quorum)
# - BYO firewall with restrictive rules (ADR-006)
# - Let's Encrypt TLS via cert-manager ACME
# - Packer baked CIS-hardened image (ADR-009)
# - etcd S3 backup to Hetzner Object Storage
# - Custom hostname (real DNS required)
#
# Prerequisites:
#   1. A real domain with DNS access (for Let's Encrypt)
#   2. A Packer snapshot ID (from packer-hcloud-rke2)
#   3. Hetzner Object Storage credentials (for etcd backup)
#
# Usage:
#   export TF_VAR_hcloud_api_token="your-hetzner-api-token"
#   export TF_VAR_admin_password="your-rancher-admin-password"
#   tofu init
#   tofu plan
#   tofu apply
#
# After apply:
#   1. Create DNS A record: rancher.example.com → ingress_lb_ipv4 output
#   2. Wait for Let's Encrypt certificate issuance (~2 min)
#   3. Open https://rancher.example.com
#   4. Log in with admin / $TF_VAR_admin_password
#   5. Create Cloud Credentials for downstream Hetzner projects
#   6. Provision downstream clusters via Rancher UI
# ──────────────────────────────────────────────────────────────────────────────

module "rancher_management" {
  source = "../.."

  # ── Credentials ──────────────────────────────────────────────────────────────
  hcloud_api_token = var.hcloud_api_token

  # ── Rancher configuration ───────────────────────────────────────────────────
  rancher_hostname = var.rancher_hostname
  admin_password   = var.admin_password

  # DECISION: Let's Encrypt for production.
  # Why: Real TLS certificate, no browser warnings, trusted by all clients.
  # Requires: DNS A record pointing rancher_hostname → ingress LB IP.
  tls_source        = "letsEncrypt"
  letsencrypt_email = var.letsencrypt_email

  # ── HA infrastructure ───────────────────────────────────────────────────────
  cluster_name              = "rancher"
  management_node_count     = 3
  control_plane_server_type = "cx43"
  node_location             = "hel1"

  # DECISION: Use Packer baked CIS-hardened image.
  # Why: CIS Level 1 prerequisites (etcd user, kernel modules, sysctl params)
  #      must exist before RKE2 starts. Packer snapshot bakes them in.
  # See: packer-hcloud-rke2 repo, ADR-009: Golden Image Delivery
  hcloud_image = var.hcloud_image

  # ── Firewall (BYO per ADR-006) ─────────────────────────────────────────────
  firewall_ids = [hcloud_firewall.management.id]

  # ── etcd backup ─────────────────────────────────────────────────────────────
  # DECISION: Local etcd snapshots every 6 hours as baseline.
  # Why: S3 backup requires external credentials. Local snapshots provide
  #      baseline protection. For S3, append etcd-s3 config below.
  rke2_config = <<-EOT
    etcd-snapshot-schedule-cron: "0 */6 * * *"
    etcd-snapshot-retention: 10
    %{if var.etcd_s3_endpoint != ""}
    etcd-s3: true
    etcd-s3-endpoint: "${var.etcd_s3_endpoint}"
    etcd-s3-bucket: "${var.etcd_s3_bucket}"
    etcd-s3-access-key: "${var.etcd_s3_access_key}"
    etcd-s3-secret-key: "${var.etcd_s3_secret_key}"
    etcd-s3-region: "${var.etcd_s3_region}"
    %{endif}
  EOT
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Firewall — production management cluster (BYO per ADR-006)                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "hcloud_firewall" "management" {
  name = "rancher-mgmt-ha"

  labels = {
    "cluster-name" = "rancher"
    "managed-by"   = "opentofu"
    "role"         = "management"
    "environment"  = "production"
  }

  # ICMP — diagnostics
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # K8s API — restrict to operator networks only
  # DECISION: Do NOT open 6443 to 0.0.0.0/0 in production.
  # Why: The K8s API is the highest-value attack surface. Restrict to known
  #      operator IPs or VPN CIDRs. For initial setup, temporarily open wider
  #      and lock down after deploying VPN or bastion.
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = var.operator_cidrs
  }

  # RKE2 node-to-node — etcd peer, kubelet, RKE2 supervisor
  # NOTE: In HA mode, nodes must communicate on these ports.
  # Hetzner private network traffic bypasses firewalls, so these rules
  # are only needed if nodes use public IPs for inter-node communication.
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "9345"
    source_ips = var.operator_cidrs
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
  description = "Effective Rancher hostname"
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

output "network_id" {
  description = "Hetzner private network ID — use for downstream cluster templates (ADR-005)"
  value       = module.rancher_management.network_id
}

output "rancher_admin_token" {
  description = "Rancher admin API token (sensitive)"
  value       = module.rancher_management.rancher_admin_token
  sensitive   = true
}

output "rancher_admin_password" {
  description = "Rancher admin password (sensitive)"
  value       = module.rancher_management.rancher_admin_password
  sensitive   = true
}
