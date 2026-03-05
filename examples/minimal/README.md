# Minimal Example

Single-node Rancher management cluster on Hetzner Cloud with self-signed TLS.

## Usage

```bash
export TF_VAR_hcloud_api_token="your-hetzner-api-token"
export TF_VAR_admin_password="your-rancher-admin-password"  # min 12 chars
export TF_VAR_rancher_hostname="rancher.example.com"

tofu init
tofu apply
```

### Testing with sslip.io (no DNS required)

```bash
# Phase 1: Deploy infrastructure to get LB IP
tofu apply -target=module.rancher_management.module.rke2_cluster \
           -target='module.rancher_management.hcloud_load_balancer.ingress["main"]' \
           -target='module.rancher_management.hcloud_load_balancer_network.ingress["main"]' \
           -target='module.rancher_management.hcloud_load_balancer_target.ingress["main"]' \
           -target='module.rancher_management.hcloud_load_balancer_service.http["main"]' \
           -target='module.rancher_management.hcloud_load_balancer_service.https["main"]'

# Phase 2: Full apply with sslip.io hostname
export TF_VAR_rancher_hostname="rancher.$(tofu output -raw ingress_lb_ipv4).sslip.io"
tofu apply
```

## After Deploy

1. Open the `rancher_url` output in a browser (accept self-signed cert warning)
2. Log in with `admin` / `$TF_VAR_admin_password`
3. Create Cloud Credentials for downstream Hetzner projects
4. Provision downstream RKE2 clusters via Rancher UI

<!-- BEGIN_TF_DOCS -->
### Requirements

No requirements.
### Providers

No providers.
### Resources

No resources.
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Initial password for the Rancher 'admin' user. Minimum 12 characters. | `string` | n/a | yes |
| <a name="input_hcloud_api_token"></a> [hcloud\_api\_token](#input\_hcloud\_api\_token) | Hetzner Cloud API token for the management project (read/write access required) | `string` | n/a | yes |
| <a name="input_rancher_hostname"></a> [rancher\_hostname](#input\_rancher\_hostname) | Fully qualified domain name for the Rancher UI (e.g. 'rancher.example.com'). Must resolve to the ingress LB IPv4. | `string` | n/a | yes |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email address for Let's Encrypt certificate registration. Only required when tls\_source = 'letsEncrypt'. | `string` | `""` | no |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_control_plane_lb_ipv4"></a> [control\_plane\_lb\_ipv4](#output\_control\_plane\_lb\_ipv4) | K8s API load balancer IP (for kubectl access) |
| <a name="output_ingress_lb_ipv4"></a> [ingress\_lb\_ipv4](#output\_ingress\_lb\_ipv4) | Point your DNS A-record for rancher\_hostname to this IP |
| <a name="output_rancher_admin_token"></a> [rancher\_admin\_token](#output\_rancher\_admin\_token) | Rancher admin API token (sensitive) |
| <a name="output_rancher_url"></a> [rancher\_url](#output\_rancher\_url) | Rancher UI URL |
<!-- END_TF_DOCS -->
