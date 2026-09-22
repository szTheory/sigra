---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
plan: "13"
status: complete
requirements-completed: [REL-05, REL-06]
completed: 2026-09-22
---

# Phase 242 Plan 13 Summary

Shifted public adopter safety from a brittle registry-mutation workflow to version constraints,
documentation, and deterministic repository tests.

- Removed `.github/workflows/hex-remediate-phantom.yml`, its workflow-specific p22 guard, and its
  three fixtures. No secret-bearing remediation workflow remains dispatchable from the repository.
- Updated all ten surfaced Sigra install snippets from `{:sigra, "~> 1.4.0"}` to the maintained
  bounded `{:sigra, "~> 1.5.0"}` line.
- Updated installation guidance to state the `>= 1.5.0 and < 1.6.0` boundary and clarify that
  retirement is advisory rather than a resolver or lockfile repair.
- Added `phase_242_shift_left_contract_test.exs`, which requires the exact bounded tuple in every
  owned public entry point and proves the retired mutation workflow/guard paths are absent.

## Verification

- `MIX_ENV=test mix test test/sigra/planning/phase_242_shift_left_contract_test.exs` — 2 passed.
- `MIX_ENV=dev mix docs --warnings-as-errors` — passed.
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 93 passed.
- CI run [`35717152713`](https://github.com/szTheory/sigra/actions/runs/35717152713) — passed.
- PR [#258](https://github.com/szTheory/sigra/pull/258) squash-merged as
  `2bbc8afb874af79e05708c603bdc4876e108e40b`.

The historical retirement attempts remain documented in Plans 03, 10, and 12. Any future registry
hygiene work requires its own human-owned decision and must not become a release or adopter-safety
gate.
