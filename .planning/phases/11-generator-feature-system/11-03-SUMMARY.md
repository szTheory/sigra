---
phase: 11
plan: 03
subsystem: generator-feature-system
tags: [generator, templates, mechanical-move, wave-2]
requires: [11-01, 11-02]
provides:
  - path: priv/templates/sigra.install/core/
    description: "New home for all 45 v1.0 templates (byte-identical to pre-move content)"
affects:
  - lib/mix/tasks/sigra.install.ex
  - test/sigra/install/templates_layout_test.exs
  - 11 pre-existing test files (template path references updated)
tech-stack:
  added: []
  patterns:
    - "All template lookups flow through a single find_template/1 helper (Pattern A)"
    - "core/ subdirectory layout ready for Wave 3 Features.Core.files/1"
key-files:
  created:
    - test/sigra/install/templates_layout_test.exs
  modified:
    - lib/mix/tasks/sigra.install.ex
    - test/sigra/install/api_token_generator_test.exs
    - test/sigra/install/generator_email_test.exs
    - test/sigra/install/generator_wiring_test.exs
    - test/sigra/install/generator_mfa_test.exs
    - test/sigra/install/generator_reset_test.exs
    - test/sigra/templates/settings_live_test.exs
    - test/sigra/templates/session_templates_test.exs
    - test/sigra/templates/installer_drift_test.exs
    - test/sigra/application_cookie_warning_test.exs
    - test/sigra/auth_fixtures_scenario_test.exs
    - test/sigra/guides_dx02_test.exs
  renamed:
    - "priv/templates/sigra.install/*.{ex,exs} -> priv/templates/sigra.install/core/*.{ex,exs} (45 files, R100)"
decisions:
  - "find_template/1 now prepends core/ in BOTH the override path and the library fallback — single choke point for template resolution, which made the installer-side change a one-line diff"
  - "Test helpers were NOT routed through find_template/1; instead each @template_dir / @templates_dir module attribute had /core appended — a local, surgical fix that keeps every test file independent"
metrics:
  tasks_completed: 2
  files_renamed: 45
  files_modified: 12
  files_created: 1
  tests_pass: "282/282 install tests; 2/2 golden-diff tests"
  commit: 69128ed
---

# Phase 11 Plan 03: Template Relocation to core/ Subdirectory — Summary

Mechanical content-preserving move of all 45 v1.0 `sigra.install` templates into a `core/` subdirectory, with every installer- and test-side path reference updated in a single atomic commit.

## What Changed

### 1. Template Relocation (45 pure renames)

Every file in `priv/templates/sigra.install/*.{ex,exs}` was `git mv`'d into `priv/templates/sigra.install/core/`. `git log --pretty=format: --name-status HEAD~1..HEAD` shows exactly 45 `R100` entries — zero content bytes changed, zero insertions, zero deletions on the rename half of the diff.

**Pre-move:** 45 files directly under `priv/templates/sigra.install/`, 0 subdirectories.
**Post-move:** 0 files directly under `priv/templates/sigra.install/`, 45 files under `priv/templates/sigra.install/core/`.

### 2. `lib/mix/tasks/sigra.install.ex` — `find_template/1` update

A Pattern-A audit confirmed that **every** template path in the installer flows through a single helper `find_template/1` (around line 321). The helper was the only site that needed touching:

```elixir
defp find_template(name) do
  # Phase 11-03 (CD-01): overrides now live under core/ subdir — BREAKING
  # CHANGE for pre-1.0 override consumers.
  user_override = Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core", name])

  if File.exists?(user_override) do
    user_override
  else
    Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.install", "core", name]))
  end
end
```

No Pattern-B (inline `Application.app_dir` at a call site) occurrences existed — every `EEx.eval_file` / `create_file` call in the installer receives its path from `find_template/1`, so no call-site edits were needed.

### 3. Layout test — `test/sigra/install/templates_layout_test.exs` (NEW)

Two assertions:
- `priv/templates/sigra.install/core/` contains exactly 45 files matching the post-move manifest.
- `priv/templates/sigra.install/` (top level) contains zero regular files directly.

This is the structural barrier that prevents a future regression from silently reverting the relocation.

### 4. Test helper updates (Rule 3 — blocking-issue auto-fix)

The mechanical move broke 11 pre-existing test files that read raw template content via their own `@template_dir` / `@templates_dir` / inline path constants (bypassing `find_template/1`). Each was updated to the new `core/` subpath — a single-line diff per file:

| File | Change |
|------|--------|
| `test/sigra/install/api_token_generator_test.exs` | `@template_dir` appended `"core"` |
| `test/sigra/install/generator_email_test.exs` | `@template_dir` appended `"core"` |
| `test/sigra/install/generator_wiring_test.exs` | `@template_dir` appended `"core"` |
| `test/sigra/install/generator_mfa_test.exs` | `@template_dir` appended `"core"` |
| `test/sigra/install/generator_reset_test.exs` | `@templates_dir` appended `/core` |
| `test/sigra/templates/settings_live_test.exs` | `@templates_dir` appended `/core` |
| `test/sigra/templates/session_templates_test.exs` | `@templates_dir` appended `/core` |
| `test/sigra/templates/installer_drift_test.exs` | 14× `template: "priv/templates/sigra.install/..."` → `"priv/templates/sigra.install/core/..."` (replace_all) |
| `test/sigra/application_cookie_warning_test.exs` | `@user_auth_path`, `@mfa_challenge_path` rewritten |
| `test/sigra/auth_fixtures_scenario_test.exs` | `@template_path` rewritten |
| `test/sigra/guides_dx02_test.exs` | `@templates_root` appended `"core"` |

These are all Rule-3 auto-fixes: each was directly caused by the current task's rename and was blocking test completion. Tracked as a deviation below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Test helpers with hardcoded template paths**
- **Found during:** Task 2 (`mix test test/sigra/install/` run)
- **Issue:** 11 test files beyond `installer_drift_test.exs` (which the plan anticipated) held their own hardcoded path constants to the pre-move location. The plan's audit guidance only called out `sigra.install.ex`'s `find_template/1`, but the test layer was not routed through that helper.
- **Fix:** Updated each path constant to point at the `core/` subdirectory. No logic changes.
- **Files modified:** All 11 listed in the table above.
- **Commit:** `69128ed` (bundled into the atomic Wave 2 commit)

## Deferred Issues

**1. Pre-existing `test/fixtures/install_golden/tree/**` auto-compilation**
- Full `mix test` (outside the `test/sigra/install/` subset) triggers Elixir/Mix 1.19 to attempt compilation of `.ex` files under `test/fixtures/install_golden/tree/` that reference the golden host-app module `SigraInstallGoldenTmpWeb`. This fails because the host-app module is not defined in the sigra library project.
- **Reproduced on base commit `d7cb729` (Wave 1 tip)** — confirmed not caused by this plan.
- **Impact on this plan:** none. The specific tests the plan gates on (`test/sigra/install/golden_diff_test.exs` and `test/sigra/install/templates_layout_test.exs`) run green when invoked directly. The install subset (282 tests) is fully green. The golden-diff harness captures rendered output via a tmp sub-project, not via compilation of the fixture tree in the host library.
- **Recommended follow-up (separate plan):** Add a compile-paths exclusion or move the fixture tree outside `test/` so Mix 1.19 auto-compilation ignores it.

## Verification Results

| Check | Result |
|-------|--------|
| `find priv/templates/sigra.install -maxdepth 1 -type f \| wc -l` | 0 (expected 0) |
| `find priv/templates/sigra.install/core -maxdepth 1 -type f \| wc -l` | 45 (expected 45) |
| `git diff HEAD~1 --stat -- priv/templates/sigra.install/` | 45 files changed, 0 insertions(+), 0 deletions(-) |
| `git log -1 --pretty=format: --name-status \| grep -c '^R100'` | 45 |
| `test/fixtures/install_golden/` touched? | No (verified untouched by this plan) |
| `mix test test/sigra/install/golden_diff_test.exs` | 2 tests, 0 failures (~40.8s runtime) |
| `mix test test/sigra/install/templates_layout_test.exs` | 2 tests, 0 failures |
| `mix test test/sigra/install/` (full install subset) | 282 tests, 0 failures (~41.3s runtime) |
| `mix compile --warnings-as-errors` | clean |

Golden-diff runtime before/after the move: ~40s in both states — unchanged, as expected (the harness exercises the rendered output, not the template source).

## Self-Check: PASSED

- File `priv/templates/sigra.install/core/user.ex` — FOUND
- File `test/sigra/install/templates_layout_test.exs` — FOUND
- Commit `69128ed` — FOUND in `git log`
- 45 R100 renames — VERIFIED
- Install test subset green — VERIFIED (282/282)
- Golden-diff green — VERIFIED (2/2)
