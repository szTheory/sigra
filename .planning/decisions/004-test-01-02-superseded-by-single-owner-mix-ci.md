# ADR 004: TEST-01/TEST-02 are superseded by the single-owner `mix ci` topology

**Status:** Accepted
**Date:** 2026-09-22
**Context:** Phase 241 (v1.48 CLEAN-BASELINE) — retire the v1.47 timing-receipt formatter and record the guarantee that replaces its unowned measurement surface.

## The problem

`Sigra.CI.ExUnitTimingFormatter` was a per-test timing formatter, but no leg of the `mix ci`
alias named it. A measurement apparatus that no command invokes makes no measurement, so its
module and its unit test could pass while asserting nothing about the library suite. Retaining it
would misrepresent the CI topology; deleting it without a decision record would instead hide the
effect on branches that still carry the former wiring.

## Decision

TEST-01 and TEST-02 are superseded. The orphaned formatter and its test are deleted; the `mix ci`
alias and the Phase 233 alias contract remain unchanged. The replacement is an assertion of the
topology's derived guarantee, not a snapshot of the current workflow shape.

## Replacement guarantee

The `mix ci` topology guarantees **exactly one owner of the full library suite**. Plan 241-02
asserts that guarantee as a derived property: across the `library_tests*` job bodies there is one
`MIX_ENV=test mix ci` invocation and none invokes bare `mix test`. It does not restate HEAD's
`ci.yml` shape as the requirement; this ADR supplies the decision that makes the property the
replacement guarantee.

## Affected refs

The 2026-09-22 pre-delete sweep iterated every local and remote head and filtered out
`test/support` and `.planning` paths. It found the following ten refs carrying a live consumer of
`SIGRA_EXUNIT_TIMING_PATH` outside those directories:

| Ref | Affected paths |
| --- | --- |
| `refs/heads/agent-exec-235-1-04-evidence` | `.github/workflows/ci.yml`; `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `test/sigra/planning/phase_233_library_economics_contract_test.exs`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/heads/agent-exec-235-1-12-evidence` | `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `scripts/ci/library-partitions.sh`; `scripts/ci/library-partitions.test.sh`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/heads/agent-exec-235-1-18-evidence` | `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `scripts/ci/library-partitions.sh`; `scripts/ci/library-partitions.test.sh`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/heads/agent-exec-235-1-29-authority` | `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `scripts/ci/library-partitions-portability.test.sh`; `scripts/ci/library-partitions.sh`; `scripts/ci/library-partitions.test.sh`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/heads/ci/phase-235-1-evidence` | `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `scripts/ci/library-partitions.sh`; `scripts/ci/library-partitions.test.sh`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/heads/ci/phase-235-16-source-complete` | `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `scripts/ci/library-partitions-portability.test.sh`; `scripts/ci/library-partitions.sh`; `scripts/ci/library-partitions.test.sh`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/heads/gsd/phase-232-playwright-economics` | `.github/workflows/ci.yml`; `test/sigra/planning/phase_233_library_economics_contract_test.exs` |
| `refs/remotes/origin/ci/phase-235-1-evidence` | `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `scripts/ci/library-partitions-portability.test.sh`; `scripts/ci/library-partitions.sh`; `scripts/ci/library-partitions.test.sh`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/remotes/origin/ci/phase-235-16-source-complete` | `.github/workflows/ci.yml`; `scripts/ci/library-economics.sh`; `scripts/ci/library-economics.test.sh`; `test/sigra/planning/phase_233_library_economics_contract_test.exs`; `test/sigra/planning/phase_235_1_library_economics_contract_test.exs` |
| `refs/remotes/origin/gsd/phase-232-playwright-economics` | `.github/workflows/ci.yml`; `test/sigra/planning/phase_233_library_economics_contract_test.exs` |

A cherry-pick from any listed ref will fail `compile --warnings-as-errors` against the deleted
module for a reason unrelated to its own diff. That failure is intentional and visible: a
consumer-bearing branch must be rebased or have its obsolete timing wiring removed, not silently
merged as if the deleted module still existed.

## Consequences

- The only source files removed are the unused timing formatter and its test; `mix ci` retains its
  existing seven-leg topology.
- The former timing receipts are no longer presented as CI evidence.
- The affected branches are deliberately not repaired in this phase; their stale consumers remain
  explicit in the table above.

## Revisit triggers

Revisit this decision only if Sigra again needs timing receipts and first assigns them to a real,
single CI owner with a fail-first proof, or if an affected branch is promoted for merge and needs a
scoped migration. Any amendment is made in place with a dated, explicit retraction rather than a
silent edit.
