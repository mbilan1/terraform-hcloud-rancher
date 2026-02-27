# ──────────────────────────────────────────────────────────────────────────────
# Root module outputs — rewired from child modules
#
# DECISION: Outputs grouped by concern: Rancher, Infrastructure, Cluster.
# Why: Consumers need different outputs for different tasks:
#      - Rancher URL + token for downstream cluster provisioning
#      - Kubeconfig for direct cluster management
#      - LB IPs for DNS configuration
# ──────────────────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════════
#  Rancher
# ═══════════════════════════════════════════════════════════════════════════════

output "rancher_url" {
  description = "Rancher UI URL (HTTPS)"
  value       = module.rancher.rancher_url
}

output "rancher_admin_token" {
  description = "Rancher admin API token for initial configuration. Treat as a secret."
  value       = module.rancher.admin_token
  sensitive   = true
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Infrastructure
# ═══════════════════════════════════════════════════════════════════════════════

output "control_plane_lb_ipv4" {
  description = "IPv4 address of the control-plane load balancer (K8s API, registration)"
  value       = module.rke2_cluster.control_plane_lb_ipv4
}

output "ingress_lb_ipv4" {
  description = "IPv4 address of the ingress load balancer (Rancher UI)"
  value       = hcloud_load_balancer.ingress.ipv4
}

output "network_id" {
  description = "Hetzner Cloud private network ID (for reference)"
  value       = module.rke2_cluster.network_id
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Cluster credentials
# ═══════════════════════════════════════════════════════════════════════════════

output "kube_config" {
  description = "Full kubeconfig file content for direct cluster access"
  value       = module.rke2_cluster.kube_config
  sensitive   = true
}

output "cluster_host" {
  description = "Kubernetes API server endpoint URL"
  value       = module.rke2_cluster.cluster_host
}

output "cluster_ca" {
  description = "Cluster CA certificate (PEM-encoded)"
  value       = module.rke2_cluster.cluster_ca
  sensitive   = true
}

output "client_cert" {
  description = "Client certificate for cluster authentication (PEM-encoded)"
  value       = module.rke2_cluster.client_cert
  sensitive   = true
}

output "client_key" {
  description = "Client private key for cluster authentication (PEM-encoded)"
  value       = module.rke2_cluster.client_key
  sensitive   = true
}
