# Minimal Example

Single-node Rancher management cluster on Hetzner Cloud with self-signed TLS and sslip.io auto-hostname.

## Usage

```bash
export TF_VAR_hcloud_api_token="your-hetzner-api-token"

tofu init
tofu plan
tofu apply
```

Admin password is auto-generated. Retrieve it after apply:

```bash
tofu output -raw rancher_admin_password
```

### With custom hostname and Let's Encrypt

```bash
export TF_VAR_hcloud_api_token="your-hetzner-api-token"

tofu init
tofu apply -var='rancher_hostname=rancher.example.com' \
           -var='tls_source=letsEncrypt' \
           -var='letsencrypt_email=ops@example.com' \
           -var='admin_password=YourSecurePassword123'
```

## After Deploy

1. Open the `rancher_url` output in a browser (accept self-signed cert warning for sslip.io)
2. Log in with `admin` / the auto-generated password (`tofu output -raw rancher_admin_password`)
3. Create Cloud Credentials for downstream Hetzner projects
4. Provision downstream RKE2 clusters via Rancher UI

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | ~> 1.49 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | 1.60.1 |

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
| <a name="input_hcloud_api_token"></a> [hcloud\_api\_token](#input\_hcloud\_api\_token) | Hetzner Cloud API token for the management project (read/write access required) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ingress_lb_ipv4"></a> [ingress\_lb\_ipv4](#output\_ingress\_lb\_ipv4) | Point your DNS A-record for rancher\_hostname to this IP |
| <a name="output_initial_master_ipv4"></a> [initial\_master\_ipv4](#output\_initial\_master\_ipv4) | Public IP of the initial master node |
| <a name="output_rancher_admin_password"></a> [rancher\_admin\_password](#output\_rancher\_admin\_password) | Rancher admin password (auto-generated) |
| <a name="output_rancher_admin_token"></a> [rancher\_admin\_token](#output\_rancher\_admin\_token) | Rancher admin API token (sensitive) |
| <a name="output_rancher_hostname"></a> [rancher\_hostname](#output\_rancher\_hostname) | Effective Rancher hostname (auto-generated from LB IP if not provided) |
| <a name="output_rancher_url"></a> [rancher\_url](#output\_rancher\_url) | Rancher UI URL |
<!-- END_TF_DOCS -->
