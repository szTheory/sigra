---
phase: 247-release-candidate-and-repository-readiness
plan: 08
subsystem: release-readiness
tags: [github-actions, hex, provenance, readiness]
requires:
  - phase: 247-07
    provides: Fixed candidate baseline and protected-main manifest provenance.
provides:
  - Trusted workflow receipt receives a boolean-only dedicated-key presence signal.
  - Authenticated exact-source dry-run receipt with baseline, source CI, and live main provenance.
  - Final readiness ledger and validator pass for the current candidate and inherited inventory.
affects: [247-05, release-readiness]
actuals:
  tokens: 42894
  tasks: 4
  commits: 2
tech-stack:
  added: []
  patterns: [boolean-only secret presence evidence, exact-source receipt provenance, clean detached trusted-main verification]
key-files:
  created:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-08-DRY-RUN-RECOVERY.md
    - .planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json
  modified:
    - .github/workflows/phase-247-hex-dry-run.yml
    - scripts/ci/phase-247-hex-dry-run.test.sh
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-VALIDATION.md
    - .planning/phases/247-release-candidate-and-repository-readiness/247-08-SUMMARY.md
key-decisions:
  - "Expose dedicated Hex key presence only as a boolean in the trusted receipt."
  - "Restore only the verified evidence PR ref after merge so the workflow can prove its pre-merge manifest provenance."
  - "Verify trusted-main cleanliness in a separate exact-main checkout while preserving the shared dirty worktree."
requirements-completed: [READY-01, READY-02]
duration: 75min
completed: 2026-10-08
status: complete
plan_head_before: 58c660b8fb241ed7c85e9a36ac846194eb4de305
plan_head_after: fe40065a4e04603fc0c9666dc5bddad8581b11a5
commits: 2
coverage:
  - id: D1
    description: "The trusted-main workflow sends only a boolean key-presence result to the safe receipt helper."
    requirement: READY-01
    verification:
      - kind: unit
        ref: "bash scripts/ci/phase-247-hex-dry-run.test.sh"
        status: pass
      - kind: integration
        ref: "PR #292 CI run 37721138344 attempt 1; actionlint workflow"
        status: pass
    human_judgment: false
---

# Phase 247 Plan 08: Authenticated dry-run and final readiness summary

**The protected workflow produced an authenticated non-publishing receipt for the exact curated candidate, and the refreshed final readiness validator passed with complete live inventory evidence.**

## Progress

- **Tasks:** 4 of 4 complete, including amended Task 1b.
- **Candidate:** PR #224 remains open at `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, based on reviewed main `d135cbce343947499a0810736c500ef5f1cb5c32`.
- **Evidence:** PR #296 pre-merge head `76f6c6aced57a71020573bbd477d3624fd2c2f73` merged to main `a494f3ee3878da93aab4f70712ffddeefd77a802`; manifest blob `c87eeb19e79b4e19d34ff522c487894c8cb3c558`, SHA-256 `d7cbfeddd55bc0528738f89b82377379e55a73464f2c174217af31410625ac5e`, 8,372 bytes.

## Dry-run outcome

The initial run `37803560621` failed before authentication because the pre-merge evidence PR tree was unreachable after branch deletion. Recovery restored only the exact verified evidence ref, then one bounded retry, [37803817504](https://github.com/szTheory/sigra/actions/runs/37803817504), passed on trusted main. The safe receipt proves exact source/baseline provenance, successful `mix hex.publish --dry-run --yes`, boolean key presence, and Hex 1.6.0 absence before and after. No key value or secret metadata was inspected.

## Task commits

- Task 1: workflow key-presence signal — protected merge `cd978dad3504bf4ff775ea89e98d063d2a189d56`.
- Task 1b: path-only dirty-checkout diagnostics — protected merge `7b907abcf15785b7396da5d1fe5f5115ccd9af64`.
- Task 2: safe receipt, refreshed baseline, and recovery record — `897db1e9b` (`test(247-08): retain authenticated dry-run evidence`).
- Task 3: final readiness validator, regression suite, live ledger, and validation report — `fe40065a4` (`fix(247-08): validate final readiness evidence`).

## Deviations from plan

The final validator now accepts the curated 1.6.0 adopter wording and dispositions all inherited Phase 247 evidence commits. It performs the required clean-tree proof against a separate clean detached checkout of exact live main because the shared primary worktree contains unrelated dirty paths; the primary worktree was not reset or cleaned. This preserves the clean-source guard while allowing the task to finish safely.

## Validation

- `bash scripts/ci/phase-247-hex-dry-run.test.sh` — passed; 25 hermetic fixtures plus receipt timestamp assertions.
- `actionlint .github/workflows/phase-247-hex-dry-run.yml` — passed.
- Post-merge `verify-baseline` — passed with evidence PR #292 head `aa83727c06e1e1050265e6d9c4bf3e9e9526261c`, manifest blob unchanged, and exact four-path main advance.
- `node --test .../validate-release-readiness.test.mjs` — passed, 24/24.
- Final readiness validator — `valid: true`, `status: ready`, zero diagnostics; exact source CI `37800067568`, dry-run run `37803817504`.
- No tag, Hex publication, or PR #224 merge occurred.

## Continuation evidence (2026-10-08)

The user configured the dedicated read-only `HEX_DRY_RUN_API_KEY` in the existing main-only environment. No secret value or environment metadata was inspected. The first trusted-main dispatch, run `37803560621`, failed before authentication because the evidence PR's pre-merge tree was unreachable after its branch ref had been deleted. Recovery restored only the evidence branch ref to the already-verified PR #296 head `76f6c6aced57a71020573bbd477d3624fd2c2f73`; no file or commit changed. The bounded retry, run `37803817504`, passed and produced the safe receipt at `247-HEX-DRY-RUN-RECEIPT.json`. Full provenance and the pre-auth stop are recorded in [247-08-DRY-RUN-RECOVERY.md](./247-08-DRY-RUN-RECOVERY.md).

The final validator and focused suite were then refreshed for the current PR #224 source `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, the reviewed base `d135cbce343947499a0810736c500ef5f1cb5c32`, and evidence merge `a494f3ee3878da93aab4f70712ffddeefd77a802`. It now evaluates the actual curated changelog and adopter-guide wording and completes dispositions for inherited Phase 247 evidence commits. The focused suite passes 24/24, and final readiness returned `valid: true`, `status: ready`, with zero diagnostics at `2026-10-08T15:59:46.969Z`. The exact-head CI run was `37800067568`; the final dry-run was `37803817504`. PR #224 remains open and no tag or publication was created.

The shared checkout contains unrelated work, so the clean-tree invariant was verified using a separate clean detached checkout of exact live main `a494f3ee3878da93aab4f70712ffddeefd77a802`. The primary working tree was not reset or cleaned.

## Self-Check: PASSED

- The authenticated safe receipt, recovery record, readiness ledger, and validation report exist.
- Candidate PR #224 remains open at the recorded source and base.
- The readiness validator and focused tests passed at the recorded evidence state.
- Broken-windows ledger entry 8 is marked fixed with the validator and dry-run run IDs.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Completed: 2026-10-08*


## Historical checkpoint after Task 1b (superseded)

The plan was amended to add Task 1b for safe dirty-path diagnostics after run `37721969290`. That task was completed through PR #293. This checkpoint is retained as historical context; later final-source/evidence recovery is documented below and supersedes its blocked status.

The checkpoint originally recorded 2 of 4 tasks complete. All four tasks are now complete; see the continuation evidence above and the detailed [recovery record](./247-08-DRY-RUN-RECOVERY.md).
