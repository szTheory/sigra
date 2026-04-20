# Phase 25 Plan Check

**Verdict:** PASS (with 2 INFO notes, no blockers, no revisions required)
**Checked:** 2026-04-15
**Checker:** gsd-plan-checker (goal-backward verification)

---

## Goal coverage

Phase goal: *"Un-skip `Sigra.UpgradeIntegrationTest` (3 tests in `test/upgrade_test.exs`) by fixing the two latent bugs PR #9 surfaced when it renamed the shadowed integration module."*

| # | ROADMAP success criterion | Plan | Task | Covered by |
|---|---------------------------|------|------|------------|
| 1 | Remove `@moduletag skip:` from `test/upgrade_test.exs` | 25-02 | Task 2 | `<action>` Step 1 explicitly deletes PR #9 preamble + `@moduletag skip:` while PRESERVING `@moduletag :upgrade` and `@moduletag timeout: 600_000`. Acceptance criterion: `grep -c "@moduletag skip:" test/upgrade_test.exs` returns 0. |
| 2 | 3 `Sigra.UpgradeIntegrationTest` tests pass locally against `sigra-uat-postgres` | 25-02 | Task 2 | `<verify><automated>` runs `mix test test/upgrade_test.exs --include upgrade` and greps `0 failures` + `0 skipped`. Action Step 2 targets `3 tests, 0 failures, 0 skipped`. |
| 3 | 3 tests pass in CI `library_tests` job against `postgres:15` | — | — | Explicitly deferred to post-merge manual verification per 25-VALIDATION.md "Manual-Only Verifications" table. Plan 25-02 `<success_criteria>` #5 acknowledges this. **Valid deferral — CI parity cannot be verified from a local execute-phase run.** |
| 4 | New regression test proves same-second timestamp generator produces distinct, monotonically-increasing prefixes | 25-01 | Task 1 (RED) + Task 2 (GREEN) | Task 1 adds `describe "next_migration_timestamp/2"` block with assertions `String.to_integer(t2) > String.to_integer(t1)` and `~r/^\d{14}$/`. Task 2 makes it pass. |
| 5 | `mix test test/upgrade_test.exs` reports `0 failures, 0 skipped` | 25-02 | Task 2 | `<verify>` greps both `0 failures` AND `0 skipped`. Acceptance criterion reiterates. |
| 6 | Full `mix test` stays green locally and in CI on every existing test | 25-02 | Task 2 Step 3 | Action explicitly cites PR #9 baseline "`1813 tests, 0 failures, 3 skipped`" → target "`1814+ tests, 0 failures, 0 skipped`". Plan 25-01 Task 2 additionally runs `mix test --exclude upgrade` to catch unit-level regressions from the Bug B fix. |

**Coverage verdict:** All 6 ROADMAP criteria are covered. Criterion 3 is correctly scoped as a manual post-merge check (the VALIDATION.md contract documents this as the only manual verification in the phase).

---

## Dimension-by-dimension findings

### Dimension 1: Requirement coverage — PASS
Requirements `Phase-25-Bug-B` (Plan 25-01) and `Phase-25-Bug-A` (Plan 25-02) both appear in `requirements:` frontmatter. Together they decompose the phase goal cleanly along the bug-boundary; no uncovered requirement.

### Dimension 2: Task completeness — PASS
All 4 tasks have `<files>`, `<read_first>`, `<action>`, `<verify><automated>`, `<acceptance_criteria>`, `<done>`. Task types (`auto`, `auto tdd="true"`) are valid. No empty elements.

### Dimension 3: Dependency correctness — PASS
- Plan 25-01: `wave: 1`, `depends_on: []` — correct (Bug B fix is upstream of integration tests).
- Plan 25-02: `wave: 2`, `depends_on: ["25-01"]` — correct (integration tests exercise the install→upgrade path that Bug B breaks). The ordering is critical: if Plan 25-02 Task 2 ran before Plan 25-01's fix, all 3 tests would fail with `Ecto.MigrationError: migration version NNNN is duplicated`. Dependency graph is acyclic and consistent.

### Dimension 4: Key links planned — PASS
- Plan 25-01 `key_links`: `lib/sigra/upgrade.ex` call site → `next_migration_timestamp/2` helper via direct function call. Task 2 Step 2 explicitly rewrites the call site AND adds a `grep` check that `Calendar.strftime(DateTime.utc_now` returns ZERO hits (`acceptance_criteria`).
- Plan 25-02 `key_links`: helper scripts → `SIGRA_TEST_RESULT:<value>` sentinel line via `IO.puts`. Task 1 `<action>` emits the literal sentinel inside the `mix run -e` script AND the `Regex.run` extractor on the receiving side. Both ends of the wire are planned.

### Dimension 5: Scope sanity — PASS
- Plan 25-01: 2 tasks, 2 files modified. Well within budget.
- Plan 25-02: 2 tasks, 1 file modified. Well within budget.
- Total: 4 tasks, 3 files, ~1 helper function + ~2 helper rewrites + 1 skip-removal. Estimated context usage well below 50%.

### Dimension 6: Verification derivation — PASS
Truths in `must_haves` are user-observable (not implementation-focused):
- Plan 25-01: "mix sigra.install followed immediately by mix sigra.upgrade no longer produces duplicate migration versions" ✅ observable
- Plan 25-02: "All 3 Sigra.UpgradeIntegrationTest tests pass locally" + "Full mix test reports 0 failures, 0 skipped" ✅ observable

If a reviewer ran only the must_haves, they would know the phase succeeded. Goal-backward derivation is clean.

### Dimension 7: Context compliance — N/A
No CONTEXT.md present for Phase 25 (phase was scoped directly from PR #9 incident, no discuss-phase session).

### Dimension 7b: Scope reduction detection — PASS
No "v1", "simplified", "placeholder", "future enhancement", "basic version", "stub", or scope-reduction language found in either plan. The plans deliver the full fix for both bugs, not a reduced version. The primary recommendation from RESEARCH.md (Option 2: scan-and-bump) is implemented verbatim.

### Dimension 7c: Architectural tier compliance — PASS
Per RESEARCH.md Architectural Responsibility Map: migration filename generation (upgrade) belongs in the library (`Sigra.Upgrade`). Plan 25-01 puts the fix there. Test harness work belongs in `test/`. Plan 25-02 puts the fix there. No tier mismatch.

### Dimension 8: Nyquist compliance — PASS
- **8e (VALIDATION.md exists):** ✅ `25-VALIDATION.md` present.
- **8a (automated verify presence):** All 4 tasks have `<automated>` commands. No MISSING references.
- **8b (feedback latency):** Plan 25-01 tasks run `mix test test/sigra/upgrade_test.exs` (~5s). Plan 25-02 Task 1 runs `mix compile --warnings-as-errors` (~10s). Plan 25-02 Task 2 runs `mix test test/upgrade_test.exs --include upgrade` (~90-200s per VALIDATION.md estimate). All under the 90s soft-warning threshold for their scope tier. No watch-mode flags.
- **8c (sampling continuity):** 4 tasks, 4 automated verifies. 100% coverage — never 3 consecutive tasks without verification.
- **8d (Wave 0 completeness):** No MISSING references; no Wave 0 work needed per VALIDATION.md ("Existing infrastructure covers all phase requirements").

### Dimension 9: Cross-plan data contracts — PASS
The only shared artifact is the `priv/repo/migrations/` directory. Plan 25-01 changes how `Sigra.Upgrade` writes to it; Plan 25-02 does not write to it. No conflicting transforms. The integration test (Plan 25-02) consumes the directory read-only via `mix sigra.upgrade` subprocess invocation.

### Dimension 10: CLAUDE.md compliance — PASS
- Elixir ~> 1.18 / Ecto ~> 3.13: both fixes use only stdlib (`Calendar`, `DateTime`, `Regex`, `File`, `Path`). No new deps.
- ExUnit AAA style: Plan 25-01 Task 1 test is flat, self-contained, uses Arrange (tmp dir + seed file) / Act (two helper calls) / Assert (4 assertions). ✅
- `mix compile --warnings-as-errors` enforced in Plan 25-02 Task 1 verify. ✅
- No forbidden patterns (no Pow, no Ueberauth, no macro-heavy schema injection). ✅

### Dimension 11: Research resolution — N/A
RESEARCH.md has no `## Open Questions` section — all research is HIGH confidence and complete. Nothing to resolve.

### Dimension 12: Pattern compliance — N/A
No PATTERNS.md for Phase 25 (small 2-plan bugfix phase does not warrant cross-file pattern extraction). The plans instead reference in-code precedents directly:
- Plan 25-01 references `lib/sigra/install/migration_timestamps.ex` as the allocator precedent (both tasks' `<read_first>`).
- Plan 25-02 references `parse_http_status/1` at `test/upgrade_test.exs:372` as the sentinel-pattern precedent (called out in `<interfaces>` block).

---

## Focused verification spot-checks

### TDD shape (Plan 25-01) — PASS
- Task 1 `<action>` line: *"Run [test command] and CONFIRM the test FAILS (RED) with either `UndefinedFunctionError` (helper doesn't exist yet) or a function clause mismatch."*
- Task 1 `<acceptance_criteria>`: *"Running the test file exits non-zero (RED)"*.
- Task 2 `<verify><automated>`: greps `0 failures` (GREEN).
- Task 2 `<acceptance_criteria>`: *"`mix test test/sigra/upgrade_test.exs` exits 0 and reports `0 failures`"*.
- Task 1 `<read_first>` includes both `lib/sigra/upgrade.ex` (buggy site) and `lib/sigra/install/migration_timestamps.ex` (precedent). ✅

### Un-skip correctness (Plan 25-02 Task 2) — PASS
Action Step 1 is explicit: *"PRESERVE: `@moduletag :upgrade` (the tag used by `mix test --exclude upgrade` to gate these slow tests), `@moduletag timeout: 600_000` (the 10-minute timeout for container-backed tests)"*. Acceptance criterion confirms: *"`test/upgrade_test.exs` still contains `@moduletag :upgrade` (preserved)"*. Verified against actual file: lines 16–17 hold `:upgrade` and `timeout`, line 39 holds the `skip:` to be removed. The plan targets the correct lines.

### Concrete actions — PASS
Spot-check for abstract language:
- `grep -i "align" 25-*-PLAN.md` → 0 hits
- Plan 25-01 Task 2 contains a verbatim 38-line code block for `next_migration_timestamp/2` with exact `@spec`, guard clauses, and error handling.
- Plan 25-02 Task 1 contains verbatim before/after diffs for both `count_personal_orgs!/1` and `organizations_table_exists?/1` with exact regex `~r/SIGRA_TEST_RESULT:(\d+)/`.
- Commit messages are spelled out: `test(25-01):`, `fix(25-01):`, `fix(25-02):`, `test(25-02):`.

### Acceptance criteria testability — PASS
All criteria are grep/exit-code/literal-string checks. No subjective language ("looks right", "properly configured", "reasonable"). Every criterion can be verified by a shell one-liner.

### Full-suite baseline transition — PASS
Plan 25-02 Task 2 Step 3 cites the exact transition:
> *"The baseline from PR #9 was `1813 tests, 0 failures, 3 skipped`. With Plan 25-01's new regression test (+1) and this task's un-skip (3 skipped → 0 skipped), the new baseline should be approximately: `1814+ tests, 0 failures, 0 skipped`."*

This matches Phase 25's blind-spot-closure mandate and is more specific than a vague "full suite green."

### Code-site verification (absolute paths)
- `lib/sigra/upgrade.ex` line 285 confirmed: `timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")` — matches plan target.
- `lib/sigra/install/migration_timestamps.ex` exists — precedent file verified.
- `test/upgrade_test.exs:16-17` — `@moduletag :upgrade` and `@moduletag timeout: 600_000` confirmed (to preserve).
- `test/upgrade_test.exs:39` — `@moduletag skip:` confirmed (to remove).
- `test/upgrade_test.exs:200` — `count_personal_orgs!/1` defp confirmed.
- `test/upgrade_test.exs:224` — `organizations_table_exists?/1` defp confirmed.
- `test/upgrade_test.exs:372` — `parse_http_status/1` precedent confirmed.

All plan line-number references match reality.

---

## Findings

1. **[INFO] Plan 25-02 Task 2 `<verify><automated>` does not include a full-suite `mix test` assertion.**
   The automated gate only runs `mix test test/upgrade_test.exs --include upgrade` and greps for `0 failures` + `0 skipped`. Step 3 of the `<action>` prose does run the full `mix test` manually, and `<acceptance_criteria>` item 4 requires *"Full `mix test` exits 0 and reports `0 failures, 0 skipped`"*, but this is not captured inside the `<automated>` block. **Impact:** Nyquist sampling per 25-VALIDATION.md mandates a full-suite run after every wave anyway, so the executor will still catch any regression. **No revision required** — acceptance criterion #4 is explicit enough that the executor will run the full suite. If the planner later wants to tighten the gate, append `&& PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test 2>&1 | grep -E "0 failures, 0 skipped"` to the `<automated>` command.

2. **[INFO] Plan 25-02 Task 1 `<read_first>` does not list the precedent file path explicitly.**
   The precedent `parse_http_status/1` at `test/upgrade_test.exs:372` is referenced in the `<interfaces>` comment block at plan-level but not repeated inside Task 1's `<read_first>`. Since Task 1 already reads the FULL `test/upgrade_test.exs` file, the precedent is covered transitively. **No revision required.**

---

## Recommendation

**PASS — proceed to `/gsd-execute-phase 25`.**

Plans 25-01 and 25-02 will achieve the Phase 25 goal. Key strengths:

1. **Bug-boundary decomposition.** Each plan owns exactly one bug. Wave ordering (1 → 2) correctly reflects causal dependency: Bug B must be fixed before integration tests that exercise it can be un-skipped.
2. **TDD shape is real, not ceremonial.** Plan 25-01 Task 1 explicitly asserts the RED state (`UndefinedFunctionError` grep), and Task 2's acceptance criterion explicitly requires the same test to go GREEN.
3. **In-code precedent citations.** Both fixes reference existing in-repo patterns (`Sigra.Install.MigrationTimestamps` for Bug B, `parse_http_status/1` for Bug A) rather than inventing new approaches. This matches RESEARCH.md's "mirror patterns already present in the codebase" directive.
4. **Full scope delivery.** No "v1/v2" hedging, no "future enhancement" language, no skipped success criteria. The plans deliver every ROADMAP criterion that can be verified locally, and correctly defer only criterion #3 (CI parity) to manual post-merge verification per VALIDATION.md.
5. **Grep-verifiable acceptance criteria.** Every criterion maps to a shell command. No subjective judgment required at execute-time.
6. **Preservation discipline.** Plan 25-02 Task 2 explicitly lists `@moduletag :upgrade` and `@moduletag timeout: 600_000` as PRESERVE items — correctly identifying which parts of the quarantine block are structural vs. which parts are the PR #9 skip to remove.

The 2 INFO-level findings are polish suggestions, not blockers. The plans are execute-ready.

