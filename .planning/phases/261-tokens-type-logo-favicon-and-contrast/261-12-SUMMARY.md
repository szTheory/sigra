---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 12
subsystem: ui
tags: [brand, example-app, demo-branding, asset-cleanup, reference-grep, playwright-spec]

# Dependency graph
requires:
  - phase: 259-brand-book-vendoring
    provides: brand/ pinned by brand.sha256 (never edited here)
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: plan 02 added sigra-favicon.ico to the same images directory, so verification names files individually
provides:
  - the Rail Accent demo preset (light and dark) pointing at the demo's own /images/tasklane-mark.svg, preset id, name and every other field unchanged
  - the demo-showcase spec's preset logo src expectation following the repoint
  - the example's images directory free of the stray Phoenix-glyph logo.svg and both rail-accent mark files
  - a recorded reference grep (before and after) proving nothing referenced was deleted
affects: [261-08]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the realized text diff, deletions included)
actuals:
  tokens: 1709
  tasks: 2
  commits: 2
commits: 2
plan_head_before: e06ca009420a08ef8ba8e17985c5ae142be3324f
plan_head_after: 8bd35fa4ae9322576d767c54583f019732acba08

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Delete an asset only after a recorded reference grep, and re-run the same grep after the deletion"

key-files:
  created: []
  modified:
    - test/example/lib/example/demo/branding.ex
    - test/example/priv/playwright/tests/demo-showcase.spec.ts
  deleted:
    - test/example/priv/static/images/logo.svg
    - test/example/priv/static/images/rail-accent-mark.svg
    - test/example/priv/static/images/rail-accent-mark-dark.svg

key-decisions:
  - "The compile gate for this plan runs in the dev env (matches CI ci.yml:757, whose example compile step has no MIX_ENV), because the test-env build carries a pre-existing, unrelated /dev/mailbox verified-route warning that fails any warnings-as-errors compile of that env. Decided by the plan owner after this executor stopped and reported the conflict; the plan's verify and verification lines were amended accordingly."

patterns-established:
  - "When a plan's literal compile command fails on a warning from an untouched file, prove the warning set is exactly the known one (forced full compile), run the CI-equivalent gate, and stop for a decision rather than editing the verify"

requirements-completed: [BTOK-04]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "The Rail Accent preset's light and dark logo_url point at /images/tasklane-mark.svg; the diff of branding.ex is exactly two lines added and two removed, so the preset id rail-accent, its name and every other field are unchanged"
    requirement: BTOK-04
    verification:
      - kind: other
        ref: "git show --numstat --format= 8b349452f -- test/example/lib/example/demo/branding.ex prints 2 2; grep -c 'logo_url: \"/images/tasklane-mark.svg\"' branding.ex prints 4"
        status: pass
      - kind: other
        ref: "cd test/example && MIX_ENV=dev mix compile --warnings-as-errors exits 0 (recompiled 42 files including branding.ex)"
        status: pass
    human_judgment: false
  - id: D2
    description: "logo.svg, rail-accent-mark.svg and rail-accent-mark-dark.svg are deleted, tasklane-mark.svg and every sigra-* image stay, and the reference grep is empty after the deletion"
    requirement: BTOK-04
    verification:
      - kind: other
        ref: "git ls-files on the three paths prints nothing; git grep -n -e rail-accent-mark -e images/logo.svg over test/example/lib, priv/playwright, test, assets prints nothing; the plan's amended automated verify exits 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "The demo-showcase spec expects the Rail Accent preset logo src to be /images/tasklane-mark.svg; that expectation is edited here but only exercised against a booted app by plan 261-08 Task 3 (SIGRA_PNG_COMPARE_SKIP=1)"
    requirement: BTOK-04
    verification:
      - kind: e2e
        ref: "demo-showcase.spec.ts brand-lab Rail Accent logo src assertion, run owned by plan 261-08 Task 3"
        status: unknown
    human_judgment: true
    rationale: "Coverage not determined at authoring time: the plan assigns the booted-app run to plan 261-08, so this plan alone cannot prove the assertion passes; the verifier should classify it from the 261-08 result"

# Metrics
duration: 3min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 12: Remove Stray Rail Files and Repoint the Rail Accent Preset Summary

**The demo's Rail Accent preset now points at the demo's own Tasklane mark and the three stray files (the Phoenix-glyph logo.svg and both rail-accent marks) are deleted, with a before-and-after reference grep proving nothing referenced was removed and no PNG baseline touched.**

## Performance

- **Duration:** about 3 min of agent time (196 s between the start timestamp and the closing timestamp, spanning one stop-and-decide handoff)
- **Started:** 2026-11-16T00:09:21Z
- **Completed:** 2026-11-16T00:12:37Z
- **Tasks:** 2
- **Files modified:** 5 (2 edited, 3 deleted)

## Accomplishments

- **Reference proof before any deletion.** The grep over the whole tree (excluding `.planning`, `.gsd`) showed the two rail-accent files were referenced only by `Example.Demo.Branding` (two lines) and the demo-showcase spec (one line). `logo.svg` had no reference anywhere in the example. Dispositions are in the table below.
- **Rail Accent preset repointed.** The light and dark profiles now use `/images/tasklane-mark.svg`. The commit's `branding.ex` numstat is `2 2`, so the preset id `rail-accent`, the preset name and every colour, label and email field are untouched. The spec expectation at the preset assertion follows (`1 1`).
- **Three stray files removed.** `git rm` of exactly `logo.svg`, `rail-accent-mark.svg` and `rail-accent-mark-dark.svg`. The directory now holds `sigra-favicon.ico`, `sigra-logo-primary.svg`, `sigra-logo-primary-dark.svg` and `tasklane-mark.svg`.
- **No baseline touched.** No file under `demo-showcase.spec.ts-snapshots` changed, and no filename anywhere under `test/example/priv/playwright` contains `rail-accent` (`find -iname '*rail-accent*'` is empty).

## Task Commits

1. **Task 1: Prove every reference, repoint the Rail Accent preset and its spec expectation** - `8b349452f` (refactor)
2. **Task 2: Remove the three stray files and prove the rest of the directory is intact** - `8bd35fa4a` (chore)

**Plan metadata:** the docs commit that follows this file (SUMMARY, then STATE, ROADMAP and REQUIREMENTS).

## Files Created/Modified

- `test/example/lib/example/demo/branding.ex` - Rail Accent light and dark `logo_url` repointed to `/images/tasklane-mark.svg`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts` - preset logo `src` expectation now `/images/tasklane-mark.svg`
- `test/example/priv/static/images/logo.svg`, `rail-accent-mark.svg`, `rail-accent-mark-dark.svg` - deleted (24 lines in total)

## Reference grep record

Run before Task 1, over the tracked tree excluding `.planning` and `.gsd` (the `docs`, `guides`, `README.md`, `priv`, `lib` and `mix.exs` paths were also grepped on their own and are clean).

| Hit | Disposition |
|-----|-------------|
| `branding.ex:73` and `:88` (`rail-accent-mark.svg`, `rail-accent-mark-dark.svg`) | referenced, repointed in Task 1 |
| `demo-showcase.spec.ts:570` (`rail-accent-mark-dark.svg`) | referenced, expectation repointed in Task 1 |
| the three files' own `aria-labelledby` / `id` strings inside `rail-accent-mark*.svg` | self-references, deleted with the files |
| `test/fixtures/install_golden/tree/.../layouts.ex:43` (`~p"/images/logo.svg"`) | the generated phx.new golden fixture for a different app; generated output, out of scope |
| `test/fixtures/brand/before/tier1-library-admin/branding_live--explicit_profile.html:143,381` and `test/support/brand/catalog.ex:771` (`https://assets.demo.tasklane.test/logo.svg`) | a `.test` URL fixture, not the example's file |
| `test/sigra/brand/source_pin_test.exs:171,209,216,297` (`planted/logo.svg`, `someone/brand/logo.svg`) | synthetic strings in the privacy-scan tests |

Re-run after Task 2 (`rail-accent-mark` over the whole tree excluding `.planning` and `.gsd`; `rail-accent-mark` plus `images/logo.svg` over `test/example/lib`, `priv/playwright`, `test` and `assets`): both empty. The only remaining `images/logo.svg` text is the golden fixture's own layout, listed above.

## Decisions Made

See `key-decisions`. The one decision is where the compile gate runs; it was made by the plan owner, not by this executor.

## Deviations from Plan

### Auto-fixed Issues

None. No bug in this plan's changes was found.

### Verification-environment conflict (stopped, decided, resumed)

**1. [Rule 3 adjacent - verification gate] Plan's compile verify cannot pass in the test env**
- **Found during:** Task 1 (and again after Task 2's deletions)
- **Issue:** both tasks' `<verify>` and the plan-level `<verification>` named `cd test/example && MIX_ENV=test mix compile --warnings-as-errors`. That command exits non-zero in this repo independent of this plan: `settings_live.ex:133` uses `~p"/dev/mailbox"`, and the router only defines that route under `Application.compile_env(:example, :dev_routes)`, which only `config/dev.exs` sets. Any test-env compile of that file warns. It reproduced on three runs including a `--force` full compile, which printed exactly one warning, this one. `settings_live.ex`, `router.ex` and `config/` are unchanged since the plan's base commit. Phase 260-08 and 261-02 already recorded it as pre-existing and unrelated.
- **CI is not affected:** `ci.yml:757` (the example compile step) sets no `MIX_ENV`, so it runs in dev, where the route exists.
- **Resolution:** this executor stopped and reported the conflict rather than editing the verify. The plan owner decided to amend the plan's compile verify to `cd test/example && MIX_ENV=dev mix compile --warnings-as-errors` (the plan file edit is the owner's and is committed by them, not in this plan's commits). The amended command exits 0 after Task 1's change (42 files recompiled, `branding.ex` among them) and after Task 2's deletions, and its literal automated line for Task 2 exits 0 end to end.
- **Honest note on ordering:** Task 1 was committed before the stop, after the failure was established as pre-existing and the dev-env gate was green. Task 2's deletions were left staged during the stop and committed only after the amendment.
- **Files modified:** none by this executor for this item (the warning's file was left alone: out of scope, logged in `deferred-items.md`).

---

**Total deviations:** 0 auto-fixed bugs; 1 verification-gate amendment decided by the plan owner.
**Impact on plan:** none on the deliverable. Every acceptance criterion is met as written; only the env named in the compile command changed.

## Authentication Gates

None.

## Issues Encountered

- The pre-existing test-env warning described above (`no route path for ExampleWeb.Router matches "/dev/mailbox"`, `settings_live.ex:133`). Not caused by this plan; logged in `deferred-items.md`.
- `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started. They were never staged and are restored byte-for-byte after the state updates (sha256 pinned before and after).

## Verification

- Task 1 acceptance: `git grep -n rail-accent-mark -- test/example/lib test/example/priv/playwright test/example/test` prints nothing (PASS); `git show --numstat --format= 8b349452f -- test/example/lib/example/demo/branding.ex` prints `2 2` (PASS); the reference grep and the baseline `find` are recorded above (PASS).
- Task 2 acceptance: `git ls-files` on the three paths prints nothing (PASS); `git ls-files test/example/priv/static/images/tasklane-mark.svg` prints that path (PASS); `git status --short -- test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots` prints nothing (PASS).
- Amended compile gate: `cd test/example && MIX_ENV=dev mix compile --warnings-as-errors` exits 0, run after each task.
- Plan-level: `git diff --name-only e06ca0094..HEAD -- priv lib .github` prints nothing (PASS, example-only change). Added-line privacy grep (home paths, personal addresses) over the two commits finds nothing.
- The demo-showcase behavior run (spec executed against a booted app, `SIGRA_PNG_COMPARE_SKIP=1`) is owned by plan 261-08 Task 3 and was not run here. No Playwright spec was run, and no update flag was used anywhere.
- No ExUnit tests apply to this plan (asset cleanup and one demo module edit); no test count to report.

## Known Stubs

None.

## Threat Flags

None. This plan only removes files and repoints one demo URL to an existing in-repo asset; no endpoint, auth path, file-access pattern or schema was introduced. T-261-08 (deleting a referenced asset) is mitigated as planned: reference grep recorded before and re-run after, compile gate green, and the spec expectation was updated together with the preset.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for plan 261-08, whose Task 3 runs the whole demo-showcase spec against a booted app and is the first execution of the repointed Rail Accent `src` assertion.

## Self-Check: PASSED

- FOUND commits `8b349452f` and `8bd35fa4a` (ancestors of HEAD).
- FOUND `test/example/priv/static/images/tasklane-mark.svg`, `branding.ex`, `demo-showcase.spec.ts`; the three stray files are gone from disk and the index.
- All acceptance criteria re-run and passing; `git rev-list --count` from the ledger base gives 2 commits.
