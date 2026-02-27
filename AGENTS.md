# AI Agent Instructions

> **READ THIS ENTIRE FILE before touching any code.**
> This file provides mandatory context for AI coding assistants (GitHub Copilot, Claude, Cursor, etc.)
> working with the `terraform-hcloud-rancher` module.

---

## ⚠️ MANDATORY: Read ARCHITECTURE.md First

**Before making ANY change**, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) in full.

It contains:
- Two-phase deployment flow (L3 infrastructure → L4 Rancher)
- Dual load balancer design
- Provider flow (6 providers, bootstrap mode)
- Hetzner Node Driver integration
- Compromise Log with deliberate trade-offs
- Security model and known gaps

**If you skip ARCHITECTURE.md, you WILL break something.**

---

## What This Repository Is

An **OpenTofu/Terraform module** (NOT a root deployment) that deploys a **Rancher management cluster on Hetzner Cloud** with Hetzner Node Driver for downstream cluster provisioning.

- **IaC tool**: OpenTofu >= 1.7.0 — always use `tofu`, **never** `terraform`
- **Cloud provider**: Hetzner Cloud (EU data centers: Helsinki, Nuremberg, Falkenstein)
- **Kubernetes distribution**: RKE2 (via [terraform-hcloud-rke2](https://github.com/astract/terraform-hcloud-rke2))
- **Management plane**: Rancher (cert-manager + Helm chart + bootstrap)
- **OS**: Ubuntu 24.04 LTS
- **DNS**: AWS Route53 (optional)
- **Status**: Experimental — under active development

---

## Critical Rules

### NEVER do these:
1. **Do NOT run `tofu plan` in the root module** — root is a reusable module, not a deployment
2. **Do NOT run `tofu apply`** — provisions real cloud infrastructure and costs money
3. **Do NOT run `tofu destroy`** — destroys infrastructure
4. **Do NOT run `tofu init -upgrade`** — modifies `.terraform.lock.hcl` silently
5. **Do NOT change providers** without explicit user request AND live verification
6. **Do NOT modify `terraform.tfstate`** or `.terraform.lock.hcl` directly
7. **Do NOT commit secrets**, API keys, tokens, or private SSH keys
8. **Do NOT rewrite README.md** — it has auto-generated `terraform-docs` sections between markers
9. **Do NOT remove or modify the Compromise Log** in ARCHITECTURE.md without discussion
10. **A question is NOT a request to change code.**

### ALWAYS do these:
1. **Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** before any structural change
2. **Run `tofu validate`** after any `.tf` file change
3. **Run `tofu fmt -check`** to verify formatting
4. **Run `tofu test`** after changes to variables, guardrails, or conditional logic
5. **Preserve existing code comments** — they document deliberate compromises
6. **Read the relevant file before editing**
7. **Verify external claims via network** before making changes

### Where to run what

| Command | Root module (`/`) | `examples/*` directories |
|---------|:-:|:-:|
| `tofu validate` | ✅ Safe | ✅ Safe |
| `tofu fmt` | ✅ Safe | ✅ Safe |
| `tofu test` | ✅ Safe (uses mock_provider) | N/A |
| `tofu plan` | ❌ **Forbidden** | ✅ With credentials |
| `tofu apply` | ❌ **Forbidden** | ⚠️ Only with explicit user approval |
| `tofu destroy` | ❌ **Forbidden** | ⚠️ Only with explicit user approval |

---

## Repository Structure

### Root Terraform Files (Shim Layer)

| File | Purpose |
|------|---------|
| `main.tf` | Module calls (rke2_cluster + rancher) + ingress LB + DNS |
| `providers.tf` | Provider configs (hcloud, aws, helm, kubernetes, kubectl, rancher2) |
| `variables.tf` | All user-facing input variables |
| `outputs.tf` | Module outputs rewired from child modules |
| `versions.tf` | Provider version constraints + VERSION REGISTRY table |
| `guardrails.tf` | Preflight `check {}` blocks |

### Child Modules

#### `modules/rke2-cluster/` — L3 Infrastructure

Thin wrapper around `terraform-hcloud-rke2` that:
- Sources the rke2 module with management-cluster-specific defaults
- Hardcodes `harmony_enabled = false`, `agent_node_count = 0`, `cloud_provider_external = false`
- Exposes kubeconfig outputs for L4 provider configuration

#### `modules/rancher/` — L4 Kubernetes Management

| File | Purpose |
|------|---------|
| `main.tf` | cert-manager Helm + Rancher Helm + rancher2_bootstrap |
| `node-driver.tf` | Hetzner NodeDriver CRD + UIPlugin CRD |
| `variables.tf` | Rancher-specific inputs |
| `outputs.tf` | rancher_url, admin_token |
| `versions.tf` | required_providers (helm, kubernetes, kubectl, rancher2) |

### Other Directories

| Path | Purpose |
|------|---------|
| `docs/` | `ARCHITECTURE.md` — **READ BEFORE ANY WORK** |
| `examples/minimal/` | Minimal working deployment example |
| `tests/` | Unit tests (`tofu test`) |

---

## Architecture Constraints

### Two-Phase Deployment
```
Phase 1 (L3): module.rke2_cluster → Hetzner infra + RKE2 bootstrap → kubeconfig
Phase 2 (L4): module.rancher → cert-manager + Rancher Helm + bootstrap + NodeDriver
```

### Provider Flow (CRITICAL)
- L4 providers (helm, kubernetes, kubectl, rancher2) are configured with **outputs** from `module.rke2_cluster`
- This creates an apparent cyclic dependency but OpenTofu resolves it via deferred initialization
- The rancher2 provider runs in **bootstrap mode** (`bootstrap = true`, `insecure = true`)

### Dual Load Balancer
- **Control-plane LB**: Created by rke2 module (ports 6443, 9345)
- **Ingress LB**: Created in root `main.tf` (ports 80, 443 for Rancher UI)
- Do NOT merge them.

### RKE2 Module Dependency
- `modules/rke2-cluster/main.tf` sources `terraform-hcloud-rke2` via **local path** (`../../../terraform-hcloud-rke2`)
- This must be replaced with a git-tagged source URL before public release
- The rke2 module brings its own providers (known anti-pattern) — version pins in `versions.tf` MUST match

---

## Code Style and Conventions

Same as `terraform-hcloud-rke2`:

- **HCL formatting**: `tofu fmt` canonical style
- **Variable naming**: `snake_case`, grouped by concern
- **Comments**: `DECISION:`, `COMPROMISE:`, `WORKAROUND:`, `NOTE:`, `TODO:` prefixes
- **Outputs**: `sensitive = true` for credentials
- **`nullable = false`** on all variables
- **Exact version pins** (`= X.Y.Z`) for reproducibility

### Git Commit Convention

Conventional Commits format, English only:
```
<type>(<scope>): <short summary>
```
Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `style`, `test`, `ci`

---

## Common Pitfalls

1. **Root module is not runnable** — use `examples/` for plan/apply
2. **rancher2 provider in bootstrap mode** — only supports `rancher2_bootstrap` resource. Post-bootstrap resources need a second provider instance (not yet implemented)
3. **`initial_password` must match Helm `bootstrapPassword`** — the rancher2_bootstrap resource defaults `initial_password` to "admin", but the Helm chart sets a custom bootstrap password
4. **README.md has auto-generated sections** — do NOT edit between `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->`
5. **terraform.tfstate should NEVER be committed** — it is in `.gitignore`
6. **Local source path for rke2 module** — must be replaced with git URL before publishing
7. **Training data is stale** — always verify provider versions, chart versions, and server types via network
