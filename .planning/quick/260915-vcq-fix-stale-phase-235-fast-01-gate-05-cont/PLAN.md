---
quick_id: 260915-vcq
slug: fix-stale-phase-235-fast-01-gate-05-cont
created: 2026-09-16T02:34:29.891Z
type: quick
status: planned
files_modified:
  - test/support/planning_paths.ex
  - test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs
  - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
  - .planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md
---

<objective>
Unblock `MIX_ENV=test mix ci` on `main` (and PR #242's `ci-gate`) by fixing the ROOT CAUSE of the
3 stale phase-235 contract-test failures — a resolver bug in `Sigra.Test.PlanningPaths`, not the
tests themselves.
</objective>

<diagnosis>
VERIFIED by the orchestrator before this plan was written. Do not re-derive from scratch; do
confirm anything you rely on.

`test/support/planning_paths.ex` exists precisely to keep phase contract tests working after
milestone close-out. Its own moduledoc says so:

  "Phase contract tests assert against that evidence, so without this they break at exactly the
   moment their subject becomes immutable history"

But `requirements/0` only falls back to the archive when the LIVE file is MISSING:

```elixir
def requirements do
  live = ".planning/REQUIREMENTS.md"
  if File.regular?(Path.join(@root, live)) do
    live                                        # <- live exists, so it stops here
  else
    newest_archived("REQUIREMENTS.md") || live
  end
end
```

A milestone rollover does NOT delete `.planning/REQUIREMENTS.md` — it REPLACES it wholesale
(`cc6f17e4`, "docs: define milestone v1.48 requirements"). So the live file still exists, the
fallback never fires, and closed-milestone contract tests silently read a file that no longer
contains their subject. The helper was written for the wrong rollover shape.

Confirmed facts:
- `.planning/milestones/v1.47-REQUIREMENTS.md` EXISTS and contains `- [x] **FAST-01**` and
  exactly ONE `- [x] **GATE-05**:` (positive control: 23 total requirement lines in that file).
- The live `.planning/REQUIREMENTS.md` contains ZERO occurrences of `FAST-01` or `GATE-05`.
- `PlanningPaths.requirements()` has exactly TWO callers, and both are the failing tests
  (positive control: 8 files reference `PlanningPaths` in total).

Phase 235 belonged to milestone v1.47. That is a static, closed fact.
</diagnosis>

<tasks>

<task type="auto">
  <name>Task 1: Add a milestone-scoped requirements resolver to PlanningPaths</name>
  <files>test/support/planning_paths.ex</files>
  <action>
Add a public function that resolves the REQUIREMENTS.md snapshot for a NAMED, CLOSED milestone,
e.g. `requirements_for("v1.47")`, returning a repo-relative path to
`.planning/milestones/v1.47-REQUIREMENTS.md`.

Follow the module's existing conventions exactly:
- return a REPO-RELATIVE path (every other function does)
- when nothing resolves, return the declared path unchanged so a genuinely missing artifact fails
  loudly against the name the caller used, rather than silently resolving somewhere surprising
  (this rule is stated in the moduledoc — honor it)
- add a `@doc` consistent in voice with the neighbours

Do NOT change the semantics of the existing `requirements/0`. A future test that legitimately
asserts against the LIVE requirements must keep working. This is an addition, not a redefinition.

Extend the moduledoc briefly to record WHY both functions exist: `requirements/0` resolves the
ACTIVE milestone's file; `requirements_for/1` pins a CLOSED milestone's immutable snapshot. Note
that a rollover replaces rather than deletes the live file, which is why "live exists" is not
evidence that the live file is the right subject.
  </action>
  <verify>
    <automated>bash -c 'test -f test/support/planning_paths.ex && grep -c "def requirements_for" test/support/planning_paths.ex'</automated>
    <fails_when>the function is absent, or `requirements/0` behaviour changed (check by reading it)</fails_when>
  </verify>
  <acceptance_criteria>
    - `requirements_for/1` exists, is documented, returns a repo-relative path, and degrades to the declared path when unresolved.
    - `requirements/0` is byte-unchanged in behaviour.
  </acceptance_criteria>
  <done>A milestone-scoped resolver exists alongside the live one.</done>
</task>

<task type="auto">
  <name>Task 2: Repoint the two phase-235 contract tests at the v1.47 snapshot</name>
  <files>
    test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs
    test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
  </files>
  <action>
In BOTH files, change the `@requirements` module attribute to use the new milestone-scoped
resolver pinned to `"v1.47"` instead of `Sigra.Test.PlanningPaths.requirements()`.

Note the two files spell it differently at HEAD — one joins `@root` itself, the other does not.
Preserve each file's existing joining style; change only WHICH path is resolved.

Change NOTHING else in either file. The assertions themselves are correct and are the contract
being preserved — these tests are named "remain immutable", and pointing them at the closed
milestone's archive is what actually honors that. Do not weaken, delete, or skip any assertion.
  </action>
  <verify>
    <automated>bash -c 'MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs 2>&1 | tail -5'</automated>
    <fails_when>any failure remains, or the test count DROPS versus the 26 tests observed at HEAD (a drop means assertions were removed rather than fixed — that is not a pass)</fails_when>
  </verify>
  <acceptance_criteria>
    - Both files pass with ZERO failures.
    - Total test count across the two files is still 26 — no assertion was deleted or skipped to reach green.
  </acceptance_criteria>
  <done>Both contract tests pass against the archived v1.47 snapshot with no assertions lost.</done>
</task>

<task type="auto">
  <name>Task 3: Prove `mix ci` is unblocked and resolve the todo</name>
  <files>.planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md</files>
  <action>
Run `MIX_ENV=test mix ci` and record the result. Expect the 3 named failures to be GONE.

If OTHER failures appear that are unrelated to this change, do NOT fix them — report them
plainly and say they are out of scope. Distinguish clearly between "this change fixed its target"
and "the whole gate is now green"; they are different claims and only the first is yours.

Then move the todo from `.planning/todos/pending/` to `.planning/todos/resolved/` (as a `git mv`
rename, matching the repo convention used for the two todos plan 236-04 resolved). Append a short
resolution note recording WHICH of the todo's three options was taken and why: option 2
(repoint at the archive), because it preserves the immutability contract the tests exist to
enforce, whereas option 1 (retire) would discard it. Record that the root cause was the
`PlanningPaths.requirements/0` fallback condition, not the tests.
  </action>
  <verify>
    <automated>bash -c 'test -f .planning/todos/resolved/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md && ! test -f .planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md && echo MOVED'</automated>
    <fails_when>the todo is still pending, or exists in both places</fails_when>
  </verify>
  <acceptance_criteria>
    - The 3 originally-named failures no longer occur.
    - The todo is resolved with the chosen option and root cause recorded.
    - Any remaining unrelated `mix ci` failures are reported, not silently absorbed and not fixed.
  </acceptance_criteria>
  <done>`mix ci` no longer fails for this cause, and the todo is honestly closed.</done>
</task>

</tasks>

<prohibitions>
  - MUST NOT delete, retire, skip, or weaken any assertion in either contract test to reach green. The assertions ARE the contract; a green achieved by removing them is exactly the failure mode milestone v1.48 exists to eliminate.
  - MUST NOT change the behaviour of the existing `PlanningPaths.requirements/0`. Adding a sibling is safe; redefining it would silently retarget any future caller that legitimately wants the live file.
  - MUST NOT edit `.planning/REQUIREMENTS.md` or `.planning/milestones/v1.47-REQUIREMENTS.md`. The archived snapshot is immutable history; editing it to satisfy a test inverts the entire point.
  - MUST NOT fix unrelated `mix ci` failures found along the way — report them (ROADMAP standing constraint 4).
  - MUST NOT create or switch branches. Stay on `gsd/phase-236-flake-root-cause`.
</prohibitions>
