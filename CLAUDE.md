# Claude Instructions — terraform-hcloud-rancher

> Single source of truth for AI agents working on this repository.
> AGENTS.md redirects here. Read this file in full before any task.

---

## ⚠️ MANDATORY: Read ARCHITECTURE.md First

**Before making ANY change**, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) in full.

It contains:
- Deployment flow (L3 infrastructure + L4 via cloud-init + bootstrap)
- Dual load balancer design (BYO ingress LB)
- Provider flow (2 providers: hcloud + rancher2)
- Hetzner Node Driver integration (cloud-init manifests)
- Compromise Log with deliberate trade-offs
- Security model (True Zero-SSH)

**If you skip ARCHITECTURE.md, you WILL break something.**

---

## What This Repository Is

An **OpenTofu/Terraform module** (NOT a root deployment) that deploys a **Rancher management cluster on Hetzner Cloud** with Hetzner Node Driver for downstream cluster provisioning.

- **IaC tool**: OpenTofu >= 1.8.0 — always use `tofu`, **never** `terraform`
- **Cloud provider**: Hetzner Cloud (EU data centers: Helsinki, Nuremberg, Falkenstein)
- **Kubernetes distribution**: RKE2 (via the `terraform-hcloud-rke2-core` module)
- **Management plane**: Rancher (cert-manager + Rancher via cloud-init HelmChart CRDs + rancher2_bootstrap)
- **OS**: Ubuntu 24.04 LTS
- **DNS**: sslip.io by default, BYO DNS (Route53, Cloudflare, etc.) via `rancher_hostname`
- **Providers**: 2 only — `hcloud` + `rancher2` (no helm, kubernetes, kubectl, or aws)
- **Status**: Experimental — under active development

---

## Sibling Repositories

| Repo | Purpose |
|---|---|
| `terraform-hcloud-rke2-core` | L3 infrastructure primitive used by this module |
| `rke2-hetzner-architecture` | Architecture decisions + investigation reports |
| `rancher-hetzner-cluster-templates` | Downstream cluster Helm templates |

---

## Quick Reference

- **57 tests**, mock_provider, ~3s, $0: `tofu test`
- **Validate**: `tofu validate` (safe, always run after edits)
- **Format**: `tofu fmt` (safe, auto-fix)
- **NEVER**: `tofu plan` in root, `tofu apply`, `tofu destroy`, `tofu init -upgrade`

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

### Root Terraform Files (Facade Layer)

| File | Purpose |
|------|---------|
| `main.tf` | BYO LB + cloud-init manifests + module calls (rke2_cluster + rancher) |
| `providers.tf` | Provider configs (hcloud + rancher2 only) |
| `variables.tf` | All user-facing input variables |
| `outputs.tf` | Module outputs |
| `versions.tf` | Provider version constraints + VERSION REGISTRY table |
| `guardrails.tf` | Preflight `check {}` blocks |
| `moved.tf` | State migration blocks (singleton → for_each) |

### Child Modules

#### `modules/rke2-cluster/` — L3 Infrastructure

Thin wrapper around `terraform-hcloud-rke2-core` that:
- Sources rke2-core with management-cluster-specific defaults
- Passes `extra_server_manifests` for L4 software (cert-manager, Rancher, NodeDriver, UIPlugin, Cluster Autoscaler, Image Controller)
- Sets `delete_protection = true` for production safety
- Outputs: `network_id`, `initial_master_ipv4`, `cluster_ready`

#### `modules/rancher/` — L4 Rancher Bootstrap

| File | Purpose |
|------|---------|
| `main.tf` | `rancher2_bootstrap` only (admin password, server URL, telemetry) |
| `variables.tf` | `rancher_hostname` + `admin_password` |
| `outputs.tf` | `admin_token` |
| `versions.tf` | `required_providers` (rancher2 only) |

### Other Directories

| Path | Purpose |
|------|---------|
| `docs/` | `ARCHITECTURE.md` — **READ BEFORE ANY WORK** |
| `examples/minimal/` | Minimal working deployment example |
| `tests/` | Unit tests (`tofu test`) |

---

## Architecture Constraints

### Deployment Flow
```
L3: module.rke2_cluster → Hetzner infra + RKE2 + cloud-init manifests (cert-manager, Rancher, NodeDriver, UIPlugin, Cluster Autoscaler, Image Controller)
L4: module.rancher → rancher2_bootstrap (admin password + server URL)
```
All L4 software is deployed via cloud-init HelmChart CRDs and raw manifests — no helm/kubernetes/kubectl providers.

### Provider Model (2 providers only)
- **hcloud**: Hetzner Cloud infrastructure (servers, LBs, networks, firewalls)
- **rancher2**: Bootstrap mode only (`bootstrap = true`, `insecure = true`) — sets admin password
- No helm, kubernetes, kubectl, or aws providers

### DNS / Hostname
- **Default**: sslip.io auto-hostname from ingress LB IP (zero DNS setup)
- **Production**: Pass `rancher_hostname` with a real FQDN (Route53, Cloudflare, etc.)
- DNS is **BYO** — the module does NOT manage DNS records

### Dual Load Balancer (BYO pattern)
- **Control-plane LB**: Created by rke2-core (ports 6443, 9345)
- **Ingress LB**: Created in root `main.tf` with `for_each` gating (ports 80, 443 for Rancher UI)
- Set `create_ingress_lb = false` + `existing_ingress_lb_ipv4` for BYO
- Do NOT merge them (ADR-003).

### RKE2 Module Dependency
- `modules/rke2-cluster/main.tf` sources `terraform-hcloud-rke2-core` via git commit hash pin
- rke2-core is a proper module — no internal provider blocks, pure L3
- True Zero-SSH: no SSH keys, no port 22, no kubeconfig output (ADR-002)

---

## Code Style and Conventions

Same as `terraform-hcloud-rke2-core`:

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

### Comment Prefixes

```hcl
# DECISION: <what was decided>
# Why: <rationale>
# See: <link>

# COMPROMISE: <trade-off>
# Why: <reason ideal isn't possible>

# WORKAROUND: <what bug this works around>
# TODO: Remove when <condition>

# NOTE: <non-obvious context>
# TODO: <planned improvement>
```

---

## Workflow: Editing Variables

1. Edit `variables.tf` (root or child module)
2. Add/update `validation {}` block if needed
3. Add test case in `tests/variables.tftest.hcl` (positive + negative)
4. If cross-variable: add `check {}` in `guardrails.tf` + test in `tests/guardrails.tftest.hcl`
5. Run: `tofu validate && tofu test`

---

## Common Pitfalls

1. **Root module is not runnable** — use `examples/` for plan/apply
2. **rancher2 provider in bootstrap mode** — only supports `rancher2_bootstrap` resource. Post-bootstrap resources need a second provider instance (not yet implemented)
3. **`initial_password` must match Helm `bootstrapPassword`** — the rancher2_bootstrap resource defaults `initial_password` to "admin", but the Helm chart sets a custom bootstrap password
4. **README.md has auto-generated sections** — do NOT edit between `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->`
5. **terraform.tfstate should NEVER be committed** — it is in `.gitignore`
6. **rke2-core module pinned by commit hash** — update hash in `modules/rke2-cluster/main.tf` + run `tofu init` when upgrading
7. **Training data is stale** — always verify provider versions, chart versions, and server types via network

---

## Architecture Knowledge Base

Full architectural context is maintained in a separate repository:
- **Repo**: [rke2-hetzner-architecture](https://github.com/mbilan1/rke2-hetzner-architecture)
- Contains: ADRs, investigation reports, design documents
- Read it for platform-wide context that spans multiple repos

---

## Workflow: Updating Version Badges

README.md contains version badges (shields.io) that must stay in sync with `versions.tf`.

| Badge | Source of truth | Badge URL parameter |
|---|---|---|
| OpenTofu | `versions.tf` → `required_version` | `OpenTofu-<version>` |
| hcloud | `versions.tf` → `required_providers.hcloud.version` | `hcloud-<version>` |
| rancher2 | `versions.tf` → `required_providers.rancher2.version` | `rancher2-<version>` |
| random | `versions.tf` → `required_providers.random.version` | `random-<version>` |
| RKE2 | `variables.tf` → `rke2_version` default | `RKE2-<version>` |

When bumping a provider version:
1. Update `versions.tf`
2. Update the matching badge URL in README.md (search for `img.shields.io/badge/<name>`)
3. Run `tofu validate && tofu test`

---

## Language

- **Code & comments**: English
- **Commits**: English, Conventional Commits
- **User communication**: respond in the user's language
