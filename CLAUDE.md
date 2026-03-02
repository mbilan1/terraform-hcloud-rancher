# Claude Instructions — terraform-hcloud-rancher

> Claude-specific context. Read [AGENTS.md](AGENTS.md) first — it contains the universal rules.
> This file adds Claude-specific workflow patterns and deep architectural context.

---

## Quick Reference

- **Validate**: `tofu validate` (safe, always run after edits)
- **Format**: `tofu fmt` (safe, auto-fix)
- **Test**: `tofu test` (safe, mock_provider)
- **NEVER**: `tofu plan` in root, `tofu apply`, `tofu destroy`, `tofu init -upgrade`

---

## Architecture Knowledge Base

Platform-wide decisions are documented in a separate repository:
- **Repo**: [rke2-hetzner-architecture](https://github.com/mbilan1/rke2-hetzner-architecture)
- Contains: ADRs (5), investigation reports (3), design documents (2)
- Key ADRs: Project Structure (001), Cluster Templates for downstream (004), Shared Network (005)

---

## Two-Phase Deployment Flow

```
Phase 1 (L3): module.rke2_cluster
  └─ terraform-hcloud-rke2 (v1 child module via git source)
  └─ Produces: kubeconfig, control_plane_lb_ipv4, network_id

Phase 2 (L4): module.rancher (depends on Phase 1 outputs)
  ├─ cert-manager Helm release
  ├─ Rancher Helm release
  ├─ rancher2_bootstrap (bootstrap mode)
  └─ Hetzner Node Driver (kubectl_manifest)
      ├─ NodeDriver CRD (Go binary URL)
      └─ UIPlugin CRD (Vue 3 extension URL)

Root main.tf also creates:
  ├─ Ingress LB (hcloud_load_balancer — ports 80, 443)
  └─ DNS record (aws_route53_record — optional)
```

---

## Provider Flow (6 Providers)

| Provider | Source | Purpose | Config Source |
|---|---|---|---|
| `hcloud` | `hetznercloud/hcloud` | Hetzner infra + ingress LB | `var.hcloud_token` |
| `aws` | `hashicorp/aws` | Route53 DNS (optional) | AWS env vars |
| `helm` | `hashicorp/helm` | cert-manager + Rancher charts | `module.rke2_cluster` kubeconfig |
| `kubernetes` | `hashicorp/kubernetes` | K8s resources | `module.rke2_cluster` kubeconfig |
| `kubectl` | `gavinbunney/kubectl` | Raw manifest application | `module.rke2_cluster` kubeconfig |
| `rancher2` | `rancher/rancher2` | Bootstrap + post-bootstrap | Rancher URL + bootstrap token |

**Critical**: L4 providers (helm, kubernetes, kubectl, rancher2) get their config from Phase 1 outputs. OpenTofu handles this via deferred provider initialization.

### rancher2 Bootstrap Mode
```hcl
provider "rancher2" {
  api_url   = "https://${var.rancher_hostname}"
  bootstrap = true    # Only rancher2_bootstrap resource works
  insecure  = true    # Self-signed cert during bootstrap
}
```
Post-bootstrap resources (clusters, catalogs) need a **second provider instance** with the admin token. Not yet implemented.

---

## Key Patterns

### Ingress LB in Root (NOT in rke2 module)
```hcl
# Root main.tf creates ingress LB separately
resource "hcloud_load_balancer" "ingress" { ... }
resource "hcloud_load_balancer_target" "ingress" { ... }
resource "hcloud_load_balancer_service" "http" { ... }
resource "hcloud_load_balancer_service" "https" { ... }
```
The rke2 child module creates only the CP LB. Ingress LB is root's responsibility.

### Node Driver via kubectl_manifest
```hcl
# modules/rancher/node-driver.tf
resource "kubectl_manifest" "hetzner_node_driver" {
  yaml_body = yamlencode({
    apiVersion = "management.cattle.io/v3"
    kind       = "NodeDriver"
    # zsys-studio/rancher-hetzner-cluster-provider binary URL
  })
}
resource "kubectl_manifest" "hetzner_ui_plugin" {
  yaml_body = yamlencode({
    apiVersion = "catalog.cattle.io/v1"
    kind       = "UIPlugin"
    # zsys-studio Vue 3 extension
  })
}
```

### Variable Grouping
Variables are organized by concern:
1. **Credentials** — `hcloud_token`, `rancher_initial_password`
2. **Rancher config** — `rancher_hostname`, `rancher_version`, `cert_manager_version`
3. **Driver** — `hetzner_driver_version`, `hetzner_ui_extension_version`
4. **Infrastructure** — `cluster_name`, `master_server_type`, `location`
5. **Network** — `network_cidr`, `subnet_cidr`
6. **Security** — `ssh_key_ids`

---

## What NOT to Touch

1. **Dual LB** — CP LB (rke2 module) + Ingress LB (root). Never merge (ADR-003)
2. **rancher2 bootstrap mode** — don't add post-bootstrap resources without second provider
3. **rke2 module source** — currently git URL, will migrate to rke2-core. Don't change without explicit request
4. **Node Driver CRDs** — zsys-studio URLs. Verify versions live before updating
5. **PASSWORD SYNC** — `rancher_initial_password` var → Helm `bootstrapPassword` → rancher2_bootstrap `initial_password`. All three MUST match

---

## Downstream Clusters (Context)

This module does NOT create downstream clusters. Downstream provisioning uses:
- **Rancher Cluster Templates** (Helm charts in `rancher-hetzner-cluster-templates` repo)
- **HetznerConfig CRD** (`rke-machine-config.cattle.io/v1`) — 15 camelCase fields
- **`rancher2_machine_config_v2`** — does NOT support Hetzner (hardcoded Go switch)
- See ADR-004 and DES-001 in `rke2-hetzner-architecture`

The `network_id` output from this module is designed to be passed to downstream templates for shared networking (ADR-005).

---

## Workflow: Updating Driver Versions

1. Check live: `https://github.com/zsys-studio/rancher-hetzner-cluster-provider/releases`
2. Update `variable "hetzner_driver_version"` default
3. Update `variable "hetzner_ui_extension_version"` default
4. Verify binary URL pattern hasn't changed
5. `tofu validate && tofu test`

## Workflow: Updating Rancher/cert-manager

1. Check live: ArtifactHub or GitHub releases
2. Update version default in `variables.tf`
3. Check if Helm values schema changed (breaking changes)
4. `tofu validate && tofu test`

---

## Language

- **Code & comments**: English
- **Commits**: English, Conventional Commits
- **User communication**: respond in the user's language
