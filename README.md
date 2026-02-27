# terraform-hcloud-rancher

An **OpenTofu/Terraform module** that deploys a production-oriented **Rancher management cluster on Hetzner Cloud** with built-in Hetzner Node Driver for downstream cluster provisioning via the Rancher UI.

> **Status**: Experimental — under active development, not production-ready

## Features

- **Single `tofu apply`** — provisions RKE2 cluster, installs cert-manager, Rancher, bootstraps admin, installs Hetzner Node Driver
- **Zero SSH post-bootstrap** — no SSH provisioners after cloud-init completes (inherited from [terraform-hcloud-rke2](https://github.com/astract/terraform-hcloud-rke2))
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
  source = "github.com/astract/terraform-hcloud-rancher"

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
<!-- END_TF_DOCS -->

## License

[MIT](LICENSE) — Copyright (c) 2026 Maksym Bilan
