---
phase: 202-audit-surfaces-elevation
plan: "01"
subsystem: admin-ui
tags: [components, audit, dry, wave-1]
status: complete

dependency_graph:
  requires: []
  provides:
    - Sigra.Admin.Components.audit_table_row/1
    - Sigra.Admin.Components.audit_pagination_nav/1
    - Sigra.Admin.Components.audit_empty_state/1
  affects:
    - lib/sigra/admin/components.ex

tech_stack:
  added: []
  patterns:
    - Public function components in components.ex (same shape as audit_row/1)
    - Native CSS-only <details> disclosure for in-row progressive disclosure
    - pre-built href pass-in pattern for per-page href divergence (D-09)

key_files:
  created: []
  modified:
    - lib/sigra/admin/components.ex

decisions:
  - Used format_timestamp/1 (with-seconds) co-located in components.ex — matches AuditIndexLive format string exactly; both audit pages will emit byte-identical Occurred timestamps via the shared component
  - Placed both code.sg-code nodes inside the Event <td> <details> (not a sibling <tr>) to keep td:nth-child positional contract frozen at 4 columns and preserve D-06 equivalence
  - Used "Event codes" as the <summary> affordance label — glossary-clean per UI-SPEC copywriting contract
  - multi_page?/1 moved to components.ex as private helper — owned by audit_pagination_nav/1; LiveViews will call the shared component rather than their own copy
  - audit_empty_state/1 parametrized with title attr + inner_block slot — lowest-value DRY but enables copy divergence without markup duplication

metrics:
  duration: "136s (~2m)"
  completed: 2026-06-26
  tasks_completed: 3
  files_modified: 1
---

# Phase 202 Plan 01: Shared Audit Components (Wave 1) Summary

**One-liner:** Extracted three new public function components (`audit_table_row/1`, `audit_pagination_nav/1`, `audit_empty_state/1`) into `components.ex` with inline `<details>` code disclosure and honest-cursor nav guard.

## What Was Built

Three public function components added to `lib/sigra/admin/components.ex`, co-located with the existing `audit_row/1`:

### `audit_table_row/1`
Desktop `<tr>` with exactly 4 `<td>` columns in frozen positional order:
1. **Occurred** — `format_timestamp/1` (with-seconds) span only
2. **Event** — `action_label` status pill + optional `action_badge` pill, then a native `<details>` whose `<summary>` reads "Event codes" and whose body holds both `<code class="sg-code">{@row.id}</code>` and `<code class="sg-code">{@row.action}</code>` as real text nodes
3. **Actor** — `actor_summary` span (first, td:nth-child(3) selector contract preserved) + conditional detail lines
4. **Outcome** — risk pill or muted span, `sg-show-desktop`

Both `code.sg-code` nodes are inside the Event `<td>` `<details>` — they remain real DOM text nodes, so `firstTexts(desktop, 'code.sg-code', 2)` still returns exactly 2 (D-06 content-equivalence contract preserved).

### `audit_pagination_nav/1`
Renders `<nav :if={@meta && multi_page?(@meta)} class="sg-cluster sg-cluster--between">` with Previous/Next links. Accepts `meta`, `prev_href`, `next_href` — caller pre-builds hrefs (D-09 per-page divergence stays in LiveViews). Private `multi_page?/1` guard co-located (matches byte-identical guards from both LiveViews).

### `audit_empty_state/1`
Wraps `empty_state/1` with `title` attr + `inner_block` slot. Per-page copy divergence (index filter-aware vs per-user "no scoped events") is parametrized, not duplicated.

### Co-located private helpers (new in components.ex)
- `multi_page?/1` — honest cursor guard (no `total_pages` key; previous/next cursor presence is the signal)
- `format_timestamp/1` — `%Y-%m-%d %H:%M:%S` (with-seconds, same as `AuditIndexLive:315-318`)

### Single source of truth preserved
- `defp audit_tone/1` remains exactly ONE private definition (3 pattern-match clauses) in `components.ex` — no second copy added; `audit_table_row/1` calls it same-module.

## Verification

- `mix compile --warnings-as-errors` — clean (no warnings, no errors)
- Three new components are public (`def`, not `defp`) — callable as `<.audit_table_row>`, `<.audit_pagination_nav>`, `<.audit_empty_state>` from any LiveView that imports `Sigra.Admin.Components`
- `sg-chevron` grep → 0 results in `components.ex`
- Exactly one `defp audit_tone` definition (3 clauses) in `components.ex`
- Zero new CSS classes — browser-default `<details>` rendering; D-13 triple-copy gate is a no-op

## Wave-1 Canonical Decision (binding on Wave 2)

The shared component is `audit_table_row/1` — the `<tr>` body ONLY. The `<thead>` is NOT shared; it STAYS per-page in each LiveView. Wave-2 plans 202-02 and 202-03 both consume `audit_table_row/1` and keep their own `<thead>`.

## Deviations from Plan

None — plan executed exactly as written.

All three tasks (Task 1: `audit_table_row/1`, Task 2: `audit_pagination_nav/1`, Task 3: `audit_empty_state/1`) were implemented in a single commit since they are all in the same file and share private helpers. The compile verification (plan's `<verify>` step) passed clean for all three in one pass.

## Known Stubs

None. All components render real data from the `@row` / `@meta` assigns. No hardcoded empty values, placeholders, or TODO markers in the new code.

## Threat Flags

No new threat surface. The new components:
- Are gated by the existing admin authorization plug (all admin routes) — no new auth boundary
- Render all values through HEEx auto-escaping as text nodes — no `raw/1`, no attribute injection
- The `<details>` disclosure is CSS-only; no JS, no new network requests
- The two raw codes (event id + action code) were already visible in the primary columns; this plan only defers them behind a disclosure on the same admin-gated page (T-202-01: accepted)

## Self-Check: PASSED

- [x] `lib/sigra/admin/components.ex` exists and contains all three new public functions
- [x] Commit `3fe5e584` exists in git log
- [x] `mix compile --warnings-as-errors` clean
- [x] `defp audit_tone` has exactly one definition (3 clauses) in components.ex
- [x] Zero `sg-chevron` in changed file
