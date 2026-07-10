---
phase: 219-baseline-recapture-canary-reconciliation
plan: 03
subsystem: ci
tags: [ci, github-actions, playwright, snapshot-canary, recapture, amd64-baselines]

# Dependency graph
requires:
  - phase: 219-01
    provides: "example icon/1 :global fix — compile-warnings-as-errors cleared so recapture/smoke jobs boot"
  - phase: 219-02
    provides: "recapture_branch dispatch input + release_ref_guard relaxation + demo-showcase recapture + impersonation-banner delete-rebirth + canary-never-allowlistable guard"
provides:
  - "115 amd64-native committed PNG baselines on the Phase 219 branch (84 admin-design + 27 admin-checkpoints + 4 demo-showcase)"
  - "impersonation-banner canary re-baselined to amd64-native pixels (delete-reborn as guard-tolerated 'added'), preserving the Phase 204-03 WCAG-AA contrast fix"
  - "example_playwright_smoke compare-mode + generated_admin_playwright_smoke parity green on the branch against the recaptured baselines"
  - "PR #70 (elevate-03-wave-v144-pr) closed as subsumed (D-01)"
affects: [219-04, 219-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Branch-scoped workflow_dispatch recapture (recapture_branch input) → amd64 --update-snapshots → self-gate → bot PR into the dispatched branch → squash-merge → compare-mode green-before-merge. Yields true CI-native amd64 pixels with no required gate left red on main (no merge deadlock)."
    - "Canary delete-rebirth must COMMIT the deletion before --update-snapshots so the reborn PNG is a pure untracked 'added' relative to the delete commit; a working-tree-only find -delete reads as 'modified' vs HEAD once the canary bytes actually change."

key-files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-chromium.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-dark.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-mobile.png
    - .github/workflows/ci.yml

key-decisions:
  - "Phase 219 executed on branch gsd/phase-219-baseline-recapture-canary-reconciliation, forked off local main (181 commits ahead of origin/main — the 217/218 wave + gap-closure + install-golden rebless never pushed; repo ruleset blocks direct main pushes). This is the D-01 'branch fresh off main' base; the GSD config branching_strategy=none was overridden by the plan-level D-01 decision + the ruleset requirement."
  - "Delete-rebirth mechanism bug (219-02) fixed during this plan: the checkpoint job's find -delete produced 'modified' (guard-forbidden) for the first amd64 re-baseline of the previously hand-reconciled impersonation-banner canary. Fix (fb780889): commit the canary deletion (with bot git identity) before --update-snapshots so the reborn PNG is a pure 'added'. Empirically verified in a scratch repo (find -delete → M; git rm --cached → mixed; commit-first → clean added → guard PASS)."
  - "Blessed the impersonation-banner amd64 re-baseline via the D-05 operator scope check: it is the ONLY drifted baseline (all 110 others byte-green amd64), its committed bytes were hand-reconciled in Phase 212 PR #64 (non-amd64), and the guard classified it 'OK canary first-established (added)'. Isolated canary drift = stale baseline, not env poison."

patterns-established:
  - "The canary delete-rebirth pattern (both admin_design board-notice and admin_checkpoint impersonation-banner) requires a committed deletion to yield 'added' for a genuinely-changed canary. board-notice shares the latent gap but only stays green while byte-identical; a future third canary lane must commit the deletion."

requirements-completed: [RECAP-01]

coverage:
  - id: SC-1
    description: "All 115 committed PNG baselines are amd64-native (in-CI recapture, never darwin) and land on the Phase 219 branch via a reviewable bot PR with zero spurious drift"
    requirement: RECAP-01
    verification:
      - kind: other
        ref: "ls admin-design.spec.ts-snapshots/*.png | wc -l == 84 && admin-checkpoints == 27 && demo-showcase == 4 (115 total); recapture run 29051223765 admin_design_recapture + admin_checkpoint_recapture both success"
        status: pass
    human_judgment: false
  - id: D-04
    description: "Branch-scoped recapture dispatched (recapture_branch set); both recapture jobs conclude success on ubuntu/amd64"
    requirement: RECAP-01
    verification:
      - kind: other
        ref: "gh run 29051223765 (workflow_dispatch, headBranch=219 branch): Recapture admin-design + admin-checkpoint baselines both conclusion=success"
        status: pass
    human_judgment: false
  - id: D-05
    description: "Operator git-diff scope check of the recapture PR (named slugs) before merge — the one retained human touch"
    requirement: RECAP-01
    verification:
      - kind: manual
        ref: "PR #71 scope check: only 3 impersonation-banner PNGs changed, no source/config/template leakage, guard logged 'OK canary first-established (added)'; operator approved merge"
        status: pass
    human_judgment: true
  - id: D-01
    description: "PR #70 (elevate-03-wave-v144-pr) closed as subsumed, not rebased/reconciled"
    requirement: RECAP-01
    verification:
      - kind: other
        ref: "gh pr view 70 → state CLOSED with subsumed-by-main comment"
        status: pass
    human_judgment: false

# Metrics
duration: ~90min (incl. 2 CI recapture cycles ~20min each + delete-rebirth fix)
completed: 2026-07-09
status: complete
---

# Phase 219 Plan 03: Branch-Scoped Recapture + Operator Scope Check Summary

**Ran the branch-scoped in-CI amd64 recapture (D-04), fixed a delete-rebirth mechanism bug it surfaced, landed the recaptured baselines on the Phase 219 branch via bot PR #71 after the D-05 operator scope check, and closed PR #70 as subsumed (D-01) — all 115 committed PNG baselines are now confirmed amd64-native.**

## Accomplishments

- Created + pushed branch `gsd/phase-219-baseline-recapture-canary-reconciliation` (forked off local main; 219-01 + 219-02 landed).
- Triggered the branch-scoped recapture (`gh workflow run CI --ref <branch> -f recapture_branch=<branch>`). `release_ref_guard` relaxed correctly (recapture jobs ran, not skipped).
- **admin_design recapture: 0 changed slugs** — all 84 admin-design PNGs already amd64-native/byte-green; no design PR needed.
- **admin_checkpoint recapture: the only drifted baseline was `impersonation-banner`** (the canary). demo-showcase (4) and the other 8 checkpoint slugs were byte-green amd64.
- Diagnosed + fixed a real **delete-rebirth mechanism bug** in 219-02 (commit `fb780889`): the working-tree `find -delete` yielded `modified` (guard-forbidden) for the canary's first amd64 re-baseline. Committing the deletion before `--update-snapshots` makes the reborn PNG a pure `added` (empirically verified). Re-dispatched (run `29051223765`) → both recapture jobs `success`; guard logged `OK canary first-established (added): impersonation-banner`.
- **D-05 operator scope check** on bot PR #71: only 3 `impersonation-banner` PNGs changed, no source/config/template leakage, canary `added` not forbidden `modified` — operator approved.
- Squash-merged PR #71 into the Phase 219 branch (`ed692906`); **115-PNG set present (84/27/4)**.
- **example_playwright_smoke compare-mode green** and **generated_admin_playwright_smoke parity green** on the recapture run against the (now amd64) baselines.
- Closed PR #70 (`elevate-03-wave-v144-pr`) as subsumed per D-01.

## Commits / Artifacts

- `fb780889` — fix(219-02): commit canary deletion before rebirth so guard sees pure 'added' (D-03.2) [delete-rebirth mechanism fix]
- `ed692906` — ci: recapture admin-checkpoint + demo-showcase baselines in ubuntu CI (29051223765) (#71) [bot recapture, squash-merged into the branch]
- Bot recapture PR: **#71** (base = Phase 219 branch), merged.
- PR **#70** closed as subsumed.
- CI runs: `29048532530` (first dispatch — checkpoint job failed on canary, surfaced the bug), `29051223765` (post-fix — recapture jobs green, PR #71 opened).

## Deviations from Plan

- **Plan assumed the 219-02 delete-rebirth was sufficient; it was not.** The first recapture (run 29048532530) failed at the checkpoint canary guard because a working-tree `find -delete` reads as `modified` once the canary bytes actually change. This was an implementation gap in 219-02, not a plan-intent change. Fixed inline (fb780889) and re-dispatched — the D-04/D-05/D-01 intent is fully met.
- Plan was orchestrated inline by the execute-phase orchestrator (not a fire-and-forget subagent) because Task 1's ~20-min CI poll + Task 2's human-verify gate make a blocking subagent unsuitable.

## Issues Encountered (out of 219 scope — flagged for follow-up)

- **`fast_checks` is red on the Phase 219 branch** due to `Error: Cannot find module 'cheerio'` in the `evidence-anchor-check.mjs` / panel-eval step — NOT a snapshot-drift failure (the snapshot-canary-guard steps within fast_checks passed on the consecutive-commit diff). `fast_checks` is **green on origin/main**, so this is a **218-era eval-infra regression** (the panel/evidence scripts need `cheerio`, which the fast_checks job does not `npm install`). It is orthogonal to baseline recapture (219 is example-only, touches no eval infra) but **will block the eventual 219→main `ci-gate`**. Deferred as a tracked follow-up — see `.planning/todos/pending`.
- **`Upgrade smoke`** is red on the branch AND identically red on origin/main's latest scheduled run → **pre-existing known env failure** (published-source→local-candidate upgrade lane), not a 219 regression.
- **`Admin eval render + probe`** failed but is explicitly labeled "evidence only, not a merge gate."

## Next Phase Readiness

- 115 amd64-native baselines are on the branch; the required `example_playwright_smoke` compare gate is green-before-merge (no deadlock).
- 219-04 (allowlist reconciliation to empty steady-state, SC-2) and 219-05 (generated-host parity confirm, SC-3 — `generated_admin_playwright_smoke` already green) can proceed.
- The `cheerio` fast_checks regression must be resolved before the 219→main ship PR can pass `ci-gate` (out of this phase's recapture scope).

---
*Phase: 219-baseline-recapture-canary-reconciliation*
*Completed: 2026-07-09*

## Self-Check: PASSED

- FOUND: fb780889 (delete-rebirth fix commit)
- FOUND: ed692906 (recapture merge commit)
- VERIFIED: 84/27/4 = 115 baselines present
- VERIFIED: PR #71 merged, PR #70 closed
- VERIFIED: recapture run 29051223765 both recapture jobs success; compare-mode + parity green
