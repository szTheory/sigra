---
phase: 254-speed-up-the-measured-slow-jobs
plan: "05"
subsystem: ci
tags: [github-actions, mix, postgres, ci-speed, caches]
requires:
  - phase: 254-01
    provides: Source-bound CI preparation profile and measurement contracts
provides:
  - Removes only the library job's duplicate Hex/Rebar setup
  - Selects combined example Mix preparation after real cold/warm database parity and measured benefit
  - Records source hashes, setup command timings, seed/migration snapshots, and failure behavior
affects: [ci-workflows, example-playwright-boot, ci-preparation-profiling]
actuals:
  tokens: 13242
  tasks: 2
  commits: 7
commits: 7
plan_head_before: c240fb0efd1566b1d2e231fd663e1a0a9ddaef45
plan_head_after: 8ef86ff17a318d8c7ea22d3a6755edc8fa8d6ddd
tech-stack:
  added: []
  patterns: [Pinned action default proof, cold/warm real database comparison, source mutation contract tests]
key-files:
  created: [.planning/phases/254-speed-up-the-measured-slow-jobs/254-05-SUMMARY.md]
  modified: [.github/workflows/ci.yml, .github/actions/example-playwright-boot/action.yml, scripts/ci/ci-prep-semantics.test.mjs, scripts/ci/ci-prep-profile.mjs, scripts/ci/ci-prep-profile.test.mjs, .planning/phases/254-speed-up-the-measured-slow-jobs/254-SETUP-CHECK.json]
key-decisions:
  - "Retain the library job's outer mix deps.get because mix ci runs format before its locked dependency task, and a cold checkout failed before formatting without the fetch."
  - "Use the combined Mix preparation only after matching cold/warm migration and seed snapshots, a passing injected-failure check, and faster cold and warm preparation measurements."
patterns-established:
  - "Verify setup-beam defaults at the exact pinned source before removing any repeated setup command."
  - "Compare full preparation command time and real database state; command count alone is not evidence of a speedup."
requirements-completed: []
coverage:
  - id: D1
    description: "The library job uses pinned setup-beam Hex/Rebar defaults without repeating their installation, while retaining the cold dependency fetch and the sole mix ci owner."
    verification:
      - kind: unit
        ref: "scripts/ci/ci-prep-semantics.test.mjs#library job relies on pinned setup-beam defaults and its sole mix ci dependency owner"
        status: pass
      - kind: integration
        ref: "Isolated MIX_ENV=test CI=true mix ci after the workflow's dependency fetch; 65 tests passed and the alias exited 0."
        status: pass
    human_judgment: false
  - id: D2
    description: "The example action uses combined Mix preparation after local cold/warm database parity and timing evidence."
    verification:
      - kind: integration
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-SETUP-CHECK.json#forms"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-prep-semantics.test.mjs#preparation comparison preserves cache partitions, dependencies, readiness, and separate server boot"
        status: pass
    human_judgment: false
duration: 25min
completed: 2026-10-23
status: complete
---

# Phase 254 Plan 05: Measured Mix Preparation Summary

**Removed repeated Hex/Rebar setup and adopted combined example Mix preparation after identical cold/warm database state and faster measured runs.**

## Performance

- **Duration:** About 25 minutes
- **Started:** 2026-10-23T17:51:00Z
- **Completed:** 2026-10-23T18:16:00Z
- **Tasks:** 2/2
- **Files changed:** 7 (6 modified and this summary created)

## Accomplishments

- Removed only the library job's explicit Hex and Rebar install step. The pinned `erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124` source sets both `install-hex` and `install-rebar` defaults to `true`; the workflow does not override them or change `MIX_HOME`/`HEX_HOME` afterward.
- Retained the outer library `mix deps.get`. A clean isolated checkout showed that `mix ci` starts with `format --check-formatted`, whose formatter imports dependencies before the alias reaches `deps.get --check-locked`. Without the outer fetch, a cold checkout failed before it could run the alias's dependency task.
- Selected `mix do deps.get + compile --warnings-as-errors + ecto.create + ecto.migrate + run priv/repo/seeds.exs` for the example action after local cold and warm runs matched all 18 migration versions and seeded counts, both full preparation measurements improved, and the injected failure stopped before seeding or the sentinel task.
- Kept setup caches and fallback keys, runtime/Elixir/OTP/environment/port partitions, `npm ci`, both Playwright browser install paths, Phase 253 code-reloader configuration, readiness polling, route warming, and separate Phoenix server startup.

## Measured Preparation

Final action source comparison in `254-SETUP-CHECK.json`:

| Form | Cold | Warm | Combined total |
|---|---:|---:|---:|
| Separate commands | 24.537 s | 4.619 s | 29.156 s |
| Combined `mix do` | 22.922 s | 2.360 s | 25.282 s |

All four database snapshots matched: 18 migration versions, 47 users in the demo domain, 3 organizations, 8 memberships, 2 MFA credentials, 2 passkeys, 3 sessions, 1 identity, 43 audit events, and 1 enterprise connection. The controlled task failed with exit 1 after migrations; the expected error marker appeared, the user count remained 0, and neither seed nor the later sentinel ran. All three experiment databases were dropped.

These are local source-bound cold/warm measurements, not a hosted CI result. CISPEED-01's hosted median comparison and CISPEED-02's total runner time and 95th-percentile wait comparison remain pending; no hosted run was started.

## Task Commits

1. **Task 1 RED:** `7b1eb5d90` — failing library setup contract test and initial RED evidence.
2. **Task 1 implementation:** `75d697b21` — remove duplicate library Hex/Rebar setup while retaining the cold fetch.
3. `6dc04dafc` — preserve the first measured cold-run diagnostic before correcting the database snapshot query.
4. `3f850188d` — preserve the candidate command-construction failure before fixing it.
5. `39a831f17` — preserve the successful cold/warm preparation comparison.
6. **Task 2 RED:** `727d87c03` — comparison mode, preparation contract, and cache/readiness tests.
7. **Task 2 implementation:** `8ef86ff17` — combined example preparation, profiler support, and final setup evidence.

## Verification

- `node --test scripts/ci/ci-prep-semantics.test.mjs scripts/ci/ci-prep-profile.test.mjs scripts/ci/ci-measure-workflow.test.mjs` — 19 passed.
- `bash scripts/ci/playwright-cache-key-guard.test.sh` — 8 passed.
- `node scripts/ci/ci-prep-profile.mjs --root . --scope admin_behavior --mode compare-preparation --output .planning/phases/254-speed-up-the-measured-slow-jobs/254-SETUP-CHECK.json` — profiled; selected combined form.
- Isolated library `mix ci` — exit 0 after the required outer dependency fetch; 65 tests passed. The initial sandbox run stopped at a pre-existing test that invokes macOS `sandbox-exec`; rerunning the same command with the approved escalated execution context passed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Retained the library dependency fetch required by cold formatting**
- **Found during:** Task 1
- **Issue:** Removing the outer fetch left cold checkouts without dependencies when `format --check-formatted` ran first in `mix ci`.
- **Fix:** Removed only the confirmed duplicate Hex/Rebar step and retained the outer `mix deps.get` before `mix ci`.
- **Files modified:** `.github/workflows/ci.yml`, `scripts/ci/ci-prep-semantics.test.mjs`
- **Verification:** A clean isolated checkout failed without the fetch; the complete isolated library path passed with the fetch. Regression tests require the fetch to precede `mix ci`.
- **Committed in:** `75d697b21`

**2. [Rule 1 - Bug] Corrected the combined Mix command and PostgreSQL snapshot query**
- **Found during:** Task 2
- **Issue:** The first profiler draft emitted `mix do mix deps.get...`; the first snapshot query also assumed tables were in `public` instead of the app's `auth` schema.
- **Fix:** Built the combined task list without repeated `mix` prefixes and queried the real `auth.*` tables. The failed run records were preserved before rerunning.
- **Files modified:** `scripts/ci/ci-prep-profile.mjs`, `.planning/phases/254-speed-up-the-measured-slow-jobs/254-SETUP-CHECK.json`
- **Verification:** Final cold/warm comparison and failure experiment passed with exact database parity; the profiler and workflow tests passed.
- **Committed in:** `8ef86ff17`

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs). The separate library dependency fetch remains because real cold-path behavior disproved the plan's assumption that the alias's later locked check replaced it.

## Next Phase Readiness

Plan 254-05 implementation is complete. Phase 254 still has Plans 06-08 and its final hosted comparison/verification; CISPEED-01 and CISPEED-02 are not marked complete. No manual setup is required for this plan.

## Self-Check: PASSED

The summary file and final setup record exist. All seven plan commits are in the current branch history. The worktree root remained `/Users/jon/projects/sigra`.

---
*Phase: 254-speed-up-the-measured-slow-jobs*
*Completed: 2026-10-23*
