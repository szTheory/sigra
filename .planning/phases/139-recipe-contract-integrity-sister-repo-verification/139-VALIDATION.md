---
phase: 139
slug: recipe-contract-integrity-sister-repo-verification
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
validated: 2026-05-29
---

# Phase 139 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Signed off post-execution at milestone close — the pre-execution draft below
> is now reconciled against delivered artifacts (139-VERIFICATION.md 8/8 passed;
> fixture green live).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/sigra/recipes/companion_lib_contract_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~2 seconds (fixture only; pure filesystem, `async: true`, no DB) |

Recipe-fix verification (RCV-01/RCV-02) additionally uses `mix docs --warnings-as-errors`.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/recipes/companion_lib_contract_test.exs`
- **After every plan wave:** Run `mix test` (full suite, requires live Postgres per CLAUDE.md)
- **After recipe edits (RCV-01/RCV-02):** Run `mix docs --warnings-as-errors` — must exit 0
- **Before `/gsd-verify-work`:** Full suite must be green AND `mix docs --warnings-as-errors` clean
- **Max feedback latency:** ~2 seconds for the fixture; full suite as usual

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 139-01-01 | 01 | 1 | RCT-01 | — | N/A (docs-contract) | unit | `mix test test/sigra/recipes/companion_lib_contract_test.exs` | ✅ | ✅ green |
| 139-01-02 | 01 | 1 | RCT-01 | — | Fixture fails when a marker is removed (drift caught) | unit (negative) | manual remove-marker → assert red → revert | ✅ | ✅ green (performed: removing `## Failure modes` from accrue.md produced the named failure, green on revert — SUMMARY 01) |
| 139-01-03 | 01 | 1 | RCT-01 | — | Fixture fails when glob is empty (D-05) | unit | `mix test test/sigra/recipes/companion_lib_contract_test.exs` | ✅ | ✅ green (standalone D-05 guard test at fixture line 25, distinct from the marker sweep) |
| 139-02-01 | 02 | 1 | RCV-01 | — | `lockspire.md` example returns `{:ok, account}`/`{:error, :not_found}` | docs/source | `mix docs --warnings-as-errors` + RCT-01 fixture | ✅ | ✅ green (verified vs Lockspire `def616d`; lockspire.md:93-97 `case` shape) |
| 139-02-02 | 02 | 1 | RCV-02 | — | `rulestead.md` declares `@behaviour Rulestead.Admin.Policy` + `@impl can?/4` | docs/source | `mix docs --warnings-as-errors` + RCT-01 fixture | ✅ | ✅ green (verified vs Rulestead `0a18360`; rulestead.md:142 `@behaviour`, :148 `@impl`) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Note: RCV-01/RCV-02 are documentation-correctness fixes verified against cited sister-repo source (Lockspire v1.2.0 `def616d`; Rulestead v0.1.3 `0a18360`) — the verification is the cited reference + clean docs build, not a new runtime test. The RCT-01 fixture re-asserts structural integrity over the edited recipes.*

---

## Wave 0 Requirements

- [x] `test/sigra/recipes/companion_lib_contract_test.exs` — pure-ExUnit fixture for RCT-01. **Created and green** (44 lines, two `test` blocks, `use ExUnit.Case, async: true`, globs 6 recipes × 5 markers). Live run: 2 tests, 0 failures.

*ExUnit infrastructure already exists. The only "missing" file was the fixture itself (the Wave 1 deliverable), now created and passing. No `conftest`-equivalent or framework install required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drift is caught at merge time (Success Criteria #2) | RCT-01 | Negative test proves the fixture's value but should not ship as a permanent failing test | Temporarily remove one required marker from one recipe, run the fixture, confirm it fails with a message naming the recipe + missing marker, then revert. Document the observed failure in the task evidence. |

*All other phase behaviors have automated verification via the fixture and `mix docs --warnings-as-errors`.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (fixture file created + green)
- [x] No watch-mode flags
- [x] Feedback latency < 5s for fixture
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-05-29 — signed off post-execution at milestone close; all 5 task-map rows green, fixture passes live (2 tests, 0 failures), RCV-01/RCV-02 verified against cited sister-repo commits. 0 gaps.

---

## Validation Audit 2026-05-29

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

State-A finalization: the pre-execution draft was never signed off post-execution despite 139-VERIFICATION.md passing 8/8. Re-classified all 5 task-map rows against delivered artifacts — all COVERED/green. No MISSING/PARTIAL classifications, so no `gsd-nyquist-auditor` spawn was needed.

**Test run (this audit):**
- `mix test test/sigra/recipes/companion_lib_contract_test.exs` → 2 tests, 0 failures (0.03s, async, no DB)

**Note on `mix docs --warnings-as-errors`:** A pre-existing `lib/sigra/doctor.ex` moduledoc autolink warning (unrelated to Phase 139 — `git diff` shows 139 never touched `doctor.ex`) was tracked and resolved in Phase 140 (PROOF-01 Gate-5). The recipe edits themselves generate zero new doc warnings.
