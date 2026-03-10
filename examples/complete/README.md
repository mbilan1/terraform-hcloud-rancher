# Complete Example — HA Rancher Management Cluster

Production-ready example with:
- **3-node HA** control plane (etcd quorum)
- **BYO firewall** with restrictive operator-only CIDR rules (ADR-006)
- **Let's Encrypt** TLS (requires real DNS)
- **Packer baked image** support for CIS-hardened nodes (ADR-009)
- **etcd S3 backup** to Hetzner Object Storage (optional)

## Prerequisites

1. **DNS access** — create an A record `rancher.example.com → <ingress LB IP>` after first apply
2. **Hetzner API token** — for the management project (read/write)
3. **Packer snapshot** (optional) — build with `packer-hcloud-rke2` for CIS-hardened nodes

## Quick Start

```bash
export TF_VAR_hcloud_api_token="your-token"
export TF_VAR_admin_password="your-secure-password"
export TF_VAR_rancher_hostname="rancher.example.com"
export TF_VAR_letsencrypt_email="ops@example.com"

tofu init
tofu plan
tofu apply
```

After apply:
1. Note the `ingress_lb_ipv4` output
2. Create DNS A record: `rancher.example.com → <ingress_lb_ipv4>`
3. Wait ~2 minutes for Let's Encrypt certificate
4. Open `https://rancher.example.com`

## With CIS-Hardened Image

```bash
# Build golden image first
cd /path/to/packer-hcloud-rke2
packer build -var "hcloud_token=$HCLOUD_TOKEN" -var "enable_cis_hardening=true" .

# Use the snapshot ID
export TF_VAR_hcloud_image="12345678"  # from Packer output
```

## With etcd S3 Backup

```bash
export TF_VAR_etcd_s3_endpoint="fsn1.your-objectstorage.com"
export TF_VAR_etcd_s3_bucket="rancher-etcd-backup"
export TF_VAR_etcd_s3_access_key="your-access-key"
export TF_VAR_etcd_s3_secret_key="your-secret-key"
```

## Cost Estimate

| Resource | Type | Qty | ~EUR/mo |
|----------|------|-----|---------|
| Control plane | cx43 (8 vCPU, 16 GB) | 3 | 3 × €23.49 = €70.47 |
| Ingress LB | lb11 | 1 | €5.39 |
| Private network | — | 1 | Free |
| **Total** | | | **~€76/mo** |

## See Also

- [examples/minimal/](../minimal/) — single-node dev setup
- [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) — full architecture documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | ~> 1.49 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | ~> 1.49 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_rancher_management"></a> [rancher\_management](#module\_rancher\_management) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [hcloud_firewall.management](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/firewall) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Initial Rancher admin password (min 12 characters) | `string` | n/a | yes |
| <a name="input_etcd_s3_access_key"></a> [etcd\_s3\_access\_key](#input\_etcd\_s3\_access\_key) | S3 access key for etcd snapshots | `string` | `""` | no |
| <a name="input_etcd_s3_bucket"></a> [etcd\_s3\_bucket](#input\_etcd\_s3\_bucket) | S3 bucket name for etcd snapshots | `string` | `""` | no |
| <a name="input_etcd_s3_endpoint"></a> [etcd\_s3\_endpoint](#input\_etcd\_s3\_endpoint) | S3-compatible endpoint for etcd snapshots (e.g. 'fsn1.your-objectstorage.com'). Empty = local snapshots only. | `string` | `""` | no |
| <a name="input_etcd_s3_region"></a> [etcd\_s3\_region](#input\_etcd\_s3\_region) | S3 region for etcd snapshots (e.g. 'eu-central') | `string` | `"eu-central"` | no |
| <a name="input_etcd_s3_secret_key"></a> [etcd\_s3\_secret\_key](#input\_etcd\_s3\_secret\_key) | S3 secret key for etcd snapshots | `string` | `""` | no |
| <a name="input_hcloud_api_token"></a> [hcloud\_api\_token](#input\_hcloud\_api\_token) | Hetzner Cloud API token for the management project (read/write access required) | `string` | n/a | yes |
| <a name="input_hcloud_image"></a> [hcloud\_image](#input\_hcloud\_image) | Hetzner image — stock 'ubuntu-24.04' or Packer snapshot ID (e.g. '12345678') for CIS-hardened image | `string` | `"ubuntu-24.04"` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email for Let's Encrypt certificate registration | `string` | n/a | yes |
| <a name="input_operator_cidrs"></a> [operator\_cidrs](#input\_operator\_cidrs) | CIDRs allowed to access K8s API (port 6443). Default: office/VPN only. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_rancher_hostname"></a> [rancher\_hostname](#input\_rancher\_hostname) | FQDN for Rancher (e.g. 'rancher.example.com'). Must have a DNS A record pointing to the ingress LB IP. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ingress_lb_ipv4"></a> [ingress\_lb\_ipv4](#output\_ingress\_lb\_ipv4) | Point your DNS A-record for rancher\_hostname to this IP |
| <a name="output_initial_master_ipv4"></a> [initial\_master\_ipv4](#output\_initial\_master\_ipv4) | Public IP of the initial master node |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | Hetzner private network ID — use for downstream cluster templates (ADR-005) |
| <a name="output_rancher_admin_password"></a> [rancher\_admin\_password](#output\_rancher\_admin\_password) | Rancher admin password (sensitive) |
| <a name="output_rancher_admin_token"></a> [rancher\_admin\_token](#output\_rancher\_admin\_token) | Rancher admin API token (sensitive) |
| <a name="output_rancher_hostname"></a> [rancher\_hostname](#output\_rancher\_hostname) | Effective Rancher hostname |
| <a name="output_rancher_url"></a> [rancher\_url](#output\_rancher\_url) | Rancher UI URL |
<!-- END_TF_DOCS -->