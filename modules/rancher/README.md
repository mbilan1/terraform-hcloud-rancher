# rancher

L4 Rancher child module — bootstraps the Rancher admin user via the `rancher2` provider.

## Purpose

Handles admin bootstrap after Rancher is installed by RKE2 HelmController via cloud-init:

- **Admin bootstrap** — `rancher2_bootstrap` sets initial admin password and retrieves API token

> **Note**: cert-manager, Rancher Helm chart, Hetzner Node Driver, and UI Plugin are all deployed via RKE2 cloud-init manifests (generated in root `main.tf`). This module only performs admin bootstrap via the `rancher2` provider — no `helm`, `kubernetes`, or `kubectl` providers.

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
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Initial password for the Rancher 'admin' user. | `string` | n/a | yes |
| <a name="input_rancher_hostname"></a> [rancher\_hostname](#input\_rancher\_hostname) | Fully qualified domain name for the Rancher UI (e.g. 'rancher.example.com'). | `string` | n/a | yes |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_token"></a> [admin\_token](#output\_admin\_token) | Rancher admin API token for programmatic access. Treat as a secret. |
<!-- END_TF_DOCS -->
