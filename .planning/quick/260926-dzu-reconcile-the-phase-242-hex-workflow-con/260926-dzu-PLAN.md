---
quick_id: 260926-dzu
phase: quick-260926-dzu
plan: 01
type: execute
wave: 1
depends_on: []
autonomous: true
date: 2026-09-26
status: planned
files_modified:
  - .github/workflows/hex-remediate-phantom.yml
  - scripts/ci/prohibitions/p22-hex-remediation.test.mjs
  - test/fixtures/prohibitions/p22-hex-remediation-broadened.yml
  - test/fixtures/prohibitions/p22-hex-remediation-unsafe-secret.yml
  - .planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-PLAN.md
  - .planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md
  - .planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-VERIFICATION.md
  - .planning/STATE.md
must_haves:
  truths:
    - "The Phase 242 shift-left contract remains authoritative: the ten public install snippets retain the bounded 1.5 tuple and the retired mutation workflow and guard remain absent."
    - "Only the four Phase 242 Plan 13 artifacts observed as resurrected in the disposable clone are removed; the Phase 242 contract test and unrelated fixtures are untouched."
    - "The full `mix ci` gate passes in the disposable clone before any source commit is created; transient failures receive one retry, and deterministic failures are repaired only when their cause is within the four authorized files and repair preserves the scoped correction."
    - "The quick PLAN, SUMMARY, VERIFICATION, and Quick Tasks Completed/Last activity updates are committed in the disposable clone after the gate passes, with Phase 244 continuation recorded as Plan 3 of 5 and Plan 03 blocked at the `mix ci` gate."
    - "No source or quick-task document is staged or committed in the primary checkout, and no push, external branch update, or PR #283 update occurs in this quick task."
  artifacts:
    - "The workflow, p22 guard, and two resurrected YAML fixtures are absent from the disposable clone after correction."
    - "test/sigra/planning/phase_242_shift_left_contract_test.exs remains unchanged and passes as part of `mix ci`."
    - "The clone-local quick PLAN, SUMMARY, and VERIFICATION record the source commit, successful `mix ci` result, and exact evidence; its STATE.md records Phase 244 Plan 3 of 5 as blocked at the `mix ci` gate plus the quick completion row and Last activity."
  key_links:
    - "242-SAFETY-CLOSEOUT.md and Plan 242-13 establish that the mutation workflow, its guard, and its three YAML fixtures were intentionally removed; the test's absence assertions are correct."
    - "Phase242ShiftLeftContractTest checks absence of the workflow and p22 guard, so removing their resurfaced copies restores the intended contract."
    - "The root `mix ci` alias runs formatting, dependency checks, warning-free compilation, the test suite, install-golden checks, and dependency-off CI validation."
---

<objective>
Reapply Phase 242 Plan 13's bounded source-control safety closeout in the disposable Phase 244 measurement clone, then establish the required full `mix ci` proof before committing that scoped correction.

Purpose: The closeout evidence and merged Plan 13 show that the workflow, p22 guard, and their YAML fixtures were intentionally retired. The Phase 242 contract test's absence assertions are correct; the resurrected files are the mismatch.
Output: Exactly the currently resurrected Plan 13 workflow/guard/fixture files removed from the disposable clone, a passing full `mix ci` run, and one local scoped commit only after that gate passes.

Scope decisions: No external API integration, schema change, or identity-model change is in scope. Preserve the public installation constraint and all historical Phase 242 evidence. Work only in `/private/tmp/sigra-phase244-plan02-clone`; keep the primary shared checkout untouched.
</objective>

<execution_context>
@/Users/jon/.codex/gsd-core/workflows/execute-plan.md
</execution_context>

<context>
@.planning/STATE.md
@AGENTS.md
@.planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md
@.planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-13-SUMMARY.md
@.planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-13-PLAN.md
@test/sigra/planning/phase_242_shift_left_contract_test.exs
@.planning/todos/pending/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md

Live planning-time scope observation in `/private/tmp/sigra-phase244-plan02-clone`: the worktree is clean with no unmerged paths; these four tracked files are present: `.github/workflows/hex-remediate-phantom.yml`, `scripts/ci/prohibitions/p22-hex-remediation.test.mjs`, `test/fixtures/prohibitions/p22-hex-remediation-broadened.yml`, and `test/fixtures/prohibitions/p22-hex-remediation-unsafe-secret.yml`. `test/fixtures/prohibitions/p22-hex-remediation-missing-deps.yml` is already absent there. Preserve `test/fixtures/prohibitions/p22-hex-evidence-incomplete.json` and all other files.

Plan 13 explicitly removed the mutation workflow, its guard, and three YAML fixtures; it says not to restore any mutation automation. The `Phase242ShiftLeftContractTest` absence assertions match that decision. This plan only removes the four observed resurrected artifacts and does not edit the test or public documentation.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Reapply the Plan 13 retirement and prove the full CI gate</name>
  <files>/private/tmp/sigra-phase244-plan02-clone/.github/workflows/hex-remediate-phantom.yml, /private/tmp/sigra-phase244-plan02-clone/scripts/ci/prohibitions/p22-hex-remediation.test.mjs, /private/tmp/sigra-phase244-plan02-clone/test/fixtures/prohibitions/p22-hex-remediation-broadened.yml, /private/tmp/sigra-phase244-plan02-clone/test/fixtures/prohibitions/p22-hex-remediation-unsafe-secret.yml</files>
  <action>
Before changing any source, inspect the disposable clone live: confirm `git -C /private/tmp/sigra-phase244-plan02-clone rev-parse --show-toplevel` resolves to that clone, `git -C /private/tmp/sigra-phase244-plan02-clone status --porcelain` is empty, `git -C /private/tmp/sigra-phase244-plan02-clone diff --name-only --diff-filter=U` is empty, and `git -C /private/tmp/sigra-phase244-plan02-clone ls-files --error-unmatch` plus filesystem checks confirm the four paths listed under `<files>` are still tracked and present. If any precondition differs from this planning-time observation, stop without editing and report the exact difference; do not inspect or modify the primary checkout's index or working tree.

In the disposable clone only, remove exactly those four tracked files. Do not edit `test/sigra/planning/phase_242_shift_left_contract_test.exs`, public install documentation, `test/fixtures/prohibitions/p22-hex-evidence-incomplete.json`, or any Phase 244 files. The third YAML fixture named by the historical Plan 13 is already absent in the target clone; do not recreate or otherwise change it. Confirm the complete tracked diff consists only of deletions of the four authorized paths.

Run the full repository gate from `/private/tmp/sigra-phase244-plan02-clone` with `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci`. This invokes the project's `ci` alias rather than root `mix test`; the unchanged Phase 242 contract test must pass within that gate. If the gate reports a transient failure, diagnose the signal and retry the full gate once. For a deterministic failure, diagnose the root cause and repair it automatically only when the cause lies within the four authorized resurrected files and the repair preserves the exact scoped retirement. If a deterministic failure requires changing anything outside that scope, stop: retain the exact command, failure output, and diagnosis in a clone-local uncommitted verification record, create no source or documentation commit, and report the blocker. Never waive a failed or missing gate. Once the gate passes, confirm the tracked diff contains only deletions of the four authorized paths, then commit exactly those four deletions in the disposable clone. Do not push, update PR #283, or stage/commit source or quick-task documents in the primary checkout.
  </action>
  <verify>
    <automated>cd /private/tmp/sigra-phase244-plan02-clone && MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci</automated>
  </verify>
  <done>The clone's live preflight matched the authorized scope; the full gate passes after at most one retry for a transient failure; deterministic failures are repaired only within the authorized four-file scope or left with exact diagnostics and no commit; exactly the four observed Plan 13 artifacts are deleted; the four-path correction is committed locally only after the pass; the primary checkout and PR #283 are untouched.</done>
</task>

<task type="auto">
  <name>Task 2: Record the validated quick task in the disposable clone</name>
  <files>/private/tmp/sigra-phase244-plan02-clone/.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-PLAN.md, /private/tmp/sigra-phase244-plan02-clone/.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md, /private/tmp/sigra-phase244-plan02-clone/.planning/STATE.md</files>
  <action>
    After Task 1 returns, materialize the revised PLAN and a SUMMARY in the clone quick directory. Regardless of whether the gate passes, correct the clone STATE.md continuation to Phase 244 `Plan: 3 of 5`, overall status executing and Plan 03 blocked. If Task 1 failed, record the actual remaining `mix ci` failures and the path to `MIX-CI-BLOCKED.md`; if it passed, keep the Phase 244 plan active for resumption. Use the live phase-plan index and existing `244-03-SUMMARY.md` as evidence. Record session stop/resume with the GSD state command and preserve unrelated state fields/rows. Only if Task 1 passes and the verifier confirms all must_haves may the orchestrator add the Quick Tasks Completed row/Last activity and commit quick docs. On any gate failure, mark this quick task blocked/incomplete, do not add a completed-task row, and do not commit source or docs. Never stage or commit in the primary checkout; do not push or update a PR.
  </action>
  <verify>
    <automated>cd /private/tmp/sigra-phase244-plan02-clone &amp;&amp; rg -n "Plan: 3 of 5|Plan 03 blocked" .planning/STATE.md &amp;&amp; test -f .planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-PLAN.md &amp;&amp; test -f .planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md</automated>
  </verify>
  <done>The clone contains and locally commits the revised quick PLAN, SUMMARY, VERIFICATION, and the authorized STATE.md continuation correction and quick-task record through `gsd_run query commit`; the source and documentation commits remain separate and local; the clone is clean; the primary checkout and PR #283 remain untouched.</done>
</task>

</tasks>

<orchestrator_bookkeeping>
After the verifier creates the VERIFICATION artifact, the GSD orchestrator performs Steps 7–8 in the disposable clone only. Materialize the quick VERIFICATION there, append the Quick Tasks Completed row for `260926-dzu`, and update Last activity in the clone STATE.md while preserving other fields and rows. Commit only the PLAN, SUMMARY, VERIFICATION, and STATE.md through the clone's `gsd_run query commit`; confirm that documentation commit contains only those paths and the clone is clean. The user chose proceed after the second plan-check iteration; Task 2 addresses the remaining state-position finding. The primary checkout stays unstaged and uncommitted; no push or PR update is authorized.
</orchestrator_bookkeeping>

<orchestrator_bookkeeping>
The user chose to proceed after the second plan-check iteration. After executor return, the orchestrator creates the required verification artifact and corrects the clone Phase 244 continuation to Plan 3 blocked even if the gate failed. Do not mark the quick task complete, append a completed Quick Tasks row, or commit docs unless the full gate passes and verification passes. If the gate fails, preserve exact diagnostics in the quick directory, leave all commits unstaged/uncreated, and stop with an incomplete quick task.
</orchestrator_bookkeeping>

<threat_model>
## Security Context

Configured enforcement: OWASP ASVS L1; block on high-severity threats. The workflow was a secret-bearing mutation lane capable of registry changes. Removing its resurfaced copy reduces the retired secret-bearing mutation surface; this deletion introduces no new threat.

## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| GitHub Actions workflow → Hex registry | A repository workflow could use repository-held credentials to mutate release state. |
| Primary checkout → disposable clone | Source edits must remain isolated from the user's dirty primary checkout. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260926-DZU-01 | Tampering | Resurfaced Hex remediation workflow | high | mitigate | Remove the tracked mutation workflow, its p22 guard, and its two present YAML fixtures in the clean disposable clone; the existing Phase 242 contract test continues to assert that the workflow and guard are absent. |
| T-260926-DZU-02 | Tampering | User's primary checkout | medium | mitigate | Restrict source mutation, quick-task documents, state bookkeeping, and both local commits to `/private/tmp/sigra-phase244-plan02-clone`; stage or commit nothing in the primary checkout and stop if clone preconditions differ. |
</threat_model>

<verification>
From the disposable clone, the exact four-file source diff contains only the Plan 13 resurrection removals, the unchanged Phase 242 contract test succeeds as part of `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci`, and the local source commit is created only after the full gate passes. A transient gate failure is retried once; deterministic failures are repaired only within the authorized scope, otherwise exact diagnostics are retained without a source or documentation commit. After a successful gate and passed verification, the orchestrator records GSD Quick documents and corrects the clone-local Phase 244 position to Plan 3, then commits those docs with a separate clone-local `gsd_run query commit`. If the gate fails, the quick task remains blocked and uncommitted; record Plan 3 blocked with exact diagnostics. No source or documentation stage/commit in the primary checkout, push, external branch update, or PR update is part of this task.
</verification>

<success_criteria>
The resurfaced secret-bearing mutation lane is retired again in the disposable clone, the Phase 242 absence contract is green under full `mix ci`, the clone-local source and GSD documentation commits accurately record the result, and no unrelated or primary-checkout files are staged or committed.
</success_criteria>

<output>
Create `.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md` when done.
</output>
