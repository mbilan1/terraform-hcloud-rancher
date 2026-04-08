# terraform-hcloud-rancher
![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/mbilan1/terraform-hcloud-rancher?utm_source=oss&utm_medium=github&utm_campaign=mbilan1%2Fterraform-hcloud-rancher&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)
[![Lint: fmt](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/lint-fmt.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/lint-fmt.yml)
[![Lint: validate](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/lint-validate.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/lint-validate.yml)
[![Lint: tflint](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/lint-tflint.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/lint-tflint.yml)

[![SAST: Checkov](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/sast-checkov.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/sast-checkov.yml)
[![SAST: KICS](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/sast-kics.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/sast-kics.yml)
[![SAST: tfsec](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/sast-tfsec.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/sast-tfsec.yml)

[![Test: variables](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/unit-variables.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/unit-variables.yml)
[![Test: guardrails](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/unit-guardrails.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/unit-guardrails.yml)

[![Integration: plan](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/integration-plan.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/integration-plan.yml)
[![E2E: apply](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/e2e-apply.yml/badge.svg)](https://github.com/mbilan1/terraform-hcloud-rancher/actions/workflows/e2e-apply.yml)

<!-- Version badges — source: versions.tf (required_version, required_providers), variables.tf (rke2_version) -->
![OpenTofu](https://img.shields.io/badge/OpenTofu-%3E%3D1.8.0-844FBA?logo=opentofu&logoColor=white)
![hcloud](https://img.shields.io/badge/hcloud-1.60.1-E10000?logo=hetzner&logoColor=white)
![rancher2](https://img.shields.io/badge/rancher2-13.1.4-0075A8?logo=rancher&logoColor=white)
![random](https://img.shields.io/badge/random-3.8.1-7B42BC?logo=terraform&logoColor=white)
![RKE2](https://img.shields.io/badge/RKE2-v1.35.3%2Brke2r1-0075A8?logo=kubernetes&logoColor=white)

> **⚠️ Experimental (Beta)** — This is an **unofficial** community implementation, under active development and **not production-ready**.
> APIs, variables, and behavior may change without notice. Use at your own risk.
> No stability guarantees are provided until v1.0.0.

An **OpenTofu/Terraform module** that deploys a **Rancher management cluster on Hetzner Cloud** with built-in Hetzner Node Driver for downstream cluster provisioning via the Rancher UI.

## Ecosystem

This module is part of the **RKE2-on-Hetzner** ecosystem — a set of interconnected projects that together provide a complete Kubernetes management platform on Hetzner Cloud.

| Repository | Role in Ecosystem |
|---|---|
| [`terraform-hcloud-rke2-core`](https://github.com/mbilan1/terraform-hcloud-rke2-core) | L3 infrastructure primitive — servers, network, readiness |
| **`terraform-hcloud-rancher`** (this repo) | **Management cluster — Rancher + Node Driver on RKE2** |
| [`rancher-hetzner-cluster-templates`](https://github.com/mbilan1/rancher-hetzner-cluster-templates) | Downstream cluster provisioning via Rancher UI |
| [`packer-hcloud-rke2`](https://github.com/mbilan1/packer-hcloud-rke2) | Packer node image — CIS-hardened snapshots |

```
rke2-core (L3 infra) → rancher (L3+L4 management) → cluster-templates (downstream via UI)
                                                    ↑
                                        packer (node images)
```

## Features

- **Single `tofu apply`** — provisions RKE2 cluster, installs cert-manager, Rancher, bootstraps admin, installs Hetzner Node Driver
- **True Zero-SSH** — no SSH keys, no port 22, no sshd (inherited from `terraform-hcloud-rke2-core`, ADR-002)
- **sslip.io by default** — auto-generates hostname from ingress LB IP, zero DNS setup needed
- **BYO DNS** — pass `rancher_hostname` with any FQDN (Route53, Cloudflare, etc.) for production
- **BYO Ingress LB** — create or bring your own load balancer (`for_each` gating pattern)
- **Hetzner Node Driver** — [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) installed via cloud-init
- **TLS flexibility** — self-signed (Rancher CA), Let's Encrypt, or user-provided certificate
- **Dual Load Balancer** — control-plane LB (K8s API) + ingress LB (Rancher UI)
- **CIS hardening** — optional RKE2 CIS profile via `enable_cis` with automatic PSA exemptions for Rancher
- **2 providers only** — `hcloud` + `rancher2` (all L4 via cloud-init manifests)

## Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| [OpenTofu](https://opentofu.org/) | >= 1.8.0 | Infrastructure as Code |
| [Hetzner Cloud](https://www.hetzner.com/cloud) | API token | Cloud provider |

## Quick Start

```hcl
module "rancher" {
  source = "git::https://github.com/mbilan1/terraform-hcloud-rancher.git?ref=v0.1.0"

  hcloud_api_token = var.hcloud_api_token
  admin_password   = var.admin_password

  # rancher_hostname is optional — defaults to sslip.io auto-hostname
  # For production, set a real FQDN:
  # rancher_hostname = "rancher.example.com"
}
```

See [examples/minimal/](examples/minimal/) for a complete working example.

### DNS Configuration

By default, the module auto-generates a [sslip.io](https://sslip.io) hostname from the ingress LB IP — **no DNS setup is required**.

For production, bring your own DNS (Route53, Cloudflare, or any provider):

1. Deploy with default sslip.io to obtain `ingress_lb_ipv4` output
2. Create an A record in your DNS provider: `rancher.example.com → <ingress_lb_ipv4>`
3. Re-apply with the FQDN:

```hcl
module "rancher" {
  source = "git::https://github.com/mbilan1/terraform-hcloud-rancher.git?ref=v0.1.0"

  hcloud_api_token  = var.hcloud_api_token
  rancher_hostname  = "rancher.example.com"  # Your R53/Cloudflare managed FQDN
  admin_password    = var.admin_password
  tls_source        = "letsEncrypt"
  letsencrypt_email = "ops@example.com"
}
```

> **Route53 example**: Create an `aws_route53_record` alongside this module,
> pointing at the `ingress_lb_ipv4` output. See the architecture docs for details.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design document including:

- Module architecture (L3 infrastructure + L4 Kubernetes management)
- Infrastructure topology (dual LB design)
- Deployment flow (two-phase apply)
- Downstream cluster provisioning via Rancher UI
- Security model
- Compromise log

## Module Structure

```
terraform-hcloud-rancher/
├── main.tf              # Root facade — BYO LB + cloud-init manifests + module calls
├── variables.tf         # All user-facing input variables
├── outputs.tf           # Module outputs
├── providers.tf         # Provider configurations (hcloud + rancher2)
├── versions.tf          # Provider version constraints
├── guardrails.tf        # Preflight check {} blocks
├── moved.tf             # State migration (singleton → for_each)
├── modules/
│   ├── rke2-cluster/    # L3: Hetzner infrastructure via terraform-hcloud-rke2-core
│   └── rancher/         # L4: Rancher admin bootstrap only (rancher2_bootstrap)
├── examples/
│   ├── minimal/         # Minimal working deployment (sslip.io, self-signed TLS)
│   └── complete/        # HA 3-node with BYO firewall, Let's Encrypt, Packer image
├── tests/               # OpenTofu unit tests (tofu test)
└── docs/
    └── ARCHITECTURE.md  # Full design documentation
```

## Providers

| Provider | Source | Version | Purpose |
|----------|--------|---------|---------|
| hcloud | hetznercloud/hcloud | 1.60.1 | Hetzner Cloud resources |
| rancher2 | rancher/rancher2 | 13.1.4 | Rancher bootstrap |

> **Note**: cert-manager, Rancher, NodeDriver, and UIPlugin are deployed via RKE2 cloud-init manifests (HelmChart CRDs). No `helm`, `kubernetes`, or `kubectl` providers needed.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | = 1.60.1 |
| <a name="requirement_rancher2"></a> [rancher2](#requirement\_rancher2) | = 13.1.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | = 3.8.1 |
### Providers

| Name | Version |
|------|---------|
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | 1.60.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |
### Resources

| Name | Type |
|------|------|
| [hcloud_load_balancer.ingress](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer) | resource |
| [hcloud_load_balancer_network.ingress](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_network) | resource |
| [hcloud_load_balancer_service.http](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_service.https](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_target.ingress](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_target) | resource |
| [random_password.admin](https://registry.terraform.io/providers/hashicorp/random/3.8.1/docs/resources/password) | resource |
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hcloud_api_token"></a> [hcloud\_api\_token](#input\_hcloud\_api\_token) | Hetzner Cloud API token for the management project (read/write access required) | `string` | n/a | yes |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Initial password for the Rancher 'admin' user. Leave empty to auto-generate a secure random password (output as rancher\_admin\_password). | `string` | `""` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | cert-manager Helm chart version to install. | `string` | `"1.17.2"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Identifier prefix for all provisioned resources (servers, LBs, network). Must be lowercase alphanumeric, max 20 characters. | `string` | `"rancher"` | no |
| <a name="input_control_plane_server_type"></a> [control\_plane\_server\_type](#input\_control\_plane\_server\_type) | Hetzner Cloud server type for management cluster nodes. Minimum cx43 (8 vCPU, 16 GB) for Rancher. | `string` | `"cx43"` | no |
| <a name="input_create_ingress_lb"></a> [create\_ingress\_lb](#input\_create\_ingress\_lb) | Create a Hetzner ingress load balancer for Rancher UI (ports 80/443). Set to false when using a pre-existing or external load balancer. | `bool` | `true` | no |
| <a name="input_enable_cis"></a> [enable\_cis](#input\_enable\_cis) | Enable CIS hardening for the management cluster. Activates RKE2 CIS profile, creates prerequisites (etcd user, kernel params), and exempts cattle-system from PodSecurity restricted policy. Works with both stock ubuntu-24.04 and Packer golden images. | `bool` | `false` | no |
| <a name="input_existing_ingress_lb_ipv4"></a> [existing\_ingress\_lb\_ipv4](#input\_existing\_ingress\_lb\_ipv4) | IPv4 address of an existing ingress load balancer. Only used when create\_ingress\_lb = false. If set, auto-generates hostname from this IP (unless rancher\_hostname is provided). | `string` | `""` | no |
| <a name="input_firewall_ids"></a> [firewall\_ids](#input\_firewall\_ids) | List of Hetzner firewall IDs to attach to all management cluster nodes. BYO: create firewalls externally and pass their IDs. | `list(number)` | `[]` | no |
| <a name="input_hcloud_image"></a> [hcloud\_image](#input\_hcloud\_image) | OS image for management cluster nodes. Use 'ubuntu-24.04' (default) or a Hetzner snapshot ID from a Packer baked image. | `string` | `"ubuntu-24.04"` | no |
| <a name="input_hcloud_network_cidr"></a> [hcloud\_network\_cidr](#input\_hcloud\_network\_cidr) | IPv4 address range for the Hetzner private network in CIDR notation. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_hcloud_network_zone"></a> [hcloud\_network\_zone](#input\_hcloud\_network\_zone) | Hetzner network zone encompassing all node locations. | `string` | `"eu-central"` | no |
| <a name="input_hetzner_driver_version"></a> [hetzner\_driver\_version](#input\_hetzner\_driver\_version) | Version of zsys-studio/rancher-hetzner-cluster-provider to install as Rancher Node Driver. | `string` | `"0.9.0"` | no |
| <a name="input_install_hetzner_driver"></a> [install\_hetzner\_driver](#input\_install\_hetzner\_driver) | Install zsys-studio Hetzner Node Driver for downstream cluster provisioning via Rancher UI. Set to false if the driver is managed externally. | `bool` | `true` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email address for Let's Encrypt certificate registration. Required when tls\_source = 'letsEncrypt', ignored otherwise. | `string` | `""` | no |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | Number of control-plane nodes for the management cluster. Use 1 for dev/test, 3 for HA production. | `number` | `1` | no |
| <a name="input_node_location"></a> [node\_location](#input\_node\_location) | Primary Hetzner datacenter location for management cluster nodes (e.g. 'hel1', 'nbg1', 'fsn1'). | `string` | `"hel1"` | no |
| <a name="input_rancher_hostname"></a> [rancher\_hostname](#input\_rancher\_hostname) | FQDN for the Rancher UI (e.g. 'rancher.example.com'). Leave empty to auto-generate from ingress LB IP via sslip.io. | `string` | `""` | no |
| <a name="input_rancher_version"></a> [rancher\_version](#input\_rancher\_version) | Rancher Helm chart version to install (e.g. '2.13.3'). Must be compatible with the Kubernetes version. | `string` | `"2.13.3"` | no |
| <a name="input_rke2_config"></a> [rke2\_config](#input\_rke2\_config) | Additional RKE2 config.yaml content appended to every management cluster node. | `string` | `"etcd-snapshot-schedule-cron: \"0 */6 * * *\"\netcd-snapshot-retention: 10\n"` | no |
| <a name="input_rke2_version"></a> [rke2\_version](#input\_rke2\_version) | RKE2 release tag to deploy (e.g. 'v1.34.4+rke2r1'). Leave empty for stable channel. | `string` | `"v1.34.4+rke2r1"` | no |
| <a name="input_ssh_key_ids"></a> [ssh\_key\_ids](#input\_ssh\_key\_ids) | List of Hetzner SSH key IDs to install on management cluster nodes. Empty by default (Zero-SSH). | `list(number)` | `[]` | no |
| <a name="input_subnet_address"></a> [subnet\_address](#input\_subnet\_address) | Subnet allocation for cluster nodes within the private network. | `string` | `"10.0.1.0/24"` | no |
| <a name="input_tls_source"></a> [tls\_source](#input\_tls\_source) | TLS certificate source for Rancher. 'rancher' = self-signed CA generated by Rancher, 'letsEncrypt' = Let's Encrypt via cert-manager ACME, 'secret' = user-provided TLS secret. | `string` | `"rancher"` | no |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_ingress_lb_ipv4"></a> [ingress\_lb\_ipv4](#output\_ingress\_lb\_ipv4) | IPv4 address of the ingress load balancer (Rancher UI). Point DNS A record here. |
| <a name="output_initial_master_ipv4"></a> [initial\_master\_ipv4](#output\_initial\_master\_ipv4) | Public IPv4 of the initial master (control-plane node that bootstrapped the cluster) |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | Hetzner Cloud private network ID (for cluster template pre-fill — ADR-005) |
| <a name="output_rancher_admin_password"></a> [rancher\_admin\_password](#output\_rancher\_admin\_password) | Rancher admin password (auto-generated if not provided). Use to log in at rancher\_url. |
| <a name="output_rancher_admin_token"></a> [rancher\_admin\_token](#output\_rancher\_admin\_token) | Rancher admin API token for initial configuration. Treat as a secret. |
| <a name="output_rancher_hostname"></a> [rancher\_hostname](#output\_rancher\_hostname) | Effective Rancher hostname (auto-generated from LB IP if not provided) |
| <a name="output_rancher_url"></a> [rancher\_url](#output\_rancher\_url) | Rancher UI URL (HTTPS) |
<!-- END_TF_DOCS -->

## License

[MIT](LICENSE) — Copyright (c) 2026 Maksym Bilan
