---
phase: "86"
plan: "02"
subsystem: email-visual-regression
tags: [playwright, visual-regression, email, mix-tasks, snapshot-testing]
dependency_graph:
  requires: [86-01-PLAN.md]
  provides: [email-snapshot-harness, playwright-email-lane, uat-report-task]
  affects: [test/example/priv/playwright, lib/mix/tasks]
tech_stack:
  added:
    - premailex ~> 0.3 (CSS inlining in example app)
  patterns:
    - Playwright per-project expect.toHaveScreenshot.pathTemplate for baseline routing
    - System.cmd subprocess pattern for root Mix task accessing sub-project modules
    - D-86-04 frozen fixtures (time, ip, geo_city, device, user.email)
key_files:
  created:
    - lib/mix/tasks/sigra.email.snapshot.ex
    - lib/mix/tasks/sigra.uat.report.ex
    - test/example/priv/playwright/tests/email-visual.spec.ts
    - test/example/priv/email_snapshots/ (9 HTML files)
    - test/example/priv/playwright/__snapshots__/email-visual.spec.ts/ (36 PNG baselines)
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - test/example/mix.exs
decisions:
  - Use per-project expect.toHaveScreenshot.pathTemplate (not snapshotPathTemplate) to route email-visual baselines to canonical directory without breaking admin checkpoint lane
  - System.cmd subprocess with MIX_ENV=test renders emails from root task into example app, using sentinel delimiters to extract HTML from mixed stdout
  - Single-dash separators in PNG filenames because Playwright sanitizes __ to - in {arg} token; uat.report updated to match
metrics:
  duration: "~180 minutes (across two sessions)"
  completed_at: "2026-04-26T18:39:36Z"
  tasks_completed: 2
  files_changed: 51
---

# Phase 86 Plan 02: Email Snapshot Harness and Visual Regression Lane Summary

Deterministic email prerender pipeline (`mix sigra.email.snapshot`) and UAT evidence generator (`mix sigra.uat.report`) with committed Playwright baselines — full 9-template × 2-engine × 2-theme = 36-cell matrix verified green.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Mix tasks: email snapshot + UAT report | 9518c80 | lib/mix/tasks/sigra.email.snapshot.ex, lib/mix/tasks/sigra.uat.report.ex, test/example/mix.exs |
| 2 | Playwright email visual lane + 36 baselines | b52ab55 | playwright.config.ts, tests/email-visual.spec.ts, 36 PNG baselines, 9 HTML snapshots |

## Verification Results

All acceptance criteria met at completion:

- `MIX_ENV=test mix sigra.email.snapshot --check` → "OK: all 9 templates rendered successfully"
- `MIX_ENV=test mix sigra.uat.report --phase=04 --check` → "OK: all 8 Phase 04 baselines present"
- `MIX_ENV=test mix sigra.uat.report --phase=08 --check` → "OK: all 28 Phase 08 baselines present"
- `npx playwright test tests/email-visual.spec.ts` (all 4 projects) → "36 passed (10.6s)"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Playwright `{arg}` token sanitizes `__` to `-` in snapshot filenames**

- **Found during:** Task 2, after generating baselines and running `uat.report --check`
- **Issue:** The plan specified `{template}__{engine}__{theme}.png` baseline names. Playwright 1.59 sanitizes double underscores (`__`) to single dashes (`-`) when using `{arg}` in a `pathTemplate`. Actual committed filenames use single dashes: `lockout-notification-chromium-light.png`. The `uat.report.ex` task was looking for double-underscore names and reported 0/36 present.
- **Fix:** Updated `sigra.uat.report.ex` `build_manifest/1` and `run_check!/2` to construct filenames with single dashes (`#{template}-#{engine}-#{theme}.png`). Added inline comment explaining the Playwright sanitization behavior.
- **Files modified:** `lib/mix/tasks/sigra.uat.report.ex`
- **Commit:** b52ab55

**2. [Rule 3 - Blocking] Wrong HTML output directory in email-visual.spec.ts path resolution**

- **Found during:** Task 2 initial Playwright run
- **Issue:** First attempt used `resolve(__dirname, '..', 'email_snapshots')` — `__dirname` is `tests/` so path resolved to `playwright/email_snapshots/` instead of `priv/email_snapshots/`.
- **Fix:** Corrected to `resolve(__dirname, '..', '..', 'email_snapshots')`.
- **Files modified:** `test/example/priv/playwright/tests/email-visual.spec.ts`
- **Commit:** b52ab55

**3. [Rule 3 - Blocking] Per-project snapshot routing used wrong Playwright config key**

- **Found during:** Task 2, first `--update-snapshots` run
- **Issue:** First attempt used `project.snapshotPathTemplate` which only affects `toMatchSnapshot()`, not `toHaveScreenshot()`. Global `expect.toHaveScreenshot.pathTemplate` overrode it, sending all baselines to `tests/email-visual.spec.ts-snapshots/` instead of `__snapshots__/email-visual.spec.ts/`.
- **Fix:** Changed all 4 email-visual projects to use `project.expect.toHaveScreenshot.pathTemplate` (the correct per-project override for screenshot baselines).
- **Files modified:** `test/example/priv/playwright/playwright.config.ts`
- **Commit:** b52ab55

## Architectural Notes

### Subprocess pattern for cross-project email rendering

Root-level Mix tasks cannot directly `require` or call modules from sub-projects. The `sigra.email.snapshot` task renders email HTML by spawning a subprocess:

```
System.cmd("mix", ["run", "--no-start", "--eval", script], cd: "test/example", env: [{"MIX_ENV", "test"}])
```

The rendered HTML is extracted from mixed stdout using sentinel delimiters (`<<<EMAIL_HTML_START>>>` / `<<<EMAIL_HTML_END>>>`). This avoids leaking Phoenix application startup side effects into the parent process and keeps the task dependency-free from the example app's compile path.

### Playwright per-project `expect.toHaveScreenshot.pathTemplate`

The 4 email-visual projects override the global snapshot path at the project level using `project.expect.toHaveScreenshot.pathTemplate`. This routes baselines to `__snapshots__/email-visual.spec.ts/{arg}{ext}` without a `{-projectName}` suffix, since engine and theme are already encoded in the `arg` (snapshot name). The existing admin checkpoint projects are unaffected.

### Filename separator: single dash

Playwright's `{arg}` token strips or replaces special characters for filesystem safety. Double underscores `__` become single dashes `-`. The spec file still uses `__` as separator in the `toHaveScreenshot()` call (for readability in the source), but the committed PNG names use single dashes. The `uat.report` task matches against the actual on-disk names.

## Known Stubs

None. All 36 baselines are committed real screenshots. The `uat.report` manifest generator reads actual file hashes and byte sizes.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundaries introduced. Mix tasks read local files and write to `.planning/` or `priv/`. The `--check` mode is read-only.

## Self-Check: PASSED

- Task 1 commit `9518c80` exists: confirmed
- Task 2 commit `b52ab55` exists: confirmed
- `lib/mix/tasks/sigra.email.snapshot.ex` exists: confirmed
- `lib/mix/tasks/sigra.uat.report.ex` exists: confirmed
- `test/example/priv/playwright/tests/email-visual.spec.ts` exists: confirmed
- 36 PNG baselines under `__snapshots__/email-visual.spec.ts/`: confirmed (36 files)
- 9 HTML snapshots under `priv/email_snapshots/`: confirmed (9 files)
