---
phase: "86"
plan: "03"
subsystem: email-visual-regression
tags: [ci, playwright, email, evidence, gauat, uat, visual-regression, github-actions]

# Dependency graph
requires:
  - 86-02-PLAN.md
  - test/example/priv/playwright/__snapshots__/email-visual.spec.ts (36 committed baselines)
  - lib/mix/tasks/sigra.uat.report.ex (report generator)
provides:
  - "email_visual_regression CI job in .github/workflows/ci.yml"
  - "docs/uat-ci-coverage.md SEED-1/2 residual columns pointing at email_visual_regression"
  - ".planning/uat-evidence/v1.20/INDEX.md — Phase 86 evidence index with both email-phase-04 and email-phase-08"
  - ".planning/uat-evidence/v1.20/email-phase-04/README.md — GAUAT-01 evidence pointer with YAML frontmatter"
  - ".planning/uat-evidence/v1.20/email-phase-04/manifest.json — 8-cell machine-readable Phase 04 evidence"
  - ".planning/uat-evidence/v1.20/email-phase-04/reports/contrast-summary.json"
  - ".planning/uat-evidence/v1.20/email-phase-04/reports/byte-budget.csv"
  - "8 hero PNGs at email-phase-04/snapshots/__sha-6ce3cd3.png (D-86-06 naming contract)"
  - "86-VERIFICATION.md with phase-close SHA 6ce3cd3, GAUAT-01/02 PASS attestation, snapshot count = 36"
affects:
  - GAUAT-01
  - GAUAT-02

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SIGRA_CI_RUN_URL / SIGRA_GIT_TAG / SIGRA_CI_WORKFLOW env vars passed from CI for provenance in uat.report README frontmatter"
    - "Hero PNG naming: {template}__{engine}__{theme}__sha-{short-sha}.png (D-86-06); source baselines use single-dash separators (Playwright sanitization), destinations use double-underscore"
    - "byte-budget.csv generated alongside contrast-summary.json in reports/ subdirectory"
    - "tag-conditional gh release upload v1.20.0 inside email_visual_regression CI job"

key-files:
  created:
    - .planning/uat-evidence/v1.20/INDEX.md
    - .planning/uat-evidence/v1.20/email-phase-04/README.md
    - .planning/uat-evidence/v1.20/email-phase-04/manifest.json
    - .planning/uat-evidence/v1.20/email-phase-04/reports/contrast-summary.json
    - .planning/uat-evidence/v1.20/email-phase-04/reports/byte-budget.csv
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__chromium__light__sha-6ce3cd3.png
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__chromium__dark__sha-6ce3cd3.png
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__webkit__light__sha-6ce3cd3.png
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__webkit__dark__sha-6ce3cd3.png
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__chromium__light__sha-6ce3cd3.png
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__chromium__dark__sha-6ce3cd3.png
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__webkit__light__sha-6ce3cd3.png
    - .planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__webkit__dark__sha-6ce3cd3.png
    - .planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-VERIFICATION.md
  modified:
    - .github/workflows/ci.yml
    - docs/uat-ci-coverage.md
    - lib/mix/tasks/sigra.uat.report.ex

key-decisions:
  - "uat.report updated to emit git_tag, ci_run_url, ci_workflow frontmatter fields from env vars (SIGRA_GIT_TAG, SIGRA_CI_RUN_URL, SIGRA_CI_WORKFLOW) — satisfies D-86-06 README frontmatter contract"
  - "uat.report updated to write byte-budget.csv alongside contrast-summary.json — satisfies plan files_modified list"
  - "Hero PNGs copied from single-dash source (Playwright sanitization) to double-underscore destination per D-86-06"
  - "email_visual_regression CI job uses MIX_ENV=test for both snapshot and report lanes — no Phoenix boot required"
  - "tag-conditional release upload uses exact bundle from same run (not rebuilt) per D-86-01"
  - "GA-02 v1.4 human-MUA claim demoted to historical-only in docs/uat-ci-coverage.md — not a waiver"

requirements-completed: [GAUAT-01, GAUAT-02]

# Metrics
duration: ~25min
completed: 2026-04-26
---

# Phase 86 Plan 03: CI Wiring, Phase 04 Evidence, and Merge-Gate Verification

`email_visual_regression` CI job with snapshot + report + Playwright lanes, artifact upload, and v1.20.0 release-asset promotion; GAUAT-01 Phase 04 evidence bundle (8 SHA-suffixed hero PNGs, manifest, contrast/byte-budget reports, YAML-frontmatter README); SEED-1/2 residual-policy update; 86-VERIFICATION.md merge-gate record.

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-26T18:45:00Z
- **Completed:** 2026-04-26T19:10:00Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- Added `email_visual_regression` job to `.github/workflows/ci.yml` with three lanes: L1 snapshot prerender (`mix sigra.email.snapshot --check`), L2 narrow Playwright email-visual spec (all 4 email-visual projects), L3 evidence report generation (`mix sigra.uat.report --phase=04/08`). Job uploads raw bundle artifact on every run (14d on main, 7d on PR) and promotes to `v1.20.0` release asset on `refs/tags/v1.20.0` via `gh release upload` without rebuilding.

- Updated `docs/uat-ci-coverage.md` SEED-1/2 residual columns to reference `email_visual_regression` CI job and committed evidence paths. Added `email_visual_regression` to the "Where to run this" job list. Demoted GA-02 v1.4 human-MUA claim to historical-only (not a waiver).

- Updated `lib/mix/tasks/sigra.uat.report.ex` to emit `git_tag`, `ci_run_url`, and `ci_workflow` frontmatter fields from env vars (`SIGRA_GIT_TAG`, `SIGRA_CI_RUN_URL`, `SIGRA_CI_WORKFLOW`) satisfying the D-86-06 README frontmatter contract. Added `byte-budget.csv` generation alongside `contrast-summary.json`.

- Created `.planning/uat-evidence/v1.20/INDEX.md` enumerating both `email-phase-04` and `email-phase-08` evidence directories with hero PNG naming contract explanation and residual policy reference.

- Materialized Phase 04 GAUAT-01 evidence bundle: ran `mix sigra.uat.report --phase=04` to generate README/manifest/reports from the committed Wave 2 baselines; copied 8 canonical baselines from `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/` to `.planning/uat-evidence/v1.20/email-phase-04/snapshots/` with D-86-06 double-underscore + SHA-suffix naming.

- Created `86-VERIFICATION.md` with phase-close SHA `6ce3cd3`, snapshot count = 36, contrast min ratio = 4.5, byte budget max = 100000, GAUAT-01/02 PASS attestation, and residual statement (legacy Outlook desktop Word engine OOS, copy tone subjective, deliverability not rendering).

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Wire CI lane, INDEX, VERIFICATION, residual-policy docs | afaa905 | .github/workflows/ci.yml, docs/uat-ci-coverage.md, lib/mix/tasks/sigra.uat.report.ex, .planning/uat-evidence/v1.20/INDEX.md, 86-VERIFICATION.md |
| 2 | Phase 04 evidence bundle and 8 hero PNGs | c700a97 | email-phase-04/README.md, manifest.json, reports/, 8 SHA-suffixed PNGs |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] uat.report README frontmatter missing required D-86-06 fields**
- **Found during:** Task 1, reading the D-86-06 contract in 86-RESEARCH.md vs what uat.report produced
- **Issue:** The uat.report task generated README frontmatter with `phase`, `gauat_requirement`, `hex_version`, `git_sha`, `generated_by`, `generated_at`, `disposition` — but was missing `git_tag`, `ci_run_url`, and `ci_workflow` which D-86-06 requires for provenance traceability.
- **Fix:** Updated `sigra.uat.report.ex` to read `SIGRA_GIT_TAG`, `SIGRA_CI_RUN_URL`, `SIGRA_CI_WORKFLOW` env vars and include all three in the frontmatter. CI job sets these from `github.ref_name`, `github.run_id`, and a literal string.
- **Files modified:** `lib/mix/tasks/sigra.uat.report.ex`
- **Committed in:** afaa905 (Task 1 commit)

**2. [Rule 2 - Missing Critical Functionality] byte-budget.csv not generated by uat.report task**
- **Found during:** Task 1, cross-checking plan's `files_modified` list against uat.report's actual output
- **Issue:** The plan's `files_modified` includes `email-phase-04/reports/byte-budget.csv` but the uat.report task only generated `contrast-summary.json` in reports/.
- **Fix:** Added `build_byte_budget_csv/1` function and a `File.write!` call to emit `byte-budget.csv` (CSV with template/engine/theme/byte_size/byte_budget_max/outcome columns).
- **Files modified:** `lib/mix/tasks/sigra.uat.report.ex`
- **Committed in:** afaa905 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (Rule 2 — missing critical functionality to satisfy D-86-06 evidence contract)
**Impact on plan:** Minimal. Both fixes extend the uat.report task in the correct direction. The evidence contract is now fully satisfied.

## Known Stubs

None. All hero PNGs are real screenshots from committed Wave 2 baselines. The manifest rows contain real SHA-256 hashes and byte sizes. The CI job wiring points at the actual uat.report task.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundaries introduced. The `email_visual_regression` CI job reads only committed files and environment variables. The `gh release upload` step uses the least-privilege `github.token` (scoped to `contents: write` at job level only).

## Self-Check

Files verified as existing:
- `.github/workflows/ci.yml` — FOUND, contains `email_visual_regression`, `refs/tags/v1.20.0`, `gh release upload`
- `docs/uat-ci-coverage.md` — FOUND, contains `email_visual_regression`, `legacy Outlook desktop`, `GAUAT-01`
- `.planning/uat-evidence/v1.20/INDEX.md` — FOUND
- `.planning/uat-evidence/v1.20/email-phase-04/README.md` — FOUND (disposition: pass, git_sha: 6ce3cd3)
- `.planning/uat-evidence/v1.20/email-phase-04/manifest.json` — FOUND (8 rows, all outcome: pass)
- `.planning/uat-evidence/v1.20/email-phase-04/reports/contrast-summary.json` — FOUND
- `.planning/uat-evidence/v1.20/email-phase-04/reports/byte-budget.csv` — FOUND
- 8 hero PNGs in `email-phase-04/snapshots/` — FOUND, count = 8, all match `__sha-6ce3cd3.png` naming
- `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-VERIFICATION.md` — FOUND

Commits verified:
- `afaa905` — Task 1 (CI lane + docs + INDEX + VERIFICATION)
- `c700a97` — Task 2 (Phase 04 evidence bundle + hero PNGs)

## Self-Check: PASSED
