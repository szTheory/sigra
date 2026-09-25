---
phase: 231-gate-honesty-nightly-revival
plan: 08
subsystem: infra
tags: [github-actions, ci, gate-honesty, ci-skip-manifest, bash]

requires:
  - phase: 231-07
    provides: "The manifest's gate column made load-bearing for the first time (p10's gate-column parity assertion plus the rotted-gate-string prohibition), the true post-D-06 five-row lane-set floor, and the explicit hand-off recorded in 231-07's SUMMARY: 'GATE-03's own runtime verdict mechanism ... remains open work for a later plan.'"
provides:
  - "scripts/ci/honest-skip-verdict.sh: the GATE-03 verdict logic. Reads .github/ci-skip-manifest.tsv, cross-checks a fixed nine-lane ci-gate.needs list against the workflow's own needs: block (modulo the changes input-provider exclusion), builds D-03's per-event allow-set, and computes a PASS/FAIL verdict per lane with rot detection on the manifest's gate column."
  - "scripts/ci/honest-skip-verdict.test.sh: 19 hermetic self-test cases (A-S) covering both verdict directions, both anti-vacuity forms, the --force-rot-probe seam's on/off behaviour, and the workflow needs: cross-check in both directions -- no gh stub needed since the script under test never invokes gh."
  - "A new fast_checks step, 'Honest-skip verdict self-test', wired immediately after Wait-for-ci-gate self-test (plan 231-01) and before Phase 230 prohibition guards, running on every PR and push."
  - "Case T (the static assertion that ci-gate itself invokes this script) is explicitly recorded as absent-by-design in the self-test's own case-table docstring, attributed to plan 231-09."
affects: [231-09]

tech-stack:
  added: []
  patterns:
    - "A CI guard that never invokes gh: unlike ci-demotion-observer.sh, honest-skip-verdict.sh's entire input surface (event name, docs-only flag, nine lane results) arrives via CLI flags / env vars that a future ci-gate step maps from needs.*.result -- so its hermetic self-test needs no PATH-shadowed gh stub at all, only --from-json fixture files."
    - "Row-existence-preserving manifest lookup: manifest_lookup() prints a '1<TAB>gate' sentinel rather than just the gate cell, so the caller can distinguish 'row exists with an empty gate' from 'no row at all' -- a single bare print cannot make that distinction and would conflate a genuinely rotted-empty gate with a legitimate cascade case."
    - "Bidirectional needs: cross-check with a single named input-provider exclusion (changes), proven to pass against the shipped ci.yml both before and after plan 231-09 is expected to add changes to ci-gate.needs -- a needs: edit that adds or drops any other lane fails the verdict instead of silently widening or shrinking its scope."

key-files:
  created:
    - scripts/ci/honest-skip-verdict.sh
    - scripts/ci/honest-skip-verdict.test.sh
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "GATE-03 is NOT marked Complete. This plan ships the verdict LOGIC and its hermetic self-test only (D-02), exactly as the plan's own must_haves backstop states: 'SC-3's live halves ... close in plan 231-09, which wires the script into ci-gate and adds the force_rot_probe input.' ci-gate's actual verification step (ci.yml:1831) is unchanged by this plan -- it still treats every skipped result as a pass for every lane in its needs:, with no distinction between a legitimate and a rotted skip, until plan 231-09 wires this script in as a real step. Marking GATE-03 complete now would be the exact premature-completion failure this phase has already had to correct twice (per the executor brief's explicit warning)."
  - "The rot check requires a gate cell to be non-empty AND mention either github.event_name or docs_only, in addition to not matching the three rotted patterns (github.head_ref, a ship/ branch path, a 7-40 char hex SHA). This is slightly stronger than RESEARCH's literal step 3 (which only names the rotted-pattern check), but is a direct, deliberate reading of the action text's own requirement clause ('require its manifest gate cell to be non-empty and to mention either the event-name expression or the docs-only output') -- a gate that is merely non-rotted but references neither honest signal (e.g. an unrelated boolean) would otherwise pass unverified."
  - "The --force-rot-probe seam forces example_playwright_smoke's result to skipped and overrides ONLY its resolved manifest gate (in-memory, never touching the real manifest file) to a synthetic branch-keyed string. Because example_playwright_smoke is never in ALLOWED_SKIPS on any event, the probe reds through the ordinary not-allowed path (step 2) rather than requiring a dedicated probe-only verdict branch -- matching the plan's own A3 note that this routes 'through the ordinary rot path rather than a probe-only branch.' The synthetic gate string is carried into the FAIL reason text so the output visibly names a rotted-looking pattern, satisfying SC-3's requirement that the rot-probe verdict name the lane in the job log."

requirements-completed: []

coverage:
  - id: D1
    description: "honest-skip-verdict.sh builds no second enumeration of legitimate skips -- it reads only .github/ci-skip-manifest.tsv for gate data, with the one hard-coded set (the fixed nine ci-gate.needs lane ids) cross-checked at runtime against ci.yml's own needs: block"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "manual invocation: bash scripts/ci/honest-skip-verdict.sh --workflow <fixture missing a lane> ... -> exit 1 naming the missing lane; bash ... --workflow <fixture with zero needs> -> exit 1 with the literal broken-parse phrase; both proven against the shipped ci.yml with zero cross-check failures"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-03's allow-set is correct: empty on any non-pull_request event; on pull_request, {upgrade_smoke, library_tests_dep_off when docs-only=true}"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "scripts/ci/honest-skip-verdict.test.sh cases B, C, D, E, F (19/19 passing)"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-04's non-vacuity floor: a manifest yielding fewer than five ci-gate.needs-intersecting rows fails with the literal 'the parse broke, this is not a pass' phrase"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "scripts/ci/honest-skip-verdict.test.sh case K; positive control case Q confirms the shipped manifest yields exactly 5"
        status: pass
    human_judgment: false
  - id: D4
    description: "Rot detection: an allowed skip still FAILS when its manifest gate cell is empty, references github.head_ref/a branch path/a literal SHA, or mentions neither github.event_name nor docs_only -- the assertion that would have caught GATE-02's own defect"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "scripts/ci/honest-skip-verdict.test.sh case L (rotted upgrade_smoke gate fixture, still exits 1 with the offending cell quoted)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Second anti-vacuity form: a fully empty lane-result map fails with a broken-wiring message rather than reading as nothing-to-check-so-pass"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "scripts/ci/honest-skip-verdict.test.sh case J"
        status: pass
    human_judgment: false
  - id: D6
    description: "The --force-rot-probe seam is a provable no-op when unset and reproduces SC-3's fail direction (naming example_playwright_smoke) when set"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "scripts/ci/honest-skip-verdict.test.sh cases M, N"
        status: pass
    human_judgment: false
  - id: D7
    description: "Honest-skip verdict self-test runs in fast_checks on every PR and push, hermetically (no gh, no network, no GH_TOKEN), after Wait-for-ci-gate self-test and before Phase 230 prohibition guards"
    requirement: "GATE-03"
    verification:
      - kind: unit
        ref: "python3 YAML-parse assertion locating the exact step name and ordering; actionlint -shellcheck= .github/workflows/ci.yml exit 0"
        status: pass
    human_judgment: false
  - id: D8
    description: "GATE-03 is genuinely NOT complete after this plan -- ci-gate's own verification step is unchanged; the verdict is not yet consumed by ci-gate. SC-3's live proof (two dispatched runs, clean and rot-probed) is deferred to plan 231-09."
    requirement: "GATE-03"
    verification: []
    human_judgment: true
    rationale: "Whether GATE-03's literal REQUIREMENTS.md text ('ci-gate distinguishes ... and fails on the latter') is satisfied depends on ci-gate actually invoking this script and that invocation being observed on real CI runs -- neither happens in this plan by its own explicit design (the must_haves backstop truth names plan 231-09 as owning SC-3's live halves). A human/later-plan judgment closes GATE-03 once 231-09 lands and its two runs are observed."

duration: ~35min
completed: 2026-07-30
status: complete
---

# Phase 231 Plan 08: GATE-03 honest-skip verdict logic, shipped hermetically (ci-gate wiring deferred to 231-09)

**`scripts/ci/honest-skip-verdict.sh` reads `.github/ci-skip-manifest.tsv` and computes a per-lane PASS/FAIL verdict distinguishing a legitimately-gated skip from a rotted one -- with a 19/19 hermetic self-test wired into `fast_checks` -- but is not yet consumed by `ci-gate` itself, so GATE-03 stays correctly `Pending`.**

## Performance

- **Duration:** ~35min
- **Started:** 2026-07-30 ~08:05 UTC
- **Completed:** 2026-07-30 ~08:40 UTC
- **Tasks:** 2 planned (Task 1: the verdict script; Task 2: hermetic self-test + fast_checks wiring)
- **Files modified:** 3 (2 created, 1 modified) -- exactly the plan's declared fence, no deviations

## Accomplishments

- **The verdict script builds no second enumeration (D-01).** `honest-skip-verdict.sh`'s only hard-coded set is the fixed nine `ci-gate.needs` lane ids (sourced in a comment from `ci.yml:1793-1802`), and even that list is cross-checked at runtime against the workflow's own `needs:` block -- proven to pass against the shipped `ci.yml` with zero cross-check failures, and proven to fail (naming the offending id) against two fixture workflows: one missing a lane, one with no `needs:` block at all.
- **D-03's allow-set is exact.** On `pull_request`: `{upgrade_smoke}`, plus `library_tests_dep_off` only when `--docs-only true`. On any other event (`push`, `schedule`, `workflow_dispatch`): empty. Proven both directions live from the command line (evidence below) and via self-test cases B/C/D/E/F.
- **The rot check is the assertion that would have caught GATE-02's own defect.** An allowed skip still FAILS when its manifest gate cell is empty, references `github.head_ref`, a `ship/`-prefixed branch path, or a 7-40 char hex SHA, or mentions neither `github.event_name` nor `docs_only`. Proven against a fixture manifest whose `upgrade_smoke` gate cell was rewritten to a branch-keyed expression: the skip was allowed by D-03's rules yet the verdict still reds, quoting the offending cell verbatim in its FAIL reason.
- **Both anti-vacuity forms fail closed.** A manifest yielding zero rows intersecting the nine-lane set fails with the repo's literal phrase `the parse broke, this is not a pass`; a fully empty lane-result map fails with a distinct broken-wiring message. Neither reads as "nothing to check, so pass."
- **The `--force-rot-probe` seam is a provable no-op by default.** Forcing `example_playwright_smoke` (never in the allow-set on any event) to a skipped result with a synthetic rotted gate string reds through the ordinary not-allowed-skip path and names the lane; the identical invocation without the flag exits 0 and carries no probe banner.
- **19/19 hermetic self-test cases (A-S), ~2.8s wall-clock**, wired into `fast_checks` immediately after plan 231-01's `Wait-for-ci-gate self-test` step and before `Phase 230 prohibition guards`. No `gh` PATH-shadow stub is needed anywhere in this test file -- the script under test invokes `gh` nowhere, by construction (its entire input surface is CLI flags and env vars, matching how a future `ci-gate` step would map `needs.*.result`).
- **Case T is recorded as absent-by-design**, not silently omitted: the self-test's own docstring names it and attributes ownership to plan 231-09, because the static wiring assertion ("ci-gate actually invokes this script") cannot pass until that plan adds the step.
- **The zero-cost advisory NOTE from RESEARCH Open Question 5 is emitted**, never fails the verdict: `example_unit_smoke` is flagged as a ruleset-required check name absent from `ci-gate.needs` / this script's lane set, with the deferral attributed to plan 231-09.
- **`node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` remains 58/58** and `bash scripts/ci/ci-demotion-observer.test.sh` / `bash scripts/ci/wait-for-ci-gate.test.sh` remain fully green -- this plan touches no file either depends on.

## Task Commits

1. `d24cdafd` (feat) -- Task 1: `scripts/ci/honest-skip-verdict.sh`, the GATE-03 verdict logic.
2. `e35d86bf` (test) -- Task 2: `scripts/ci/honest-skip-verdict.test.sh` (19 cases) plus the `Honest-skip verdict self-test` step wired into `ci.yml`'s `fast_checks`.

**Plan-metadata commit:** created after this SUMMARY, per `commit_docs: true`.

## Files Created/Modified

- `scripts/ci/honest-skip-verdict.sh` -- the verdict: reads the manifest, cross-checks the workflow's `ci-gate.needs`, builds D-03's per-event allow-set, computes a PASS/FAIL verdict per lane with rot detection, emits `--format table|json`.
- `scripts/ci/honest-skip-verdict.test.sh` -- 19 hermetic cases (A-S), no `gh` stub needed.
- `.github/workflows/ci.yml` -- one new `fast_checks` step, `Honest-skip verdict self-test`, placed after `Wait-for-ci-gate self-test` and before `Phase 230 prohibition guards`.

## Decisions Made

See `key-decisions` in frontmatter. In full:

1. **GATE-03 left `Pending`**, per the plan's own explicit backstop truth naming plan 231-09 as owner of SC-3's live halves (the actual `ci-gate` wiring and the two dispatched runs proving it in both directions).
2. **The rot check additionally requires an honest-signal mention** (`github.event_name` or `docs_only`) beyond just rejecting the three rotted patterns, reading the action text's requirement clause literally rather than narrowing to RESEARCH's shorter step-3 summary.
3. **The rot-probe overrides the resolved gate in-memory only**, routing through the existing not-allowed-skip verdict path rather than adding a dedicated probe-only branch -- consistent with the plan's own A3 flagged-assumption note.

## Deviations from Plan

None -- plan executed exactly as written. All three files in the declared fence (`scripts/ci/honest-skip-verdict.sh`, `scripts/ci/honest-skip-verdict.test.sh`, `.github/workflows/ci.yml`) were touched and no others. No bugs, missing functionality, or blocking issues were found that required Rule 1-3 auto-fixes.

## Issues Encountered

None. `shellcheck` was run against both new scripts as an extra local check (not in the plan's own verify block) and reported zero warnings on both.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- **GATE-03's logic half is genuinely done and hermetically proven.** `scripts/ci/honest-skip-verdict.sh` is a complete, correct, fail-closed verdict function over the manifest and the nine `ci-gate.needs` lane results. Nothing in this plan's deliverable needs revisiting by 231-09 except wiring it in.
- **What remains for plan 231-09, unchanged from 231-07's own hand-off:** add a `checkout` step to the `ci-gate` job (it has none today -- the verdict script needs to read the committed manifest and workflow files), map the nine `needs.*.result` values plus `needs.changes.outputs.docs_only` into a new step's `env:`, add `changes` to `ci-gate.needs` (this plan's cross-check is proven to tolerate that addition via the `changes` input-provider exclusion), add the `force_rot_probe` `workflow_dispatch` input, and observe two live runs: one clean (`ci-gate` succeeds), one rot-probed (`ci-gate` fails, naming `example_playwright_smoke`). Only then does GATE-03's literal text -- "`ci-gate` distinguishes ... and fails on the latter" -- become true of the actual running gate.
- **Case T** (the static assertion that `ci-gate` invokes this script) is 231-09's to add, once the step exists to assert against.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30*

## Verification Evidence (actually run)

### Task 1's automated verify block (plan's own literal command)

```
$ bash -n scripts/ci/honest-skip-verdict.sh
(exit 0)
$ bash scripts/ci/honest-skip-verdict.sh --nonsense-flag
honest-skip-verdict: FAIL: unknown arg: --nonsense-flag
(exit 2)
$ bash scripts/ci/honest-skip-verdict.sh --event pull_request --docs-only false \
    --lane install_golden_contract=success --lane library_tests=success \
    --lane library_tests_dep_off=success --lane install_smoke=success \
    --lane upgrade_smoke=skipped --lane example_http_smoke=success \
    --lane example_playwright_smoke=success --lane generated_admin_playwright_smoke=success \
    --lane fast_checks=success --format json | python3 -c "...assert d['verdict']=='PASS'; assert len(d['lanes'])==9..."
OK
$ ! bash ... --event push ... | grep -c "upgrade_smoke" >/dev/null
(the push-event invocation reds and names upgrade_smoke, so the negation of the grep-pipeline exit succeeds)
$ bash scripts/ci/honest-skip-verdict.sh --event push --docs-only false --lane upgrade_smoke=skipped --format table 2>&1 | grep -c "upgrade_smoke"
2
```

### The verdict discriminates: the same skip, two events, opposite verdicts

**`pull_request` (upgrade_smoke's skip is legitimate, event-gated):**

```
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
exit: 0
```

**`push` (the identical skip is now illegitimate -- upgrade_smoke's gate is event-gated and this is the wrong event):**

```
Honest-skip verdict -- event: push, docs_only: false

lane                              result   verdict
install_golden_contract           success  PASS
library_tests                     success  PASS
library_tests_dep_off             success  PASS
install_smoke                     success  PASS
upgrade_smoke                     skipped  FAIL
example_http_smoke                success  PASS
example_playwright_smoke          success  PASS
generated_admin_playwright_smoke  success  PASS
fast_checks                       success  PASS

  FAIL upgrade_smoke: lane 'upgrade_smoke' skipped on event 'push', which is not in the legitimate-skip set for this event; manifest gate: "github.event_name != 'pull_request'"
  NOTE: example_unit_smoke is a ruleset-required check name absent from ci-gate.needs / this script's fixed lane set (Phase 231 GATE-03 todo, filed by plan 231-09). Advisory only -- never fails the verdict.
exit: 1
```

### Rot detection: an allowed skip still fails on a rotted gate

Fixture manifest with `upgrade_smoke`'s gate cell rewritten to `github.event_name != 'pull_request' || github.head_ref == 'ship/rot-test-fixture'`, `--event pull_request`, `upgrade_smoke=skipped` (otherwise D-03-legitimate):

```
  FAIL upgrade_smoke: lane 'upgrade_smoke' skipped and was allowed to for event 'pull_request', but its
  manifest gate "github.event_name != 'pull_request' || github.head_ref == 'ship/rot-test-fixture'" is
  rotted (references a branch head, a branch path, or a literal commit SHA) -- a branch-keyed gate is
  empty on every non-pull_request event and stale the moment the branch merges
exit: 1
```

### The rot-probe seam

```
$ bash scripts/ci/honest-skip-verdict.sh --event pull_request --docs-only false --force-rot-probe \
    --lane <all nine success> --format table
*** ROT PROBE ACTIVE (--force-rot-probe): forcing example_playwright_smoke to a skipped result carrying
a synthetic rotted gate, self-test purposes only -- this run does not reflect real CI ***
  FAIL example_playwright_smoke: lane 'example_playwright_smoke' skipped on event 'pull_request', which
  is not in the legitimate-skip set for this event; manifest gate: "github.head_ref == 'ship/rot-probe-synthetic'"
exit: 1

$ bash scripts/ci/honest-skip-verdict.sh --event pull_request --docs-only false \
    --lane <identical all-nine-success map> --format table
(no probe banner; every lane PASS)
exit: 0
```

### Task 2's automated verify block (plan's own literal command)

```
$ bash scripts/ci/honest-skip-verdict.test.sh
Test A: all nine lanes success on pull_request -> exit 0
  PASS: A: exit 0, no FAIL lines
...
Test S: a fixture workflow missing a lane from ci-gate.needs -> exit 1
  PASS: S: exit 1, names the lane missing from ci-gate.needs
Results: 19 passed, 0 failed
honest-skip-verdict.test: PASS

$ actionlint -shellcheck= .github/workflows/ci.yml
(exit 0, no output)

$ python3 -c "...YAML-parse assertion locating the step, its name, and its position after
  Wait-for-ci-gate self-test..."
OK
```

`time bash scripts/ci/honest-skip-verdict.test.sh`: **~2.8s wall-clock**, well under the 5s admissibility bar for `fast_checks`.

### Full prohibition suite, re-confirmed after both commits

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 58
# pass 58
# fail 0
```

### Sibling self-tests unaffected

```
$ bash scripts/ci/ci-demotion-observer.test.sh
Results: 19 passed, 0 failed
ci-demotion-observer.test: PASS

$ bash scripts/ci/wait-for-ci-gate.test.sh
Results: 11 passed, 0 failed
wait-for-ci-gate.test: PASS
```

### Extra local checks (not required by the plan's own verify block)

```
$ shellcheck scripts/ci/honest-skip-verdict.sh
(no output, exit 0)
$ shellcheck scripts/ci/honest-skip-verdict.test.sh
(no output, exit 0)
$ grep -c 'GH_TOKEN' scripts/ci/honest-skip-verdict.test.sh
0
$ awk '!/^[[:space:]]*#/' scripts/ci/honest-skip-verdict.sh | grep -c 'gh '
0
```

## Self-Check: PASSED

- FOUND: `scripts/ci/honest-skip-verdict.sh`
- FOUND: `scripts/ci/honest-skip-verdict.test.sh`
- FOUND: `.github/workflows/ci.yml` -- `Honest-skip verdict self-test` step present, after `Wait-for-ci-gate self-test`, before `Phase 230 prohibition guards`
- FOUND commit: `d24cdafd`
- FOUND commit: `e35d86bf`
- CONFIRMED: `bash scripts/ci/honest-skip-verdict.test.sh` -- 19/19 passing locally
- CONFIRMED: `actionlint -shellcheck= .github/workflows/ci.yml` -- exit 0
- CONFIRMED: `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` -- 58/58
- CONFIRMED: `git diff` on `.planning/REQUIREMENTS.md` will show no change to GATE-03's checkbox (stays `[ ]`, correctly Pending)
