# rke2-cluster

L3 infrastructure child module — provisions an RKE2 Kubernetes cluster on Hetzner Cloud via the `terraform-hcloud-rke2` module.

## Purpose

Thin wrapper around `terraform-hcloud-rke2` with management-cluster-specific defaults:

- `cloud_provider_external = false` — no HCCM needed for management clusters
- `save_ssh_key_locally = false` — zero SSH principle

## Usage

This module is called internally by the root module. Do not use it directly.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
### Providers

No providers.
### Resources

No resources.
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Identifier prefix for all resources | `string` | n/a | yes |
| <a name="input_hcloud_api_token"></a> [hcloud\_api\_token](#input\_hcloud\_api\_token) | Hetzner Cloud API token for the management project | `string` | n/a | yes |
| <a name="input_control_plane_count"></a> [control\_plane\_count](#input\_control\_plane\_count) | Number of control-plane nodes (1 or 3+) | `number` | `1` | no |
| <a name="input_control_plane_server_type"></a> [control\_plane\_server\_type](#input\_control\_plane\_server\_type) | Hetzner server type for control-plane nodes | `string` | `"cx43"` | no |
| <a name="input_enable_secrets_encryption"></a> [enable\_secrets\_encryption](#input\_enable\_secrets\_encryption) | Enable Kubernetes Secrets encryption at rest in etcd | `bool` | `true` | no |
| <a name="input_hcloud_network_cidr"></a> [hcloud\_network\_cidr](#input\_hcloud\_network\_cidr) | Private network CIDR | `string` | `"10.0.0.0/16"` | no |
| <a name="input_hcloud_network_zone"></a> [hcloud\_network\_zone](#input\_hcloud\_network\_zone) | Hetzner network zone | `string` | `"eu-central"` | no |
| <a name="input_k8s_api_allowed_cidrs"></a> [k8s\_api\_allowed\_cidrs](#input\_k8s\_api\_allowed\_cidrs) | CIDR blocks allowed for K8s API access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | RKE2 release tag to deploy | `string` | `"v1.34.4+rke2r1"` | no |
| <a name="input_load_balancer_location"></a> [load\_balancer\_location](#input\_load\_balancer\_location) | Hetzner datacenter for the control-plane load balancer | `string` | `"hel1"` | no |
| <a name="input_node_location"></a> [node\_location](#input\_node\_location) | Primary Hetzner datacenter location | `string` | `"hel1"` | no |
| <a name="input_ssh_allowed_cidrs"></a> [ssh\_allowed\_cidrs](#input\_ssh\_allowed\_cidrs) | CIDR blocks allowed for SSH access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_subnet_address"></a> [subnet\_address](#input\_subnet\_address) | Subnet CIDR for cluster nodes | `string` | `"10.0.1.0/24"` | no |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_cert"></a> [client\_cert](#output\_client\_cert) | Client certificate for cluster authentication (PEM-encoded) |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | Client private key for cluster authentication (PEM-encoded) |
| <a name="output_cluster_ca"></a> [cluster\_ca](#output\_cluster\_ca) | Cluster CA certificate (PEM-encoded) |
| <a name="output_cluster_host"></a> [cluster\_host](#output\_cluster\_host) | Kubernetes API server endpoint URL |
| <a name="output_control_plane_lb_ipv4"></a> [control\_plane\_lb\_ipv4](#output\_control\_plane\_lb\_ipv4) | IPv4 address of the control-plane load balancer |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | Full kubeconfig file content |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | Hetzner Cloud private network ID |
<!-- END_TF_DOCS -->
