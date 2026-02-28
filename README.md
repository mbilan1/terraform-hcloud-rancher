# terraform-hcloud-rancher

An **OpenTofu/Terraform module** that deploys a production-oriented **Rancher management cluster on Hetzner Cloud** with built-in Hetzner Node Driver for downstream cluster provisioning via the Rancher UI.

> **Status**: Experimental — under active development, not production-ready

## Features

- **Single `tofu apply`** — provisions RKE2 cluster, installs cert-manager, Rancher, bootstraps admin, installs Hetzner Node Driver
- **Zero SSH post-bootstrap** — no SSH provisioners after cloud-init completes (inherited from the `terraform-hcloud-rke2` module)
- **Hetzner Node Driver** — [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) installed automatically
- **TLS flexibility** — self-signed (Rancher CA), Let's Encrypt, or user-provided certificate
- **Dual Load Balancer** — control-plane LB (K8s API) + ingress LB (Rancher UI)
- **Secrets encryption at rest** — RKE2 secrets encryption enabled by default
- **Route53 DNS** — optional A record for Rancher hostname

## Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| [OpenTofu](https://opentofu.org/) | >= 1.7.0 | Infrastructure as Code |
| [Hetzner Cloud](https://www.hetzner.com/cloud) | API token | Cloud provider |
| [AWS](https://aws.amazon.com/) | Credentials (optional) | Route53 DNS management |

## Quick Start

```hcl
module "rancher" {
  source = "github.com/<owner>/terraform-hcloud-rancher"

  hcloud_api_token = var.hcloud_api_token
  rancher_hostname = "rancher.example.com"
  admin_password   = var.admin_password
}
```

See [examples/minimal/](examples/minimal/) for a complete working example.

### Development with sslip.io

For testing without DNS setup, use [sslip.io](https://sslip.io) with the ingress LB IP:

```bash
# After first apply (to get the LB IP):
export TF_VAR_rancher_hostname="rancher.$(tofu output -raw ingress_lb_ipv4 | tr '.' '-').sslip.io"

# Or with dots:
export TF_VAR_rancher_hostname="rancher.$(tofu output -raw ingress_lb_ipv4).sslip.io"
```

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
├── main.tf              # Root shim — module calls + ingress LB + DNS
├── variables.tf         # All user-facing input variables
├── outputs.tf           # Module outputs
├── providers.tf         # Provider configurations (6 providers)
├── versions.tf          # Provider version constraints
├── guardrails.tf        # Preflight check {} blocks
├── modules/
│   ├── rke2-cluster/    # L3: Hetzner infrastructure via terraform-hcloud-rke2
│   └── rancher/         # L4: cert-manager + Rancher Helm + bootstrap + Node Driver
├── examples/
│   └── minimal/         # Minimal working deployment
├── tests/               # OpenTofu unit tests (tofu test)
└── docs/
    └── ARCHITECTURE.md  # Full design documentation
```

## Providers

| Provider | Source | Version | Purpose |
|----------|--------|---------|---------|
| hcloud | hetznercloud/hcloud | 1.60.1 | Hetzner Cloud resources |
| aws | hashicorp/aws | 6.33.0 | Route53 DNS |
| helm | hashicorp/helm | 3.1.1 | cert-manager + Rancher |
| kubernetes | hashicorp/kubernetes | 3.0.1 | Kubernetes resources |
| kubectl | alekc/kubectl | 2.1.3 | Raw YAML manifests (CRDs) |
| rancher2 | rancher/rancher2 | 13.1.4 | Rancher bootstrap |

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | = 6.33.0 |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | = 1.60.1 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | = 3.1.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | = 2.1.3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | = 3.0.1 |
| <a name="requirement_rancher2"></a> [rancher2](#requirement\_rancher2) | = 13.1.4 |
### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.33.0 |
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | 1.60.1 |
### Resources

| Name | Type |
|------|------|
| [aws_route53_record.rancher](https://registry.terraform.io/providers/hashicorp/aws/6.33.0/docs/resources/route53_record) | resource |
| [hcloud_load_balancer.ingress](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer) | resource |
| [hcloud_load_balancer_network.ingress](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_network) | resource |
| [hcloud_load_balancer_service.ingress_http](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_service.ingress_https](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_target.ingress_masters](https://registry.terraform.io/providers/hetznercloud/hcloud/1.60.1/docs/resources/load_balancer_target) | resource |
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Initial password for the Rancher 'admin' user. Must be at least 12 characters. Change immediately after first login. | `string` | n/a | yes |
| <a name="input_hcloud_api_token"></a> [hcloud\_api\_token](#input\_hcloud\_api\_token) | Hetzner Cloud API token for the management project (read/write access required) | `string` | n/a | yes |
| <a name="input_rancher_hostname"></a> [rancher\_hostname](#input\_rancher\_hostname) | Fully qualified domain name for the Rancher UI (e.g. 'rancher.example.com'). Must resolve to the ingress LB. | `string` | n/a | yes |
| <a name="input_aws_access_key"></a> [aws\_access\_key](#input\_aws\_access\_key) | AWS access key for Route53 DNS management. If empty, uses default AWS credentials chain. | `string` | `""` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for the Route53 provider. | `string` | `"eu-central-1"` | no |
| <a name="input_aws_secret_key"></a> [aws\_secret\_key](#input\_aws\_secret\_key) | AWS secret key for Route53 DNS management. If empty, uses default AWS credentials chain. | `string` | `""` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | cert-manager Helm chart version to install. | `string` | `"1.17.2"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Identifier prefix for all provisioned resources (servers, LBs, network, firewall). Must be lowercase alphanumeric, max 20 characters. | `string` | `"rancher"` | no |
| <a name="input_control_plane_server_type"></a> [control\_plane\_server\_type](#input\_control\_plane\_server\_type) | Hetzner Cloud server type for management cluster nodes. Minimum cx43 (8 vCPU, 16 GB) for Rancher. | `string` | `"cx43"` | no |
| <a name="input_create_dns_record"></a> [create\_dns\_record](#input\_create\_dns\_record) | Create a Route53 DNS record for rancher\_hostname pointing to the ingress LB. Requires route53\_zone\_id. | `bool` | `false` | no |
| <a name="input_enable_secrets_encryption"></a> [enable\_secrets\_encryption](#input\_enable\_secrets\_encryption) | Enable Kubernetes Secrets encryption at rest in etcd via RKE2. | `bool` | `true` | no |
| <a name="input_hcloud_network_cidr"></a> [hcloud\_network\_cidr](#input\_hcloud\_network\_cidr) | IPv4 address range for the Hetzner private network in CIDR notation. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_hcloud_network_zone"></a> [hcloud\_network\_zone](#input\_hcloud\_network\_zone) | Hetzner network zone encompassing all node locations. | `string` | `"eu-central"` | no |
| <a name="input_hetzner_driver_version"></a> [hetzner\_driver\_version](#input\_hetzner\_driver\_version) | Version of zsys-studio/rancher-hetzner-cluster-provider to install as Rancher Node Driver. | `string` | `"0.8.0"` | no |
| <a name="input_install_hetzner_driver"></a> [install\_hetzner\_driver](#input\_install\_hetzner\_driver) | Install the zsys-studio Hetzner Node Driver and UI Extension. Set to false if managing the driver separately. | `bool` | `true` | no |
| <a name="input_k8s_api_allowed_cidrs"></a> [k8s\_api\_allowed\_cidrs](#input\_k8s\_api\_allowed\_cidrs) | CIDR blocks allowed to access the Kubernetes API (port 6443). Default: open. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | RKE2 release tag to deploy (e.g. 'v1.34.4+rke2r1'). Leave empty for stable channel. | `string` | `"v1.34.4+rke2r1"` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email address for Let's Encrypt certificate registration. Required when tls\_source = 'letsEncrypt', ignored otherwise. | `string` | `""` | no |
| <a name="input_load_balancer_location"></a> [load\_balancer\_location](#input\_load\_balancer\_location) | Hetzner datacenter location for load balancers. Should match node\_location for lowest latency. | `string` | `"hel1"` | no |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | Number of control-plane nodes for the management cluster. Use 1 for dev/test, 3 for HA production. | `number` | `1` | no |
| <a name="input_node_location"></a> [node\_location](#input\_node\_location) | Primary Hetzner datacenter location for management cluster nodes (e.g. 'hel1', 'nbg1', 'fsn1'). | `string` | `"hel1"` | no |
| <a name="input_rancher_version"></a> [rancher\_version](#input\_rancher\_version) | Rancher Helm chart version to install (e.g. '2.13.3'). Must be compatible with the Kubernetes version. | `string` | `"2.13.3"` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | AWS Route53 hosted zone ID. Required when create\_dns\_record is true. | `string` | `""` | no |
| <a name="input_ssh_allowed_cidrs"></a> [ssh\_allowed\_cidrs](#input\_ssh\_allowed\_cidrs) | CIDR blocks allowed to access SSH (port 22) on cluster nodes. Default: open (rke2 module uses SSH provisioners internally). | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_subnet_address"></a> [subnet\_address](#input\_subnet\_address) | Subnet allocation for cluster nodes within the private network. | `string` | `"10.0.1.0/24"` | no |
| <a name="input_tls_source"></a> [tls\_source](#input\_tls\_source) | TLS certificate source for Rancher. 'rancher' = self-signed CA generated by Rancher, 'letsEncrypt' = Let's Encrypt via cert-manager ACME, 'secret' = user-provided TLS secret. | `string` | `"rancher"` | no |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_cert"></a> [client\_cert](#output\_client\_cert) | Client certificate for cluster authentication (PEM-encoded) |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | Client private key for cluster authentication (PEM-encoded) |
| <a name="output_cluster_ca"></a> [cluster\_ca](#output\_cluster\_ca) | Cluster CA certificate (PEM-encoded) |
| <a name="output_cluster_host"></a> [cluster\_host](#output\_cluster\_host) | Kubernetes API server endpoint URL |
| <a name="output_control_plane_lb_ipv4"></a> [control\_plane\_lb\_ipv4](#output\_control\_plane\_lb\_ipv4) | IPv4 address of the control-plane load balancer (K8s API, registration) |
| <a name="output_ingress_lb_ipv4"></a> [ingress\_lb\_ipv4](#output\_ingress\_lb\_ipv4) | IPv4 address of the ingress load balancer (Rancher UI) |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | Full kubeconfig file content for direct cluster access |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | Hetzner Cloud private network ID (for reference) |
| <a name="output_rancher_admin_token"></a> [rancher\_admin\_token](#output\_rancher\_admin\_token) | Rancher admin API token for initial configuration. Treat as a secret. |
| <a name="output_rancher_url"></a> [rancher\_url](#output\_rancher\_url) | Rancher UI URL (HTTPS) |
<!-- END_TF_DOCS -->

## License

[MIT](LICENSE) — Copyright (c) 2026 Maksym Bilan
