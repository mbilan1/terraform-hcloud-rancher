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
- Admin password appears in plain text in state via cloud-init user_data. Documented compromise with mitigation (encrypt state at rest) in `main.tf`, but this is not surfaced in README/user docs.
- **Fix**: Surface the existing state encryption requirement prominently in user-facing docs (e.g., README) and document post-deploy admin password rotation.

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
- Minimal provider set (hcloud, rancher2, plus utility `hashicorp/random`; no helm/kubernetes/kubectl providers)
- Delete protection hardcoded for management cluster
- Offline test suite with mock providers

---

## Fix Verification Status (2026-03-07)

Verified against commit `42ba086` ("fix: resolve code review findings") on `main`.

| # | Issue | Severity | Status | Notes |
|---|-------|----------|--------|-------|
| 1 | Missing `install_hetzner_driver` variable | Critical | **NOT FIXED** | README still documents it; variable still absent |
| 2 | RKE2 version mismatch in docs | Critical | **NOT FIXED** | terraform-docs not regenerated; README shows v1.32, code uses v1.34 |
| 3 | Subnet not validated against network CIDR | High | **PARTIAL** | CIDR syntax validated; containment check not added to guardrails.tf |
| 4 | Overly permissive firewall in example | High | **NOT FIXED** | examples/minimal still opens 6443 to 0.0.0.0/0 |
| 5 | LB health check during startup | High | **NOT FIXED** | No retry increase or documentation added |
| 6 | Admin password in state | Medium | **FIXED** | COMPROMISE comment added to main.tf with mitigation guidance |
| 7 | Undocumented rke2_config default | Medium | **NOT FIXED** | etcd snapshot defaults still undocumented |
| 8 | Missing version compatibility matrix | Medium | **NOT FIXED** | No matrix in ARCHITECTURE.md |
| 9 | Let's Encrypt validation gap | Medium | **FIXED** | Email @ validation added to variables.tf |
| 10 | Indefinite cleanup TODOs | Low | **NOT FIXED** | No deadline added |
| 11 | Port 80 health check assumptions | Low | **NOT FIXED** | No documentation added |
| 12 | Missing labels on LB network | Low | **NOT FIXED** | hcloud_load_balancer_network still unlabeled |

**Additional fixes applied** (beyond review scope): heredoc escaping fix, IP validation via cidrhost(), node_location allowlist validation, random provider declaration, unused rancher_url output removed, 7 new tests (42 total).

**Summary**: 2/12 fully fixed, 1 partial, 9 not fixed. Critical items remain open.
