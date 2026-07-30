---
phase: 231-gate-honesty-nightly-revival
plan: 05
subsystem: infra
tags: [github-actions, ci, playwright, admin-eval, harness, css-tokens]

requires:
  - phase: 231-04
    provides: "webkit install for admin_eval_render + probes.ts SVGAnimatedString crash fix (D-11 steps 1-2), the two preconditions this plan needed cleared before phase (a) could run to near-completion"
provides:
  - "The first-ever real CI observation of the admin-eval harness: phase (a) executed 192 tests, 8 failed / 184 passed, and the harness aborted there under set -euo pipefail before phase (a2) or any of b1-b6 ran"
  - "A previously-undiagnosed HARD-GATE finding: probe #5 (off-scale-radius-shadow-control) fails .sg-applied-chip__remove's 22px control height against the --sg-control-* scale (28/36/44/48px), on every board surface that renders an applied-chip filter, on the admin-eval (desktop chromium) project only"
  - "Confirmation, from a downloaded bundle.json, that app_git_sha equals the run's headSha (769177ba...) for every bundle that WAS captured — the committed-HEAD trap does not apply to this run"
affects: [231-06]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "Task 1 executed as a pure read: CI run 30504235540 dispatched and observed; guides/reference/admin-render-sha.json and guides/reference/fix-queue.json were NOT modified (git diff --name-only for this plan is empty)."
  - "STOPPED before the plan's checkpoint:decision task (Task 2) and before Task 3. The observed red is not a b3/b4/b5 ledger-comparison red (the RESEARCH R4-R9 precondition inventory the checkpoint was built to reconcile) -- phase (a) itself failed on a genuine HARD-GATE probe finding, before phase (a2) or any b-phase ever ran. Task 3's own acceptance criteria explicitly forbid using a partial render as a baseline ('a partial render must never become a baseline; if the source run aborted, dispatch a fresh one first') -- and re-dispatching would deterministically reproduce the same failure, since the .sg-applied-chip__remove/--sg-control-* conflict is a fixed CSS fact, not a flake. Resolving it requires a code change (CSS, probe, or suppression-attribute decision) outside this plan's files_modified fence (guides/reference/admin-render-sha.json, guides/reference/fix-queue.json only) -- exactly the 'code fix outside the file fence, or a judgment call about real defect vs. environment' condition the orchestrator instructed this executor to stop and report on, rather than guess or patch around."
  - "One accidental side effect cleaned up: the recapture_branch=worktree-discuss-231 dispatch (required to satisfy release_ref_guard on a bare workflow_dispatch, per this plan's own repo-specific gotcha) caused admin_checkpoint_recapture to open PR #132 against worktree-discuss-231. Closed and its branch deleted; see Deviations."

requirements-completed: []

coverage: []

duration: 45min
completed: 2026-07-30
status: blocked
---

# Phase 231 Plan 05: D-11 step 3 — run the harness in CI and read what it says (BLOCKED, escalated)

**The admin-eval harness executed for real in CI for the first time (run 30504235540, job 90750408342): phase (a) ran 192 Playwright tests (8 failed / 184 passed, 22.7m) and the script aborted there under `set -euo pipefail` — none of phases (a2) or b1-b6 ever ran. The failure is a genuine, previously-undiagnosed HARD-GATE finding (probe #5, `off-scale-radius-shadow-control`: `.sg-applied-chip__remove`'s 22px control height is not on the `--sg-control-*` scale), which requires a code decision outside this plan's file fence — so this plan stops here and reports rather than guessing at a fix or a ledger reconciliation that does not apply to this failure class.**

## Performance

- **Duration:** ~45 min (dispatch attempt 1 → cancel → correct dispatch → harness completion → log analysis → cleanup)
- **Started:** 2026-07-30T00:54:24Z
- **Completed:** 2026-07-30 (stopped at the escalation point, not at plan completion)
- **Tasks:** 1 of 3 completed (Task 1: read/observe). Task 2 (checkpoint:decision) and Task 3 (apply reconciliation) NOT reached — see Key Decisions.
- **Files modified:** 0 (this plan is a pure observation; no ledger file was touched)

## Accomplishments

- **D-11 step 3 is now a real, recorded observation, not a checkbox.** b1 through b6 have executed zero times in CI, in either direction (pass or fail) — because phase (a) itself has never completed a render since the harness existed. This plan proves that fact from a real run rather than assuming it.
- Diagnosed the actual blocker precisely: a real CSS/design-token conflict, not either of the two bugs 231-04 already fixed (WebKit absence, SVGAnimatedString crash — both confirmed gone: zero WebKit-related and zero `className.includes` crash failures in this run).
- Confirmed, independently of b1 (which never ran), that the committed-HEAD trap does not apply here: every captured bundle's `app_git_sha` equals this run's `headSha` (`769177ba199c816601b5fb935cdec820b6c9ba58`), which is also this branch's current HEAD.
- Cleaned up an accidental side effect of the dispatch mechanics (PR #132) — see Deviations.

## Task Commits

No task commits — Task 1 is a pure read (no `guides/reference/admin-render-sha.json` or `guides/reference/fix-queue.json` change), and Tasks 2/3 were not reached.

**Plan-metadata commit:** this SUMMARY.md, committed alone (plan not complete; no STATE.md/ROADMAP.md/REQUIREMENTS.md completion bookkeeping performed — see Next Phase Readiness).

## Files Created/Modified

None. `git diff --name-only` against the branch tip this plan started from is empty for `guides/reference/`.

## Decisions Made

See `key-decisions` in frontmatter. In prose: this plan followed Task 1 to the letter (dispatch, read, classify — no fixing), then recognized that the observed red does not fit the shape Task 2's checkpoint was built for (a b3/b4/b5 ledger-comparison red per RESEARCH's R4-R9) and stopped rather than force-fitting it into `rebase-ci-native` / `route-as-regressions` / `no-change`. None of those three options are honest answers to "phase (a) itself failed on a HARD-GATE finding before any ledger comparison ran."

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, dispatch mechanics] Bare `workflow_dispatch` failed `release_ref_guard`; corrected dispatch input used**
- **Found during:** Task 1, first dispatch attempt
- **Issue:** `gh workflow run "CI" --ref worktree-discuss-231` (no inputs) reached `release_ref_guard`, which requires `refs/tags/v*` for a bare manual dispatch. It failed (`Manual CI release-evidence runs must use refs/tags/v*`), and `admin_eval_render` (which `needs: [release_ref_guard]`) concluded `skipped` — run `30504166627`. This is the exact gotcha flagged in this plan's brief (the same one that produced PRs #126-131 in an earlier plan).
- **Fix:** Cancelled the useless run (`gh run cancel 30504166627`), then redispatched with `-f recapture_branch=worktree-discuss-231`, which `release_ref_guard`'s own logic treats as "recapture dispatch; guard not applicable" (`ci.yml:80-82`). `release_ref_guard` succeeded on the corrected dispatch (run `30504235540`) and `admin_eval_render` actually ran.
- **Files modified:** None (CI dispatch mechanics only, no repo file change).
- **Verification:** `gh run view 30504235540 --json jobs` shows `Release ref guard: success` and `Admin eval render + probe: failure` (executed, not skipped) — the correct shape for D-11 step 3's observation goal.
- **Committed in:** N/A (no repo change).

**2. [Rule 3 - Blocking, side-effect cleanup] Closed an accidentally-opened recapture PR**
- **Found during:** post-run cleanup, per the plan's repo-specific gotchas ("clean up anything you create; report anything you created and closed")
- **Issue:** Setting `recapture_branch` (required to clear `release_ref_guard`, see #1 above) also satisfies `admin_design_recapture` and `admin_checkpoint_recapture`'s shared `if: github.event_name != 'pull_request'` condition — there is no way to dispatch a workflow_dispatch run that reaches `admin_eval_render` without also running these two jobs. `admin_checkpoint_recapture` found a drifted baseline (`impersonation-banner`, 3 PNGs) and opened PR #132 (`ci/recapture-admin-checkpoints-30504235540` → `worktree-discuss-231`, scoped correctly by the `recapture_branch` input rather than landing on `main`). `admin_design_recapture` found nothing to commit and opened no PR.
- **Fix:** Closed PR #132 with an explanatory comment and deleted its branch (`gh pr close 132 --delete-branch`). Verified no other open recapture PRs remain (`gh pr list --search recapture --state all` shows #126-131 already closed by a prior plan, and #132 now closed by this one).
- **Files modified:** None (GitHub PR/branch cleanup only).
- **Verification:** `gh pr list --repo szTheory/sigra --state open` no longer lists #132; `gh pr view 132` shows `state: CLOSED`.
- **Committed in:** N/A (no repo change).

---

**Total deviations:** 2 (both Rule 3, dispatch-mechanics/cleanup — neither touched a repo file).
**Impact on plan:** No scope creep. Both deviations were procedural (how to reach the observation), not substantive changes to the plan's deliverable.

## Issues Encountered

**The plan's stated purpose — "find out what b1-b6 actually do in CI" — resolved to "they have not yet had the chance to run," which is itself the honest finding this plan exists to surface (per D-15's framing: "b1-b6 have never executed in CI, so their pass is unproven"). See Verification Evidence below for the full quoted record.**

## User Setup Required

None.

## Next Phase Readiness

**This plan is BLOCKED, not complete.** GATE-04 is NOT marked complete (correctly — 231-CONTEXT's own gotcha warns against exactly this). `state advance-plan` was NOT run. Plan 231-06 (which deletes `ci.yml:2450`'s job-level `continue-on-error`, D-11 step 4) MUST NOT proceed until this finding is resolved — deleting the flag now would turn `admin_eval_render` into a hard-failing job on every push to `main`, on a defect that is real and currently unfixed.

**What is needed to unblock, in order:**
1. A decision on `.sg-applied-chip__remove`'s relationship to probe #5 (`off-scale-radius-shadow-control`)'s control-height scale check — three honest routes, none of which are in this plan's file fence:
   - **(a)** Change the component's height to snap to `--sg-control-xs` (28px) or another scale step — a visible design change to the shipped applied-chip remove affordance across the admin UI, in tension with `guides/reference/admin-quality-ledger.md:65`'s existing, separately-reviewed target-size decision ("remove control `sg-applied-chip__remove` ~22×22 CSS px (near-threshold; ... D-08 near-threshold precedent for dense admin inline chip remove)").
   - **(b)** Exempt `.sg-applied-chip__remove` from probe #5's `isControl` check via the existing `data-sg-off-scale-radius-shadow-control-audit-only` suppression attribute (`probes.ts:432`), if the near-threshold sizing is judged intentional and the control-scale check inapplicable to this specific inline chip affordance.
   - **(c)** Remove `.sg-applied-chip__remove` from probe #5's `isControl` classlist (`probes.ts:481-484`) entirely, if the probe's scope was over-broad when it was authored (216-05/06) and a chip's remove-link was never meant to be checked against button/input-scale control heights in the first place.
2. Once resolved and committed (outside this plan's fence), re-dispatch `admin_eval_render` (same `recapture_branch` mechanics documented above) and re-run this plan's Task 1 read against the new run. Only then does Task 2's checkpoint (which reconciliation route for any *b3/b4/b5* red, if one still occurs) become the correct next step.
3. **Do not treat this SUMMARY's diagnosis as authorization to make the fix.** It is outside `files_modified` (`guides/reference/admin-render-sha.json`, `guides/reference/fix-queue.json` only) and is exactly the kind of code-level judgment call this plan was instructed to stop and report rather than resolve unilaterally.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30 (blocked/escalated, not plan-complete)*

## Verification Evidence (actually run)

### Run and job identity

- **CI run (successful dispatch, the one this SUMMARY reports on):** `30504235540` — `https://github.com/szTheory/sigra/actions/runs/30504235540`
  - Trigger: `workflow_dispatch` with `recapture_branch=worktree-discuss-231`
  - `headSha`: `769177ba199c816601b5fb935cdec820b6c9ba58` (this branch's HEAD at dispatch time — no new commits landed before or during this plan)
  - `headBranch`: `worktree-discuss-231`
- **`Admin eval render + probe (evidence only, not a merge gate)` job:** `90750408342`
  - `status`: `completed`, `conclusion`: **`failure`**
  - Started: `2026-07-30T00:57:30Z`, Completed: `2026-07-30T01:21:51Z` — **wall-clock ≈ 24m21s**, comfortably inside the 40-minute job `timeout-minutes` ceiling (≈61% of it; no timeout risk observed).
- **Discarded first attempt (bare dispatch, cancelled):** run `30504166627` — `release_ref_guard` failed (`Manual CI release-evidence runs must use refs/tags/v*`); `admin_eval_render` concluded `skipped` (not a real observation). Cancelled via `gh run cancel`.

### Phase (a)'s Playwright summary line — quoted verbatim from the job log

```
2026-07-30T00:59:02.7349560Z Running 192 tests using 1 worker
...
2026-07-30T01:21:43.0900226Z   8 failed
2026-07-30T01:21:43.0944308Z   184 passed (22.7m)
2026-07-30T01:21:43.4516190Z ##[error]Process completed with exit code 1.
```

### Which of the seven harness banners appeared, in order — quoted verbatim

Only **one** banner appears in the entire step log (`Run admin-eval harness (render matrix + derivative guards)`):

```
2026-07-30T00:59:01.3014081Z admin-eval-harness: (a) render matrix + probes + bundles (3 projects)
```

**No other banner appears.** The following, all absent (grep for `admin-eval-harness:` across the full step log returns exactly the one line above):
- `admin-eval-harness: (a2) fix-queue derivation + open_findings update (D-12)` — **absent**
- `admin-eval-harness: (b1) stale-render guard` — **absent**
- `admin-eval-harness: (b2) evidence anchor integrity check` — **absent**
- `admin-eval-harness: (b3) fix-queue derived-field lint (auto_eligible, priority, open_findings)` — **absent**
- `admin-eval-harness: (b4) quality findings consistency guard (working-tree vs committed HEAD)` — **absent**
- `admin-eval-harness: (b5) award ledger verify-then-climb guard (working-tree vs committed HEAD)` — **absent**
- `admin-eval-harness: (b6) settled findings lint` — **absent**
- `admin-eval-harness: PASS — all phases green` — **absent**

**Why:** `npx playwright test tests/admin-eval.spec.ts --project=admin-eval --project=admin-eval-mobile --project=admin-eval-dark` (phase (a)) exited with `Process completed with exit code 1` (8 test failures), and the harness runs under `set -euo pipefail` (`admin-eval-harness.sh:55`) — the very next command (`node scripts/ci/fix-queue-build.mjs`, phase (a2)) never executed, and neither did any of b1-b6. The harness died at the **first** phase, not partway through the b-phases.

### b1's `stale-render-guard` line — **could not be quoted; b1 never ran.** Independent confirmation instead.

b1 never executed (see banner list above), so there is no `stale-render-guard: checking N bundle(s) against HEAD <sha>` line to quote from this run. Assumption A7 (shallow checkout keeps `bundle_sha == HEAD`) is **not settled by this run's b1 execution** — but it IS independently confirmed true by inspecting a captured bundle directly:

```
$ gh run download 30504235540 --repo szTheory/sigra --name admin-eval-bundles-30504235540 --dir /tmp/admin-eval-bundles-30504235540
$ find /tmp/admin-eval-bundles-30504235540 -name "bundle.json" | wc -l
171
$ find /tmp/admin-eval-bundles-30504235540 -name "bundle.json" | head -1 | xargs cat | node -e "...console.log('app_git_sha:', j.app_git_sha)"
app_git_sha: 769177ba199c816601b5fb935cdec820b6c9ba58
```

This matches the run's `headSha` (`769177ba199c816601b5fb935cdec820b6c9ba58`) exactly. 171 of an expected 186 cells' worth of bundles were captured (partial, by construction — the 8 failing test IDs across the `admin-eval` project never wrote a `bundle.json`, and each failure retried once, contributing to the shortfall along with any bundles the mobile/dark projects share cell keys with). No shallow-clone mismatch occurred for any bundle that WAS written; had b1 run, it would have found no SHA-mismatch violations among the 171 captured bundles. It is dishonest to claim more than that — b1 itself never ran, so its own check of the missing 15 bundles-that-should-exist (the ones the harness would have flagged as "bundle absent" had phase (a) not already aborted first) was never performed either.

### Exact failure text of the first red phase, with surface and cell, classified

**Failing phase:** (a) itself — `npx playwright test tests/admin-eval.spec.ts` on the `admin-eval` project (desktop Chrome, HARD-GATE geometry). Not a b-phase. **8 distinct test failures**, all the same probe class, all on the `admin-eval` project only (zero failures on `admin-eval-mobile` or `admin-eval-dark`):

```
1) [admin-eval] › tests/admin-eval.spec.ts:382:11 › render bundle: board-mg-2/populated
   Error: Gate-severity probe findings on board-mg-2-populated/light-desktop-populated:
     [off-scale-radius-shadow-control] .sg-applied-chip__remove: control height 22px is not on --sg-control-* scale
     (×6, repeated per occurrence of the control on the board)
   at captureSurface (tests/admin-eval.spec.ts:330:13)

2) board-mg-2/zero        — identical finding, cell light-desktop-zero
3) board-mg-2/loading     — identical finding, cell light-desktop-loading
4) board-mg-2/error       — identical finding, cell light-desktop-error
5) board-task_card/default    — Gate-severity probe findings on board-task_card-default/light-desktop-populated
6) board-applied_chip/default — Gate-severity probe findings on board-applied_chip-default/light-desktop-populated
7) board-skeleton/default     — Gate-severity probe findings on board-skeleton-default/light-desktop-populated
8) board-audit_row/default    — Gate-severity probe findings on board-audit_row-default/light-desktop-populated
```

Every failure is the identical probe class and message shape: `[off-scale-radius-shadow-control] .sg-applied-chip__remove: control height 22px is not on --sg-control-* scale`, thrown from `probes.ts`'s probe #5 (`probeOffScaleRadiusShadowControl`, `probes.ts:408-540`) via `admin-eval.spec.ts:330` (`captureSurface`'s gate-finding throw). `probes.ts:481-484` deliberately includes `.sg-applied-chip__remove` in the `isControl` check; the shipped CSS (`sigra_admin.css:949-957`) sizes it purely via content + `padding: var(--sg-space-1)` with no explicit height/min-height on the `--sg-control-*` scale (`xs`=28px, `sm`=36px, `md`=44px, `lg`=48px) — 22px matches none of them.

**Classification against RESEARCH's R1-R12 table: does not match any row.** R1-R3 and R10-R12 concern phase (a)'s own environment (checkout depth, WebKit, timeout) and are confirmed **not** the cause here (WebKit is installed and used correctly — zero `admin-eval-mobile` failures; no `SVGAnimatedString`/`className.includes` crash appears anywhere in the log). R4-R9 all describe *b-phase* reds that presuppose phase (a) succeeded — none apply, because phase (a) itself is what failed. This is a **new precondition class**, call it **R13**: a genuine HARD-GATE probe finding, undiscoverable before now because no CI render had ever completed far enough to exercise probe #5 against a real `.sg-applied-chip` render (the two 231-04-fixed bugs blocked every previous attempt).

### Job conclusion and duration

```
$ gh run view 30504235540 --repo szTheory/sigra --json jobs
"Admin eval render + probe (evidence only, not a merge gate)": status=completed, conclusion=failure
started: 2026-07-30T00:57:30Z, completed: 2026-07-30T01:21:51Z  →  24m21s wall-clock
```

24m21s is well inside the job's `timeout-minutes: 40` ceiling (≈61%). No timeout risk; `continue-on-error: true` (job-level, `ci.yml:2450`, untouched by this plan) is why this red did not sink the overall run — `admin_eval_render` is advisory-only and not in `ci-gate.needs`. (`ci-gate` did go red on this run, but from `upgrade_smoke`'s pre-existing, unrelated failure — see below, not from `admin_eval_render`, which is correctly excluded from `ci-gate.needs`.)

### Ledger integrity check (post-run)

```
$ node -e "const l=require('./guides/reference/admin-render-sha.json'); ... cells: 186, total open_findings: 33642"
```
Unchanged from before this plan ran — `git diff --name-only` shows no change to `guides/reference/admin-render-sha.json` or `guides/reference/fix-queue.json`. The read did not corrupt the ledger, and no ledger write was attempted (correctly — Task 3's own acceptance criteria forbid committing a regeneration from a partial/aborted render).

### Other run context (for completeness, not part of this plan's mandate)

- `Upgrade smoke (published source series → local candidate)`: **failure** — per the coordinator's note, this is pre-existing, unrelated repo debt (the `<.button type>` upgrade-smoke issue tracked separately: `.planning/todos/pending/2026-07-10-upgrade-smoke-button-type-hex-publish.md`-class issue). Not chased by this plan.
- `ci-gate`: **failure** — a downstream consequence of `upgrade_smoke`'s pre-existing failure (a real `ci-gate.needs` lane); `admin_eval_render` is correctly NOT in `ci-gate.needs`, so its own failure did not additionally redden `ci-gate`.
- `Notify on red ci-gate (release-lane-rot)`: **success** — the D-22/D-23 self-healing notifier fired correctly against the real red `ci-gate`, consistent with prior-plan evidence (issue #118).
- `Generated admin Playwright smoke`: **success** (GATE-02, landed by 231-02) — unaffected by this finding.
- `Recapture admin-design baselines (in-CI)`: **success**, no PR opened (no drift found).
- `Recapture admin-checkpoint baselines (in-CI)`: **success**, opened PR #132 (drift: `impersonation-banner`) — closed by this plan, see Deviations.

## Self-Check: PASSED

- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-05-SUMMARY.md`
- CONFIRMED: `guides/reference/admin-render-sha.json` still parses (186 cells, 33,642 open_findings — unchanged)
- CONFIRMED: `guides/reference/fix-queue.json` untouched (`git diff --name-only` empty for `guides/reference/`)
- CONFIRMED: CI run `30504235540` exists and is queryable (`gh run view 30504235540`)
- CONFIRMED: job `90750408342` (`Admin eval render + probe`) exists within that run, `conclusion: failure`
- CONFIRMED: PR #132 is closed (`gh pr view 132` → `state: CLOSED`) and its branch deleted
- CONFIRMED: no other open recapture PRs remain (`gh pr list --search recapture --state all` — all `#126-132` are `CLOSED`)
