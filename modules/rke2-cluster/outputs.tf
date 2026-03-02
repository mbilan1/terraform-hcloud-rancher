# ──────────────────────────────────────────────────────────────────────────────
# rke2-cluster child module — outputs
#
# DECISION: Expose only the L3 outputs produced by rke2-core.
# Why: rke2-core is Zero-SSH and pure L3 — it does not produce kubeconfig,
#      TLS certificates, or LB IPs (LBs are the consumer's responsibility, ADR-003).
#      The parent module needs:
#        - network_id: ingress LB network attachment
#        - initial_master_ipv4: K8s API endpoint for L4 providers
#        - cluster_ready: explicit dependency anchor for module.rancher
# See: /home/mbilan/workdir/rke2-hetzner-architecture/decisions/adr-003-dual-load-balancer.md
# ──────────────────────────────────────────────────────────────────────────────

output "network_id" {
  description = "Hetzner Cloud private network ID (for ingress LB attachment)"
  value       = module.cluster.network_id
}

output "initial_master_ipv4" {
  description = "Public IPv4 of the initial master (K8s API endpoint host)"
  value       = module.cluster.initial_master_ipv4
}

output "cluster_ready" {
  description = "True when the K8s API server is reachable on port 6443"
  value       = module.cluster.cluster_ready
}
