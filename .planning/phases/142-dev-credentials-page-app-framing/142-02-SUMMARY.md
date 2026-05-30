---
phase: 142-dev-credentials-page-app-framing
plan: "02"
subsystem: example-app-branding
tags:
  - vaultr-branding
  - example-app
  - layout
  - phoenix
dependency_graph:
  requires:
    - 142-01 (compile_env dev route gate; Sign In link path confirmed from router)
  provides:
    - Vaultr page title and brand span visible in browser tab and header
    - Contextual "Sign In →" nav link for unauthenticated visitors
  affects:
    - test/example/lib/example_web/components/layouts/root.html.heex
    - test/example/lib/example_web/components/layouts.ex
tech_stack:
  added: []
  patterns:
    - HEEx attribute swap on <.live_title> component
    - data-testid attribute on brand span for testability
    - :if={is_nil(@current_scope)} guard on nav li for conditional rendering
key_files:
  created: []
  modified:
    - test/example/lib/example_web/components/layouts/root.html.heex
    - test/example/lib/example_web/components/layouts.ex
decisions:
  - Used is_nil(@current_scope) guard on the Sign In <li> (primary form per D-10); current_scope has default: nil in Layouts.app so no nil-dereference risk
  - Removed all three Phoenix fixture nav links (Website/GitHub/Get Started) and replaced with single contextual Sign In link
  - org_switcher and impersonation_banner rows left byte-for-byte unchanged (D-09 compliance)
metrics:
  duration: "3 minutes"
  completed: "2026-05-30"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
---

# Phase 142 Plan 02: Vaultr Branding — Layout Title and Brand Span Summary

**One-liner:** Rebranded example app root layout with Vaultr page title default/suffix and replaced the Phoenix version span + fixture nav links with a Vaultr brand span and contextual Sign In link.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Rebrand root.html.heex — Vaultr page title (D-08) | d650804 | test/example/lib/example_web/components/layouts/root.html.heex |
| 2 | Rebrand layouts.ex — Vaultr brand span + contextual nav (D-08, D-09, D-10) | cf96964 | test/example/lib/example_web/components/layouts.ex |

## What Was Built

### Task 1: root.html.heex (line 7)
Changed `default="Example" suffix=" · Phoenix Framework"` to `default="Vaultr" suffix=" · Vaultr"` on the `<.live_title>` component. Browser tab now reads "Vaultr" for pages without a `page_title` assign and "Page Title · Vaultr" when a `page_title` is set.

### Task 2: layouts.ex (lines 48-52, 60-72)
Two targeted edits in the `app/1` function body:
1. **Brand span:** `<span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>` replaced with `<span class="text-sm font-semibold" data-testid="app-name">Vaultr</span>` — removes the Phoenix version string, adds the Vaultr brand name and a testid anchor for DEMO-02 contract tests.
2. **Nav `<ul>`:** Three Phoenix fixture links (Website/GitHub/Get Started to phoenixframework.org and hexdocs.pm) replaced with a single contextual `<li :if={is_nil(@current_scope)}>` containing a "Sign In →" primary button pointing to `~p"/users/log_in"`.

Untouched per D-09: `<.org_switcher :if={@current_scope && @current_scope.active_organization}>` block and `<.impersonation_banner :if={@current_scope && @current_scope.impersonating_from}>` line.

## Verification Results

All 8 plan verification checks passed:
1. `mix compile` exits 0, no errors or warnings
2. `grep 'default="Vaultr"' root.html.heex` — match
3. `grep 'suffix=" · Vaultr"' root.html.heex` — match
4. `grep 'data-testid="app-name"' layouts.ex` — match
5. `grep "Application.spec(:phoenix, :vsn)" layouts.ex` — no match (GOOD)
6. `grep "phoenixframework.org" layouts.ex` — no match (GOOD)
7. `grep "org_switcher" layouts.ex` — match (untouched, D-09 compliant)
8. `grep "impersonation_banner" layouts.ex` — match (untouched, D-09 compliant)

## Deviations from Plan

None — plan executed exactly as written. Both edits matched the verbatim before/after content from 142-PATTERNS.md. The `is_nil(@current_scope)` guard form (primary form from D-10) was used without fallback.

## Known Stubs

None — both files contain no placeholder text, hardcoded empty values, or TODO markers.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. The "Sign In →" nav link points to the existing `~p"/users/log_in"` route (T-142-02 accepted per plan threat model).

## Self-Check: PASSED

- [x] `test/example/lib/example_web/components/layouts/root.html.heex` exists and contains `default="Vaultr"`
- [x] `test/example/lib/example_web/components/layouts.ex` exists and contains `data-testid="app-name"`
- [x] Commit d650804 exists (Task 1)
- [x] Commit cf96964 exists (Task 2)
