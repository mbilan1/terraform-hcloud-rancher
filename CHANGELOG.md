# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-03-05

### Added

- **Management cluster**: Single-node or HA RKE2 cluster on Hetzner Cloud via `terraform-hcloud-rke2-core`
- **Rancher installation**: cert-manager + Rancher Helm chart deployed via cloud-init HelmChart CRDs
- **Admin bootstrap**: `rancher2_bootstrap` resource sets admin password and server URL
- **TLS sources**: Self-signed (Rancher CA), Let's Encrypt, or user-provided certificate
- **Hetzner Node Driver**: [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) v0.8.0 installed via `rancher2_node_driver`
- **Dual Load Balancer**: Control-plane LB (ports 6443, 9345) + Ingress LB (ports 80, 443)
- **BYO ingress LB**: `create_ingress_lb = false` + `existing_ingress_lb_ipv4` for BYO pattern
- **sslip.io auto-hostname**: Auto-generates `rancher.<LB_IP>.sslip.io` — zero DNS setup
- **Packer baked image support**: `hcloud_image` variable wired through full module chain
- **BYO Firewall passthrough**: `firewall_ids` variable wired through full module chain (ADR-006)
- **Dual rancher2 provider**: Bootstrap mode + admin alias for post-bootstrap resources
- **rke2_config passthrough**: `rke2_config` variable with etcd snapshot defaults (6h schedule, 10 retention)
- **Secrets encryption**: RKE2 secrets encryption at rest enabled by default
- **Guardrails**: Preflight `check {}` blocks for variable validation
- **Tests**: 35 unit tests (variable validation + guardrails) via `tofu test`
- **Examples**: `examples/minimal/` — single-node management cluster
- **Documentation**: `docs/ARCHITECTURE.md`, `README.md`, `AGENTS.md`
- **REUSE compliance**: SPDX licensing metadata via `REUSE.toml`

### Changed

- **RKE2 default**: Bumped to v1.34.4+rke2r1
- **L3 base**: Migrated from `terraform-hcloud-ubuntu-rke2` (v1) to `terraform-hcloud-rke2-core` (v2)
- **Provider model**: Reduced to 2 providers only (hcloud + rancher2) — eliminated helm/kubernetes/kubectl
- **NodeDriver**: Moved from cloud-init CRD to `rancher2_node_driver` resource (crash-loop fix)
- **Location default**: Switched examples to `hel1` (cpx42 availability)

### Removed

- Route53 DNS integration (BYO DNS pattern instead)
- Firewall variables (BYO Firewall per ADR-006)
- Dead `install_hetzner_driver` variable
