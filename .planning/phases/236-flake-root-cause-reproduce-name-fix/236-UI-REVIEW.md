# Phase 236 — UI Review

**Audited:** 2026-09-19  
**Baseline:** abstract 6-pillar standards (no UI-SPEC.md); admin UI principles/design contract  
**Screenshots:** not captured (no dev server at ports 3000, 5173, or 8080; code-only audit)

## Pillar Scores

| Pillar | Score | Key Finding |
|---|---:|---|
| 1. Copywriting | 3/4 | Audit-specific labels, empty state, and recovery copy are clear; one generic “Clear” action lacks context. |
| 2. Visuals | 3/4 | Strong page/filter/results hierarchy and responsive table/card split; no visual capture and no explicit loading presentation. |
| 3. Color | 3/4 | Uses the `sg-*` token/component system consistently, but code-only review cannot verify contrast or 60/30/10 balance. |
| 4. Typography | 3/4 | Type hierarchy is coherent and deliberately restrained; the view itself only explicitly applies `sg-text-sm`, leaving key metadata hierarchy to implicit defaults. |
| 5. Spacing | 3/4 | Consistent stack/cluster/form-grid scale with no arbitrary values; dense six-field filter panel needs breakpoint verification. |
| 6. Experience Design | 2/4 | Filter race fix and empty/error paths are present, but there is no loading/pending state while `handle_params/3` queries. |

**Overall: 17/24**

## Top 3 Priority Fixes

1. **Add a LiveView loading/pending treatment for audit queries** — a slow filter/preset navigation can leave the old results visually unchanged and gives no task feedback; render `aria-busy` plus a skeleton or disabled submit state around the results/filter action.
2. **Make the “Clear” action self-describing** — “Clear filters” is clearer than the generic `Clear` at `audit_index_live.ex:143`, especially for screen-reader link lists and narrow layouts.
3. **Verify responsive filter density and table/card visual contrast at 375/768/1440px** — the six-field grid and two result renderings are structurally responsive, but this audit had no running server/screenshots; capture deterministic baselines and adjust wrapping/overflow if needed.

## Detailed Findings

### Pillar 1: Copywriting (3/4)

**WARNING:** The page has domain-specific copy (`Audit evidence`, `Failures`, `Impersonation`, `Apply filters`, `Export CSV`) at `lib/sigra/admin/live/audit_index_live.ex:72-145`. Its empty states explain both no-data and filtered-no-match cases and provide a concrete recovery action at `:198-206`. The load error is actionable at `:35-44`.

**WARNING:** The primary reset control is only `Clear` (`:143`), unlike the more explicit `Clear all filters` controls at `:164` and `:202`. Rename it to `Clear filters` for consistent intent.

### Pillar 2: Visuals (3/4)

**WARNING:** The composition has a clear hierarchy: scope ribbon → page header → presets → filter panel → active filters → results/empty state → pagination (`:68-214`), and it explicitly switches table/card result components with `sg-show-desktop`/`sg-show-mobile` (`:168-196`). However, no screenshot was possible, so actual fold behavior, wrapping, and table disclosure presentation remain unverified.

**WARNING:** `audit_table_row/1` exposes event codes behind native `<details>` (`lib/sigra/admin/components.ex:763-775`), which is a good density choice, but there is no loading visual during a patch/query transition.

### Pillar 3: Color (3/4)

**WARNING:** The view uses semantic system classes (`sg-btn--primary/secondary/ghost`, `sg-filter-panel`, `sg-status-pill`, `sg-muted`, `data-tone`) rather than hardcoded colors (`audit_index_live.ex:79-145`, `components.ex:704-715`). That supports the brand cascade and tone semantics. Contrast and 60/30/10 distribution cannot be proven without rendered screenshots/theme inspection; retain this as a verification gap rather than a pass.

### Pillar 4: Typography (3/4)

**WARNING:** The page title/kicker and field labels establish a sensible hierarchy (`audit_index_live.ex:71-74`, `:100-137`), and result metadata uses `sg-text-sm`/`sg-text-xs` (`components.ex:709-712`, `:760`, `:770`). The audit view itself has no explicit heading size/weight classes, so visual strength depends on global CSS; capture/inspect rendered light/dark modes before treating this as excellent.

### Pillar 5: Spacing (3/4)

**WARNING:** Layout uses the established `sg-stack--6`, `--3`, `--2`, `sg-cluster`, and `sg-form-grid--cols` scale (`audit_index_live.ex:68`, `:97`, `:154`, `:158`), with no arbitrary pixel/rem spacing in the audited LiveView. The six-field grid is dense and must be checked at the documented mobile/tablet breakpoints; no screenshot was available to confirm control wrapping or tap-target separation.

### Pillar 6: Experience Design (2/4)

**WARNING:** The phase correctly moves filter submission into `handle_event("apply_filters", ...)` and `push_patch/2` (`audit_index_live.ex:55-63`), whitelisting params and preserving URL ownership. Presets, clear/remove-chip links, pagination, empty states, and a query error flash are covered (`:76-91`, `:152-166`, `:198-213`, `:35-44`).

**WARNING:** There is no `loading`, `isLoading`, `pending`, skeleton, `phx-disable-with`, or `aria-busy` path in `AuditIndexLive`; `mount/3` starts with empty rows (`:14-21`) and `handle_params/3` performs the query synchronously (`:25-45`). On a slow initial load or patch, users receive no explicit progress feedback. This is the main experience gap and limits the score to 2/4.

## Files Audited

- `lib/sigra/admin/live/audit_index_live.ex`
- `lib/sigra/admin/components.ex` (shared audit row/table/empty/pagination components)
- `priv/templates/sigra.install/admin/sigra_admin.css` (responsive `sg-*` component rules)
- `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-PLAN.md` through `236-04-PLAN.md`
- `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-SUMMARY.md` through `236-04-SUMMARY.md`
- `guides/reference/admin-ui-principles.md`
- `guides/reference/admin-design-contract.md`
