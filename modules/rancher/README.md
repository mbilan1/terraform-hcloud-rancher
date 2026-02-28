# rancher

L4 Kubernetes management child module — installs cert-manager, Rancher (Helm), bootstraps admin user, and optionally registers the Hetzner Node Driver.

## Purpose

Handles all Kubernetes-level (L4) concerns for the Rancher management cluster:

- **cert-manager** — TLS certificate lifecycle management
- **Rancher** — management plane Helm chart installation
- **Admin bootstrap** — initial `admin` user password and API token
- **Hetzner Node Driver** — [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) CRDs for downstream Hetzner cluster provisioning

## Usage

This module is called internally by the root module. Do not use it directly.

The `helm`, `kubernetes`, `kubectl`, and `rancher2` providers must be configured in the root module with kubeconfig credentials from the L3 rke2-cluster module.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.0 |
| <a name="requirement_rancher2"></a> [rancher2](#requirement\_rancher2) | >= 13.0.0 |
### Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0.0 |
| <a name="provider_rancher2"></a> [rancher2](#provider\_rancher2) | >= 13.0.0 |
### Resources

| Name | Type |
|------|------|
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.rancher](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.hetzner_node_driver](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.hetzner_ui_extension](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [rancher2_bootstrap.admin](https://registry.terraform.io/providers/rancher/rancher2/latest/docs/resources/bootstrap) | resource |
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Initial password for the Rancher 'admin' user. | `string` | n/a | yes |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | cert-manager Helm chart version. | `string` | n/a | yes |
| <a name="input_hetzner_driver_version"></a> [hetzner\_driver\_version](#input\_hetzner\_driver\_version) | Version of zsys-studio/rancher-hetzner-cluster-provider. | `string` | n/a | yes |
| <a name="input_rancher_hostname"></a> [rancher\_hostname](#input\_rancher\_hostname) | Fully qualified domain name for the Rancher UI (e.g. 'rancher.example.com'). | `string` | n/a | yes |
| <a name="input_rancher_version"></a> [rancher\_version](#input\_rancher\_version) | Rancher Helm chart version. | `string` | n/a | yes |
| <a name="input_install_hetzner_driver"></a> [install\_hetzner\_driver](#input\_install\_hetzner\_driver) | Install the zsys-studio Hetzner Node Driver and UI Extension. | `bool` | `true` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email address for Let's Encrypt certificate registration. Required only when tls\_source = 'letsEncrypt'. | `string` | `""` | no |
| <a name="input_tls_source"></a> [tls\_source](#input\_tls\_source) | TLS certificate source for Rancher: 'rancher' (self-signed), 'letsEncrypt', or 'secret'. | `string` | `"rancher"` | no |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_token"></a> [admin\_token](#output\_admin\_token) | Rancher admin API token for programmatic access. Treat as a secret. |
| <a name="output_rancher_url"></a> [rancher\_url](#output\_rancher\_url) | Rancher UI URL (HTTPS) |
<!-- END_TF_DOCS -->
