# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **CIS hardening**: `enable_cis` variable — single feature flag for RKE2 CIS 1.23 profile, passthrough to rke2-core (ADR-011)
- **PSA exemption**: Pre-creates `cattle-system` namespace with PodSecurity `privileged` labels when CIS enabled — prevents Rancher pod admission failures
- **YAML-safe passwords**: `random_password` uses `override_special = "-_."` to avoid YAML parsing breakage in cloud-init HelmChart values
- **CI/CD**: Gate 0 (lint + SAST) and Gate 1 (unit tests) GitHub Actions workflows (ADR-010)
- **examples/complete/**: HA 3-node management cluster with BYO firewall, Let's Encrypt TLS, Packer image support, and conditional etcd S3 backup
- **Operations Guide**: Backup & restore section (etcd snapshots, S3 backup, restore procedure, Rancher Backup Operator)
- **Operations Guide**: Monitoring & observability section (Rancher Monitoring, resource sizing, external integration)
- **Operations Guide**: Audit logging section (RKE2 audit policy configuration, log forwarding)
- **Operations Guide**: Network policies section (default-deny baseline, Canal/Calico enforcement)

### Changed

- **Module source**: `terraform-hcloud-rke2-core` switched from local path to git reference `v0.1.0`
- **Roadmap**: Marked mid-term items as complete (HA example, BYO firewall, backup/restore, monitoring)

## [0.1.0] - 2026-03-06

### Added

- **Management cluster**: Single-node or HA RKE2 cluster on Hetzner Cloud via `terraform-hcloud-rke2-core`
- **Rancher installation**: cert-manager + Rancher Helm chart deployed via cloud-init HelmChart CRDs
- **Admin bootstrap**: `rancher2_bootstrap` resource sets admin password and server URL
- **TLS sources**: Self-signed (Rancher CA), Let's Encrypt, or user-provided certificate
- **Hetzner Node Driver**: [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) v0.9.0 installed via cloud-init raw manifest (`metadata.name: hetzner`)
- **Dual Load Balancer**: Control-plane LB (ports 6443, 9345) + Ingress LB (ports 80, 443)
- **BYO ingress LB**: `create_ingress_lb = false` + `existing_ingress_lb_ipv4` for BYO pattern
- **sslip.io auto-hostname**: Auto-generates `rancher.<LB_IP>.sslip.io` — zero DNS setup
- **Packer baked image support**: `hcloud_image` variable wired through full module chain
- **BYO Firewall passthrough**: `firewall_ids` variable wired through full module chain (ADR-006)
- **rancher2 provider**: Bootstrap mode for admin password setup
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
- **NodeDriver**: Deployed via cloud-init raw manifest with explicit `metadata.name: hetzner` (avoids `rancher2_node_driver` which generates `nd-XXXXX` names incompatible with Rancher provisioning)
- **Location default**: Switched examples to `hel1` (cpx42 availability)

### Removed

- Route53 DNS integration (BYO DNS pattern instead)
- Firewall variables (BYO Firewall per ADR-006)
- Dead `install_hetzner_driver` variable
