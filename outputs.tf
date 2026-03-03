# ──────────────────────────────────────────────────────────────────────────────
# Root module outputs
#
# DECISION: Outputs grouped by concern: Rancher, Infrastructure.
# Why: Consumers need different outputs for different tasks:
#      - Rancher URL + token for downstream cluster provisioning via UI
#      - LB IPs for DNS configuration
#      - network_id for cluster template pre-fill (ADR-005: shared VLAN)
# NOTE: Kubeconfig outputs removed — kubeconfig is retrieved from Rancher UI
#       post-bootstrap. This is a deliberate design decision (ADR-002 Zero-SSH).
#       rke2-core does not output kubeconfig by design.
# ──────────────────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════════
#  Rancher
# ═══════════════════════════════════════════════════════════════════════════════

output "rancher_url" {
  description = "Rancher UI URL (HTTPS)"
  value       = "https://${local.effective_hostname}"
}

output "rancher_hostname" {
  description = "Effective Rancher hostname (auto-generated from LB IP if not provided)"
  value       = local.effective_hostname
}

output "rancher_admin_token" {
  description = "Rancher admin API token for initial configuration. Treat as a secret."
  value       = module.rancher.admin_token
  sensitive   = true
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Infrastructure
# ═══════════════════════════════════════════════════════════════════════════════

output "initial_master_ipv4" {
  description = "Public IPv4 of the initial master (control-plane node that bootstrapped the cluster)"
  value       = module.rke2_cluster.initial_master_ipv4
}

output "ingress_lb_ipv4" {
  description = "IPv4 address of the ingress load balancer (Rancher UI). Point DNS A record here."
  value       = local.effective_lb_ipv4
}

output "network_id" {
  description = "Hetzner Cloud private network ID (for cluster template pre-fill — ADR-005)"
  value       = module.rke2_cluster.network_id
}
