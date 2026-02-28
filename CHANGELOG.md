# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **Management cluster**: Single-node or HA RKE2 cluster on Hetzner Cloud via the `terraform-hcloud-rke2` module
- **Rancher installation**: cert-manager + Rancher Helm chart deployed in single `tofu apply`
- **Admin bootstrap**: `rancher2_bootstrap` resource sets admin password and server URL
- **TLS sources**: Self-signed (Rancher CA), Let's Encrypt, or user-provided certificate
- **Hetzner Node Driver**: [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) v0.8.0 installed as Rancher NodeDriver + UI Extension
- **Dual Load Balancer**: Control-plane LB (ports 6443, 9345) + Ingress LB (ports 80, 443)
- **Route53 DNS**: Optional A record for Rancher hostname
- **Secrets encryption**: RKE2 secrets encryption at rest enabled by default
- **Guardrails**: 5 preflight `check {}` blocks (DNS, LE email, AWS creds, server type, FQDN)
- **Tests**: Variable validation + guardrail tests via `tofu test`
- **Examples**: `examples/minimal/` — minimal working deployment
- **Documentation**: `docs/ARCHITECTURE.md` (729 lines), `README.md`, `AGENTS.md`
- **REUSE compliance**: SPDX licensing metadata via `REUSE.toml`
