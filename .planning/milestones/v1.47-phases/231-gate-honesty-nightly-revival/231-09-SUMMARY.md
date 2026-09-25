---
phase: 231-gate-honesty-nightly-revival
plan: 09
subsystem: infra
tags: [github-actions, ci, gate-honesty, ci-skip-manifest, bash]

requires:
  - phase: 231-08
    provides: "scripts/ci/honest-skip-verdict.sh (the GATE-03 verdict logic) plus its 19-case hermetic self-test, wired into fast_checks. GATE-03 left correctly Pending because ci-gate did not yet invoke the script."
provides:
  - "ci-gate rewired: a checkout (its first working tree ever), a `changes` needs-edge as an input provider, and a new 'Honest-skip verdict (GATE-03)' step running BEFORE the byte-unchanged legacy 'Verify required release CI lanes' loop."
  - "The `force_rot_probe` workflow_dispatch input, mirroring `force_fail_probe`'s shape, threaded into the verdict step's env so SC-3's fail direction is re-provable on demand forever."
  - "Self-test case T: the static assertion that ci-gate's shipped step list actually invokes honest-skip-verdict.sh ahead of the legacy loop, with the docs-only/event-name/probe env keys present -- closing the case 231-08 deliberately left absent-by-design."
  - "SC-3 closed on three live runs at commit d7f75397, across two event types: one clean workflow_dispatch (ci-gate success, all nine lanes non-skipped), one rot-probe workflow_dispatch (ci-gate failure naming example_playwright_smoke and its synthetic rotted gate), and one ordinary pull_request run (ci-gate success, upgrade_smoke's legitimate event-gated skip observed live)."
  - "GATE-03 marked Complete in REQUIREMENTS.md, citing all three run IDs."
  - "The example_unit_smoke / ci-gate.needs gap filed as a diagnosed, unowned todo (.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md)."
affects: [231-10, 231-11]

tech-stack:
  added: []
  patterns:
    - "A two-step ci-gate: the new verdict step runs first and the pre-existing 'Verify required release CI lanes' loop stays byte-identical behind it, so the diff is reviewable and the new check is provably additive rather than a silent replacement."
    - "A workflow_dispatch probe input threaded through env, not a branch experiment: force_rot_probe (mirroring force_fail_probe) makes the fail direction re-provable on demand forever, matching Phase 230's standing-receipt posture."
    - "needs: list parsing is comment-intolerant: honest-skip-verdict.sh's own needs: extractor (and its self-test's copy of the same awk) requires every line inside ci-gate.needs to be a bare '- id' entry -- any comment or blank line inside the list silently zeroes the extraction. Explanatory comments belong above the needs: key, never inside the list."

key-files:
  created:
    - .planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md
  modified:
    - .github/workflows/ci.yml
    - scripts/ci/honest-skip-verdict.test.sh
    - .planning/REQUIREMENTS.md

key-decisions:
  - "GATE-03 marked Complete. Its literal REQUIREMENTS.md text -- 'ci-gate distinguishes skipped-because-correctly-gated from skipped-because-rotted, and fails on the latter' -- is proven on three live runs at the same commit, in both directions, across both event types ci-gate actually runs on in this phase window (workflow_dispatch and pull_request). The example_unit_smoke gap does not bear on this text: GATE-03 is about ci-gate's skip-legitimacy verdict over the lanes it already knows about, not about which lanes are declared as needs: at all -- that is a distinct, already-CONTEXT-out-of-scope gap, filed as its own todo per plan instruction."
  - "The rot-probe comment placement bug (a multi-line comment inside ci-gate.needs silently zeroed honest-skip-verdict.sh's own needs: extraction) was fixed by moving the explanatory prose above the needs: key rather than editing the shipped script -- this plan's file fence is ci.yml + the test file only, and the fix keeps honest-skip-verdict.sh untouched while restoring both the shipped script's live cross-check and case R/T's local copy of the same awk."
  - "DOCS_ONLY and FORCE_ROT_PROBE reach the verdict script via bare env-var pass-through (their step env: key names are byte-identical to the names honest-skip-verdict.sh already reads as defaults, e.g. `FORCE_ROT_PROBE=\"${FORCE_ROT_PROBE:-}\"`), while EVENT_NAME is explicitly passed as `--event \"${EVENT_NAME}\"` because the script's own default read name (GITHUB_EVENT_NAME) differs from the plan-mandated env key name (EVENT_NAME, matching the `changes` job's own convention at ci.yml:115). All three still reach the shell exclusively through the env: map -- referencing a mapped shell variable inside run: is not the same as inlining a `${{ }}` context expression, which never appears in any run: body in the job."

requirements-completed: [GATE-03]

coverage:
  - id: D1
    description: "ci-gate has a checkout, a changes needs-edge (input provider, not a gated lane), and a new 'Honest-skip verdict (GATE-03)' step ahead of the byte-unchanged legacy loop"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "python3 YAML-parse assertion (plan's own verify block): checkout is first step pinned to actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1, verdict step second with docs-only/event-name/probe env keys, legacy step third"
        status: pass
    human_judgment: false
  - id: D2
    description: "The legacy 'Verify required release CI lanes' step's name/env/run are byte-identical to the parent commit"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "python3 comparison against git show HEAD~1:.github/workflows/ci.yml -- MATCH"
        status: pass
    human_judgment: false
  - id: D3
    description: "No run: body in the ci-gate job contains an inlined GitHub context expression; every context value reaches the shell only through env:"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "python3 scan of all three ci-gate step run: bodies for '${{' -- zero matches"
        status: pass
    human_judgment: false
  - id: D4
    description: "Self-test case T: the shipped ci-gate actually invokes the verdict script, ahead of the legacy loop, with the docs-only/event-name/probe env keys present; falsifiable against a fixture ci-gate missing the step"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "scripts/ci/honest-skip-verdict.test.sh case T (20/20 passing); fail-first check against a fixture workflow observed to correctly FAIL before case T was added to the shipped file"
        status: pass
    human_judgment: false
  - id: D5
    description: "p06-never-docs-gate-asserting-lanes and the full prohibition suite remain green now that ci-gate.needs carries a changes edge"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs -- 58/58"
        status: pass
    human_judgment: false
  - id: D6
    description: "SC-3 closed live: clean dispatched run -- ci-gate success, all nine lanes non-skipped, empty allow-set on workflow_dispatch"
    requirement: "GATE-03"
    verification:
      - kind: e2e
        ref: "gh workflow run \"CI\" -f force_rot_probe=false -f recapture_branch=worktree-discuss-231 -> run 30526744204, ci-gate job 90824424228, conclusion success"
        status: pass
    human_judgment: false
  - id: D7
    description: "SC-3 closed live: rot-probe dispatched run -- ci-gate failure, verdict step names example_playwright_smoke and quotes its synthetic rotted gate string"
    requirement: "GATE-03"
    verification:
      - kind: e2e
        ref: "gh workflow run \"CI\" -f force_rot_probe=true -f recapture_branch=worktree-discuss-231 -> run 30526771018, ci-gate job 90823547343, conclusion failure, step 'Honest-skip verdict (GATE-03)' failure"
        status: pass
    human_judgment: false
  - id: D8
    description: "The docs-only/pull_request branch of D-03's allow-set is exercised live (not just hermetically): upgrade_smoke skipped, verdict PASS, on a real pull_request-event run"
    requirement: "GATE-03"
    verification:
      - kind: e2e
        ref: "PR #125 synchronize run 30526727106 (pull_request event, same commit d7f75397), ci-gate job 90822708355, conclusion success, verdict table shows upgrade_smoke skipped/PASS"
        status: pass
    human_judgment: false
  - id: D9
    description: "The example_unit_smoke / ci-gate.needs gap is filed as a diagnosed, phase-unowned todo, visible in every gate log via the verdict script's advisory NOTE"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "test -f + python3 frontmatter/body assertion (plan's own verify block) -- OK; git diff --stat HEAD -- .github scripts empty for this task"
        status: pass
    human_judgment: false

duration: ~50min
completed: 2026-07-30
status: complete
---

# Phase 231 Plan 09: GATE-03 wired into ci-gate — closed live in both directions across two event types

**`ci-gate` now genuinely fails when a `ci-gate.needs` lane skips illegitimately and passes when it skips legitimately, proven on three live runs at commit `d7f75397` — one clean `workflow_dispatch`, one deliberately rotted `workflow_dispatch` probe naming the lane, and one ordinary `pull_request` run exercising the real event-gated skip — closing GATE-03.**

## Performance

- **Duration:** ~50min (includes ~20min of live CI wall-clock waiting on the two dispatched runs)
- **Started:** 2026-07-30 ~08:15 UTC
- **Completed:** 2026-07-30 ~09:05 UTC
- **Tasks:** 3 planned, 3 completed
- **Files modified:** 4 (1 created, 3 modified: `.github/workflows/ci.yml`, `scripts/ci/honest-skip-verdict.test.sh`, `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`, `.planning/REQUIREMENTS.md`)

## Sample size (explicit, per the executor brief's own instruction)

**3 live runs, 2 event types, 1 deliberate failure + 2 passes, all at the same commit SHA (`d7f753974af93d2485ab9f70454fe0ce88d289a6`).** The two dispatched runs (`30526744204` clean, `30526771018` rot-probe) were launched back-to-back against the identical commit so the only variable between them is the `force_rot_probe` input value. The third run (`30526727106`) was not separately dispatched — pushing the Task 1 commit to the open PR branch (#125) automatically produced a `pull_request`-event CI run at the same SHA, which turned out to be exactly the evidence needed for D-03's `pull_request`-only allow-set branch: a real `upgrade_smoke` skip, observed live as legitimately gated, not merely asserted by the hermetic self-test. This is deliberately economical rather than exhaustive (per the executor brief's explicit caution against GATE-02's 26-dispatch gap-closure pattern) because the fail-direction mechanism is re-provable forever via `force_rot_probe` — a fourth or fifth dispatch would add no new information, only re-confirm the same two code paths.

## Accomplishments

- **`ci-gate` gained a checkout, a `changes` needs-edge, and a new verdict step — the legacy loop stays byte-identical.** The pre-existing `Verify required release CI lanes` step's `name:`, `env:`, and `run:` body are byte-for-byte identical to the parent commit (`git show HEAD~1:.github/workflows/ci.yml`), confirmed by direct text comparison. The new `Honest-skip verdict (GATE-03)` step runs immediately before it.
- **Every GitHub context value reaches the shell only through `env:`.** Scanned all three `ci-gate` steps' `run:` bodies for `${{` — zero matches. Independently confirmed on the live rot-probe run's log: `token: ***` (masked) on the checkout step, and the verdict step's `env:` block lists `DOCS_ONLY`, `EVENT_NAME`, `FORCE_ROT_PROBE`, and all nine `*_RESULT`-style keys before the `run:` body references only `${VAR}` shell expansions.
- **Fixed a parser-breaking bug my own edit introduced, without touching the out-of-fence script.** Placing an explanatory multi-line comment *inside* `ci-gate.needs` (before the `- changes` entry) silently zeroed `honest-skip-verdict.sh`'s own `needs:` extraction (its awk resets `in_needs=0` on the first non-item line), which would have broken the shipped script's cross-check on every real CI run. Moved the comment above the `needs:` key instead — `honest-skip-verdict.test.sh` went from 15/20 failing (self-inflicted) to 20/20 passing.
- **Self-test case T added and proven falsifiable.** Modeled on `ci-demotion-observer.test.sh:376-390`'s static wiring style: extracts the `ci-gate` job block via the same awk pattern `honest-skip-verdict.sh` itself uses, asserts the verdict step exists, sits before the legacy step in list order, invokes `honest-skip-verdict.sh`, and carries the `DOCS_ONLY`/`EVENT_NAME`/`FORCE_ROT_PROBE` env keys. Manually verified fail-first against a fixture `ci-gate` job missing the verdict step entirely (correctly failed: `verdict_line=<missing> legacy_line=18 invokes=0 docs_only=0 event_name=0 probe=0`) before confirming it passes against the shipped workflow.
- **SC-3 closed live, both directions, both observed event types:**
  - **Clean control** (`30526744204`, `workflow_dispatch`, `force_rot_probe=false`): `ci-gate` job `90824424228` concluded `success`. All nine lanes reported `success` (none `skipped`), confirming D-03's "no `ci-gate.needs` lane may skip on a non-`pull_request` event" for a `workflow_dispatch` run.
  - **Rot probe** (`30526771018`, `workflow_dispatch`, `force_rot_probe=true`): `ci-gate` job `90823547343` concluded `failure`, at the `Honest-skip verdict (GATE-03)` step specifically (the legacy step downstream was correctly `skipped`, never even evaluated).
  - **Live `pull_request` run** (`30526727106`, PR #125 synchronize, same commit): `ci-gate` job `90822708355` concluded `success`, with `upgrade_smoke` reported `skipped` / `PASS` — the real event-gated skip, observed live rather than only hermetically.
- **The `notify_release_lane_rot` consumer fired for real on the rot-probe run**, an incidental live receipt: job `90823574231` concluded `success` and appended an occurrence comment to tracking issue #118. A same-session follow-up comment was posted identifying it as the deliberate SC-3 probe: https://github.com/szTheory/sigra/issues/118#issuecomment-5128725755
- **GATE-03 marked Complete in REQUIREMENTS.md**, citing all three run IDs and explicitly noting the `example_unit_smoke` gap does not bear on GATE-03's literal text.
- **The `example_unit_smoke` gap filed** as a diagnosed, phase-unowned todo per plan instruction, cross-referenced with the sibling SEED-005 P1-2 deferral already in `231-CONTEXT.md`.
- **Two `github-actions`-spawned recapture PRs closed and their branches deleted**: `#166` (`ci/recapture-admin-checkpoints-30526771018`) and `#167` (`ci/recapture-admin-checkpoints-30526744204`), both base `worktree-discuss-231`, both spawned by this plan's two dispatches. No other open PRs touched.

## Task Commits

1. **Task 1: Wire the verdict into ci-gate and add the rot-probe input (D-02, D-05)** — `d7f75397` (feat)
2. **Task 3: File the deferred example_unit_smoke honesty gap as a diagnosed todo** — `a5ca105d` (docs)

**Task 2** (Close SC-3 with two dispatched runs) changed no file by design — its deliverable is the two live receipts recorded in this SUMMARY. `git diff --stat HEAD -- .github scripts` was empty for that task, as required.

**Plan-metadata commit:** created after this SUMMARY, per `commit_docs: true` (also carries the GATE-03 completion in `.planning/REQUIREMENTS.md`).

## Files Created/Modified

- `.github/workflows/ci.yml` — `force_rot_probe` dispatch input added after `force_fail_probe`; `ci-gate.needs` gained `changes` (with an explanatory comment placed above the `needs:` key, not inside the list); `ci-gate.steps` gained a pinned checkout and the `Honest-skip verdict (GATE-03)` step ahead of the byte-unchanged legacy loop.
- `scripts/ci/honest-skip-verdict.test.sh` — case T added (static wiring assertion), docstring updated, self-test now 20/20.
- `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` — new, diagnosed, no `resolves_phase`.
- `.planning/REQUIREMENTS.md` — GATE-03 checkbox and traceability row marked Complete, citing run IDs. GATE-01, GATE-02, GATE-04 rows untouched (confirmed via `git diff`).

## Decisions Made

See `key-decisions` in frontmatter. In full:

1. **GATE-03 marked Complete**, citing three live run IDs across two event types. Its literal REQUIREMENTS.md text is a claim about `ci-gate`'s skip-verdict behavior over the lanes it already knows about (`ci-gate.needs`), not a claim about which lanes are declared there — the `example_unit_smoke` gap is real but is a distinct, CONTEXT-scoped-out concern, correctly filed as its own todo rather than folded into this requirement.
2. **Fixed the needs:-list-comment parser bug by moving the comment, not by editing `honest-skip-verdict.sh`.** The plan's declared file fence for this plan is `.github/workflows/ci.yml` + `scripts/ci/honest-skip-verdict.test.sh` + the todo file; the bug was in the shipped script's `needs:` extractor, but the safe fix (comments live outside the parsed list) required no edit to that script at all.
3. **`DOCS_ONLY`/`FORCE_ROT_PROBE` pass through bare env; `EVENT_NAME` needs an explicit `--event` flag.** The script's own internal default-read names (`DOCS_ONLY`, `FORCE_ROT_PROBE`) happen to match the plan's mandated `env:` key names exactly, so no CLI flag is needed for those two — the script picks them up automatically. `EVENT_NAME` (the plan-mandated key, matching the `changes` job's own convention) differs from the script's default read name (`GITHUB_EVENT_NAME`), so it is passed explicitly via `--event "${EVENT_NAME}"`, still exclusively through the env-mapped shell variable.

## Deviations from Plan

**1. [Rule 1 - Bug] Fixed a needs:-list comment-parser break introduced by my own Task 1 edit.**
- **Found during:** Task 1's own verify block (`bash scripts/ci/honest-skip-verdict.test.sh` immediately went from expected-green to 15/20 failing).
- **Issue:** Placing the plan-instructed "one-line comment stating [`changes`] is an input provider" *inside* the `needs:` list (before `- changes`) caused `honest-skip-verdict.sh`'s own `extract_ci_gate_needs()` awk (and its self-test's local copy in case R) to see a non-item line first and reset `in_needs=0`, silently yielding zero extracted needs entries. This is not a hypothetical — it broke every hermetic test case that invokes the real shipped workflow.
- **Fix:** Moved the explanatory comment to sit directly above the `needs:` key (job-level comment) rather than inside the list, and added a note there flagging the parser's comment-intolerance for future editors. No change to `honest-skip-verdict.sh` itself — stayed within the plan's declared file fence.
- **Files modified:** `.github/workflows/ci.yml` (comment relocation only, same commit as the rest of Task 1).
- **Commit:** `d7f75397`

No other deviations. All three declared-fence files were touched and no others (plus `.planning/REQUIREMENTS.md`, which the plan's `<output>` section implicitly requires for marking GATE-03 and which every prior plan in this phase has also updated for its own requirement).

## Issues Encountered

None beyond the parser bug documented above (caught and fixed within Task 1, before any commit).

## User Setup Required

None — no external service configuration required. `gh` was already authenticated as `szTheory` with `workflow` scope, sufficient to dispatch `workflow_dispatch` runs and close PRs.

## PRs Closed

- **#166** `ci/recapture-admin-checkpoints-30526771018` → `worktree-discuss-231` — closed, branch deleted. Spawned by the rot-probe dispatch.
- **#167** `ci/recapture-admin-checkpoints-30526744204` → `worktree-discuss-231` — closed, branch deleted. Spawned by the clean-control dispatch.

No other open PRs were touched (`#125` phase PR, `#124` docs/230-phase-complete, `#122` release-please — all left alone).

## Next Phase Readiness

- **GATE-03 is genuinely closed.** Nothing remains for a future plan on this requirement's literal text.
- **The `example_unit_smoke` gap is filed and visible in every `ci-gate` run's log** (the GATE-03 verdict script's advisory NOTE), owned by no phase. 231-10/231-11 or the phase verifier should be aware it exists but are not required to act on it — CONTEXT places it explicitly out of scope for this phase.
- **`ci-gate` is confirmed green on the non-probe path at current branch HEAD** (`a5ca105d`, one commit ahead of the wiring commit `d7f75397` — Task 3 changed only a `.planning/todos/` file, so the non-probe live-run evidence at `d7f75397` still describes the current `ci-gate` behavior byte-for-byte). 231-10 and 231-11 can build on this branch without `ci-gate` being broken for them.
- **Issue #118 (`release-lane-rot`) carries a labelled follow-up comment** on this plan's probe occurrence, consistent with the phase's "a red must produce a trusted signal" thesis applied to the probe's own side effect.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30*

## Verification Evidence (actually run)

### Task 1's automated verify block (plan's own literal commands)

```
$ bash scripts/ci/honest-skip-verdict.test.sh
... (after fixing the self-inflicted comment-parser break)
Results: 20 passed, 0 failed
honest-skip-verdict.test: PASS

$ actionlint -shellcheck= .github/workflows/ci.yml
(exit 0, no output)

$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 58
# pass 58
# fail 0

$ python3 -c "...YAML-parse assertion (checkout pinned/first, verdict step second with docs-only/
  event-name/probe env keys, legacy step third, ci-gate.needs has 10 entries including changes,
  if: always() unchanged)..."
OK
```

### Legacy step byte-identity (plan's own acceptance criterion)

```
$ python3 -c "compare extract_step(old, 'Verify required release CI lanes') vs
  extract_step(new, 'Verify required release CI lanes')"
MATCH
```

### No inlined GitHub context in any ci-gate run: body

```
$ python3 -c "scan all three ci-gate steps' run: for '${{'"
clean: Checkout (honest-skip manifest)
clean: Honest-skip verdict (GATE-03)
clean: Verify required release CI lanes
```

### Case T fail-first observation (acceptance criterion: falsifiable)

Against a fixture `ci-gate` job with only a `noop` step (no verdict, no checkout):

```
correctly FAILS: verdict_line=<missing> legacy_line=18 invokes=0 docs_only=0 event_name=0 probe=0
```

Then, against the shipped workflow after Task 1's edit:

```
Test T: ci-gate's own step list invokes honest-skip-verdict.sh ahead of the legacy loop
  PASS: T: ci-gate invokes honest-skip-verdict.sh before the legacy loop, env carries docs-only/event-name/probe keys
```

### SC-3 receipts (Task 2 — the deliverable, no file changed)

**Dispatch commands (both against ref `worktree-discuss-231`, commit `d7f75397`):**

```
$ gh workflow run "CI" --repo szTheory/sigra --ref worktree-discuss-231 \
    -f force_rot_probe=false -f recapture_branch=worktree-discuss-231
-> run 30526744204

$ gh workflow run "CI" --repo szTheory/sigra --ref worktree-discuss-231 \
    -f force_rot_probe=true -f recapture_branch=worktree-discuss-231
-> run 30526771018
```

**Run 1 — clean control (`30526744204`, `workflow_dispatch`, `ci-gate` job `90824424228`, conclusion `success`):**

```
env:
  DOCS_ONLY: false
  EVENT_NAME: workflow_dispatch
  FORCE_ROT_PROBE: false
  INSTALL_GOLDEN_CONTRACT: success
  LIBRARY_TESTS: success
  LIBRARY_TESTS_DEP_OFF: success
  INSTALL_SMOKE: success
  UPGRADE_SMOKE: success
  EXAMPLE_HTTP_SMOKE: success
  EXAMPLE_PLAYWRIGHT_SMOKE: success
  GENERATED_ADMIN_PLAYWRIGHT_SMOKE: success
  FAST_CHECKS: success

Honest-skip verdict -- event: workflow_dispatch, docs_only: false

lane                              result   verdict
install_golden_contract           success  PASS
library_tests                     success  PASS
library_tests_dep_off             success  PASS
install_smoke                     success  PASS
upgrade_smoke                     success  PASS
example_http_smoke                success  PASS
example_playwright_smoke          success  PASS
generated_admin_playwright_smoke  success  PASS
fast_checks                       success  PASS

  NOTE: example_unit_smoke is a ruleset-required check name absent from ci-gate.needs / this script's fixed lane set (Phase 231 GATE-03 todo, filed by plan 231-09). Advisory only -- never fails the verdict.
  every skip (if any) on this lane set is legitimately gated for this event, and no allowed gate is rotted.
```

All nine lanes actually **executed** (`success`, zero `skipped`) — confirming D-03's "no `ci-gate.needs` lane may legitimately skip on a non-`pull_request` event" for the `workflow_dispatch` case, and that the control run is a genuine positive proof, not a coincidental pass.

**Run 2 — rot probe (`30526771018`, `workflow_dispatch`, `ci-gate` job `90823547343`, conclusion `failure`):**

```
env:
  DOCS_ONLY: false
  EVENT_NAME: workflow_dispatch
  FORCE_ROT_PROBE: true
  INSTALL_GOLDEN_CONTRACT: success
  LIBRARY_TESTS: success
  LIBRARY_TESTS_DEP_OFF: success
  INSTALL_SMOKE: success
  UPGRADE_SMOKE: success
  EXAMPLE_HTTP_SMOKE: success
  EXAMPLE_PLAYWRIGHT_SMOKE: success
  GENERATED_ADMIN_PLAYWRIGHT_SMOKE: success
  FAST_CHECKS: success

*** ROT PROBE ACTIVE (--force-rot-probe): forcing example_playwright_smoke to a skipped result carrying a synthetic rotted gate, self-test purposes only -- this run does not reflect real CI ***
Honest-skip verdict -- event: workflow_dispatch, docs_only: false

lane                              result   verdict
install_golden_contract           success  PASS
library_tests                     success  PASS
library_tests_dep_off             success  PASS
install_smoke                     success  PASS
upgrade_smoke                     success  PASS
example_http_smoke                success  PASS
example_playwright_smoke          skipped  FAIL
generated_admin_playwright_smoke  success  PASS
fast_checks                       success  PASS

  FAIL example_playwright_smoke: lane 'example_playwright_smoke' skipped on event 'workflow_dispatch', which is not in the legitimate-skip set for this event; manifest gate: "github.head_ref == 'ship/rot-probe-synthetic'"
  NOTE: example_unit_smoke is a ruleset-required check name absent from ci-gate.needs / this script's fixed lane set (Phase 231 GATE-03 todo, filed by plan 231-09). Advisory only -- never fails the verdict.
##[error]Process completed with exit code 1.
```

The downstream `Verify required release CI lanes` step's conclusion was `skipped` (never evaluated — the verdict step's non-zero exit under `set -euo pipefail` halted the job before it ran), and `Checkout (honest-skip manifest)`'s log shows `token: ***` (masked), confirming Prohibition #2 (no secret emission).

**Run 3 — live `pull_request` run (`30526727106`, PR #125 synchronize triggered by pushing `d7f75397`, `ci-gate` job `90822708355`, conclusion `success`):**

```
env:
  DOCS_ONLY: false
  EVENT_NAME: pull_request

Honest-skip verdict -- event: pull_request, docs_only: false

lane                              result   verdict
install_golden_contract           success  PASS
library_tests                     success  PASS
library_tests_dep_off             success  PASS
install_smoke                     success  PASS
upgrade_smoke                     skipped  PASS
example_http_smoke                success  PASS
example_playwright_smoke          success  PASS
generated_admin_playwright_smoke  success  PASS
fast_checks                       success  PASS

  NOTE: example_unit_smoke is a ruleset-required check name absent from ci-gate.needs / this script's fixed lane set (Phase 231 GATE-03 todo, filed by plan 231-09). Advisory only -- never fails the verdict.
  every skip (if any) on this lane set is legitimately gated for this event, and no allowed gate is rotted.
```

This is D-03's `pull_request`-only allow-set branch, observed **live** (not just via the hermetic self-test): `upgrade_smoke` genuinely skipped on this real PR run and the verdict correctly reported `PASS` for it.

**Confirming the non-probe path is clean, not stuck red:** both `30526744204` (clean dispatch) and `30526727106` (ordinary PR run) — the two non-probe runs at the same commit — concluded `ci-gate` `success`. The rot-probe run's failure is attributable solely to `force_rot_probe=true`, not to any lingering effect: all three runs share commit `d7f753974af93d2485ab9f70454fe0ce88d289a6`, and the two non-probe runs are green while only the probe run is red. The gate is not stuck in either state.

**Tracking-issue follow-up comment (Prohibition 4 — labelled, not silent):**
https://github.com/szTheory/sigra/issues/118#issuecomment-5128725755

### Task 3's automated verify block (plan's own literal command)

```
$ test -f .planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md \
    && python3 -c "...frontmatter/body assertions..."
OK

$ git diff --stat HEAD -- .github scripts
(empty)
```

### Recapture PRs closed

```
$ gh pr close 166 --repo szTheory/sigra --delete-branch --comment "..."
✓ Closed pull request szTheory/sigra#166
✓ Deleted branch ci/recapture-admin-checkpoints-30526771018

$ gh pr close 167 --repo szTheory/sigra --delete-branch --comment "..."
✓ Closed pull request szTheory/sigra#167
✓ Deleted branch ci/recapture-admin-checkpoints-30526744204
```

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml` — `force_rot_probe` input, `changes` needs-edge, checkout + verdict step present
- FOUND: `scripts/ci/honest-skip-verdict.test.sh` — case T present, 20/20 passing
- FOUND: `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`
- FOUND: `.planning/REQUIREMENTS.md` — GATE-03 marked Complete, GATE-01/GATE-02/GATE-04 untouched
- FOUND commit: `d7f75397`
- FOUND commit: `a5ca105d`
- CONFIRMED: run `30526744204` — `ci-gate` job `90824424228`, conclusion `success`
- CONFIRMED: run `30526771018` — `ci-gate` job `90823547343`, conclusion `failure`, failed step `Honest-skip verdict (GATE-03)`
- CONFIRMED: run `30526727106` — `ci-gate` job `90822708355`, conclusion `success`
- CONFIRMED: `bash scripts/ci/honest-skip-verdict.test.sh` — 20/20 passing locally
- CONFIRMED: `actionlint -shellcheck= .github/workflows/ci.yml` — exit 0
- CONFIRMED: `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 58/58
- CONFIRMED: PRs #166 and #167 closed, branches deleted
- CONFIRMED: issue #118 labelling comment posted
