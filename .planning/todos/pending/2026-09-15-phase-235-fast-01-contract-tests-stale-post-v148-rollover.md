---
created: 2026-09-15
source: Phase 236 plan 02 (Task 3, mix ci gate)
severity: medium
resolves_phase: unassigned
---

# Phase 235 FAST-01/GATE-05 source-complete contract tests are stale since the v1.48 rollover

`test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` and
`test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` assert that
`.planning/REQUIREMENTS.md` marks `FAST-01` and `GATE-05` as `[x]` complete. Those
requirement IDs belonged to the v1.47 CI-EFFICIENCY milestone. `.planning/REQUIREMENTS.md`
was replaced wholesale for the v1.48 CLEAN-BASELINE milestone at commit `cc6f17e4`
("docs: define milestone v1.48 requirements") — the new file has no `FAST-01` or
`GATE-05` entries at all, so both source-contract tests now fail unconditionally.

## How it was found

Discovered running `MIX_ENV=test mix ci` during Phase 236 plan 02 (audit URL ownership
fix). Confirmed pre-existing and unrelated to that plan's diff:

- `git log --oneline -1 -- test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs`
  → `cc4835c5` ("chore: close out v1.47 CI-EFFICIENCY (#241)") — last touched **before**
  the v1.48 requirements rollover.
- `git log --oneline -1 -- .planning/REQUIREMENTS.md` → `cc6f17e4`, `c5c65971`, then
  `34291dcd` (Phase 236 plan 01) — none of these are Phase 236 plan 02 commits.
- `git status --porcelain .planning/REQUIREMENTS.md` is clean under plan 02's diff.

So the break predates Phase 236 entirely and predates plan 02's work; `mix ci` has been
red on `main` since `cc6f17e4` merged, independent of the `Generated admin Playwright
smoke` flake that Phase 236 exists to fix.

## Failures observed

```
1) test authenticated strict pass is reconciled exactly into FAST-01 and its residual
   (Sigra.Planning.Phase235Fast01SourceCompleteContractTest)
   assert requirements =~ "- [x] **FAST-01**"

2) test completed ownership proof and contributor topology remain immutable
   (Sigra.Planning.Phase235Fast01SourceCompleteContractTest)
   assert length(Regex.scan(~r/^- \[x\] \*\*GATE-05\*\*:/m, requirements)) == 1
   left: 0, right: 1

3) test derived candidate stays non-authoritative while the later source-complete pass
   closes FAST-01 (Sigra.Planning.Phase235Fast01GapClosureContractTest)
```

## Options

1. Retire both test files as superseded-by-milestone-rollover — they asserted a
   point-in-time state of a REQUIREMENTS.md that no longer exists in this form once a
   milestone closes and rolls to the next. Record the retirement as a decision, not a
   silent delete.
2. Rewrite them to assert against `.planning/archive/` (or wherever v1.47's closed
   REQUIREMENTS.md snapshot lives, if one is archived), so the contract still proves
   something about the CLOSED milestone's completion record rather than the live file.
3. Do nothing until whichever future phase owns "clean up stale phase-numbered
   `test/sigra/planning/*.exs` contract tests" — precedent: `204-02` deleted
   `phase_192_known_failure_contract_test.exs` once its subject was fully resolved.

Not fixed in Phase 236 plan 02: out of that plan's file scope
(`lib/sigra/admin/live/audit_index_live.ex` +
`test/sigra/planning/phase_236_audit_url_ownership_test.exs` only) and unrelated to its
GREEN-02 objective.
