# Deep Code Review: terraform-hcloud-rancher

**Date**: 2026-03-07
**Reviewer**: Automated Deep Review (Claude)
**Overall Score**: 8.5/10

## Executive Summary

Well-architected, production-ready Terraform module for deploying Rancher management clusters on Hetzner Cloud. Strong security practices (zero-SSH, sensitive marking, comprehensive validation). Issues are primarily documentation gaps and validation edge cases.

**Total Issues: 12** — 2 Critical, 3 High, 4 Medium, 3 Low

---

## Critical Issues

### 1. Missing Input Variable: `install_hetzner_driver`

- **Files**: `variables.tf` (missing), `README.md:168` (documented)
- **Impact**: README documents `install_hetzner_driver` (bool, default true), but the variable doesn't exist in code. Hetzner Node Driver is unconditionally deployed via cloud-init manifest `02-hetzner-node-driver.yaml`.
- **Fix**: Either implement the variable with conditional logic, or remove it from README.

### 2. RKE2 Version Mismatch Across Documentation

- **Files**: `variables.tf:294` → `v1.34.4+rke2r1`, `README.md:174` → `v1.32.2+rke2r1`, `modules/rke2-cluster/README.md:40` → `v1.32.2+rke2r1`
- **Impact**: Users reading docs expect v1.32, but v1.34 is actually deployed. These are different minor versions with potential incompatibilities.
- **Fix**: Regenerate terraform-docs to align all documentation with actual defaults.

---

## High Severity Issues

### 3. Subnet Not Validated Against Network CIDR

- **File**: `variables.tf:211-221`
- **Impact**: `subnet_address` has CIDR syntax check but no validation it's contained within `hcloud_network_cidr`. Users can specify `192.168.1.0/24` subnet in a `10.0.0.0/16` network — passes plan, fails at apply.
- **Fix**: Add guardrail check in `guardrails.tf`.

### 4. Overly Permissive Firewall in Example

- **File**: `examples/minimal/main.tf:81-86`
- **Impact**: K8s API (6443) open to `0.0.0.0/0` and `::/0`. Bad security example for users to copy.
- **Fix**: Restrict to operator IP or add `allowed_cidr` variable with documentation.

### 5. LB Health Check Inadequate During Rancher Startup

- **File**: `main.tf:281-305`
- **Impact**: Health checks mark backend unhealthy in ~20-30s, but Rancher bootstrap takes up to 6 minutes. Users experience 502 errors during normal startup.
- **Fix**: Increase retries or document the startup window.

---

## Medium Severity Issues

### 6. Admin Password in OpenTofu State (Acknowledged)

- **File**: `main.tf:19-41`
- Admin password appears in plain text in state via cloud-init user_data. Documented compromise, but no mitigation guidance.
- **Fix**: Document state encryption requirement and post-deploy password rotation.

### 7. Undocumented `rke2_config` Default Behavior

- **File**: `variables.tf:275-288`
- Default enables etcd snapshots every 6 hours (10 retention) without explicit opt-in. May cause unexpected disk usage.
- **Fix**: Document default behavior and disk implications.

### 8. Missing Version Compatibility Matrix

- **File**: `variables.tf:39-49, 290-300`
- No documented compatibility matrix for Rancher/RKE2/cert-manager version combinations.
- **Fix**: Add tested version combinations to ARCHITECTURE.md.

### 9. Guardrails: Let's Encrypt Validation Gap

- **File**: `guardrails.tf`
- Let's Encrypt email check exists, but no validation that the domain resolves or that port 80 is accessible for ACME challenge.
- **Fix**: Document ACME prerequisites prominently.

---

## Low Severity Issues

### 10. Indefinite Cleanup TODOs

- **Files**: `moved.tf:8`, `providers.tf:51-52`
- `TODO: Remove after all known deployments have migrated` — no actionable deadline.
- **Fix**: Add date-based or version-based cleanup criteria.

### 11. Port 80 Health Check Assumptions Undocumented

- **File**: `main.tf:281-288`
- Assumes ingress controller is healthy before Rancher bootstrap completes.
- **Fix**: Document assumptions or switch to HTTPS health check.

### 12. Missing Labels on LB Network Attachment

- **File**: `main.tf:251-258`
- `hcloud_load_balancer` has labels, but `hcloud_load_balancer_network` does not.
- **Fix**: Add consistent labels.

---

## Strengths

- Sensitive variables properly marked (`hcloud_api_token`, `admin_password`, outputs)
- Comprehensive input validation (nullable=false, regex, CIDR checks)
- Cross-variable validation via `guardrails.tf`
- Excellent architecture documentation (ARCHITECTURE.md, 728 lines)
- Code comments with DECISION/COMPROMISE/WORKAROUND prefixes
- Zero-SSH design (no SSH keys, no provisioners, cloud-init only)
- Provider consolidation (only hcloud + rancher2)
- Delete protection hardcoded for management cluster
- Offline test suite with mock providers
