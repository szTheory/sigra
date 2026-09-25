---
phase: 231-gate-honesty-nightly-revival
plan: 07
subsystem: infra
tags: [github-actions, ci, gate-honesty, prohibition-guard, ci-skip-manifest]

requires:
  - phase: 231-GAP-GATE02
    provides: "the corrected, multi-round-proven 320px reflow containment fix (8/8 green dispatched runs at sha 70bed477), which is D-08/D-09's hard-fail precondition for enabling the lane on pull_request"
provides:
  - "D-06's deletion: generated_admin_playwright_smoke's stale head_ref-keyed `if:` is gone outright (not replaced), so the job runs on every event including pull_request, gated by nothing"
  - "The same-commit companion set (C-2's corrected, larger-than-D-10 scope): the manifest row recording the stale gate deleted; p10's tier-A and total-row floors lowered with the reason recorded in each assertion message; three MAINTAINING.md passages (cadence list, Tier A prose, accepted-residuals renumbering) reconciled"
  - "GATE-03's first load-bearing use of the manifest's gate column: a new p10 assertion comparing each row's recorded gate against the real ci.yml if:, and a second forbidding any gate from referencing github.head_ref, a branch path, or a literal SHA -- both proven fail-first against violating fixtures"
  - "Genuine, observed pull_request-event execution proof: two separate PR-event CI runs (30521272305 at 6741eebd, 30523049209 at 7cae9ae8) both show `Generated admin Playwright smoke: success`, non-skipped -- the first time this lane has ever executed on a real pull_request event"
  - "generated_admin_playwright_smoke is confirmed IN ci-gate.needs (ci.yml:1831), so this enable is merge-blocking on PRs, not merely visible -- the asymmetric contrast to admin_eval_render (hard signal on push/schedule/dispatch, but NOT in ci-gate.needs, still skips on PRs) is why GATE-02 closes here while GATE-04 stays Pending"
  - "A same-defect-class bug found and fixed mid-plan: scripts/ci/ci-demotion-observer.test.sh's EVAL_NAME fixture still carried admin_eval_render's PRE-231-06 display name, so 5 of its 19 cases silently stopped resolving the moment 231-06's rename landed in the real manifest -- a guard that had quietly stopped asserting the truth, caught only because this plan's own dispatches exercised it"
affects: [231-08, 231-09, 231-10, 231-11]

tech-stack:
  added: []
  patterns:
    - "Same-commit multi-file demotion reversal: deleting a gate condition, its manifest row, and the guard floors that enumerate it all land in ONE commit, with the floor's new value and its reason recorded INSIDE the assertion message rather than in a comment beside it -- so the guard's own failure text is the audit trail if the floor is ever moved again without justification."
    - "Gate-column parity as a guard, not just an id/display_name guard: p10 now extracts the job- or step-level `if:` from ci.yml and compares it (after normalizeExpr) against the manifest's own recorded `gate` cell -- the check that would have caught GATE-02's defect, generalized so the next one like it cannot land silently."
    - "A rotted-gate-string blocklist (head_ref / branch path / literal SHA) as a standing structural prohibition, not a one-off fix -- forbidding the PATTERN that produced GATE-02's defect is stated as stronger than fixing the one instance."

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - .github/ci-skip-manifest.tsv
    - scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs
    - MAINTAINING.md
    - scripts/ci/ci-demotion-observer.test.sh

key-decisions:
  - "GATE-02 is marked Complete in REQUIREMENTS.md. Its literal text -- 'Generated-host parity is verified on a lane that actually executes; no required or aggregated lane can report pass solely because it was skipped by a stale condition' -- is fully satisfied and observed: the stale condition is deleted outright (not replaced with the house non-PR pattern, which D-06 explicitly rejects as restating the defect), the lane is confirmed IN ci-gate.needs (ci.yml:1831, so it is a required/aggregated lane), and two independent pull_request-event CI runs show it executing (success, non-skipped) rather than reporting pass by being skipped."
  - "GATE-03 is NOT marked Complete. Its literal text -- 'ci-gate distinguishes skipped because correctly gated for this event from skipped because its gate rotted, and fails on the latter' -- describes a RUNTIME verdict mechanism inside the ci-gate job itself. ci-gate's own verification step (ci.yml:1835+) is unchanged by this plan: it still treats every `skipped` result as a pass for every lane in its `needs:`, with no distinction between a legitimate and a rotted skip. This plan delivers a necessary STATIC precondition for that mechanism (the manifest's `gate` column is now cross-checked against ci.yml and forbidden from referencing head_ref/branch/SHA, both enforced in fast_checks on every PR) but does not build the runtime verdict script (`scripts/ci/honest-skip-verdict.sh` per D-01/D-02, wired into ci-gate as a step) that GATE-03's text actually requires. That remains open work for a later plan in this phase (per the phase's own Wave-0 inventory)."
  - "The ci-demotion-observer.test.sh fix is recorded as a deviation, not folded silently into Task 1: it is a genuine bug (Rule 1) discovered mid-plan, in a file outside this plan's declared fence, caused by 231-06's rename never being verified against this specific bash self-test locally. Fixing it was necessary to obtain ANY green CI run, and it is explicitly a strengthening (the guard's recorded expected data now matches the one fewer/renamed lane it actually tracks) rather than a widening -- no assertion was relaxed and no exemption was added."
  - "Sample size, stated explicitly per the plan's own mandate not to repeat 231-02's single-green-run error: the corrected CSS fix (sha 70bed477) has now been green on 12 consecutive observed CI executions of Generated admin Playwright smoke across three different shas (70bed477: 8/8 workflow_dispatch; 6741eebd: 2/2, one workflow_dispatch + one pull_request, job-level green even though the overall run failed on an unrelated Fast-checks bug; 7cae9ae8: 2/2, one workflow_dispatch + one pull_request, fully green including ci-gate) and two trigger types, zero failures, against a formerly ~38-60% failure rate."

requirements-completed: [GATE-02]

coverage:
  - id: D1
    description: "ci.yml:1674's stale head_ref-keyed if: is deleted outright (not replaced with a non-PR pattern), so generated_admin_playwright_smoke runs on every event including pull_request, with timeout-minutes/needs/name unchanged"
    requirement: "GATE-02"
    verification:
      - kind: unit
        ref: "actionlint -shellcheck= .github/workflows/ci.yml -- exit 0; python3 YAML-parse assertion -- job declares no `if` key, name/timeout-minutes/needs byte-unchanged"
        status: pass
      - kind: integration
        ref: "CI run 30523049209 (pull_request event, sha 7cae9ae8): Generated admin Playwright smoke -- success, non-skipped; ci-gate -- success. CI run 30521272305 (pull_request event, sha 6741eebd): Generated admin Playwright smoke -- success, non-skipped (first-ever PR-event execution of this lane)."
        status: pass
    human_judgment: false
  - id: D2
    description: "Same-commit companions land alongside the deletion: manifest row removed, p10's tier-A (9->8) and total-row (12->11) floors lowered with the reason recorded inside each assertion message, MAINTAINING.md's three passages (cadence list :137, Tier A prose :152-157, accepted-residuals :274-282) reconciled, and MAINTAINING.md:104-110's five ruleset-required check-name strings left byte-unchanged"
    requirement: "GATE-02"
    verification:
      - kind: unit
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs -- 58/58; python3 manifest-parse assertion -- generated_admin_playwright_smoke absent, admin_eval_render + design_gallery_snapshots present, 15 total rows, exactly 8 tier-A; git diff MAINTAINING.md shows no hunk in the :104-110 range"
        status: pass
    human_judgment: false
  - id: D3
    description: "p10 gains two new assertions making the manifest's gate column load-bearing: a gate-column-vs-ci.yml parity check, and a rotted-gate-string prohibition (no gate may reference github.head_ref, a branch path, or a literal SHA) -- both proven fail-first against violating fixtures via GSD_PROHIB_SUBJECT"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs (58/58 total suite, including both new tests, against the shipped manifest); fail-first observed separately against two mutated temp fixtures (quoted below) -- gate-mismatch fixture: 7/8 pass, 1 fail with the exact assertion diff; rotted-gate fixture: 1 fail naming the offending row and the matched pattern"
        status: pass
    human_judgment: true
    rationale: "GATE-03's literal REQUIREMENTS.md text describes ci-gate's own runtime verdict distinguishing a legitimate skip from a rotted one. This plan's two new assertions are a necessary static precondition (the manifest's gate column is now cross-checked and forbidden from rotted patterns) but do not implement that runtime mechanism inside ci-gate itself -- that is scripts/ci/honest-skip-verdict.sh per D-01/D-02, not built by this plan. A human/later-plan judgment is required on whether GATE-03 closes incrementally or only on the runtime script landing; this plan does not claim GATE-03 complete."
  - id: D4
    description: "scripts/ci/ci-demotion-observer.test.sh's stale EVAL_NAME fixture (pre-231-06 admin_eval_render display name) is corrected to match the real, current name, restoring the self-test to 19/19 -- a strengthening (recorded truth now matches the one fewer/renamed lane actually tracked), not a widening"
    requirement: null
    verification:
      - kind: unit
        ref: "bash scripts/ci/ci-demotion-observer.test.sh -- 19/19 (was 14/19 before the fix); CI job Fast checks -- failure at sha 6741eebd (both events), success at sha 7cae9ae8 (both events)"
        status: pass
    human_judgment: false
  - id: D5
    description: "generated_admin_playwright_smoke confirmed IN ci-gate.needs (ci.yml:1831), so the enable is merge-blocking on PRs, not merely visible -- contrasted explicitly against admin_eval_render (hard signal on push/schedule/dispatch, NOT in ci-gate.needs, still skips on PRs), which is why GATE-02 closes while GATE-04 correctly stays Pending"
    requirement: "GATE-02"
    verification:
      - kind: other
        ref: "grep -A15 '^  ci-gate:' .github/workflows/ci.yml -- generated_admin_playwright_smoke present in needs:, admin_eval_render absent"
        status: pass
    human_judgment: false

duration: ~1h9min (2 CI round-trips: ~30min for the first pair of runs that surfaced the demotion-observer bug, ~27min for the confirming pair after the fix)
completed: 2026-07-30
status: complete
---

# Phase 231 Plan 07: GATE-02 enabled on pull_request, genuinely merge-blocking, with observed PR-event proof

**`generated_admin_playwright_smoke`'s stale `head_ref`-keyed condition is deleted outright (not replaced) so the job now runs -- and is confirmed executing, non-skipped -- on real `pull_request` events; it is confirmed `ci-gate.needs`-blocking; `p10` gains two new assertions making the skip-manifest's `gate` column load-bearing for the first time; and a same-defect-class bug (a guard's own stale expected data, left behind by 231-06's rename) was found and fixed along the way.**

## Performance

- **Duration:** ~1h9min, almost entirely CI wall-clock across two round-trips
- **Started:** 2026-07-30 ~06:46 UTC (immediately after the GATE-02 gap-closure task)
- **Completed:** 2026-07-30 ~07:56 UTC
- **Tasks:** 2 planned (Task 1: delete the gate + same-commit companions; Task 2: confirm + record SC-2), plus one unplanned deviation task (fix the demotion-observer self-test) discovered between them
- **Files modified:** 5 (4 in the plan's declared fence, 1 deviation outside it)

## Accomplishments

- **D-06's deletion landed exactly as specified.** `ci.yml:1674`'s `if: github.event_name != 'pull_request' || github.head_ref == 'ship/v1.42-ci-gate-remediation'` is gone -- not replaced with the house `github.event_name != 'pull_request'` pattern, which the plan explicitly forbids because it would still leave parity verified on no PR at all. `timeout-minutes: 15`, `needs: release_ref_guard`, and the job `name:` are byte-unchanged.
- **The same-commit companion set landed in one commit** (`6741eebd`): the manifest row recording the stale gate string verbatim is deleted; `p10`'s tier-A floor (9->8) and total-row floor (12->11) are lowered with the reason recorded inside each assertion's own failure message, naming the removed row and citing Phase 231 GATE-02 / D-06; `MAINTAINING.md`'s three passages (the nightly-only cadence list, the Tier A honest-skip prose, and the accepted-residuals section, which now describes one residual instead of two) are all reconciled. `MAINTAINING.md:104-110`'s five ruleset-required check-name strings are confirmed byte-unchanged.
- **GATE-03's manifest gate column is now load-bearing for the first time.** Two new `p10` assertions: one compares every manifest row's recorded `gate` against the real `if:` ci.yml declares (job-level directly; step-level via a new `stepIf` helper scoped to the step's `id:` line and the next step boundary), and one forbids any gate from referencing `github.head_ref`, a branch path, or a literal commit SHA. Both are proven fail-first against mutated temporary fixtures (not committed to the repo, per the plan's file fence) via `GSD_PROHIB_SUBJECT` -- see Verification Evidence below for the exact failure output.
- **Genuine `pull_request`-event execution is observed, twice, independently.** CI run `30521272305` (sha `6741eebd`) and CI run `30523049209` (sha `7cae9ae8`) both show `Generated admin Playwright smoke: success`, non-`skipped` -- the first time in this repo's history this lane has executed on a real `pull_request` event rather than being inferred from YAML.
- **The enable is confirmed merge-blocking, not merely visible.** `generated_admin_playwright_smoke` is present in `ci-gate.needs` (`ci.yml:1819-1832`). This is the asymmetry that lets GATE-02 close here while GATE-04 correctly stays `Pending`: `admin_eval_render` is a hard signal on push/schedule/dispatch but is NOT in `ci-gate.needs` and still skips on every PR.
- **A same-defect-class bug was found and fixed mid-plan, not written off as a typo.** `scripts/ci/ci-demotion-observer.test.sh`'s `EVAL_NAME` fixture still read `admin_eval_render`'s PRE-231-06 display name (`"...evidence only, not a merge gate)"`); once the real manifest carried 231-06's renamed value (`"...hard signal on push/schedule/dispatch; not in ci-gate)"`), the script's live name-resolution against the real manifest stopped matching the self-test's own hardcoded fixture payload, and 5 of 19 cases silently started failing with "not found in the run by name." This is thematically the same failure class this whole phase exists to find: a guard whose recorded expected data had quietly drifted from reality. Fixed by updating the one string; this is a strengthening (the guard now asserts exactly the truth) not a widening.
- **Two confirming CI runs after the fix are fully green**, both events, both including `ci-gate: success`: PR-event run `30523049209` and dispatch run `30523113463`, both at sha `7cae9ae8`.
- **Two `github-actions` recapture PRs spawned by this plan's dispatches were closed** (`#164`, `#165`, both `ci/recapture-admin-checkpoints-<runid>` targeting `worktree-discuss-231`), with their branches deleted. No recapture PRs remain open.

## Task Commits

1. `6741eebd` (feat) -- Task 1: delete `generated_admin_playwright_smoke`'s stale `head_ref` gate; same-commit companions (`.github/ci-skip-manifest.tsv` row deletion, `p10`'s two lowered floors plus two new assertions, three `MAINTAINING.md` passages).
2. `7cae9ae8` (fix) -- unplanned deviation, discovered between Task 1's dispatch and Task 2's confirmation: correct `scripts/ci/ci-demotion-observer.test.sh`'s stale `EVAL_NAME` fixture.

Task 2 (confirm the enabled lane + record SC-2's restatement) changed no files beyond the deviation fix above -- its deliverable is the observed-run evidence recorded in this SUMMARY, per its own acceptance criteria ("Change no file in this task unless the run reds").

**Plan-metadata commit:** created after this SUMMARY, per `commit_docs: true`.

## Files Created/Modified

- `.github/workflows/ci.yml` -- `generated_admin_playwright_smoke`'s stale `if:` and its now-false D-08 comment deleted; replaced with a Phase 231 GATE-02 / D-06 comment recording the deletion, the defect it corrects, and the measured cost (~4 runner-minutes fully parallel vs a 989s PR pole). `timeout-minutes`, `needs`, `name` unchanged.
- `.github/ci-skip-manifest.tsv` -- the `generated_admin_playwright_smoke` tier-A row deleted; both `observer: assert` rows (`admin_eval_render`, `design_gallery_snapshots`) untouched.
- `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` -- tier-A floor 9->8, total-row floor 12->11, both with the reason recorded inside the assertion message; two new tests (`gate` column vs `ci.yml`, rotted-gate-string prohibition) plus a local `stepIf` helper.
- `MAINTAINING.md` -- nightly-only cadence list, Tier A honest-skip prose, and accepted-residuals section (renumbered to one entry, residual 2 marked "Retired (Phase 231 GATE-02 / D-06)") all reconciled. `:104-110` untouched.
- `scripts/ci/ci-demotion-observer.test.sh` -- `EVAL_NAME` fixture corrected from the pre-231-06 stale display name to the current one (deviation, outside the plan's declared fence).

## Decisions Made

See `key-decisions` in frontmatter. In full:

1. **GATE-02 marked Complete** in `REQUIREMENTS.md`, cited against two independent `pull_request`-event runs (`30521272305`, `30523049209`) plus the `ci-gate.needs` confirmation.
2. **GATE-03 left `Pending`.** This plan's two new `p10` assertions are a genuine, necessary contribution to GATE-03 (the manifest's `gate` column is now cross-checked and forbidden from rotted patterns, in `fast_checks` on every PR) but do not build the runtime verdict mechanism inside `ci-gate` that GATE-03's literal text describes. That remains a later plan's work per this phase's own Wave-0 inventory (`scripts/ci/honest-skip-verdict.sh` + `.test.sh`, D-01/D-02).
3. **GATE-04 status untouched**, correctly `Pending`, per explicit instruction.
4. **The demotion-observer fix is documented as a deviation** (Rule 1, auto-fixed bug) rather than folded silently into Task 1's commit, because it touches a file outside the plan's declared fence and was discovered only via this plan's own CI dispatches, not anticipated by the plan text.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `ci-demotion-observer.test.sh`'s stale `admin_eval_render` display-name fixture**
- **Found during:** Task 2 (confirming the enabled lane) -- both CI dispatches at sha `6741eebd` (PR-event run `30521272305`, dispatch run `30521297923`) reported `Fast checks: failure` at step "Demotion observer self-test," despite this plan's own Task 1 changes having nothing to do with `admin_eval_render`.
- **Issue:** `scripts/ci/ci-demotion-observer.test.sh`'s hardcoded `EVAL_NAME="Admin eval render + probe (evidence only, not a merge gate)"` was the job's PRE-231-06 display name. `ci-demotion-observer.sh` resolves a construct's expected display name live from the real `.github/ci-skip-manifest.tsv`, which 231-06 (commit `e38693b7`) had already updated to the new name (`"...hard signal on push/schedule/dispatch; not in ci-gate)"`). Once the manifest carried the new name, the self-test's own fixture payload (built with the stale `EVAL_NAME`) stopped matching, and 5 of 19 cases failed with "not found in the run by name -- renamed, removed, or its owning job never ran." 231-06's own dispatched confirming run (`30514238789`, sha `91d42bf8`) had happened BEFORE the rename commit (`e38693b7`), so this drift was never locally exercised by 231-06 before this plan's dispatch surfaced it.
- **Fix:** updated `EVAL_NAME` to the current, real display name. No other change.
- **Files modified:** `scripts/ci/ci-demotion-observer.test.sh`.
- **Verification:** `bash scripts/ci/ci-demotion-observer.test.sh` locally: 19/19 (was 14/19). CI: `Fast checks` `failure` at sha `6741eebd` (both events) -> `success` at sha `7cae9ae8` (both events).
- **Committed in:** `7cae9ae8`.

---

**Total deviations:** 1 auto-fixed (Rule 1, bug in a file outside the declared fence).
**Impact on plan:** Necessary to obtain any green confirming run; explicitly a strengthening (the guard's recorded expected data now matches reality) rather than a widening -- no assertion relaxed, no exemption added, no `continue-on-error` touched anywhere.

## Issues Encountered

**A push-triggered `pull_request` synchronize event did not fire immediately for the second commit (`7cae9ae8`).** The first commit (`6741eebd`) triggered its PR-event run within ~15s of the push. The second push registered on the PR's `headRefOid` immediately (confirmed via `gh pr view 125 --json headRefOid`) but the corresponding Actions `pull_request` run did not appear for roughly 90 seconds -- a GitHub webhook-delivery delay, not a repo configuration issue. Resolved by polling; no workaround was needed. Recorded here because it is a minor, previously-unobserved wrinkle relevant to future plans in this phase that rely on push-triggered PR-event proof under a tight dispatch cadence.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- **GATE-02 is genuinely closed.** `generated_admin_playwright_smoke` runs on every event including `pull_request`, is confirmed in `ci-gate.needs` (merge-blocking), and has been observed executing (non-skipped) on two independent `pull_request` events. No artifact anywhere still records the retired branch-name condition.
- **GATE-03 is partially advanced, not closed.** The manifest's `gate` column is now cross-checked against `ci.yml` and forbidden from rotted patterns (`head_ref`/branch/SHA) -- a real, load-bearing static guard, running in `fast_checks` on every PR. What remains for a later plan: `scripts/ci/honest-skip-verdict.sh` (+ `.test.sh`), wired into the `ci-gate` job itself per D-01/D-02, to actually distinguish a legitimate skip from a rotted one at merge-verdict time -- today `ci-gate` still treats every `skipped` result as a pass, unconditionally, for every lane in its `needs:`.
- **The pull_request-event execute/skip picture, captured from the two confirming green PR-event runs (`30521272305`, `30523049209`), useful to whichever plan owns GATE-01/GATE-03 next:**

  **Executes on `pull_request` (non-skipped):** `Release ref guard`, `Detect docs-only change`, `Library tests` (+ shard 1, shard 2, dep-off), `Install golden + idempotency contract`, `Generated admin Playwright smoke` (newly, this plan), `Example unit smoke`, `Example Playwright smoke`, `Example HTTP smoke`, `Install smoke`, `Fast checks`, `ci-gate`.

  **Skips on `pull_request` (by design, Tier A -- event-gated, pre-existing Phase 196, explicitly out of this plan's scope per the manifest header, "Phase 231's GATE-01/GATE-02 own these; the observer deliberately does NOT assert on them"):** `Install matrix`, `Passkeys manual fallback smoke`, `Passkeys opt-out smoke`, `Nightly probe (forced-failure self-test)`, `Upgrade smoke`, `Recapture admin-design baselines`, `Recapture admin-checkpoint baselines`, `Notify on red ci-gate (release-lane-rot)` (this last one, `exempt` tier, is additionally outcome-gated -- it only fires when `ci-gate` itself fails, so a green PR run correctly never triggers it).

  **Skips on `pull_request` (by design, Tier B -- demoted by Phase 230, deliberately NOT merge-blocking, GATE-04's remit which stays `Pending`):** `Admin eval render + probe (hard signal on push/schedule/dispatch; not in ci-gate)`.

  For every Tier-A/Tier-B skip above, GATE-03's still-unbuilt runtime verdict script (`scripts/ci/honest-skip-verdict.sh`) is what will eventually assert its legitimacy against the manifest at `ci-gate` time; GATE-01's nightly-revival work (schedule-lane leniency removal, GitHub Pages seeding) is what covers these same lanes on their intended non-PR events.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30*

## Verification Evidence (actually run)

### Task 1 verification (plan's own acceptance criteria)

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 58
# pass 58
# fail 0

$ actionlint -shellcheck= .github/workflows/ci.yml
(exit 0, no output)

$ python3 -c "... (the plan's own YAML-parse + manifest-parse assertion block) ..."
OK {'A': 8, 'B': 2, 'C': 5} 15
```

### p10's two new assertions, proven fail-first against mutated temp fixtures (not committed)

**Gate-column mismatch fixture** (admin_eval_render's `gate` cell replaced with `github.event_name == 'push'`, disagreeing with ci.yml's real `github.event_name != 'pull_request'`):

```
$ GSD_PROHIB_SUBJECT=<tmp>/gate-mismatch.tsv node --test --test-reporter=tap scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs
not ok 5 - gate column matches the if: expression ci.yml actually declares (Phase 231 GATE-02 / GATE-03)
  error: |-
    manifest row `admin_eval_render` records gate "github.event_name == 'push'", but ci.yml's
    actual condition is "github.event_name != 'pull_request'". A gate column that disagrees
    with the real if: is exactly Phase 231 GATE-02's defect class: a condition that reads
    plausibly and verifies nothing.
  expected: "github.event_name == 'push'"
  actual: "github.event_name != 'pull_request'"
Results: 7 passed, 1 failed
```

**Rotted-gate-string fixture** (admin_eval_render's `gate` cell replaced with a branch-keyed condition, `github.event_name != 'pull_request' || github.head_ref == 'ship/some-branch'`):

```
$ GSD_PROHIB_SUBJECT=<tmp>/rotted-gate.tsv node --test --test-reporter=tap scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs
not ok 6 - no manifest gate string references a branch name or a literal commit SHA (Phase 231 GATE-03)
  error: 'manifest row `admin_eval_render` records gate "github.event_name != ''pull_request'' ||
    github.head_ref == ''ship/some-branch''", which matches /github\.head_ref/ — github.head_ref
    is empty on every non-pull_request event and stale the moment the branch merges. This is
    Phase 231 GATE-02''s own defect class (the stale
    `github.head_ref == ''ship/v1.42-ci-gate-remediation''` clause); forbidding the pattern
    structurally is stronger than fixing one instance.'
```

Both fixtures were temp files, never committed (respecting the plan's declared file fence of exactly 4 files for Task 1).

**Against the real, shipped manifest, both new assertions pass** (confirmed as part of the 58/58 suite run above).

### GATE-02 evidence chain: sample size and every observed run

| Sha | Trigger | Run ID | Job `Generated admin Playwright smoke` | Overall run conclusion | Notes |
|---|---|---|---|---|---|
| `70bed477` (gap-closure) | `workflow_dispatch` x8 | `30519167723`, `30519171389`, `30519175220`, `30519179013`, `30519182596`, `30519186296`, `30519190135`, `30519193712` | success (all 8) | success (all 8) | Pre-D-06: PR-event still `skipped` on every round (lane not yet enabled) |
| `6741eebd` (this plan, Task 1) | `workflow_dispatch` | `30521297923` | **success** | failure | Overall run red on the unrelated `ci-demotion-observer.test.sh` bug, fixed below |
| `6741eebd` (this plan, Task 1) | `pull_request` | `30521272305` | **success** | failure | **First-ever genuine `pull_request`-event execution of this lane** |
| `7cae9ae8` (this plan, deviation fix) | `workflow_dispatch` | `30523113463` | success | **success** | Fully green including `ci-gate` |
| `7cae9ae8` (this plan, deviation fix) | `pull_request` | `30523049209` | success | **success** | Fully green including `ci-gate`; second genuine PR-event execution |

**12 consecutive green job-level observations, 0 failures, since the corrected CSS fix (`70bed477`) landed** -- across 3 shas and both `workflow_dispatch` and `pull_request` trigger types. Against a formerly measured ~38-60% failure rate on the pre-fix content, this sample is not a coin-flip: every fix in the four-round gap-closure chain was causally tied to a specific offender named by the prior round's failure, and this plan adds zero new CSS changes -- it only proves the already-corrected fix under the trigger type (`pull_request`) that had never actually run it before.

### `ci-gate.needs` confirmation (merge-blocking, not merely visible)

```
$ grep -n "^  ci-gate:" -A 13 .github/workflows/ci.yml
  ci-gate:
    name: ci-gate
    runs-on: ubuntu-latest
    timeout-minutes: 5
    needs:
      - install_golden_contract
      - library_tests
      - library_tests_dep_off
      - install_smoke
      - upgrade_smoke
      - example_http_smoke
      - example_playwright_smoke
      - generated_admin_playwright_smoke
      - fast_checks
```

`admin_eval_render` is absent from this list -- confirming the asymmetry: GATE-02's lane is merge-blocking on PRs; GATE-04's lane is not.

### Confirming run job tables (both fully green, sha `7cae9ae8`)

**PR-event run `30523049209`:**
```
Release ref guard: success
Fast checks (milestone/installer/contracts/snapshot/ledger guards): success
Detect docs-only change: success
Passkeys manual fallback smoke: skipped
Install matrix (flag combinations): skipped
Passkeys opt-out smoke: skipped
Nightly probe (forced-failure self-test): skipped
Library tests shard 1: success
Install golden + idempotency contract (subprocess harness): success
Generated admin Playwright smoke: success
Library tests shard 2: success
Admin eval render + probe (hard signal on push/schedule/dispatch; not in ci-gate): skipped
Upgrade smoke (published source series -> local candidate): skipped
Recapture admin-checkpoint baselines (in-CI): skipped
Recapture admin-design baselines (in-CI): skipped
Example HTTP smoke (boot + curl critical routes): success
Install smoke (fresh phx.new + sigra.install): success
Library tests (dep-off — Threadline absent): success
Example unit smoke (ExUnit + ConnTest): success
Example Playwright smoke (full lifecycle): success
Library tests: success
ci-gate: success
Notify on red ci-gate (release-lane-rot): skipped
```
Overall conclusion: **success**.

**Dispatch run `30523113463`:** all 26 jobs `success` except `Notify on red ci-gate (release-lane-rot)` correctly `skipped` (outcome-gated, `ci-gate` did not fail). Overall conclusion: **success**.

### Recapture PR cleanup

```
$ gh pr close 164 --repo szTheory/sigra --delete-branch
✓ Closed pull request szTheory/sigra#164
✓ Deleted branch ci/recapture-admin-checkpoints-30521297923
$ gh pr close 165 --repo szTheory/sigra --delete-branch
✓ Closed pull request szTheory/sigra#165
✓ Deleted branch ci/recapture-admin-checkpoints-30523113463
$ gh pr list --repo szTheory/sigra --state open --json headRefName --jq '.[] | select(.headRefName | startswith("ci/recapture-admin-checkpoints"))'
(empty)
```

### Full prohibition suite, re-confirmed after every commit

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 58
# pass 58
# fail 0
```

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml` -- `generated_admin_playwright_smoke` declares no `if`
- FOUND: `.github/ci-skip-manifest.tsv` -- `generated_admin_playwright_smoke` row absent, 15 rows, 8 tier-A
- FOUND: `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` -- two new tests present and passing (58/58 suite)
- FOUND: `MAINTAINING.md` -- three passages reconciled, `:104-110` byte-unchanged
- FOUND: `scripts/ci/ci-demotion-observer.test.sh` -- `EVAL_NAME` corrected, 19/19 locally
- FOUND commit: `6741eebd`
- FOUND commit: `7cae9ae8`
- CONFIRMED: CI run `30521272305` (pull_request, sha `6741eebd`) -- `Generated admin Playwright smoke: success`
- CONFIRMED: CI run `30523049209` (pull_request, sha `7cae9ae8`) -- fully green, `ci-gate: success`
- CONFIRMED: CI run `30523113463` (workflow_dispatch, sha `7cae9ae8`) -- fully green
- CONFIRMED: `generated_admin_playwright_smoke` present in `ci-gate.needs` (`ci.yml:1831`)
- CONFIRMED: no open recapture PRs (`gh pr list --search recapture --state open` scoped check -> empty)
- CONFIRMED: PR #125 (`worktree-discuss-231` -> `main`) remains the tracking PR for this branch's work
- CONFIRMED: `git diff` on `.planning/REQUIREMENTS.md` will show only `GATE-02` flipped to `[x]` (applied in state-update step below), `GATE-03`/`GATE-04` left `[ ]`
