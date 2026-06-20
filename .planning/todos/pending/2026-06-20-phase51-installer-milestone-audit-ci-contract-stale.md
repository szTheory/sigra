---
created: 2026-06-20T00:00:00.000Z
status: pending
title: Phase51 installer-golden CI-contract test asserts a job (installer_milestone_audit:) that Phase 194 folded into fast_checks
area: test
files:
  - test/sigra/planning/phase_51_install_golden_ci_contract_test.exs
source: phase 195 Wave 1 post-merge gate (execute-phase) — full `mix test` surfaced 6 failures; this one isolated to a Phase-194 contract drift, not a Phase-195 regression
---

## What

`Sigra.Planning.Phase51InstallGoldenCiContractTest` (test/sigra/planning/phase_51_install_golden_ci_contract_test.exs:20)
asserts `yml =~ "installer_milestone_audit:"` against `.github/workflows/ci.yml`.
That string no longer exists as a job key — the assertion fails.

## Why this is NOT a phase-195 regression

Phase 194 (commit `4c9226ed` — "fold 6 leaf guard jobs into fast_checks + rewire
ci-gate (CACHE-02)") removed the standalone `installer_milestone_audit:` job and
folded it into a named *step* inside `fast_checks` ("Installer milestone audit
(INT-01..03)" running `scripts/ci/installer-milestone-audit.sh`).

Verified at the immediate pre-195 baseline (`a0b3cbd2`): `ci.yml` already had
**0** occurrences of `installer_milestone_audit:` — the test was already failing
before Phase 195 began. Phase 195 touched only the `library_tests*` region of
ci.yml (plus test tags/async/guides) and did not modify this test file.

## Fix direction

Update the Phase51 contract test to anchor on the new fast_checks step rather than
the removed job key — e.g. assert the `fast_checks` job contains the
`Installer milestone audit` step / `scripts/ci/installer-milestone-audit.sh` run,
preserving the original intent (the installer milestone audit still runs in CI).
Confirm against `MAINTAINING.md §Installer golden CI contract`. Likely a sibling
debt: re-audit the other Phase-5x `*_ci_contract_test.exs` locks for the same
Phase-194 job→step fold.
