---
phase: 231-gate-honesty-nightly-revival
plan: 04
subsystem: infra
tags: [github-actions, ci, playwright, webkit, svg, bash, node-test, prohibitions]

requires:
  - phase: 231-01
    provides: "the scripts/ci/<name>.sh + <name>.test.sh house pattern this plan reuses for the cache-key guard, and the scripts/ci/prohibitions/*.test.mjs house shape for the new p14 guard"
provides:
  - "admin_eval_render installs chromium AND webkit, matching its admin-eval-mobile (iPhone 13 / WebKit) project"
  - "Phase-230 browser-set cache key re-tokened -v1 -> -v2, with the stronger no-cache-step structural guarantee documented inline"
  - "scripts/ci/playwright-cache-key-guard.sh generalized to match any -vN version-token suffix (C-6), with a new fail-closed self-test case"
  - "probes.ts's ember-class check derives from classList instead of className, surviving SVG elements"
  - "scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs -- a falsifiable guard against the crash class, proven fail-first"
affects: [231-05, 231-06]

tech-stack:
  added: []
  patterns:
    - "dot-anchored property-access regex (\\.className\\.method) to distinguish an element property read from an unrelated bare local variable of the same name -- textual static analysis without type information"
    - "line-count-preserving local comment stripper (per-line block-comment state machine) for guards that need to report an offending LINE NUMBER, where _lib.mjs's shared stripJsComments collapses embedded newlines and is unusable for that purpose"

key-files:
  created:
    - scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs
  modified:
    - .github/workflows/ci.yml
    - scripts/ci/playwright-cache-key-guard.sh
    - scripts/ci/playwright-cache-key-guard.test.sh
    - test/example/priv/playwright/lib/eval/probes.ts

key-decisions:
  - "D-11 steps 1-2 executed in strict order: browsers installed + cache re-tokened first (commit 9ce7d6cb), probe fix + guard second (commit f2f8212e). Step 4 (deleting ci.yml:2450's continue-on-error) explicitly NOT touched -- that is plan 231-06's D-11 step 4, gated on 231-05 first reading whether b1-b6 actually pass in CI."
  - "C-6 closed in the same commit as the re-token: playwright-cache-key-guard.sh's version-extraction regex generalized from a hard-coded -v1 literal to any -vN token, plus a new self-test case (Test F) proving the generalization did not also make the -vN suffix itself optional."
  - "The 'admin_eval_render declares no actions/cache step' structural guarantee (must_haves truth + threat T-231-04-01) is real but was mis-scoped in the plan text: the job DOES carry a pre-existing, unrelated actions/cache step for Elixir deps (test/example/deps, test/example/_build), shipped by Phase 216. Verification was adapted to the accurate invariant -- no cache step whose path/key references Playwright browser binaries (ms-playwright / playwright-chromium-webkit) -- which is what the threat model actually protects against. See Deviations."
  - "p14's violation/floor/negative-control patterns are dot-anchored (\\.className, not bare className) to correctly exclude probes.ts:709-746's pre-existing, unrelated local variable also named className (destructured from element.getAttribute('class') ?? '', always a plain string). A bare-className pattern would false-positive there."

requirements-completed: []

coverage:
  - id: D1
    description: "admin_eval_render's browser install step now installs chromium and webkit (was chromium-only), with a step name recording the real reason (admin-eval-mobile is iPhone 13 / WebKit) instead of asserting the now-false chromium-only claim"
    requirement: "GATE-04"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml; python3 YAML assertion (adapted, see Deviations) confirming the single install step's run line, step name, and both D-13 continue-on-error boundaries"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase-230 browser-set cache key re-tokened -v1 -> -v2 with the boundary and structural guarantee documented inline; C-6 closed by generalizing playwright-cache-key-guard.sh's extraction regex and self-test in the same commit"
    requirement: "GATE-04"
    verification:
      - kind: unit
        ref: "bash scripts/ci/playwright-cache-key-guard.sh; bash scripts/ci/playwright-cache-key-guard.test.sh (8 cases A-F)"
        status: pass
    human_judgment: false
  - id: D3
    description: "probes.ts:380's ember-class check derives entirely from classList (a DOMTokenList on both HTML and SVG elements), never className (an SVGAnimatedString on SVG elements), so it returns false instead of throwing on an SVG element. probes.ts:176 and :237 (D-12: not-the-bug) are byte-identical."
    requirement: "GATE-04"
    verification:
      - kind: unit
        ref: "node --test scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs (3/3); node --test scripts/ci/prohibitions/*.test.mjs (56/56); npx playwright test --list (391 tests, 20 files, zero parse errors); git diff shows a single hunk inside the ember-reserved-for probe only"
        status: pass
    human_judgment: false
  - id: D4
    description: "p14 guard proven fail-first against a violating fixture (a synthetic el.className.includes(...) call) and against a gutted fixture (both safe reads removed), before being trusted as a green gate"
    requirement: "GATE-04"
    verification:
      - kind: unit
        ref: "GSD_PROHIB_SUBJECT=<violating fixture> node --test p14-no-svg-classname-string-ops.test.mjs -> 1 test red (test 2, correctly diagnosable by line + text); GSD_PROHIB_SUBJECT=<gutted fixture> -> 2 tests red (parse floor + negative control)"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-07-29
status: complete
---

# Phase 231 Plan 04: Admin-eval browser install + probe SVG-crash fix (D-11 steps 1-2, C-6) Summary

**`admin_eval_render` now installs both chromium and webkit (matching its `admin-eval-mobile` iPhone-13/WebKit project), and the `probes.ts` ember-class check derives from `classList` instead of the SVG-unsafe `className`, closing the two diagnosed bugs that made every b1-b6 harness phase fail before it could even be observed.**

## Performance

- **Duration:** ~22 min (commit-to-commit)
- **Started:** 2026-07-29 (task 1 first edit)
- **Completed:** 2026-07-29
- **Tasks:** 2/2 completed
- **Files modified:** 5 (1 created, 4 modified)

## Accomplishments

- **D-11 step 1 (Task 1):** `admin_eval_render`'s Playwright browser install step now runs `npx playwright install --with-deps chromium webkit`, matching the form already used at `playwright-github-pages.yml:92-94`. The step's `name:` was rewritten from asserting "admin-eval uses chromium" (now false) to stating the real reason: the `admin-eval-mobile` project is `devices['iPhone 13']`, i.e. WebKit.
- Re-tokened the Phase-230 browser-set cache key (`example_playwright_smoke`'s `playwright_browsers_cache` step) from `-v1` to `-v2`, recording the GATE-04 boundary in the key itself, and extended the inline comment with the structural guarantee: `admin_eval_render` carries no cache step that could restore Playwright browser binaries, so no cross-job cache restore can make WebKit appear there without the install step actually running.
- **C-6 closed in the same commit:** generalized `playwright-cache-key-guard.sh`'s extraction regex from a hard-coded `-v1` literal to any `-vN` version token, updated its docstring/example/failure message, and extended `playwright-cache-key-guard.test.sh`'s fixtures to the `-v2` shape plus a new Test F proving the guard still fails closed when the `-vN` suffix is absent entirely (generalizing to "any `-vN`" did not also make the token optional). 8/8 self-test cases pass.
- **D-11 step 2 (Task 2):** Fixed `probes.ts:380`'s `el.className.includes('ember')`, which threw `TypeError: el.className.includes is not a function` on any SVG element (`className` is an `SVGAnimatedString` there, not a plain string) — the bug that clustered the chromium/dark failures on `board-mg-2` (all four states) plus `board-summary_chip` and `board-field_help` on push run `30472016250`. `isEmberClass` now derives entirely from `classList` (a `DOMTokenList` on both HTML and SVG elements): keeps `classList.contains('sg-ember')`, replaces the substring check with a scan over the token list for any token containing `ember`. `probes.ts:176` and `:237` (D-12: explicitly not-the-bug) are byte-for-byte unchanged.
- Created `scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs`: a falsifiable guard with a parse floor, the prohibition itself (no `.className` property read immediately followed by a method call), and a D-12 negative control asserting the two safe reads survive. Proven fail-first against both a violating fixture and a gutted fixture (see Verification Evidence below) before being trusted.

## Task Commits

Each task was committed atomically:

1. **Task 1: Install WebKit for admin_eval_render, re-token the cache key, and generalize the key guard (C-6)** - `9ce7d6cb` (feat)
2. **Task 2: Fix the SVGAnimatedString crash and make it non-reintroducible** - `f2f8212e` (fix)

_Plan-metadata commit created in the state-update step below, per `commit_docs: true`._

## Files Created/Modified

- `.github/workflows/ci.yml` — `admin_eval_render`'s browser install widened to `chromium webkit` with a corrected step name; `example_playwright_smoke`'s cache key re-tokened `-v1` → `-v2` with an extended structural-guarantee comment.
- `scripts/ci/playwright-cache-key-guard.sh` — extraction regex generalized from literal `-v1` to any `-vN`; docstring, example comment, and failure message updated to match.
- `scripts/ci/playwright-cache-key-guard.test.sh` — fixtures updated to the `-v2` shape; new Test F (no `-vN` suffix at all → exit 1, fail-closed).
- `test/example/priv/playwright/lib/eval/probes.ts` — `isEmberClass` at the ember-reserved-for probe now derives from `classList`, not `className`.
- `scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs` — new prohibition guard (3 tests: parse floor, prohibition, D-12 negative control), with a local line-count-preserving comment stripper (see Decisions).

## Decisions Made

See `key-decisions` in frontmatter. In prose: D-11 steps 1-2 and C-6 were implemented exactly as `231-CONTEXT.md`/`231-PLAN.md` specified, with two verification adaptations made necessary by pre-existing code the plan's literal `<verify>` snippets did not account for (see Deviations below) — the underlying invariants both snippets were checking for are still fully proven, just via corrected, more precise assertions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in plan's literal verify script, not in code] Adapted the "no actions/cache step" assertion to the actual threat**
- **Found during:** Task 1
- **Issue:** The plan's `<verify>` python snippet asserts `not any(s.get('uses','').startswith('actions/cache') for s in j['steps'])` against `admin_eval_render`. This job has carried a legitimate, unrelated `actions/cache` step since Phase 216 ("Cache example deps (admin-eval-render lane)", caching `test/example/deps` and `test/example/_build` — Elixir dependency/build artifacts, never `~/.cache/ms-playwright`). The literal assertion would fail against this pre-existing, correct code, and deleting that cache step would be an unrelated, unauthorized structural change (it has nothing to do with the WebKit fix and touches performance infrastructure this plan has no mandate over).
- **Fix:** Ran the assertion in its intended, narrower form: no `actions/cache` step in `admin_eval_render` whose `path` references `ms-playwright` or whose `key` references `playwright-chromium-webkit`. This is the actual invariant the threat model (T-231-04-01) describes — no cross-job restore can make WebKit *browser binaries* appear without the install step running — and it holds. The pre-existing Elixir deps cache is orthogonal to this hazard and was left untouched.
- **Files modified:** None beyond Task 1's planned edits (`ci.yml`, the two guard files).
- **Verification:** Adapted python YAML assertion (below) exits `OK`; `actionlint` exits 0; `playwright-cache-key-guard.sh`/`.test.sh` both green.
- **Committed in:** `9ce7d6cb` (part of Task 1's commit)

**2. [Rule 1 - Bug in plan's literal verify script, not in code] Adapted the raw-text `className` regex and `ember-reserved-for` anchor to survive pre-existing, unrelated code**
- **Found during:** Task 2
- **Issue:** The plan's `<verify>` node snippet matches `/className\s*\.\s*[A-Za-z_]/g` and `(s.match(/className/g)||[]).length` against the RAW (comment-inclusive) file text, and locates the ember probe via `s.indexOf('ember-reserved-for')`. Two pre-existing facts break this literally: (a) `probes.ts:709-746` (Probe #8, `card-in-card`, shipped before this plan) destructures a LOCAL variable also named `className` from `element.getAttribute('class') ?? ''` — always a plain string, never `SVGAnimatedString` — and calls `.split(' ')` on it, which the naive regex flags as a false-positive "string-method call on className"; (b) `'ember-reserved-for'` appears three times before the actual probe body (a doc comment at `:19`, a `probe_class` enum entry at `:51`), so `indexOf`'s first hit is nowhere near the `isEmberClass` fix site, making the `classList` proximity check fail even though the fix is correctly present.
- **Fix:** Ran the equivalent assertions in their intended, precise form: (a) the violation/floor checks use a DOT-ANCHORED pattern (`\.className\s*\.\s*[A-Za-z_]` / `\.className\b`) which correctly distinguishes an element PROPERTY-ACCESS chain (`el.className.foo`, the actual crash shape) from a bare local variable of the same name (`className.split(...)`, syntactically unambiguous without needing type information); (b) anchored the `classList`-proximity check on the unambiguous, single-occurrence identifier `const isEmberClass` instead of the thrice-repeated string `'ember-reserved-for'`. Also rewrote my own new inline comment in `probes.ts` to avoid the literal substring `className.includes` (which would itself have tripped the naive raw-text regex), preferring `"never className -- className is an SVGAnimatedString..."` phrasing with no dot immediately after either occurrence.
- **Files modified:** None beyond Task 2's planned edits (`probes.ts`, the new `p14` file).
- **Verification:** Adapted node assertion (below) prints `OK 2`; `p14` alone: 3/3 pass; full prohibition suite: 56/56 pass; `npx playwright test --list`: 391 tests, 20 files, zero parse errors; `git diff` on `probes.ts` shows exactly one hunk, inside the ember-reserved-for probe.
- **Committed in:** `f2f8212e` (part of Task 2's commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — the plan's own literal `<verify>` scripts were too broad given pre-existing, unrelated code the planner did not have visibility into; the underlying invariants they intended to prove are fully proven by the corrected assertions below).
**Impact on plan:** No scope creep. Neither deviation touched a single line outside the two tasks' planned files. Both are documentation of *verification* corrections, not code changes beyond what the plan already specified.

## Issues Encountered

None beyond the two verification adaptations documented above as deviations.

## Verification Evidence (actually run)

### Task 1

```
$ actionlint -shellcheck= .github/workflows/ci.yml
(exit 0, no output)

$ bash scripts/ci/playwright-cache-key-guard.sh
playwright-cache-key-guard: PASS (key version 1.59.1 matches lockfile 1.59.1)

$ bash scripts/ci/playwright-cache-key-guard.test.sh
Test A: matching versions -> exit 0, PASS line names both versions
  PASS: Test A: guard exits 0 on matching fixtures
  PASS: Test A: PASS line names the matching version
Test B: mismatched versions -> exit 1, FAIL line names both versions + both paths
  PASS: Test B: guard exits 1 on mismatched versions
  PASS: Test B: FAIL line names both versions and both file paths
Test C: workflow fixture has no Playwright cache key -> exit 1 (not silently exempt)
  PASS: Test C: guard exits 1 when the workflow has no Playwright cache key
Test D: lockfile fixture has no @playwright/test entry -> exit 1
  PASS: Test D: guard exits 1 when the lockfile has no @playwright/test entry
Test E: unknown flag -> exit 2 with an unknown-arg message on stderr
  PASS: Test E: guard exits 2 with an unknown-arg message on --bogus-flag
Test F: no -vN suffix token at all -> exit 1 (generalizing -v1 to -vN did not make -vN optional)
  PASS: Test F: guard exits 1 when the workflow key has no -vN suffix token
----------------------------------------
Results: 8 passed, 0 failed
----------------------------------------
playwright-cache-key-guard.test: PASS

$ python3 -c "...(adapted YAML assertion, see Deviations #1)..." # -> OK
```

### Task 2

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs
# tests 3
# pass 3
# fail 0

$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 56
# pass 56
# fail 0

$ node -e "...(adapted raw-text assertion, see Deviations #2)..." # -> OK 2

$ cd test/example/priv/playwright && npx playwright test --list >/dev/null
(exit 0; "Total: 391 tests in 20 files")

$ git diff test/example/priv/playwright/lib/eval/probes.ts
(single hunk, inside probeEmberReservedFor only -- lines 176 and 237 unchanged)
```

### p14 fail-first proof (required by acceptance criteria)

Against a synthetic fixture reproducing the crash shape:
```
$ GSD_PROHIB_SUBJECT=/tmp/p14-fixtures/bad.ts node --test --test-reporter=tap \
    scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs
not ok 2 - no `.className` property read is followed by a string-method invocation
  error: found 1 `.className` read(s) immediately followed by a method call:
         line 4: `.className.includes`. ...
# pass 2
# fail 1
```

Against a gutted fixture (both D-12 safe reads removed):
```
$ GSD_PROHIB_SUBJECT=/tmp/p14-fixtures/gutted.ts node --test --test-reporter=tap \
    scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs
not ok 1 - parse floor: the subject contains at least two `.className` property reads
not ok 3 - D-12 negative control: the two safe truthiness reads at ~176 and ~237 survive
# pass 1
# fail 2
```

Both fixtures and the temp scratch files used to derive the line-preserving stripper design were deleted after use; nothing under `/tmp` is committed.

### D-13 boundaries confirmed intact

```
$ python3 -c "...
assert j['continue-on-error'] is True   # admin_eval_render job-level flag
assert h['continue-on-error'] is True   # admin_eval_harness step-level flag
"
D-13 boundaries intact: job-level continue-on-error=True, admin_eval_harness continue-on-error=True
```

`ci.yml:2450` and the `admin_eval_harness` step's `continue-on-error: true` were not touched by either task — confirmed by `git diff` showing no hunk in that region beyond the browser-install-step name/run-line change (Task 1) and cache-comment extension.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- D-11 steps 1-2 are complete. Step 3 ("run and READ whether b1-b6 pass") is explicitly **not** performed here — that is plan 231-05's job, and this plan makes no claim about whether the harness now passes end-to-end in CI. The two diagnosed bugs from push run `30472016250` are fixed; D-15's "a third defect class is likely" remains unproven either way and is 231-05's to observe.
- Step 4 (deleting `ci.yml:2450`'s job-level `continue-on-error`) was explicitly not performed — confirmed intact by the D-13 boundary check above. That is plan 231-06's, strictly gated on 231-05's observation.
- The re-tokened `-v2` cache key and the widened browser install mean the next `example_playwright_smoke` run on this branch will be a genuine cache MISS (first run to ever populate the `-v2` entry) — expected and does not indicate a regression.
- No blockers for 231-05. This plan touched only the files in its `files_modified` fence.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-29*

## Self-Check: PASSED

- FOUND: `scripts/ci/prohibitions/p14-no-svg-classname-string-ops.test.mjs`
- FOUND: `test/example/priv/playwright/lib/eval/probes.ts`
- FOUND: `.github/workflows/ci.yml`
- FOUND: `scripts/ci/playwright-cache-key-guard.sh`
- FOUND: `scripts/ci/playwright-cache-key-guard.test.sh`
- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-04-SUMMARY.md`
- FOUND commit: `9ce7d6cb`
- FOUND commit: `f2f8212e`
