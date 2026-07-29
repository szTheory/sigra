---
phase: 230-tier-1-critical-path-reclamation
plan: 06
subsystem: infra
tags: [ci, github-actions, playwright, caching, bash]

# Dependency graph
requires:
  - phase: 230-05
    provides: "the `changes` job / `docs_only` output and its step-level guard convention, which the new cache and install steps reuse"
provides:
  - "A SHA-pinned, browser-set-scoped Playwright browser cache (`playwright-chromium-webkit-1.59.1-v1`) on the one PR-path job that still installs browsers, with a branched install keyed on an exact cache-hit"
  - "`scripts/ci/playwright-cache-key-guard.sh` — a hermetic guard that fails closed when the cache key's version drifts from the resolved `@playwright/test` lockfile version"
  - "`scripts/ci/playwright-cache-key-guard.test.sh` — a hermetic self-test proving the guard in both directions with mktemp fixtures, no network"
  - "The guard + self-test wired into `fast_checks` as an adjacent, ungated step pair"
affects: [230-07, 230-09, 231]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cache-hit branched install (SHA-pinned actions/cache, exact-match `cache-hit` gate, dependency install runs on both branches)"
    - "Version cross-check guard reading two files off disk and comparing (no jq, no YAML parser — grep/sed line extraction)"

key-files:
  created:
    - scripts/ci/playwright-cache-key-guard.sh
    - scripts/ci/playwright-cache-key-guard.test.sh
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "Followed D-15/D-16/D-17/D-18 verbatim: cache key encodes browser set (chromium-webkit) and literal version (1.59.1), the OS dependency install always runs on both branches, and the honest expected win (~15-25s) is recorded in a code comment rather than claiming the full ~61s."
  - "Guard extraction is pure grep/sed (no jq, no YAML parser) to stay dependency-free and match the closest analog (quality-ledger-monotonic.sh)."
  - "Guard failures are explicit `fail()` calls after `|| true`-guarded command substitutions — the `|| true` only prevents `set -e` from killing the script before the explicit empty-value check runs; it never converts a missing input into a passing comparison."

requirements-completed: [FAST-06]

coverage:
  - id: D1
    description: "Playwright browser cache step inserted immediately before 'Install Playwright browsers' in example_playwright_smoke, keyed on browser-set + version, with a branched install (dependency-only on exact hit, full install otherwise) and a summary line reporting the hit value"
    requirement: FAST-06
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml && python3 verify block (Task 1) — both exit 0"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/planning/ — 50 tests, 0 failures, 12 skipped (baseline match)"
        status: pass
    human_judgment: false
  - id: D2
    description: "scripts/ci/playwright-cache-key-guard.sh cross-checks the workflow cache key version against the lockfile's resolved @playwright/test version, failing closed on every degenerate case"
    requirement: FAST-06
    verification:
      - kind: unit
        ref: "bash scripts/ci/playwright-cache-key-guard.sh — PASS (key version 1.59.1 matches lockfile 1.59.1)"
        status: pass
      - kind: unit
        ref: "bash scripts/ci/playwright-cache-key-guard.test.sh — 7 passed, 0 failed"
        status: pass
    human_judgment: false
  - id: D3
    description: "Guard + self-test wired into fast_checks as an adjacent, ungated step pair before actions/setup-node"
    requirement: FAST-06
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml && python3 verify block (Task 3) — exit 0; grep -c 'playwright-cache-key-guard' .github/workflows/ci.yml == 2"
        status: pass
    human_judgment: false
  - id: D4
    description: "AFTER-PR / AFTER-PR-WARM miss-then-hit pair on the same pull request, with install-step and actions/cache post-step durations recorded verbatim in 230-EVIDENCE.md"
    requirement: FAST-06
    verification: []
    human_judgment: true
    rationale: "This falsifiable pair requires two completed CI runs on the same pull request and is explicitly captured by plan 09 Task 1, not this plan — a brand-new cache key can only miss on the run that introduces it, so no in-plan-06 evidence can satisfy this truth. Deferred by design (plan frontmatter depends_on / plan 09 ownership)."

duration: 4min
completed: 2026-07-29
status: complete
---

# Phase 230 Plan 06: Playwright Browser Cache + Version-Drift Guard Summary

**SHA-pinned, browser-set-scoped Playwright browser cache on `example_playwright_smoke` with an exact-hit-branched install, plus a hermetic `scripts/ci/playwright-cache-key-guard.sh` that fails `fast_checks` loudly if the cache key's version ever drifts from the resolved lockfile version.**

## Performance

- **Duration:** ~4 min (commit-to-commit span; wall time including reads was longer)
- **Started:** 2026-07-29T00:29:09Z (session start, per STATE.md)
- **Completed:** 2026-07-29T00:35:30-04:00 (last commit)
- **Tasks:** 3
- **Files modified:** 3 (1 modified twice — `.github/workflows/ci.yml`; 2 created)

## Accomplishments

- Inserted `Cache Playwright browsers` (`id: playwright_browsers_cache`) immediately before `Install Playwright browsers` in `example_playwright_smoke`, reusing the already-pinned `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0` verbatim — no new third-party action introduced.
- Rewrote `Install Playwright browsers`'s body as a two-branch shell block: on an exact cache hit, run only `npx playwright install-deps chromium webkit`; otherwise run the full `npx playwright install --with-deps chromium webkit`. The OS dependency install always runs, so a hit can never produce a missing-system-dependency failure.
- Cache key `${{ runner.os }}-playwright-chromium-webkit-1.59.1-v1` deliberately encodes the browser set, so a chromium-only job (`admin_eval_render`, whose `admin-eval-mobile` project is iPhone 13/WebKit) can never silently inherit WebKit binaries from this key. Confirmed the versioned key string appears exactly once in the file.
- Both the cache step and the install step carry plan 05's `needs.changes.outputs.docs_only != 'true'` guard, and the existing `Cache hit summary` step now reports the browser cache's exact-hit value alongside the deps-cache line — no new summary step.
- Created `scripts/ci/playwright-cache-key-guard.sh`: reads the version out of the workflow's cache key line and the version out of `test/example/priv/playwright/package-lock.json`'s `@playwright/test` entry, using grep/sed only (no jq, no YAML parser), and fails closed on every degenerate case (missing file, absent key, absent lockfile entry, non-semver shape) — never routes a missing input to a passing comparison.
- Created `scripts/ci/playwright-cache-key-guard.test.sh`: 7 hermetic cases (matching pair, mismatched pair, no-key-in-workflow, no-entry-in-lockfile, unknown-flag, plus 2 content-assertion sub-cases) against `mktemp -d` fixtures, zero network access.
- Wired both as an adjacent, ungated step pair (`Playwright cache key guard` / `Playwright cache key guard self-test`) into `fast_checks`, in the zero-setup bash-only region immediately after the existing `Docs-only classifier self-test` and before `actions/setup-node`.

## Task Commits

1. **Task 1: Cache the browser binaries and branch the install on an exact cache hit** - `91de2331` (feat)
2. **Task 2: Guard the cache key's version against lockfile drift** - `69190c29` (test)
3. **Task 3: Wire the guard and its self-test into fast_checks** - `2c2e4a43` (feat)

_Task 2 is tagged `tdd="true"` in the plan but, per the plan's own `<action>`, the guard and its self-test were authored as a matched pair and verified together in one commit — there is no separate committed-red state, since the plan's `<behavior>` block is proven directly by the fixture-driven self-test rather than by an initially-failing implementation._

## Files Created/Modified

- `.github/workflows/ci.yml` - Added the `Cache Playwright browsers` step, branched the `Install Playwright browsers` body on `cache-hit`, extended the `Cache hit summary` step, and added the `Playwright cache key guard` + self-test step pair to `fast_checks`.
- `scripts/ci/playwright-cache-key-guard.sh` - New hermetic version-drift guard, no `gh`, no network.
- `scripts/ci/playwright-cache-key-guard.test.sh` - New hermetic self-test, 7 passing cases.

## Decisions Made

- Cache key literal version (`1.59.1`) over a lockfile hash, per D-18 — a hash churns on unrelated dependency changes; the literal is what the guard in Task 2 exists to protect.
- Guard implementation uses only `grep`/`sed` line extraction rather than `jq` or a YAML parser, matching the closest in-repo analog (`quality-ledger-monotonic.sh`) and keeping the guard dependency-free.
- AFTER-PR / AFTER-PR-WARM evidence capture is explicitly out of scope for this plan (see D4 above) — it requires two completed CI runs on the same pull request and is owned by plan 09 Task 1.

## Deviations from Plan

None - plan executed exactly as written. All three tasks' automated `<verify>` blocks pass: `actionlint -shellcheck=` exits 0 on every task, the Task 1 and Task 3 Python structural checks both print `OK`, `bash scripts/ci/playwright-cache-key-guard.test.sh` reports 7 passed / 0 failed, `bash scripts/ci/playwright-cache-key-guard.sh` passes against the real repo, the temporary-mismatch acceptance check (editing the key to `1.60.0` and confirming a FAIL, then restoring and confirming PASS) was performed manually and left no diff, and `mix test test/sigra/planning/` matches the pre-change baseline (50 tests, 0 failures, 12 skipped) after every task.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The cache mechanics and the drift guard are both in place and self-verified; the phase's remaining Playwright-cache obligation is purely evidentiary: plan 09 Task 1 must capture the AFTER-PR (miss) and AFTER-PR-WARM (hit) pair from two completed runs on the same pull request and record both runs' `Install Playwright browsers` duration and `actions/cache` post-step duration verbatim in `230-EVIDENCE.md`.
- Plan 230-07 continues editing `.github/workflows/ci.yml`; this plan's diff is scoped strictly to the `example_playwright_smoke` Playwright-cache block and the `fast_checks` guard-pair insertion, and does not touch the 230-03 gating, the seam-outcome aggregator, the 230-04 `admin_eval_render` gate/concurrency block, or the 230-05 `docs_only` guards elsewhere in the file.

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-29*
