# rke2-cluster

L3 infrastructure child module — provisions an RKE2 Kubernetes cluster on Hetzner Cloud via `terraform-hcloud-rke2-core`.

## Purpose

Thin wrapper around `terraform-hcloud-rke2-core` with management-cluster-specific defaults:

- `delete_protection = true` — prevents accidental destruction of the management cluster
- `extra_server_manifests` — passes HelmChart CRDs (cert-manager, Rancher) for cloud-init deployment
- Builds `control_plane_nodes` map from simple `count + type + location` API

## Usage

This module is called internally by the root module. Do not use it directly.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cluster"></a> [cluster](#module\_cluster) | git::https://github.com/mbilan1/terraform-hcloud-rke2-core.git | 995cb16446143c723063ee6d77af99ec4824e356 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Identifier prefix for all resources | `string` | n/a | yes |
| <a name="input_control_plane_count"></a> [control\_plane\_count](#input\_control\_plane\_count) | Number of control-plane nodes (1 or 3+) | `number` | `1` | no |
| <a name="input_control_plane_server_type"></a> [control\_plane\_server\_type](#input\_control\_plane\_server\_type) | Hetzner server type for control-plane nodes | `string` | `"cx43"` | no |
| <a name="input_enable_cis"></a> [enable\_cis](#input\_enable\_cis) | Enable RKE2 CIS hardening. Idempotent on Packer images. | `bool` | `false` | no |
| <a name="input_extra_server_manifests"></a> [extra\_server\_manifests](#input\_extra\_server\_manifests) | Map of filename => YAML placed in /var/lib/rancher/rke2/server/manifests/. RKE2 HelmController auto-installs these. | `map(string)` | `{}` | no |
| <a name="input_firewall_ids"></a> [firewall\_ids](#input\_firewall\_ids) | List of Hetzner firewall IDs to attach to nodes. | `list(number)` | `[]` | no |
| <a name="input_hcloud_image"></a> [hcloud\_image](#input\_hcloud\_image) | OS image for nodes. Use 'ubuntu-24.04' or a Hetzner snapshot ID. | `string` | `"ubuntu-24.04"` | no |
| <a name="input_hcloud_network_cidr"></a> [hcloud\_network\_cidr](#input\_hcloud\_network\_cidr) | Private network CIDR | `string` | `"10.0.0.0/16"` | no |
| <a name="input_hcloud_network_zone"></a> [hcloud\_network\_zone](#input\_hcloud\_network\_zone) | Hetzner network zone | `string` | `"eu-central"` | no |
| <a name="input_node_location"></a> [node\_location](#input\_node\_location) | Primary Hetzner datacenter location | `string` | `"hel1"` | no |
| <a name="input_rke2_config"></a> [rke2\_config](#input\_rke2\_config) | Additional RKE2 config.yaml content appended to every node. | `string` | `""` | no |
| <a name="input_rke2_version"></a> [rke2\_version](#input\_rke2\_version) | RKE2 release tag to deploy (e.g. 'v1.34.4+rke2r1'). Empty = stable channel. | `string` | `"v1.34.4+rke2r1"` | no |
| <a name="input_ssh_key_ids"></a> [ssh\_key\_ids](#input\_ssh\_key\_ids) | List of Hetzner SSH key IDs to install on nodes. BYO: Zero-SSH by default. | `list(number)` | `[]` | no |
| <a name="input_subnet_address"></a> [subnet\_address](#input\_subnet\_address) | Subnet CIDR for cluster nodes | `string` | `"10.0.1.0/24"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_ready"></a> [cluster\_ready](#output\_cluster\_ready) | True when the K8s API server is reachable on port 6443 |
| <a name="output_initial_master_ipv4"></a> [initial\_master\_ipv4](#output\_initial\_master\_ipv4) | Public IPv4 of the initial master (K8s API endpoint host) |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | Hetzner Cloud private network ID (for ingress LB attachment) |
<!-- END_TF_DOCS -->
