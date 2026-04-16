# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.7.0] - 2026-04-16

### Added

- **Fleet PSA RBAC pre-creation**: New raw manifest `05-fleet-psa-rbac.yaml` creates `ClusterRole fleet-controller-psa` (verb `updatepsa` on `management.cattle.io/projects`) and `ClusterRoleBinding` for the `fleet-controller` ServiceAccount in `cattle-fleet-system`. Fixes `fleet-agentmanagement` `CrashLoopBackOff` introduced by Rancher 2.14.0 namespace label reconciliation (rancher/rancher#53268, #44402). Validated on rancher-management-dev.abzt.de — 0 restarts after fix.
- **`letsencrypt_environment` variable**: New string variable (default `"production"`, accepts `"production"` or `"staging"`). Renders `letsEncrypt.environment` in the Rancher HelmChart values. Allows DEV/staging deploys to use the Let's Encrypt staging CA and avoid ACME rate limits.
- **Tests**: 3 new unit tests for `letsencrypt_environment` (rejects invalid, accepts production, accepts staging).

### Fixed

- **Test file formatting**: `tofu fmt` cleanup in `tests/variables.tftest.hcl` (alignment of `rancher_replicas` test variables).

## [0.6.0] - 2026-04-08

### Changed

- **Rancher default version**: Bumped from `2.13.3` to `2.14.0`
- **cert-manager default version**: Bumped from `1.17.2` to `1.20.1`
- **Cluster Autoscaler default version**: Bumped from `9.46.6` to `9.56.0`
- **RKE2 default version**: Bumped from `v1.34.4+rke2r1` to `v1.35.3+rke2r1`
- **rke2-core pin**: Updated to `v0.4.0` (RKE2 v1.35.3+rke2r1)

## [0.5.3] - 2026-04-05

### Changed

- **Ingress LB algorithm**: Set `least_connections` instead of default `round_robin` on `hcloud_load_balancer.ingress` for better traffic distribution across control plane nodes

## [0.3.2] - 2026-04-04

### Fixed

- **CIS PSA exemption**: Pre-create `fleet-default` and `cattle-fleet-system` namespaces with `privileged` PodSecurity labels when `enable_cis = true`. Without this, RKE2 CIS profile blocks machine provisioning Jobs and Fleet controller pods in these namespaces (`restricted:latest` rejects pods missing seccompProfile, runAsNonRoot, capabilities drop).

## [0.2.1] - 2026-04-02

### Fixed

- **HA etcd join failure**: Bumped `terraform-hcloud-rke2-core` pin from `995cb16` (v0.2.0) to `0b8c498` (v0.2.2) — includes `node-ip` detection via Hetzner Metadata Service, fixing joining nodes stuck on etcd `MemberAdd` timeout (INV-005)

## [Unreleased-next]

### Added

- **Cluster Autoscaler**: `install_cluster_autoscaler` feature flag + HelmChart CRD manifest for CAPI-based autoscaling (ADR-008)
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
- **rke2-core pin**: Bumped from `995cb16` (v0.2.0) to `ec11660` — includes CIS docs fixes, CI fixes, ip_forward fix+revert, Dependabot CI bumps
- **Roadmap**: Marked mid-term items as complete (HA example, BYO firewall, backup/restore, monitoring)

### Fixed

- **Test suite**: `cluster_name_rejects_hyphens` test was failing (regex updated to allow hyphens in `ce193aa` but test not updated), causing 40 tests to be skipped via fail-fast. Renamed to `cluster_name_accepts_hyphens`, added `cluster_name_rejects_trailing_hyphen`. Result: 57/57 pass

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
