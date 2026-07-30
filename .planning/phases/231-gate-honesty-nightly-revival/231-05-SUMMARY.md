---
phase: 231-gate-honesty-nightly-revival
plan: 05
subsystem: infra
tags: [github-actions, ci, playwright, admin-eval, harness, css-tokens, design-tokens, floor-rebase]

requires:
  - phase: 231-04
    provides: "webkit install for admin_eval_render + probes.ts SVGAnimatedString crash fix (D-11 steps 1-2), the two preconditions this plan needed cleared before phase (a) could run to completion"
provides:
  - "The first-ever complete CI execution of the admin-eval harness: phase (a) 192/192, (a2) ran, and all six of (b1)-(b6) executed and passed, ending in the harness's own PASS — all phases green banner (run 30512523387, job 90775422130)"
  - "Three probe-vs-ratified-design-decision reconciliations, each proven against a documented, pre-existing design decision the probe had never been exercised against before bundles existed: D-08 chip-remove control-scale (probes.ts), pill/code padding sub-scale tokens (probes.ts, selector-scoped), and gallery-frame card nesting (design_gallery_live.ex, suppression attribute on harness-only markup)"
  - "A fix to a pre-existing, undiscovered gap between fix-queue-build.mjs and fix-queue-lint.sh: proxy surfaces (Phase 218-01's pinned-floor L3 surfaces) are now correctly exempted from the cross-surface open_findings agreement check"
  - "guides/reference/admin-render-sha.json and fix-queue.json rebased at CI-native truth (33,642 -> 38,016 total open_findings), sourced from run 30509363963's 171 verified bundles, with the committed-HEAD trap guarded at every step"
  - "A new, sanctioned, fail-closed, verified, one-time floor-rebase declaration mechanism added to quality-findings-monotonic.sh (guides/reference/floor-rebase-declarations.json), so future harness-basis-changes have a reviewable path that does not require reverting to a known-false number or leaving a merge gate permanently red"
  - "A confirmed, characterized, cross-run genuine intermittent in Generated admin Playwright smoke (GATE-02's own lane) — NOT caused by this plan, NOT fixed here, filed as a follow-up finding"
affects: [231-06, 235]

tech-stack:
  added: []
  patterns:
    - "Selector-scoped probe sub-scale allowance: extra accepted values are read once globally but applied only to elements whose own CSS rule actually names the token (probes.ts probeOffTokenSpacing), never widened to the shared scale array — the pattern to copy for any future probe/ratified-decision reconciliation."
    - "Verified, one-time floor-rebase declaration: an array of {run_id, job_id, commit_sha, reason, prior_totals, new_totals} entries, cross-checked wholesale against the actual base/head ledger content before authorizing anything; absent file = fail-closed default; declarations go inert on their own once superseded."

key-files:
  created:
    - guides/reference/floor-rebase-declarations.json
  modified:
    - test/example/priv/playwright/lib/eval/probes.ts
    - test/example/priv/playwright/tests/admin-eval.spec.ts
    - test/example/lib/example_web/live/admin/design_gallery_live.ex
    - scripts/ci/fix-queue-lint.sh
    - scripts/ci/fix-queue-lint.test.sh
    - scripts/ci/quality-findings-monotonic.sh
    - scripts/ci/quality-findings-monotonic.test.sh
    - guides/reference/admin-render-sha.json
    - guides/reference/fix-queue.json

key-decisions:
  - "231-05's declared files_modified fence (guides/reference/admin-render-sha.json, fix-queue.json) proved too narrow for the plan's actual purpose once the harness started reaching real, never-before-exercised phases. The operator explicitly authorized six deviations beyond the fence, in order, each reviewed and accepted individually: (1) probes.ts D-08 chip-remove control-scale fix, (2) probes.ts + admin-eval.spec.ts pill/code sub-scale rescoping (first attempt too broad — global scale widening — corrected to selector-scoped on review), (3) design_gallery_live.ex card-nesting suppression, (4) fix-queue-lint.sh proxy-surface exemption, (5) quality-findings-monotonic.sh floor-rebase declaration mechanism, (6) the floor-rebase declaration data itself. See Deviations for full reasoning on each."
  - "The floor-rebase mechanism (#5/#6 above) is the single item most deserving human review at PR time, flagged explicitly by the operator: it changes the repository's CI honesty model, not just this phase's ledger. It is fail-closed by default (absent declaration = today's exact behavior), verifies every declared value against the actual ledger before authorizing anything, and authorizes exactly one transition (proven by fail-first Tests E-H)."
  - "GATE-04 is NOT marked complete. This plan proves b1-b6 execute and pass, which is D-11 step 3's deliverable — but SC-4's full receipt requires the job-level continue-on-error at ci.yml:2450 to be removed first (D-11 step 4), which is 231-06's job, not this plan's. ci.yml was not touched anywhere in this plan."
  - "A confirmed, genuine, cross-run intermittent was found in Generated admin Playwright smoke (GATE-02's own lane) during this plan's repeated dispatches — a different specific test failed on two different red runs, at commits that touched nothing that lane loads, each sticky-within-its-own-run. Characterized with full evidence, not fixed (out of 231-05's scope and file fence); flagged as a follow-up."

requirements-completed: []

coverage:
  - id: D1
    description: "The admin-eval harness's b1-b6 phases are observed executing to completion in CI for the first time, ending in the harness's own PASS — all phases green banner, with the job's own conclusion: success (not merely continue-on-error masking a red)"
    requirement: "GATE-04"
    verification:
      - kind: integration
        ref: "CI run 30512523387, job 90775422130 — quoted banners and PASS line in Verification Evidence below"
        status: pass
    human_judgment: false
  - id: D2
    description: "Three probe-vs-ratified-design-decision reconciliations (D-08 chip-remove, pill/code sub-scale tokens, gallery-frame card nesting), each proven against a specific, cited, pre-existing documented decision, none loosening the probe beyond the exact documented case"
    requirement: "GATE-04"
    verification:
      - kind: integration
        ref: "Phase (a) went from 8 failed/184 passed (run 30504235540) to 192/192 passed (run 30509363963 onward) across the three fixes, confirmed in CI logs each round"
        status: pass
    human_judgment: true
    rationale: "Each reconciliation involved a judgment call about whether a probe finding reflected a real defect or an unexercised, ratified design decision — the operator reviewed and explicitly accepted each one (see key-decisions and Deviations). Route selection is not mechanically re-verifiable from a single command."
  - id: D3
    description: "fix-queue-lint.sh proxy-surface exemption: a pre-existing gap between fix-queue-build.mjs's documented proxy-pin design (Phase 218-01) and fix-queue-lint.sh's cross-surface agreement check, fixed with a bounded, fail-first-proven exemption"
    requirement: "GATE-04"
    verification:
      - kind: unit
        ref: "bash scripts/ci/fix-queue-lint.test.sh (7/7, including new Tests 6-7 proving the exemption is bounded, not global)"
        status: pass
    human_judgment: false
  - id: D4
    description: "quality-findings-monotonic.sh floor-rebase declaration mechanism: fail-closed by default, verified not trusted, authorizes exactly one transition"
    requirement: "DX-05"
    verification:
      - kind: unit
        ref: "bash scripts/ci/quality-findings-monotonic.test.sh (11/11, including new Tests E-H — the operator independently re-ran this locally and confirmed the same result)"
        status: pass
      - kind: integration
        ref: "CI run 30512523387, job 90775412114 (Fast checks) — success, confirming the declaration validates in real CI, not just locally"
        status: pass
    human_judgment: true
    rationale: "This mechanism changes the repository's CI honesty model and was explicitly flagged by the operator as the item most deserving human review at PR time, even though its own tests are fully automated and green."

duration: ~4h (across 6 CI round-trips)
completed: 2026-07-30
status: complete
---

# Phase 231 Plan 05: D-11 step 3 — the admin-eval harness runs to completion in CI for the first time

**b1 through b6 executed and passed in CI for the first time in this repository's history (run `30512523387`, job `90775422130`, `PASS — all phases green`), reached via three probe-vs-ratified-design-decision reconciliations, a pre-existing guard gap fixed, a CI-native ledger rebase, and — because that rebase had no honest way to clear the merge-blocking monotonic guard — a new, sanctioned, verified, one-time floor-rebase declaration mechanism, all explicitly authorized by the operator beyond this plan's original file fence.**

## Performance

- **Duration:** ~4h across 6 CI round-trips (dispatch → wait ~20-25min → read → fix → repeat)
- **Started:** 2026-07-30T00:54:24Z
- **Completed:** 2026-07-30 (~04:20 UTC)
- **Tasks:** Plan's original Task 1/2/3 structure was superseded by operator-directed iterative convergence (see Deviations) — 6 CI dispatches, 9 commits
- **Files modified:** 9 (1 created, 8 modified) — all outside the plan's original 2-file fence except the final ledger commit

## Accomplishments

- **D-11 step 3's actual deliverable is now a real, quoted-from-log fact, not an assumption:** b1 (stale-render guard), b2 (evidence anchor integrity), b3 (fix-queue derived-field lint), b4 (quality findings monotonic), b5 (award ledger verify-then-climb), and b6 (settled findings lint) all executed and passed in CI, ending in the harness's own `PASS — all phases green` banner and a job `conclusion: success`.
- **Diagnosed and reconciled three previously-unexercised probe-vs-ratified-decision mismatches**, each confirmed against a specific cited document, not guessed: `.sg-applied-chip__remove`'s 22px control height vs `admin-quality-ledger.md:65`'s D-08 near-threshold review; `.sg-status-pill`/`.sg-badge`/`.sg-scope-pill`/`.sg-code`'s dedicated padding tokens vs `admin-token-reference.md:229-234`'s "admin-layer decision" sub-scale documentation; and the design gallery's own uniform card-frame convention producing an artifactual (never-in-production) card-in-card nesting on two boards.
- **Found and fixed a pre-existing, undiscovered gap** between `fix-queue-build.mjs` (Phase 218-01's documented proxy-pin design) and `fix-queue-lint.sh` (never taught the same exemption) — the first CI-native render ever to exercise the cross-surface consistency check surfaced it.
- **Rebased the admin-eval ledgers at CI-native truth** (33,642 → 38,016 total `open_findings`), sourced from a verified, complete render (171/171 bundles, phase (a) 192/192, `app_git_sha` matching HEAD), following the Phase 219 precedent.
- **Built the sanctioned mechanism the rebase actually needed**: `quality-findings-monotonic.sh` had no honest way to re-establish its floor when the measurement basis itself changes. Added a fail-closed-by-default, verified-not-trusted, one-time-transition declaration mechanism, proven fail-first with 4 new self-test cases, then wrote and verified the declaration for this specific rebase.
- **Found, characterized, and did NOT fix** a genuine cross-run intermittent in `Generated admin Playwright smoke` — GATE-02's own proof lane — with full log evidence from three runs.
- Closed 6 accidental recapture PRs (#132-#137), an unavoidable side effect of the `recapture_branch` dispatch mechanics needed to clear `release_ref_guard` on every bare `workflow_dispatch`.

## Task Commits

The plan's original Task 1/2/3 structure was superseded mid-execution (see Deviations). Actual commits, in order:

1. `5c54cf33` (docs) — recorded the initial blocked observation (phase (a) aborting on the D-08 chip-remove finding) before operator authorization to proceed further.
2. `9aafb402` (fix) — D-08 chip-remove control-scale reconciliation in `probes.ts` (operator-authored edit, reviewed and committed by this executor).
3. `b81d5cd2` (fix) — pill/code sub-scale + card-nesting reconciliations (first attempt at the pill/code fix; corrected next commit).
4. `18c2720a` (fix) — corrected the pill/code fix to be selector-scoped, not global, per operator review; added fail-first regression proof.
5. `1e44ecd8` (fix) — `fix-queue-lint.sh` proxy-surface exemption, with 2 new fail-first self-test cases.
6. `be970b50` (docs) — CI-native ledger rebase (`admin-render-sha.json` + `fix-queue.json`), sourced from run `30509363963`.
7. `8c49722b` (feat) — the floor-rebase declaration mechanism added to `quality-findings-monotonic.sh`, with 4 new fail-first self-test cases.
8. `af1b192c` (docs) — the floor-rebase declaration data itself, for this specific rebase.

**Plan-metadata commit:** created after this SUMMARY, per `commit_docs: true`.

## Files Created/Modified

- `test/example/priv/playwright/lib/eval/probes.ts` — probe #1 (`off-token-spacing`) selector-scoped pill/code sub-scale allowance; probe #5 (`off-scale-radius-shadow-control`) `.sg-applied-chip__remove` removed from `isControl`.
- `test/example/priv/playwright/tests/admin-eval.spec.ts` — fail-first regression proof for the selector-scoped pill/code allowance (non-pill element still flagged; real `.sg-status-pill` not flagged).
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — `data-sg-card-nesting-audit-only` on `#board-task_card` and `#board-skeleton`'s gallery-frame wrappers, with inline rationale.
- `scripts/ci/fix-queue-lint.sh` — proxy surfaces exempted from the cross-surface `open_findings` agreement check only (clauses a/b still apply).
- `scripts/ci/fix-queue-lint.test.sh` — 2 new fail-first cases (Test 6: two real surfaces disagreeing still fails; Test 7: a proxy disagreeing with a real surface passes).
- `scripts/ci/quality-findings-monotonic.sh` — the floor-rebase declaration mechanism (fail-closed default, wholesale verification, one-time transition).
- `scripts/ci/quality-findings-monotonic.test.sh` — 4 new fail-first cases (E: absent declaration still fails; F: mismatched declaration rejected; G: matching declaration authorizes; H: drift beyond declared floor still fails).
- `guides/reference/admin-render-sha.json` / `guides/reference/fix-queue.json` — rebased at CI-native truth (178 real cells, 38,016 total `open_findings`, 134 fix-queue entries).
- `guides/reference/floor-rebase-declarations.json` (new) — the declaration authorizing this specific rebase.

## Decisions Made

See `key-decisions` in frontmatter for the compressed version. In full: this plan began as a pure observation task (Task 1: dispatch, read, report) and correctly stopped at its first genuine fork — phase (a) itself failing on a real, previously-undiagnosed HARD-GATE finding outside the plan's file fence. The operator, given full context, made the call to resolve it autonomously ("0 human" delegation) rather than leave the phase blocked, and walked the remainder of the plan through six CI round-trips of dispatch → observe → diagnose → fix → repeat, each fix reviewed before the next dispatch. Every fix was tested against the standard "does this let a genuine future defect pass unnoticed?" — the pill/code fix failed that test on its first attempt (global scale widening) and was corrected to selector-scoped before landing.

## Deviations from Plan

### Auto-fixed / Operator-authorized Issues

**1. [Rule 4-equivalent — architectural, operator-authorized] D-08 chip-remove control-scale reconciliation**
- **Found during:** first dispatch (run `30504235540`, job `90750408342`) — phase (a) aborted at 8 failed/184 passed.
- **Issue:** probe #5 (`off-scale-radius-shadow-control`) gated `.sg-applied-chip__remove`'s 22px height against the `--sg-control-*` scale (28/36/44/48px), contradicting `admin-quality-ledger.md:65`'s explicit, separately-reviewed target-size decision for this exact control ("~22×22 CSS px (near-threshold; ... D-08 near-threshold precedent for dense admin inline chip remove)"). Never exercised before because bundles never existed in CI.
- **Fix:** removed `sg-applied-chip__remove` from probe #5's `isControl` classlist. Operator authored the edit; this executor reviewed the diff (single hunk, 19 insertions/2 deletions), verified locally (`npx playwright test --list`, `node --test prohibitions`), and committed it.
- **Files modified:** `test/example/priv/playwright/lib/eval/probes.ts`.
- **Verification:** phase (a) failures dropped from 8 to 3 on the next dispatch.
- **Committed in:** `9aafb402`.

**2. [Rule 1 — bug in first attempt, corrected on review] pill/code sub-scale reconciliation**
- **Found during:** second dispatch (run `30506164137`, job `90756310985`) — 3 remaining failures, two of them `off-token-spacing` on `.sg-status-pill` (padding [3,10,3,10]px) and `.sg-code` (padding [1,1]px).
- **Issue:** these values are driven by dedicated, documented "admin-layer decision" tokens (`--sg-pill-pad-y/-x`, `--sg-code-pad-y`; `admin-token-reference.md:229-234`), not the general `--sg-space-*` scale probe #1 checks.
- **First fix (rejected on review):** pushed the three token values onto the GLOBAL scale array — this would have let any element anywhere with 3px/10px/1px padding pass, silently waving through a real defect.
- **Corrected fix:** rescoped so the extra values are accepted only for elements whose own CSS rule actually names the token (`.sg-scope-pill`/`.sg-status-pill`/`.sg-badge` for the pill tokens, `.sg-code` for the code token). Added fail-first regression proof: a non-pill element with the same 3px/10px padding is still flagged; a real `.sg-status-pill` is not.
- **Files modified:** `test/example/priv/playwright/lib/eval/probes.ts`, `test/example/priv/playwright/tests/admin-eval.spec.ts`.
- **Verification:** `npx playwright test --list` (391 tests, 20 files, no parse errors), targeted probe tests pass locally against a booted example app, `node --test prohibitions` (56/56).
- **Committed in:** `b81d5cd2` (first attempt), corrected in `18c2720a`.

**3. [Rule 4-equivalent — harness-artifact suppression, operator-authorized] gallery-frame card-nesting reconciliation**
- **Found during:** same second dispatch — probe #8 (`card-in-card`) flagged `board-task_card` and `board-skeleton`.
- **Issue:** every gallery board wraps itself in a `.sg-card` presentational frame (a demo-harness convention shared by every board). `task_card/1` itself renders `.sg-card` (`components.ex:114`), and `board-skeleton`'s demo deliberately shows a real `.sg-card` shell containing skeleton bones — so each board's own frame nests a real card inside a real card. Confirmed this never happens in production: `index_live.ex` and `organization_live.ex` place `<.task_card>` inside `.sg-grid`, never `.sg-card`.
- **Fix:** `data-sg-card-nesting-audit-only` on the two gallery board wrapper `<div>`s — probe #8's own purpose-built, previously-unused, board-level escape hatch. Not a weakening: probe #8 still gates every other board.
- **Files modified:** `test/example/lib/example_web/live/admin/design_gallery_live.ex`.
- **Verification:** `mix compile --warnings-as-errors` (test/example, MIX_ENV=dev) clean; confirmed via CI logs (phase (a) reached 192/192 after this + the pill/code fix).
- **Committed in:** `b81d5cd2`.

**4. [Rule 1 — pre-existing guard gap, not a probe/design case] fix-queue-lint.sh proxy exemption**
- **Found during:** fourth dispatch (run `30509363963`, job `90765906275`) — phase (a) 192/192 for the first time, but b3 (`fix-queue-lint`) failed: `board-mg-1`'s freshly-computed `open_findings` (293/270) disagreed with all 8 proxy surfaces' pinned floors (197/181).
- **Issue:** `fix-queue-build.mjs` (Phase 218-01, Blocker-1) already documents proxy surfaces as structurally exempt from recomputation — their `open_findings` is a deliberately pinned floor, never meant to track a live measurement. `fix-queue-lint.sh`'s cross-surface agreement check knew how to parse the `proxy` marker (to avoid misreading it as a malformed cell) but never extended the SAME exemption to the agreement comparison. Bundles never existed before this run to exercise the gap.
- **Fix:** proxy surfaces excluded from the cross-surface agreement check only; clauses (a) non-negative and (b) `<= totalUncollapsed` still apply. Added 2 fail-first self-test cases proving the exemption is bounded (two real surfaces disagreeing still fails; a proxy disagreeing with a real surface passes).
- **Files modified:** `scripts/ci/fix-queue-lint.sh`, `scripts/ci/fix-queue-lint.test.sh`.
- **Verification:** `bash scripts/ci/fix-queue-lint.test.sh` (7/7); confirmed b3 passing in the next CI dispatch.
- **Committed in:** `1e44ecd8`.

**5. [Operator-authorized, outside the plan's file fence — flagged for human review] quality-findings-monotonic.sh floor-rebase declaration mechanism**
- **Found during:** confirming dispatch after the ledger rebase (run `30511228553`) — `fast_checks`' own `Quality findings monotonic guard` failed, as predicted: it compares against `HEAD~1` on a non-`pull_request` event (or the real merge-base on a PR), and the rebase commit is, by definition, a discontinuity versus its own immediate parent.
- **Issue:** `quality-findings-monotonic.sh` had no sanctioned way to re-establish its floor when the measurement basis itself changes (the harness that produces the ledger was broken and is now fixed, so the old floor undercounted rather than representing a real improvement). Reverting to the stale number would record a known falsehood; leaving the guard permanently red blocks all six remaining plans in the milestone.
- **Fix:** added an auditable, fail-closed-by-default, verified-not-trusted, one-time-transition declaration mechanism (see Key Decisions and Verification Evidence for full design). **This is explicitly outside 231-05's declared file fence** and is flagged as the single item most deserving human review at PR time — it changes the repository's CI honesty model.
- **Files modified:** `scripts/ci/quality-findings-monotonic.sh`, `scripts/ci/quality-findings-monotonic.test.sh`.
- **Verification:** 11/11 self-test cases (7 pre-existing unchanged + 4 new: E absent-declaration-still-fails, F mismatched-declaration-rejected, G matching-declaration-authorizes, H drift-beyond-declared-floor-still-fails). The operator independently re-ran the self-test locally and confirmed the same result. Confirmed live against the actual repo (`--base HEAD~1` and `--base <real PR merge-base with main>`, both pass with the declaration correctly authorizing exactly the 114 changed cells). Confirmed in real CI: `fast_checks` job `90775412114` — success.
- **Committed in:** `8c49722b` (mechanism), `af1b192c` (the declaration data for this rebase).

**6. [Bug in own process, self-caught] contaminated "before" snapshot for the declaration data**
- **Found during:** building the declaration data — the guard's own verification rejected my first declaration ("does not match the actual base/head ledger content").
- **Issue:** my `/tmp` backup of the "before" ledger state was taken AFTER an earlier local full-harness run (started for independent verification, run against a macOS-native boot) had already partially rewritten `admin-render-sha.json` mid-flight, before I discarded that dirty state with `git checkout --`. The backup captured the contaminated intermediate values, not the true git-committed baseline.
- **Fix:** rebuilt the declaration's `prior_totals`/`new_totals` from `git show <commit>:...` directly (the actual committed content) rather than a filesystem snapshot. This is exactly the "verified, not trusted" property working as designed — the guard caught my own mistake before it could land.
- **Files modified:** `guides/reference/floor-rebase-declarations.json` (rebuilt before first commit; no bad data was ever committed).
- **Verification:** re-ran `bash scripts/ci/quality-findings-monotonic.sh --base HEAD~1` after the fix — declaration validated, 114 cells authorized.
- **Committed in:** `af1b192c` (only the corrected version was ever committed).

---

**Total deviations:** 6 (5 code/mechanism changes beyond the declared file fence, all operator-reviewed and authorized; 1 self-caught process error with no bad data ever committed).
**Impact on plan:** Substantial expansion beyond the original 2-file fence, entirely operator-directed and reviewed at each step. No deviation was made unilaterally without either (a) being a direct instruction from the operator (chip-remove edit was operator-authored), or (b) passing the "does this let a genuine future defect pass unnoticed?" test the operator set, with one exception (the pill/code fix) that failed that test on first attempt and was corrected before landing.

## Issues Encountered

**`release_ref_guard` blocks a bare `workflow_dispatch`** — every dispatch in this plan used `-f recapture_branch=worktree-discuss-231` to clear it, which also fires `admin_design_recapture`/`admin_checkpoint_recapture` as an unavoidable side effect. 6 recapture PRs (#132-#137) were opened against `worktree-discuss-231` (correctly scoped, never against `main`) and closed by this executor after each dispatch. None were merged; all branches deleted.

**A genuine, confirmed cross-run intermittent in `Generated admin Playwright smoke`** (GATE-02's own proof lane) — found, evidenced, characterized, and explicitly NOT fixed (out of scope and file fence for 231-05). Full evidence:

| Run | Commit | Result | Failing test | Detail |
|---|---|---|---|---|
| `30509363963` (job `90765906278`) | `18c2720a` | FAILED (both attempt + retry) | `admin-generated.spec.ts:397` — audit presets | `toHaveURL` timeout: after typing an Actor filter value and clicking "Apply filters", the URL never advanced past the prior preset state (`...&outcome=failure` with no `actor=` param), across 19 polling attempts over 15s |
| `30511228553` (job `90771602255`) | `be970b50` | FAILED (both attempt + retry) | `admin-generated.spec.ts:79` — **the 320px reflow assertion GATE-02/D-09 instrumented** | `320px reflow: {"innerWidth":320,"scrollWidth":343,"clientWidth":320,"offenders":[...8 elements including .fieldset, LABEL, INPUT.w-full, BUTTON.sigra-auth-action...]}` — genuine 23px horizontal overflow at 320px/32px-font |
| `30512523387` (job `90775422138`) | `af1b192c` | PASSED (9/9, confirmed from log: "8 passed" + "1 passed") | — | — |

Two different specific tests failed on the two red runs, each sticky-within-its-own-run (attempt and retry identical both times) — a classic intermittent-at-the-lane-level signature, not a fixed deterministic bug. **Neither red commit (`18c2720a`, `be970b50`) touched `admin-generated.spec.ts`, `audit_index_live.ex`, or any auth/login CSS** — the only files those two commits changed were `probes.ts`/`admin-eval.spec.ts` (eval-harness-only code that lane does not load) and the two ledger JSON files. This rules out anything in 231-05 as the cause.

**This bears directly on GATE-02's credibility**, per the operator's own framing: the 320px reflow assertion is the specific instrumented check from 231-02/D-09 that was supposed to have closed the previously-diagnosed ~38% flake rate (231-CONTEXT D-08, pre-fix baseline). Seeing it fail again, with the identical "sticky-within-run" signature and a genuine measured 23px overflow, means either 231-02's `min-width: 0` fix did not fully close the flake, or a second, different intermittent cause (the pre-existing, unconfirmed webfont-metrics-race hypothesis in `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md`) produces the same symptom at some residual rate. **This is not resolved and should be filed as a dedicated follow-up diagnosis** — it was not chased further here because it is outside 231-05's scope (GATE-02, not GATE-04) and file fence, and a proper diagnosis needs trace/video review across several more runs, which this plan's dispatch budget did not allow for.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **GATE-04 is NOT complete.** This plan proves b1-b6 execute and pass (D-11 step 3's deliverable, now a real observed fact — see Verification Evidence). SC-4's full receipt requires `ci.yml:2450`'s job-level `continue-on-error` to be removed (D-11 step 4), which is **231-06's job**. `ci.yml` was not touched anywhere in this plan; confirmed via `git diff ci.yml` being empty across all 9 commits.
- **231-06 may now proceed** — the harness has a genuine, reproducible green run to remove the mask onto (run `30512523387`), which is exactly the precondition D-11's strict ordering required.
- **Follow-up needed, not blocking:** the `Generated admin Playwright smoke` cross-run intermittent (see Issues Encountered) should be filed as its own diagnostic item — it reopens a residual risk in GATE-02, which 231-02 previously marked closed.
- **The floor-rebase declaration mechanism is new, generic infrastructure** — any future phase that needs to re-establish a monotonic floor (not just this one) can reuse `guides/reference/floor-rebase-declarations.json` + the same verification pattern in `quality-findings-monotonic.sh`, rather than inventing a new escape hatch.
- Phase 235 (Terminal Ratification — GATE-05) will read `guides/reference/fix-queue.json` and `admin-award-ledger.json` for its before/after coverage inventory; both now reflect CI-native truth rather than the stale pre-231-04 baseline.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30*

## Verification Evidence (actually run)

### Run/job index (all 6 dispatches, in order)

| # | Run ID | Commit | `admin_eval_render` | `Generated admin Playwright smoke` | `fast_checks` | Notes |
|---|---|---|---|---|---|---|
| 1 | `30504166627` | `769177ba` | **skipped** | — | — | Bare `workflow_dispatch` (no `recapture_branch`) failed `release_ref_guard`. Cancelled. |
| 2 | `30504235540` | `769177ba` | FAILURE (job `90750408342`) | success | success | First real observation: phase (a) 8 failed/184 passed (D-08 chip-remove). |
| 3 | `30506164137` | `9aafb402` | FAILURE (job `90756310985`) | success | success | After D-08 fix: phase (a) 3 failed/189 passed (pill/code + card-nesting). |
| 4 | `30507841875` | `b81d5cd2` | FAILURE (job `90761376576`) | FAILURE (audit presets) | success | Probe #1 fix too broad, flagged on review. |
| 5 | `30509363963` | `18c2720a` | FAILURE (job `90765906275`) | FAILURE (audit presets, job `90765906278`) | success | Probe fix corrected: phase (a) **192/192**. b1/b2 PASS (first ever). b3 FAILED (proxy gap). |
| 6 | `30511228553` | `be970b50` | **SUCCESS** (job `90771602326`) | FAILURE (320px reflow, job `90771602255`) | FAILURE (Quality findings monotonic, expected — no declaration yet) | Ledger rebased + proxy fix landed: **all 7 harness banners, PASS — all phases green.** |
| 7 | `30512523387` | `af1b192c` | **SUCCESS** (job `90775422130`) | **SUCCESS** (9/9, job `90775422138`) | **SUCCESS** (job `90775412114`) | **Fully green.** Declaration mechanism validates in real CI. |

### D-11 step 3's receipt: quoted banners from run `30512523387`, job `90775422130`

```
2026-07-30T03:58:34.4831441Z admin-eval-harness: (a) render matrix + probes + bundles (3 projects)
2026-07-30T03:58:35.8973682Z Running 192 tests using 1 worker
2026-07-30T04:20:39.7189786Z   192 passed (22.1m)
2026-07-30T04:20:40.0773492Z admin-eval-harness: (a2) fix-queue derivation + open_findings update (D-12)
2026-07-30T04:20:40.1553533Z admin-eval-harness: (b1) stale-render guard
2026-07-30T04:20:40.1811417Z stale-render-guard: checking 171 bundle(s) against HEAD af1b192c5033834450533f0c2adfeeecd743ad74
2026-07-30T04:20:41.3303254Z stale-render-guard: PASS (171 bundle(s) verified at HEAD af1b192c5033834450533f0c2adfeeecd743ad74)
2026-07-30T04:20:41.3305379Z admin-eval-harness: (b2) evidence anchor integrity check
2026-07-30T04:20:41.8540590Z evidence-anchor-check: PASS (171 bundle(s), 4596 finding(s) checked)
2026-07-30T04:20:41.8660657Z admin-eval-harness: (b3) fix-queue derived-field lint (auto_eligible, priority, open_findings)
2026-07-30T04:20:41.9336765Z fix-queue-lint: PASS (134 queue entries validated)
2026-07-30T04:20:41.9339202Z admin-eval-harness: (b4) quality findings consistency guard (working-tree vs committed HEAD)
2026-07-30T04:20:41.9698622Z quality-findings-monotonic: INFO: declaration 30509363963 does not match the actual base/head ledger content — ignored, not authorizing anything
2026-07-30T04:20:41.9719957Z quality-findings-monotonic: PASS (checked vs HEAD)
2026-07-30T04:20:41.9736717Z admin-eval-harness: (b5) award ledger verify-then-climb guard (working-tree vs committed HEAD)
2026-07-30T04:20:42.0140672Z award-guard: PASS (32 cells checked vs HEAD)
2026-07-30T04:20:42.0164607Z admin-eval-harness: (b6) settled findings lint
2026-07-30T04:20:42.0219342Z settled-findings-lint: PASS (no data rows — trivially valid)
2026-07-30T04:20:42.0220911Z admin-eval-harness: PASS — all phases green
```

**All 7 banners present, in order, none missing.** The `quality-findings-monotonic: INFO: declaration ... does not match ...` line is expected and correct here: the harness's own b4 invocation uses `--base HEAD` (literal), and since `af1b192c`'s working tree exactly matches its own committed ledger (nothing changed the source since the rebase landed at `be970b50`), there is no increase to authorize in the first place — the declaration is inert for this specific comparison and only matters for `HEAD~1`/merge-base comparisons where the actual rebase transition is visible (see below).

**Job identity:** `conclusion: success`, `startedAt: 2026-07-30T03:58:34Z`, `completedAt: 2026-07-30T04:20:50Z` (wall-clock **≈22m16s**, comfortably inside the 40-minute ceiling).

### Committed-HEAD trap, verified for the final (round 6) render

`stale-render-guard`'s own PASS line above names the exact check: `171 bundle(s) verified at HEAD af1b192c5033834450533f0c2adfeeecd743ad74` — every bundle's `app_git_sha` equals the commit this run was dispatched against. **Provenance note, stated plainly:** the numbers actually recorded in `guides/reference/admin-render-sha.json`/`fix-queue.json` (committed in `be970b50`) were built from run `30509363963`'s bundles (captured at `18c2720a`), NOT from round 6's render. Round 6 (`af1b192c`) is a fresh, independent re-render that reproduces the SAME values — proven by b3/b4/b5/b6 all passing with **zero** violations against the already-committed ledger (a genuine difference would have shown up as a b3/b4 fail even without the declaration, since the harness's own `--base HEAD` check would catch an increase). The floor-rebase declaration (`guides/reference/floor-rebase-declarations.json`) correctly cites `run_id: "30509363963"` / `job_id: "90765906275"` — the actual source of the recorded numbers, not round 6.

### Floor-rebase declaration validated against the real PR merge-base (not just `HEAD~1`)

```
$ git fetch origin main && git merge-base origin/main HEAD
64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba

$ bash scripts/ci/quality-findings-monotonic.sh --base 64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba
quality-findings-monotonic: INFO: declaration 30509363963 verified and authorizes 114 cell(s)
quality-findings-monotonic: PASS (checked vs 64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba)

$ node scripts/ci/award-guard.mjs --base 64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba
award-guard: PASS (32 cells checked vs 64c39f3b5cdce64a6ee60513f5fcdfb8af5c6fba)
```

This is the scenario that actually matters — PR #125's own `fast_checks` run against `main` — not the transient `HEAD~1` case on a dispatch. Confirmed live in CI too: run `30512523387`, `fast_checks` job `90775412114` → success.

### Floor-rebase declaration mechanism self-tests

```
$ bash scripts/ci/quality-findings-monotonic.test.sh
Test A: open_findings 3→4 increase is caught by the guard (must exit non-zero)  PASS (×2)
Test B: no-change run exits 0                                                   PASS
Test C: 4→3 decrease exits 0                                                     PASS (×2)
Test D: increase from 0 IS caught                                                PASS (×2)
Test E: no declarations file present + increase -> exit non-zero                 PASS
Test F: declaration whose totals do not match the real ledger -> exit non-zero   PASS
Test G: declaration whose totals exactly match the real transition -> exit 0     PASS
Test H: increase beyond the declared new floor -> exit non-zero                  PASS
----------------------------------------
Results: 11 passed, 0 failed
----------------------------------------
quality-findings-monotonic.test: PASS
```

Independently re-run and confirmed by the operator locally with the same result.

### fix-queue-lint.sh proxy exemption self-tests

```
$ bash scripts/ci/fix-queue-lint.test.sh
Test 1-5 (pre-existing): PASS
Test 6: two non-proxy surfaces disagreeing on the same cell exits non-zero, naming the mismatch   PASS
Test 7: proxy surface disagreeing with a real surface is exempt, exits 0                          PASS
7 checks: 7 passed, 0 failed
fix-queue-lint.test.sh: PASS
```

### Full prohibition suite, re-confirmed after every code change

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 56
# pass 56
# fail 0
```

### Ledger totals (final, committed)

```
$ node -e "... sum admin-render-sha.json non-proxy cells ..."
surfaces: 65   cells: 178   total open_findings: 38016   (was 33642 pre-231-05)

$ node -e "require('./guides/reference/fix-queue.json').length"
134
```

### Recapture PR cleanup (all authorized, all created by `github-actions`, all closed)

| PR | Source run | Status |
|---|---|---|
| #132 | `30504235540` | Closed, branch deleted |
| #133 | `30506164137` | Closed, branch deleted |
| #134 | `30507841875` | Closed, branch deleted |
| #135 | `30509363963` | Closed, branch deleted |
| #136 | `30511228553` | Closed, branch deleted (initially missed one round, caught and closed on the next pass) |
| #137 | `30512523387` | Closed, branch deleted |

`gh pr list --repo szTheory/sigra --search "recapture" --state open` returns empty. None were merged; nothing else was closed or deleted.

**PR for `worktree-discuss-231` → `main`: #125** ("Phase 231 context: gate honesty + nightly revival (assumptions mode)"), confirmed `state: OPEN`.

## Self-Check: PASSED

- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-05-SUMMARY.md`
- CONFIRMED: `guides/reference/admin-render-sha.json` parses (65 surfaces, 178 real cells, 38,016 total open_findings)
- CONFIRMED: `guides/reference/fix-queue.json` parses (134 entries)
- CONFIRMED: `guides/reference/floor-rebase-declarations.json` parses (1 declaration, 114 declared items, validated against both `HEAD~1` and the real `main` merge-base)
- CONFIRMED: all 9 commits exist (`git log --oneline`): `5c54cf33`, `9aafb402`, `b81d5cd2`, `18c2720a`, `1e44ecd8`, `be970b50`, `8c49722b`, `af1b192c`, plus this SUMMARY's own metadata commit
- CONFIRMED: CI run `30512523387` exists and is queryable; job `90775422130` (`Admin eval render + probe`) `conclusion: success`; job `90775412114` (`Fast checks`) `conclusion: success`; job `90775422138` (`Generated admin Playwright smoke`) `conclusion: success`
- CONFIRMED: PR #125 exists, `state: OPEN`, `headRefName: worktree-discuss-231`, `baseRefName: main`
- CONFIRMED: no open recapture PRs remain (`gh pr list --search recapture --state open` → empty)
- CONFIRMED: `git diff .github/workflows/ci.yml` is empty across every commit in this plan
