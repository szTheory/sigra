---
phase: 203-consistency-propagation
plan: "02"
subsystem: admin-ui
tags: [component-promotion, branding-workbench, design-system, refactor]
dependency_graph:
  requires: []
  provides: [detail_input, color_field, preview_pair in Sigra.Admin.Components]
  affects: [lib/sigra/admin/components.ex, lib/sigra/admin/live/branding_live.ex]
tech_stack:
  added: []
  patterns: [shared-component-promotion (Pattern 3 from 200/202)]
key_files:
  created: []
  modified:
    - lib/sigra/admin/components.ex
    - lib/sigra/admin/live/branding_live.ex
decisions:
  - Inlined branding_field_id/branding_help_id as private helpers in components.ex (not kept in branding_live.ex) since detail_select still needs detail_field_id/detail_help_id there
  - Used Sigra.Branding.css_variables/1 fully-qualified in preview_pair/1 (no new alias added to components.ex module header)
  - Zero new sg-* classes introduced — D-05 reuses existing sg-branding-*/sg-tabs classes, making Task 2 a no-op gate
metrics:
  duration: "257s"
  completed: "2026-06-26"
  tasks_completed: 2
  files_modified: 2
status: complete
---

# Phase 203 Plan 02: Branding Component Promotion Summary

Promoted three private branding preview components from `BrandingLive` into `Sigra.Admin.Components` as public function components with explicit `attr` signatures and no `raw/1`, making the workbench obey UI-principle :29 (same-job → same-component, D-05).

## Tasks Completed

### Task 1: Promote color_field / preview_pair / detail_input to components.ex (D-05)

Moved all three `defp` definitions from `branding_live.ex` into `Sigra.Admin.Components` as `def` public components:

- `detail_input/1` — text input field for the branding Details panel; attrs: `name`, `label`, `value`, `required`, `help`
- `color_field/1` — colour picker control for Light/Dark palette panels; attrs: `name`, `label`, `value`
- `preview_pair/1` — login + email preview rail for a branding panel; attrs: `profile`, `theme`, `active`, `login_testid`, `email_testid`, `email_surface_testid`

Added two private helpers to `components.ex` owned by `detail_input/1`:
- `branding_field_id/1` — derives `"branding-<name>"` id
- `branding_help_id/1` — derives `"branding-<name>-help"` id

The private `detail_field_id/1` and `detail_help_id/1` remain in `branding_live.ex` because `detail_select/1` (which is NOT promoted — not one of the three D-05 targets) still depends on them.

Used `Sigra.Branding.css_variables/1` fully-qualified in `preview_pair/1` to avoid adding a module-level alias to `components.ex`.

**Acceptance criteria verified:**
- `grep -c 'defp detail_input\|defp color_field\|defp preview_pair' branding_live.ex` → 0
- `grep -c 'def detail_input\|def color_field\|def preview_pair' components.ex` → 3
- No `raw(` calls in any promoted component (T-203-02 mitigated)
- `mix compile --warnings-as-errors` exits 0 — call-sites resolve via existing `import Sigra.Admin.Components`
- `#restore-defaults-overlay` ConfirmDialog block byte-unchanged (D-06 prerequisite preserved)

**Commit:** `83f6f0b6`

### Task 2: CSS triple-copy lockstep gate (D-12) — no-op gate

Verified that Task 1 introduced zero new `sg-*` classes. All three `sigra_admin.css` copies remain byte-identical at the pre-existing shared md5 hash. `mix test test/sigra/install/golden_diff_test.exs` passes (2 tests, 0 failures). No changes to any CSS file.

**Result:** No-op gate — D-12 lockstep was not tripped. SUMMARY records the verified-green status.

## Deviations from Plan

None — plan executed exactly as written.

The `detail_field_id`/`detail_help_id` helpers in `branding_live.ex` remain (not removed) because `detail_select/1` — a private component that was intentionally NOT promoted — still uses them. This is correct behaviour per the plan's prohibition on touching non-D-05 components.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The promotion is a pure code-structure refactor (markup move, no behaviour change). Threat T-203-02 mitigated: no `raw/1` in any promoted component; HEEx auto-escaping applies; branding form values already validated via `Profile.new/1`.

## Self-Check: PASSED

- `lib/sigra/admin/components.ex` — exists and contains 3 new public components
- `lib/sigra/admin/live/branding_live.ex` — exists with 0 private branding preview components
- Commit `83f6f0b6` — verified in git log
- `mix compile --warnings-as-errors` — exits 0
- `mix test test/sigra/install/golden_diff_test.exs` — 2 tests, 0 failures
- Three sigra_admin.css copies — single shared md5 (unchanged)
