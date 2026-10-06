# Continue — Phase 246 delivery / Phase 247 discussion

## Last action

Confirmation recovery implementation is committed and reviewed at source `fd75cad25`. Plans 246-01/02 are complete; Plan 03 local proof passes, but required GitHub CI is missing. Phase 246 remains **2/3**, with no final VERIFICATION.md or completion claim.

## Next action

Run **`$gsd-discuss-phase 247`**. First read this handoff, `.planning/STATE.md`, and `246-03-SUMMARY.md` in this directory. Phase 247 is Release Candidate and Repository Readiness. `init.plan-phase 247` reported no planning prerequisite blocker and no context/research/plans; `246-FORWARD-ROUTE.json` retains that routing decision.

## Why

Discussion prepares the inherited checkout and repository-readiness work that holds the CI gate. Repeating Phase 246 execution before those inputs change would encounter the same known failures. Phase 246 completion remains open; planning ahead does not waive its required CI proof or Phase 247's execution dependency.

## Open threads

- `246-CI-EVIDENCE.json`: 236 focused tests pass; 8 fresh-host tests pass at identical generation/probe source; Chromium admin/confirmation/revocation pass after one retained timeout retry; review covers 19 files with zero findings.
- `246-MIX-CI-FAILURES.json`: final clean-source `mix ci` has four failures — Phase 232 cache marker, Phase 236/242 archived evidence paths, README install tuple. Example `mix precommit` also fails the existing `/dev/mailbox` test-route warning. Full failure messages and source identities are committed; no ephemeral log is needed to recover these diagnostics.
- Existing tracked/untracked workflow, package, public-doc, script and quick/debug edits predate Phase 246. Preserve them and disposition them under READY-02; avoid staging them wholesale.
- After readiness blockers change, resume `$gsd-execute-phase 246` for Plan 03's required CI receipt and final gates. Completed Plans 01/02 must not be repeated. Then reassess dependent execution readiness.

## Do not

- Mark missing CI evidence passed, close Phase 246, or start dependent execution before its gates pass.
- Rewrite captured historical inventory: live browser ownership is `test/example/priv/playwright/spec-ownership.json`; the archived Phase 234 bytes are immutable provenance.
- Reopen stale Phase 245 negative-proof work as the default forward route.
