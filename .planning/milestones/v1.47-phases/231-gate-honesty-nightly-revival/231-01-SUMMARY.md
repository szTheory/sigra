---
phase: 231-gate-honesty-nightly-revival
plan: 01
subsystem: infra
tags: [github-actions, ci, release-please, bash, gh-cli, testing]

requires: []
provides:
  - "scripts/ci/wait-for-ci-gate.sh — extracted, testable CLI for the release-lane ci-gate poll loop"
  - "scripts/ci/wait-for-ci-gate.test.sh — hermetic self-test wired into fast_checks"
  - "release-please.yml gate-ci-green rewired to the extracted script, 120-attempt ceiling, explicit timeout-minutes: 75"
  - "a live-invocation receipt proving the extracted script against a real completed push-to-main run"
affects: [231-02, 231-03, 231-04, 231-05, 231-06, 231-07, 231-08, 231-09, 231-10, 231-11]

tech-stack:
  added: []
  patterns:
    - "scripts/ci/<name>.sh + <name>.test.sh pair wired into fast_checks (house pattern, reused by every later 231 plan)"
    - "gh invoked bare via PATH so a hermetic self-test can shadow it with a recording, argv-dispatching stub"
    - "--from-json substitutes ALL network calls for a guard's hermetic mode, not just the first one — required a script-specific ci_gate_conclusion field on the from-json array shape"

key-files:
  created:
    - scripts/ci/wait-for-ci-gate.sh
    - scripts/ci/wait-for-ci-gate.test.sh
  modified:
    - .github/workflows/release-please.yml
    - .github/workflows/ci.yml

key-decisions:
  - "D-20: max-attempts raised 60 -> 120 (60-minute ceiling at the unchanged 30s interval), above the measured 28m29s post-230 push wall-clock (run 30466318240) and its 42.3m historical max."
  - "D-21: the poll loop was extracted into scripts/ci/wait-for-ci-gate.sh and proven live against run 30466318240's head SHA -- exit 0, attempts=1, well under 120."
  - "Added an actions/checkout step to gate-ci-green (Rule 3 blocking-issue fix, not named in the plan text): the extracted script is a repo file and needs to be present on the runner; the prior inline-shell job needed no checkout at all."
  - "--from-json's payload schema (a JSON array) carries a script-specific ci_gate_conclusion field per run entry so the hermetic self-test needs zero gh round-trips total (not just for the first of the two gh calls the live path makes)."

requirements-completed: [DX-05]

coverage:
  - id: D1
    description: "release-lane wait logic extracted from a 58-line inline `run:` block into scripts/ci/wait-for-ci-gate.sh, invoked by the real gate-ci-green job in release-please.yml"
    requirement: "DX-05"
    verification:
      - kind: unit
        ref: "scripts/ci/wait-for-ci-gate.test.sh (11 cases A-K)"
        status: pass
      - kind: other
        ref: "bash scripts/ci/wait-for-ci-gate.sh --sha 20e4fe3b9349d2da160d3c01fc580af7d1128317 --repo szTheory/sigra --no-dispatch --format json (live invocation against run 30466318240)"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-20: gate-ci-green polling ceiling raised from 30 to 60 minutes (max-attempts 60 -> 120), plus an explicit timeout-minutes: 75 replacing the previously-inherited 360-minute default"
    requirement: "DX-05"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/release-please.yml; python3 YAML assertion: jobs['gate-ci-green']['timeout-minutes'] == 75"
        status: pass
    human_judgment: false
  - id: D3
    description: "notify-release-failure job and D-23's already-observed notify-failure-issue.sh receipts left untouched (scope fence)"
    requirement: "DX-05"
    verification:
      - kind: other
        ref: "git diff HEAD -- .github/workflows/release-please.yml (no hunk inside jobs.notify-release-failure)"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-07-29
status: complete
---

# Phase 231 Plan 01: TRACER — wait-for-ci-gate extraction + live receipt Summary

**Extracted release-please.yml's inline ci-gate poll loop into `scripts/ci/wait-for-ci-gate.sh` with a testable CLI, raised the polling ceiling from 30 to 60 minutes (D-20), and proved the extraction end-to-end with a live invocation against a real completed push-to-main run (D-21).**

## Performance

- **Duration:** ~3 min (commit-to-commit)
- **Started:** 2026-07-29T19:18Z (approx, first task commit)
- **Completed:** 2026-07-29T19:21Z (second task commit)
- **Tasks:** 2/2 completed
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- Extracted the 58-line inline `run:` poll loop from `release-please.yml`'s `gate-ci-green` job into `scripts/ci/wait-for-ci-gate.sh`, a testable CLI with `--sha --repo --tag --workflow --max-attempts --wait-seconds --dispatch-after --no-dispatch --from-json --format` flags, preserving the original loop's exact fail-closed semantics (empty output, non-array payload, non-zero `gh` exit, exhausted attempts, and a zero-length run list all exit non-zero).
- D-20 closed: `--max-attempts` default raised from the inline 60 to 120 (a 60-minute ceiling at the unchanged 30s interval), above the measured 28m29s post-230 push wall-clock (run `30466318240`) and its 42.3m historical max. `gate-ci-green` now declares an explicit `timeout-minutes: 75`, replacing the previously-silent 360-minute inherited default.
- D-21 closed: the extracted script was invoked live against the head SHA of a real completed push-to-main run and returned success — see the receipt below. This is the tracer's own `<verify>` and the in-phase half of SC-5.
- Built `scripts/ci/wait-for-ci-gate.test.sh`, an 11-case hermetic self-test (green on first poll, green after N polls, `ci-gate` never green / exhaustion, zero-runs dispatch-once, `--no-dispatch` with zero runs, `gh` non-zero, `gh` absent, unknown flag, `--from-json` parity with zero `gh` calls, a fast positive control, and a non-array `--from-json` payload) and wired it into `fast_checks` as "Wait-for-ci-gate self-test", immediately after "Demotion observer self-test" and before "Phase 230 prohibition guards".
- Proved this plan's tracer thesis: one thin path through every layer of the phase's architecture (guard script -> self-test -> `fast_checks` wiring -> real workflow consumer -> observed-run receipt) now exists and is provably correct, for every later plan in the phase to copy.

## Task Commits

Each task was committed atomically:

1. **Task 1: TRACER — extract the poll loop, wire the real consumer, prove it live** - `32e3064c` (feat)
2. **Task 2: Hermetic self-test for the extracted loop, wired into fast_checks** - `a65b9be9` (test)

_No plan-metadata commit was made per this run's `commit_docs` setting (see State Updates below)._

## Files Created/Modified

- `scripts/ci/wait-for-ci-gate.sh` — the extracted, testable release-lane ci-gate poll loop
- `scripts/ci/wait-for-ci-gate.test.sh` — hermetic self-test (11 cases, PATH-shadowed recording `gh` stub, no network)
- `.github/workflows/release-please.yml` — `gate-ci-green` rewired to the extracted script; `timeout-minutes: 75` added; `--max-attempts 120`; an `actions/checkout` step added (see Deviations)
- `.github/workflows/ci.yml` — `fast_checks` gained the "Wait-for-ci-gate self-test" step

## Decisions Made

- **D-20 / D-21** implemented exactly as specified in `231-CONTEXT.md`: raise the ceiling, extract the loop, prove it live. No alternative considered — both were owner-selected in context-gathering.
- **`timeout-minutes: 75`** used per `231-RESEARCH.md`'s explicit recommendation (Claude's Discretion item), comfortably above the 60-minute polling ceiling and far below the 360-minute inherited default.
- **`--from-json` payload shape carries `ci_gate_conclusion`** on each run entry (a script-specific extension beyond the real `gh run list --json databaseId,status,conclusion,url,createdAt` schema), so the hermetic self-test's `--from-json` mode makes genuinely zero `gh` calls rather than only eliminating the first of the live path's two `gh` round-trips (`run list`, then `run view` for the `ci-gate` job conclusion). Documented inline in the script as intentional test-shape design.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Added `actions/checkout` to `gate-ci-green`**
- **Found during:** Task 1
- **Issue:** The original `gate-ci-green` job made no `actions/checkout` — it never needed repo files, only `gh` CLI calls against the GitHub API. Once the poll loop is extracted to `scripts/ci/wait-for-ci-gate.sh`, that script is a repo file the runner must have checked out, or `bash scripts/ci/wait-for-ci-gate.sh` fails with "No such file or directory" on every real release. This is a genuine correctness gap the plan text did not anticipate (its `<verify>` python assertion assumes `steps[0]` is the wait-for-ci-gate step).
- **Fix:** Added a pinned `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` step immediately before the "Wait for ci-gate on release SHA" step, with an inline comment explaining why it is now required. This makes the wait-for-ci-gate step `steps[1]`, not `steps[0]`.
- **Verification adjustment:** Task 1's literal `<verify>` python snippet indexes `j['steps'][0]`, which would now match the checkout step and KeyError on `s['run']`. I ran an adapted assertion that locates the step by its `run` content (`'scripts/ci/wait-for-ci-gate.sh' in s['run']`) instead of by position, and confirmed every other literal property held: `timeout-minutes == 75`, `permissions.actions == 'write'`, the step's `run` is a single line, and its `env` still declares all four of `GH_TOKEN`/`REPOSITORY`/`TAG_NAME`/`RELEASE_SHA`. All passed.
- **Files modified:** `.github/workflows/release-please.yml`
- **Verification:** `actionlint -shellcheck= .github/workflows/release-please.yml` exits 0; adapted YAML assertion (above) passes; `git diff HEAD` shows the only touched job is `gate-ci-green` — `notify-release-failure` has zero hunks (D-23 scope fence intact).
- **Committed in:** `32e3064c` (part of Task 1's commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking issue).
**Impact on plan:** Necessary for the extracted script to actually run on a real release; without it `gate-ci-green` would fail on every real release the moment `release_created` goes true. No scope creep — the fix is scoped entirely to `gate-ci-green`'s own steps.

## Issues Encountered

- The plan's Task 1 `<verify>` python snippet assumes the "Wait for ci-gate" step is `steps[0]`. It is now `steps[1]` because of the checkout-step deviation above. I ran the assertion adapted to locate the step by content rather than position and confirmed every other literal property held (see Deviations). No other issues.

## Verification Evidence (actually run)

```
$ bash scripts/ci/wait-for-ci-gate.test.sh
... (11 cases)
Results: 11 passed, 0 failed
wait-for-ci-gate.test: PASS
```
(runs in ~1.2s, well under the 5s admissibility bound for `fast_checks`)

```
$ actionlint -shellcheck= .github/workflows/release-please.yml .github/workflows/ci.yml
(exit 0, no output)
```

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 53
# pass 53
# fail 0
```
(regression check — this plan changes no prohibition subject; all 53 still pass)

### D-21 / SC-5 live-invocation receipt (the tracer's own `<verify>`)

```
$ SHA="$(gh run view 30466318240 --repo szTheory/sigra --json headSha -q .headSha)"
$ echo "$SHA"
20e4fe3b9349d2da160d3c01fc580af7d1128317

$ bash scripts/ci/wait-for-ci-gate.sh --sha "$SHA" --repo szTheory/sigra --no-dispatch --format json
{
  "sha": "20e4fe3b9349d2da160d3c01fc580af7d1128317",
  "run_url": "https://github.com/szTheory/sigra/actions/runs/30466318240",
  "attempts": 1,
  "verdict": "PASS"
}
$ echo $?
0
```

This is a **genuine observation**, not a YAML read: the script made a real `gh run list` call against `szTheory/sigra` filtered by that SHA, found the completed run, made a real `gh run view --json jobs` call to confirm the `ci-gate` job's conclusion was `success`, and a real `gh run view --json url` call to resolve the run URL — exit 0 after exactly 1 attempt, well inside the 120-attempt ceiling.

### D-21 standing-receipt note (verification: backstop, per plan frontmatter)

The plan's frontmatter explicitly marks one truth as `verification: backstop`: `gate-ci-green` carries `if: needs.release-please.outputs.release_created == 'true'`, so it never runs on an ordinary push, and the "on the next real release, `gate-ci-green` completes inside the 120-attempt ceiling" half of D-21/SC-5 **cannot be observed in this phase**. Recorded honestly here rather than claimed. The live invocation above is the full in-phase receipt this plan can produce; the real-release confirmation is a standing obligation for the next actual release, not a phase blocker (per D-21's owner-selected posture in `231-CONTEXT.md`).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- The house guard shape (script + hermetic self-test + `fast_checks` wiring + real consumer + observed-run receipt) is now proven end-to-end on this thin slice. Every later plan in Phase 231 (`231-02` through `231-11`, covering GATE-01..04) can copy this shape directly.
- `scripts/ci/wait-for-ci-gate.sh`'s `--from-json` array shape (with the `ci_gate_conclusion` extension field) is a reusable pattern for any future guard that needs to eliminate ALL network calls in hermetic mode, not just the first of several.
- No blockers for subsequent 231 plans. DX-05 is fully closed by this plan; D-24's sequencing note that DX-05 is "fully parallel" to the GATE-0x chain is honored — this plan touched only `release-please.yml` and `scripts/ci/`.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-29*

## Self-Check: PASSED

- FOUND: `scripts/ci/wait-for-ci-gate.sh`
- FOUND: `scripts/ci/wait-for-ci-gate.test.sh`
- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-01-SUMMARY.md`
- FOUND commit: `32e3064c`
- FOUND commit: `a65b9be9`
