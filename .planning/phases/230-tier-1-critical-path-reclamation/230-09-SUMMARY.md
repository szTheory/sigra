---
phase: 230-tier-1-critical-path-reclamation
plan: 09
subsystem: infra
tags: [github-actions, ci, playwright, evidence, ci-run-metrics]

requires:
  - phase: 230-tier-1-critical-path-reclamation (plans 01-08)
    provides: the six FAST-0x CI edits (design-gallery axe/snapshot split, admin_eval_render
      demotion, concurrency cancel-in-progress, docs-only classifier, Playwright browser cache,
      timeout-minutes) plus the ci-run-metrics.sh / docs-only-classify.sh /
      playwright-cache-key-guard.sh measurement and guard scripts
provides:
  - Completed 230-EVIDENCE.md: verbatim-run-ID evidence for AFTER-PR, AFTER-PR-WARM,
    AFTER-NONPR, AFTER-CANCEL, plus AFTER-PUSH and AFTER-DOCSONLY booked as explicit
    post-merge obligations
  - An observed FAST-06 miss-then-hit Playwright browser cache pair on one pull request
  - A per-requirement evidence-class table (observed / proxy-observed / hermetic-unit /
    structural-argument) mapping FAST-02 through FAST-07 and SC-1/SC-2/SC-3 to specific
    recorded numbers or named self-tests
affects: [235-tier-2-and-playwright-economics]

tech-stack:
  added: []
  patterns:
    - "Observed-run evidence capture: every duration/count claim carries a verbatim CI run ID
      and the exact scripts/ci/ci-run-metrics.sh / gh invocation that produced it"
    - "Evidence-class tagging (observed/proxy-observed/hermetic-unit/structural-argument) to
      prevent a proxy run or self-test from being skimmed as a direct observation"

key-files:
  created:
    - .planning/phases/230-tier-1-critical-path-reclamation/230-09-SUMMARY.md
  modified:
    - .planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md
    - scripts/ci/playwright-cache-key-guard.sh

key-decisions:
  - "AFTER-PR-WARM's warm commit is a one-line provenance comment appended to
    scripts/ci/playwright-cache-key-guard.sh (not touching the lockfile or the cache key
    itself) recording the AFTER-PR run ID as the cache-seeding run"
  - "Task 2's dispatch precondition ('recapture_branch empty') cannot succeed on a branch-ref
    workflow_dispatch (release_ref_guard requires refs/tags/v* or a non-empty
    recapture_branch, D-04); re-dispatched with recapture_branch set to the phase branch itself"
  - "AFTER-CANCEL's throwaway probe (PR #120) doubles as the observed docs_only=false
    impossibility evidence for AFTER-DOCSONLY: a Markdown-only probe commit still classifies
    non-docs-only because the classifier diffs against origin/main, which carries the phase's
    own non-Markdown changes"
  - "FAST-06's honest net is recorded as a cache-mechanism proof (Cache hit for / Cache restored
    from key on the hit run; real upload only on the miss run), not a wall-clock saving figure
    -- the Install Playwright browsers step showed no net time saving on this pair and that is
    recorded as an open discrepancy rather than adjusted away"

patterns-established:
  - "Post-merge obligations (AFTER-PUSH, AFTER-DOCSONLY) are recorded with Status: pending,
    their exact capture command, and a one-sentence structural reason they cannot exist
    pre-merge -- never silently dropped or fabricated"

requirements-completed: [FAST-02, FAST-03, FAST-04, FAST-05, FAST-06, FAST-07]

coverage:
  - id: D1
    description: "AFTER-PR and AFTER-PR-WARM captured: FAST-06 proven by an observed
      miss-then-hit Playwright browser cache pair on PR #117 (runs 30412458437, 30413542431),
      plus AFTER-PR's design-gallery 39-test / docs_only=false / admin_eval_render skipped facts"
    requirement: FAST-06
    verification:
      - kind: other
        ref: "bash scripts/ci/ci-run-metrics.sh --jobs 30412458437 (AFTER-PR); --jobs 30413542431 (AFTER-PR-WARM)"
        status: pass
    human_judgment: false
  - id: D2
    description: "AFTER-NONPR captured via workflow_dispatch (run 30414885679): admin_eval_render
      executes (17m54s), design_gallery_snapshots executes 84 tests, admin_design_recapture
      executes the full 123-test inventory (Pitfall 1 regression guard); recapture PR #119
      closed and its branch deleted"
    requirement: FAST-02
    verification:
      - kind: other
        ref: "bash scripts/ci/ci-run-metrics.sh --jobs 30414885679"
        status: pass
    human_judgment: false
  - id: D3
    description: "AFTER-CANCEL captured on throwaway PR #120: superseded run (30416160743)
      concludes cancelled, later run (30416184110) completes -- FAST-04's concurrency-group
      proof. AFTER-DOCSONLY's docs_only=false impossibility observed on the same commit.
      PR closed, branch deleted (remote ref confirmed 404)."
    requirement: FAST-04
    verification:
      - kind: other
        ref: "gh run list --repo szTheory/sigra --branch 230-09-cancel-probe --json databaseId,headSha,status,conclusion,createdAt"
        status: pass
    human_judgment: false
  - id: D4
    description: "230-EVIDENCE.md ledger closed: per-requirement summary table for FAST-02
      through FAST-07 plus SC-1/SC-2/SC-3 with an evidence-class column; predicted ~18m
      post-change PR wall-clock stated before the observed 16m52s; AFTER-PUSH and
      AFTER-DOCSONLY booked as explicit post-merge obligations; three discrepancies recorded
      as open items"
    requirement: FAST-05
    verification:
      - kind: unit
        ref: "python3 automated verify blocks embedded in 230-09-PLAN.md Tasks 1-3 (all print OK)"
        status: pass
    human_judgment: false

duration: 1h34m
completed: 2026-07-29
status: complete
---

# Phase 230 Plan 09: Observed-Run Evidence Capture Summary

**Completed Phase 230's before/after evidence ledger with four real CI runs (AFTER-PR, AFTER-PR-WARM, AFTER-NONPR, AFTER-CANCEL) and two explicit post-merge obligations, proving FAST-06's cache behavior as an observed miss-then-hit pair rather than a single-run claim.**

## Performance

- **Duration:** 1h34m
- **Started:** 2026-07-29T01:00:00Z (approx.)
- **Completed:** 2026-07-29T02:34:18Z
- **Tasks:** 3
- **Files modified:** 2 (`230-EVIDENCE.md`, `scripts/ci/playwright-cache-key-guard.sh`)

## Accomplishments

- **AFTER-PR + AFTER-PR-WARM (Task 1):** Captured the phase's own PR (#117) final commit
  (`ed55701a`, run `30412458437`) — design-gallery axe step at 39 tests, snapshot step skipped,
  `docs_only=false`, `admin_eval_render` skipped/0s, cache-hit: false (the key-introducing miss).
  Pushed one provenance-comment commit (`be2ff143`) as the warm commit and captured a second run
  (`30413542431`) on the same PR showing `cache-hit: true` / `Cache restored from key` — the
  hit half of FAST-06's proof.
- **AFTER-NONPR (Task 2):** Dispatched `workflow_dispatch` on the phase branch. First attempt
  with default inputs failed at `release_ref_guard` (a documented, not-a-regression guard
  behavior); re-dispatched with `recapture_branch` set to the phase branch and captured run
  `30414885679` — `admin_eval_render` executing at 17m54s, `design_gallery_snapshots` executing
  84 tests, `admin_design_recapture` executing the full 123-test inventory (confirming the
  120→123 correction, not a Pitfall 1 regression). Closed the recapture PR (#119) the dispatch
  opened.
- **AFTER-CANCEL + ledger close (Task 3):** Opened throwaway PR #120 from the phase branch,
  double-pushed to prove FAST-04's `cancel-in-progress` behavior (run `30416160743` cancelled,
  `30416184110` completed), and observed the `docs_only=false` impossibility on a Markdown-only
  commit — the in-phase evidence that closes FAST-05 alongside the hermetic self-test. Closed
  the ledger with a predicted-vs-observed wall-clock section, a per-requirement evidence-class
  table, FAST-06's honest net, and a discrepancies section.

## Task Commits

Each task was committed atomically:

1. **Task 1: AFTER-PR + AFTER-PR-WARM capture** — `be2ff143` (chore: provenance comment, the
   warm commit) + `e726f948` (docs: evidence capture)
2. **Task 2: AFTER-NONPR capture via workflow_dispatch** — `b49a47d2` (docs)
3. **Task 3: AFTER-CANCEL, post-merge obligations, ledger close** — `93d8de01` (docs)

**Plan metadata:** (this commit, following SUMMARY.md write)

## Files Created/Modified

- `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` — completed ledger:
  AFTER-PR, AFTER-PR-WARM, AFTER-NONPR, AFTER-CANCEL captured with verbatim run IDs and step
  logs; AFTER-PUSH, AFTER-DOCSONLY booked as post-merge obligations; per-requirement table with
  evidence classes; predicted-vs-observed wall-clock section; discrepancies section.
- `scripts/ci/playwright-cache-key-guard.sh` — one appended provenance comment (the AFTER-PR-WARM
  warm commit); self-test kept green (`bash scripts/ci/playwright-cache-key-guard.test.sh` →
  7 passed, 0 failed).

## Decisions Made

- The warm commit for AFTER-PR-WARM had to touch a file that is neither Markdown nor under
  `.planning/` (or the docs-only classifier would gate the Playwright lane off entirely). Used
  the plan's default choice: a one-line provenance comment in
  `scripts/ci/playwright-cache-key-guard.sh` recording the AFTER-PR run ID.
- Task 2's precondition ("`recapture_branch` empty") structurally cannot succeed on a
  branch-ref `workflow_dispatch` — `release_ref_guard` requires either a `refs/tags/v*` ref or
  a non-empty `recapture_branch` (D-04's relaxation). Re-dispatched with
  `recapture_branch=ci-efficiency-milestone-scope`, the documented way to run a branch-scoped
  dispatch.
- Recorded FAST-06's cache mechanism as directly proven (restore-log lines differ between miss
  and hit runs; the post-step upload happens only on the miss) without claiming a net
  wall-clock saving on this specific pair, since the `Install Playwright browsers` step's total
  duration was higher on the hit run — traced to apt-get variance in the non-cacheable
  OS-dependency install, not a defect in the cache wiring.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Task 2's `recapture_branch` empty precondition cannot succeed on a branch-ref dispatch**
- **Found during:** Task 2 (AFTER-NONPR capture)
- **Issue:** Dispatching `workflow_dispatch` on the phase branch with `recapture_branch` left
  at its default (empty) fails `release_ref_guard`, which requires a `refs/tags/v*` ref unless
  `recapture_branch` is set (D-04). Every downstream job — including the `admin_eval_render`
  and `design_gallery_snapshots` this task exists to observe — is skipped as a result.
- **Fix:** Re-dispatched with `recapture_branch=ci-efficiency-milestone-scope`.
- **Files modified:** None (dispatch invocation only).
- **Verification:** Second dispatch (run `30414885679`) passed `release_ref_guard` and executed
  the full matrix; all four AFTER-NONPR facts observed.
- **Committed in:** `b49a47d2` (documented in the AFTER-NONPR section as an in-ledger deviation
  note, since it changes what evidence a future reader sees, not repo code).

---

**Total deviations:** 1 auto-fixed (1 blocking, Rule 3).
**Impact on plan:** No repo code changed by the deviation — only the `gh workflow run` invocation
differed from the plan's literal precondition text. Recorded transparently in the ledger itself
so the discrepancy between the plan's precondition and the workflow's actual guard behavior is
visible to any future reader, not silently worked around.

## Issues Encountered

- **`gh` API transient network error** during a poll loop for run `30416184110` ("error
  connecting to api.github.com") — retried the same poll immediately and it succeeded; not a
  CI or evidence-capture defect.
- **`gh pr close --delete-branch` did not actually delete PR #120's remote branch** —
  `git fetch --prune` and a direct `gh api repos/.../branches/230-09-cancel-probe` call showed
  the branch still existed after the close. Deleted it explicitly via
  `gh api -X DELETE repos/.../git/refs/heads/230-09-cancel-probe` and confirmed a 404 on
  re-check. (PR #119's recapture branch, closed the same way earlier, deleted correctly on the
  first attempt — this appears to be `gh` CLI flakiness on the delete-branch flag rather than a
  systematic issue, but recorded here since it required a follow-up API call to actually
  complete the required cleanup.)

## User Setup Required

None — no external service configuration required. `gh auth status` was already authenticated
for `szTheory/sigra`.

## Next Phase Readiness

- Phase 230's evidence ledger (`230-EVIDENCE.md`) is complete for everything capturable
  pre-merge. `AFTER-PUSH` and `AFTER-DOCSONLY` remain explicit `Status: pending (post-merge
  obligation)` entries — both need the phase's PR (#117) to merge to `main` before they can be
  captured. Their exact capture commands are recorded in the ledger.
- Three discrepancies are recorded as open items (not blockers): the AFTER-PR-WARM install-step
  duration inversion (apt-mirror variance, not a cache defect), AFTER-NONPR's `ci-gate: failure`
  from the pre-existing GATE-02 defect (Phase 231's scope, not this phase's), and the Task 2
  precondition deviation documented above.
- `.planning/STATE.md` should be updated to reflect Phase 230 plan 9/9 complete after this
  summary lands; `230-VALIDATION.md`'s sign-off checklist items for the six observed-run slots
  are now satisfiable against this ledger's content, though updating that file's own checkboxes
  was not in this plan's `files_modified` scope.
- Phase 235 (Tier-2 and Playwright economics) owns the FAST-01 / under-12m verdict, measured
  over a dedicated ≥10-run post-change window — this plan's single AFTER-PR run is evidence for
  FAST-02 through FAST-07, not for FAST-01.

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-29*
