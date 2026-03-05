# rancher

L4 Rancher child module — bootstraps the Rancher admin user and registers the Hetzner Node Driver via the `rancher2` provider.

## Purpose

Handles post-bootstrap L4 concerns after Rancher is installed by RKE2 HelmController via cloud-init:

- **Admin bootstrap** — `rancher2_bootstrap` sets initial admin password and retrieves API token
- **Hetzner Node Driver** — `rancher2_node_driver` registers [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) with `privateCredentialFields` annotation for Cloud Credential support

> **Note**: cert-manager and Rancher Helm chart are deployed via RKE2 HelmChart CRDs in cloud-init (generated in root `main.tf`). This module only uses the `rancher2` provider — no `helm`, `kubernetes`, or `kubectl` providers.

## Usage

This module is called internally by the root module. Do not use it directly.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_rancher2"></a> [rancher2](#requirement\_rancher2) | >= 13.0.0 |
### Providers

| Name | Version |
|------|---------|
| <a name="provider_rancher2"></a> [rancher2](#provider\_rancher2) | >= 13.0.0 |
### Resources

| Name | Type |
|------|------|
| [rancher2_bootstrap.admin](https://registry.terraform.io/providers/rancher/rancher2/latest/docs/resources/bootstrap) | resource |
| [rancher2_node_driver.hetzner](https://registry.terraform.io/providers/rancher/rancher2/latest/docs/resources/node_driver) | resource |
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Initial password for the Rancher 'admin' user. | `string` | n/a | yes |
| <a name="input_hetzner_driver_version"></a> [hetzner\_driver\_version](#input\_hetzner\_driver\_version) | Version of the zsys-studio Hetzner Node Driver | `string` | n/a | yes |
| <a name="input_rancher_hostname"></a> [rancher\_hostname](#input\_rancher\_hostname) | Fully qualified domain name for the Rancher UI (e.g. 'rancher.example.com'). | `string` | n/a | yes |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_token"></a> [admin\_token](#output\_admin\_token) | Rancher admin API token for programmatic access. Treat as a secret. |
| <a name="output_rancher_url"></a> [rancher\_url](#output\_rancher\_url) | Rancher UI URL (HTTPS) |
<!-- END_TF_DOCS -->
