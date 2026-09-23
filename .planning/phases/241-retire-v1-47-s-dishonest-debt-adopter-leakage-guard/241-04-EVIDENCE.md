# Phase 241 Plan 04 — Composite-action pinning evidence

**Date:** 2026-09-23

## Measured guard surface

The production inventory contains 16 third-party action references: the two explicit release
workflows plus `.github/actions/*/action.yml`. The composite-action glob is a separate universe;
`@release_workflows` remains the two-file release-only list. The numeric floor is therefore 16.

## Reproducible direction proof

```bash
# Bare `uses:` fixture: a floating ref must fail after the optional-dash regex relaxation.
bash -c 'set -o pipefail; SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml MIX_ENV=test mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs > /tmp/241-04-bare.txt 2>&1; rc=$?; test "$rc" -ne 0; grep -q phase241-composite-unpinned-bare-uses /tmp/241-04-bare.txt'

# Dashed `uses:` fixture: the composite-action universe itself must be exercised independently.
bash -c 'set -o pipefail; SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml MIX_ENV=test mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs > /tmp/241-04-dashed.txt 2>&1; rc=$?; test "$rc" -ne 0; grep -q phase241-composite-unpinned-dashed-uses /tmp/241-04-dashed.txt'

# Real tree stays green; the live composite-action file is not mutated.
MIX_ENV=test mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs
git diff --exit-code -- .github/actions/example-playwright-boot/action.yml
```

Result: both fixture commands exit non-zero with their fixture path in the diagnostic; the real-tree
test passes 10 tests, 0 failures. The in-process pre-relaxation negative control proves the bare
fixture reference was invisible before the regex change.

## Scope boundary

This does not add a Dependabot `github-actions` entry for the composite action; that requires a
separately authorized change to the three-entry Dependabot contract. `ci.yml` action pins remain
outside this guard's scoped universe. The rejected alternative was mutating the real action under a
temporary stash: it would not leave a committed, repeatable RED proof.
