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
| `variables.tftest.hcl` | 23 | Variable `validation {}` blocks (positive + negative) |
| `guardrails.tftest.hcl` | 12 | Cross-variable `check {}` blocks in `guardrails.tf` |

All tests use `mock_provider` — no cloud credentials needed, no infrastructure created.
