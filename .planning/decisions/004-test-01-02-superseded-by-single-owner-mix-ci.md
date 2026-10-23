# ADR 004: TEST-01/TEST-02 are superseded by the single-owner `mix ci` topology

**Status:** Accepted
**Date:** 2026-09-19
**Context:** Phase 241 (v1.48 CLEAN-BASELINE) — retiring a formatter and formatter test that no alias leg names, while preserving the existing single-owner library-suite topology.

## The problem

TEST-01/TEST-02 depended on a per-test timing formatter. The current `mix ci` alias does not name
that formatter, so the formatter is a measurement apparatus with no measurement: it compiles from
`test/support` but no alias leg invokes it. Leaving that dead mechanism in place makes the old
guarantees look enforced when they are not.

Deleting it silently would be dishonest too. Live historical refs still carry non-`test/support`
consumers of `SIGRA_EXUNIT_TIMING_PATH`; an otherwise independent cherry-pick from one of those
refs would fail `compile --warnings-as-errors` against the deleted module.

## Decision

TEST-01/TEST-02 are superseded. Delete only
`test/support/ci/ex_unit_timing_formatter.ex` and
`test/support/ci/ex_unit_timing_formatter_test.exs`; do not alter the `mix ci` alias or the Phase
233 alias-contract test. The replacement is a recorded topology guarantee, not a rewrite that makes
a test describe whatever HEAD happens to look like.

## Replacement guarantee

The guarantee the `mix ci` topology provides is **exactly one owner of the full library suite**.
Plan 241-02 asserts that guarantee as a derived property, rather than as a restatement of HEAD's
`ci.yml` shape. This ADR records why that assertion is legitimate: the retired formatter was never
an active alias leg, and its former TEST-01/TEST-02 role is replaced by a real owner invariant.

## Affected refs

The 2026-09-19 all-ref sweep found these ten refs carrying a live non-`test/support` consumer of
`SIGRA_EXUNIT_TIMING_PATH`. A cherry-pick from any of them will fail
`compile --warnings-as-errors` against a deleted module for a reason unrelated to its own diff.

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

## Consequences

- The source tree no longer carries a formatter that no current alias invokes.
- The `mix ci` alias remains byte-for-byte the established single-owner topology.
- Future work that cherry-picks one of the affected refs must remove or rework its obsolete timing
  consumer as part of that change; this ADR makes that incompatibility explicit rather than silent.
- Plan 241-02 owns the replacement assertion and must prove its failure direction before accepting
  it.

## Revisit triggers

Revisit this decision if the library suite gains another owner, if a `mix ci` alias leg invokes a
new formatter, or if an affected historical ref is intentionally revived. Amendments follow the
dated, in-place retraction style established by ADR 003; this record is not silently rewritten.
