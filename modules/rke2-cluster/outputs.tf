# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — outputs
#
# DECISION: Expose only outputs needed by the parent module and sibling modules.
# Why: The rke2 module has ~15 outputs. The parent needs:
#      - Kubeconfig credentials for L4 provider configuration
#      - Network ID for ingress LB attachment
#      - LB IP for DNS record
# ──────────────────────────────────────────────────────────────────────────────

# ── Kubeconfig credentials (for L4 provider configuration) ───────────────────

output "cluster_host" {
  description = "Kubernetes API server endpoint URL"
  value       = module.cluster.cluster_host
}

output "cluster_ca" {
  description = "Cluster CA certificate (PEM-encoded)"
  value       = module.cluster.cluster_ca
  sensitive   = true
}

output "client_cert" {
  description = "Client certificate for cluster authentication (PEM-encoded)"
  value       = module.cluster.client_cert
  sensitive   = true
}

output "client_key" {
  description = "Client private key for cluster authentication (PEM-encoded)"
  value       = module.cluster.client_key
  sensitive   = true
}

output "kube_config" {
  description = "Full kubeconfig file content"
  value       = module.cluster.kube_config
  sensitive   = true
}

# ── Infrastructure references (for ingress LB, DNS) ─────────────────────────

output "network_id" {
  description = "Hetzner Cloud private network ID"
  value       = module.cluster.management_network_id
}

output "control_plane_lb_ipv4" {
  description = "IPv4 address of the control-plane load balancer"
  value       = module.cluster.control_plane_lb_ipv4
}
