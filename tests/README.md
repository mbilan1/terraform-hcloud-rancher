# Tests

Unit tests for variable validations and cross-variable guardrails.

## Running

```bash
# All tests (~3s, no credentials required, $0 cost)
tofu test

# Single test file
tofu test -filter=tests/variables.tftest.hcl
tofu test -filter=tests/guardrails.tftest.hcl
```

## Test Files

| File | Tests | Scope |
|------|:-----:|-------|
| `variables.tftest.hcl` | 38 | Variable `validation {}` blocks (positive + negative) |
| `guardrails.tftest.hcl` | 13 | Cross-variable `check {}` blocks in `guardrails.tf` |

All tests use `mock_provider` — no cloud credentials needed, no infrastructure created.

## Quality Gate Pipeline

```
Gate 0 ─ Static Analysis     fmt · validate · tflint · Checkov · KICS · tfsec
Gate 1 ─ Unit Tests           variables · guardrails
Gate 2 ─ Integration          tofu plan against real providers (requires secrets)
Gate 3 ─ E2E                  tofu apply + smoke tests + destroy (manual only)
```

| Gate | Badge | Workflow | Trigger | Cost |
|:----:|-------|----------|---------|:----:|
| 0a | Lint: fmt | `lint-fmt.yml` | push + PR | $0 |
| 0a | Lint: validate | `lint-validate.yml` | push + PR | $0 |
| 0a | Lint: tflint | `lint-tflint.yml` | push + PR | $0 |
| 0b | SAST: Checkov | `sast-checkov.yml` | push + PR | $0 |
| 0b | SAST: KICS | `sast-kics.yml` | push + PR | $0 |
| 0b | SAST: tfsec | `sast-tfsec.yml` | push + PR | $0 |
| 1 | Unit: variables | `unit-variables.yml` | push + PR | $0 |
| 1 | Unit: guardrails | `unit-guardrails.yml` | push + PR | $0 |
| 2 | Integration: plan | `integration-plan.yml` | PR + manual | $0 (plan) |
| 3 | E2E: apply | `e2e-apply.yml` | Manual only | ~$5/run |
