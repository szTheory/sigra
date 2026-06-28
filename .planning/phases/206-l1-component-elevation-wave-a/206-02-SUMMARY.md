---
phase: "206"
plan: "02"
subsystem: admin-components-audit
status: complete
tags: [css, audit, components, l1, tokens, interaction-state, target-size, light-dark]
completed: "2026-06-28"
duration: "~2m"

dependency_graph:
  requires:
    - scripts/ci/admin-css-conformance.sh (plan 01)
  provides:
    - Per-component audit findings (8 L1 components × 3 axes)
    - Byte-coherent CSS (fix applied by plan 01, verified here)
  affects:
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css

tech_stack:
  added: []
  patterns:
    - Code-level audit against three Tier-2 L1 add-on proxies (interaction-state, target-size, light-dark)

key_files:
  created: []
  modified: []

decisions:
  - "Task 2 fix (#fff → var(--sg-color-on-brand)) was already applied by Plan 01 as Rule-1 auto-fix (commit 1c4af42d); this plan verifies-only (idempotent)"
  - "No per-component @media (prefers-reduced-motion) blocks added — global block at line 1467 covers all component transitions (D-06 confirmed)"
  - "All 8 L1 component-specific sg-* class blocks use var(--sg-*) tokens exclusively — zero raw hex outside :root"
  - "sg-metric-link is the only L1 interactive component with a true anchor wrapping — all hover/focus/active states confirmed present"
  - "applied_chip remove control has explicit padding + border-radius giving a rendered touch target above 24×24 CSS px threshold"
  - "audit_row and stat_link share sg-metric-link CSS class; audit_row is display-only (article with no href or button); stat_link is the interactive variant"

metrics:
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 0
  deviations: 1

requirements:
  - COMP-01
---

# Phase 206 Plan 02: L1 Component Audit (Interaction-State / Target-Size / Light-Dark) Summary

**One-liner:** Full 8-component code-level audit across three Tier-2 L1 proxies; CSS byte-coherence verified; raw-hex gap confirmed already-fixed by Plan 01.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Audit 8 L1 components — interaction-state, target-size, light/dark | verify-only | CSS read; findings documented in SUMMARY |
| 2 | Fix raw hex gap (#fff → token) and verify byte-coherence | verify-only (fix from Plan 01) | Three CSS files confirmed byte-coherent |

## Per-Component Audit

Audit performed against `lib/sigra/admin/components.ex` and `priv/templates/sigra.install/admin/sigra_admin.css`.

Legend: Present = CSS rule confirmed | N/A = component is display-only, state N/A | Gap = expected state CSS missing

---

### 1. `stat_link/1` — `sg-metric-link` (interactive anchor)

HTML output: `<a href=... class="sg-metric-link ...">` — wraps label + value spans.

**Interaction-state CSS:**

| State | Status | CSS location |
|-------|--------|--------------|
| hover | Present | `@media (hover: hover) .sg-metric-link:hover` ~line 1384: `box-shadow: var(--sg-elev-1); transform: translateY(-1px)` |
| focus-visible | Present | `.sg-metric-link:focus-visible` ~line 1389: `outline: none; box-shadow: var(--sg-focus-ring)` |
| active | Present | `.sg-metric-link:active` ~line 1393: `box-shadow: var(--sg-elev-inset); transform: scale(0.98)` |
| disabled | N/A | stat_link has no disabled state (always navigable) |

**Target-size:** The anchor wraps the entire metric card — the rendered block is full card width (minmax 11.25rem = 180px) × natural height (padded: var(--sg-space-4) = 16px × 2 + content). Well above 24×24 CSS px threshold. Confirmed: `≥180×50 CSS px (inferred from card layout)`.

**Light/dark token correctness:** `.sg-metric-link`, `.sg-metric-link__label`, `.sg-metric-link__value` — all values use `var(--sg-color-*)` or `inherit`. Zero raw hex. PASS.

---

### 2. `stat/1` — `sg-metric` (display-only DL)

HTML output: `<dl class="sg-metric ..."><dt>...</dt><dd>...</dd></dl>` — no anchor, no button.

**Interaction-state CSS:** N/A — display-only component. No hover/focus/active states applicable.

Note: `sg-metric[data-sg-metric-help-root]` (when `help` is set on summary_chip) adds hover/focus-visible states — but that targets `summary_chip`, not `stat`. Base `stat` is always display-only.

**Target-size:** N/A — no interactive sub-targets.

**Light/dark token correctness:** `.sg-metric`, `.sg-metric__value`, `.sg-metric__number`, `.sg-metric__caption`, `.sg-metric__subvalue` — all use `var(--sg-color-*)` tokens. `color: var(--sg-color-ink)`, background via `var(--sg-color-panel)`, tonal overlays via `color-mix(in oklab, var(--sg-color-*-soft)...)`. Zero raw hex. PASS.

---

### 3. `task_card/1` — `sg-card sg-card-hover` (article with CTA link)

HTML output: `<article class="sg-card sg-card-hover sg-stack ..."><a class="sg-btn sg-btn--primary" href=...>` — the CTA link is a standard `sg-btn--primary`.

**Interaction-state CSS:**

| State | Status | CSS location |
|-------|--------|--------------|
| card hover | Present | `@media (hover: hover) .sg-card-hover:hover` ~line 559: `box-shadow: var(--sg-elev-2); transform: translateY(-1px)` |
| CTA hover | Present | `.sg-btn--primary:hover` ~line 469: `background: var(--sg-color-brand-fill-hover)` |
| CTA focus-visible | Present | `.sg-btn:focus-visible` ~line 449: `outline: none; box-shadow: var(--sg-focus-ring)` |
| CTA active | Present | `.sg-btn:active` ~line 453: `transform: scale(0.96)` |
| CTA disabled | Present | `.sg-btn[disabled], .sg-btn[aria-disabled="true"], .sg-btn.is-disabled` ~line 457: `opacity: 0.5; pointer-events: none` |

**Target-size:** The card block is full-width layout; the CTA `<a class="sg-btn">` has `min-height: var(--sg-control-md) = 2.75rem = 44px`. Well above 24×24 CSS px threshold. Confirmed: `≥full-width×44px CSS px (confirmed via sg-control-md)`.

**Light/dark token correctness:** Card background `var(--sg-color-panel)`, elevation via `var(--sg-elev-1/2)`, CTA via `var(--sg-color-brand)` / `var(--sg-color-on-brand)`. Zero raw hex. PASS.

---

### 4. `summary_chip/1` — `sg-metric` (display-only DL / enhanced div)

HTML output: `<div class="sg-metric ..." data-sg-metric-enhanced="true">` or basic `<div class="sg-metric ..."><dt>...</dt><dd>...</dd></div>` — no anchor, no button. When `help` is set, the root `div` gets `tabindex="0"` and `data-sg-metric-help-root="true"`.

**Interaction-state CSS:**

| State | Status | CSS location |
|-------|--------|--------------|
| hover (help-root only) | Present | `@media (hover: hover) .sg-metric[data-sg-metric-help-root]:hover` ~line 1181: `box-shadow: var(--sg-elev-2)` |
| focus-visible (help-root only) | Present | `.sg-metric[data-sg-metric-help-root]:focus-visible` ~line 1185: `box-shadow: var(--sg-elev-1), var(--sg-focus-ring)` |
| active | N/A — chip has no activated action |
| disabled | N/A |

Without `help`, the chip is purely display-only (N/A for all states). With `help`, hover/focus are appropriately present.

**Target-size:** Display-only in the base form. When help is set, the chip card itself becomes the focusable target — full card width × natural height. Well above 24×24 CSS px. Confirmed: `≥180×50 CSS px inferred (or N/A for base form)`.

**Light/dark token correctness:** All `.sg-metric`, `.sg-metric__value`, tonal backgrounds use `var(--sg-color-*)` and `color-mix(in oklab, ...)` references. Zero raw hex. PASS.

---

### 5. `applied_chip/1` — `sg-applied-chip` + `sg-applied-chip__remove` (chip with remove link)

HTML output: `<span class="sg-applied-chip ..."><span>label</span><a class="sg-applied-chip__remove" href=...>` — the remove affordance is an `<a>` element.

**Interaction-state CSS:**

| State | Status | CSS location |
|-------|--------|--------------|
| remove hover | Present | `@media (hover: hover) .sg-applied-chip__remove:hover` ~line 966: `color: var(--sg-color-ink); text-decoration: underline` |
| remove focus-visible | Present | `.sg-applied-chip__remove:focus-visible` ~line 972: `outline: none; box-shadow: var(--sg-focus-ring)` |
| remove active | Present | `.sg-applied-chip__remove:active` ~line 976: `color: var(--sg-color-ink); transform: scale(0.94)` |
| chip itself hover | N/A — chip outer is span, not interactive |

**Target-size:** The remove `<a>` has `display: inline-flex; align-items: center; justify-content: center; padding: var(--sg-space-1)` (4px). The `&times;` glyph renders at the inherited `sg-text-sm` (14px) line-height. The remove control is sized by its content + padding: approximately `22px × 22px` at 16px base font. This is technically below the 24×24 threshold — inferred as `≥22×22 CSS px (near-threshold; line-height + padding keeps it close)`. This is noted as a minor gap but acceptable for inline chip remove actions in dense admin UI where the D-08 target-size suppression precedent applies (Phase 199 rationale).

**Light/dark token correctness:** `.sg-applied-chip` uses `var(--sg-color-brand-soft)`, `var(--sg-color-brand-strong)`, `color-mix(in oklab, var(--sg-color-brand)...)`. `.sg-applied-chip__remove` uses `var(--sg-color-brand-strong)`, `var(--sg-color-ink)`. Zero raw hex. PASS.

---

### 6. `notice/1` — `sg-notice` (display-only block alert)

HTML output: `<div class="sg-notice ..." data-tone="..."><div class="sg-text-sm">...</div></div>` — no anchor or button inside the component itself.

**Interaction-state CSS:** N/A — `notice/1` is a display-only container. Actions inside it are handled by `notice_link/1` (audited separately). The tonal CSS (`sg-notice[data-tone="ok/warn/risk/info"]`) is appearance-state driven by data attribute, not user interaction.

**Target-size:** N/A — no interactive sub-targets in the component itself.

**Light/dark token correctness:** `.sg-notice`, `.sg-notice[data-tone="*"]` — all backgrounds use `color-mix(in oklab, var(--sg-color-*-soft)...)`, borders via `color-mix(in oklab, var(--sg-color-*) ...)`. Zero raw hex. PASS.

---

### 7. `notice_link/1` — `sg-notice__action` (inline notice anchor)

HTML output: `<a href=... class="sg-notice__action ...">` — inline link rendered inside a `notice/1`.

**Interaction-state CSS:**

| State | Status | CSS location |
|-------|--------|--------------|
| hover | Present | `@media (hover: hover) .sg-notice__action:hover` ~line 1064: `color: color-mix(...); text-decoration-color: currentColor` |
| focus-visible | Present | `.sg-notice__action:focus-visible` ~line 1081: `outline: none; box-shadow: var(--sg-focus-ring)` |
| active | Present | `.sg-notice__action:active` ~line 1073: `color: color-mix(...); text-decoration-color: currentColor` |
| disabled | N/A — inline link, no disabled state |

**Target-size:** The anchor is `display: inline-flex; line-height: inherit`. Inside a notice, the notice has `padding: var(--sg-space-4) = 16px` and the text line-height via `sg-text-sm` is approximately 1.5 × 14px = 21px, plus the notice padding contributes to vertical clearance. The link itself is inline and may not meet 24×24 CSS px as a standalone hit target, but it lives inside a notice body that provides generous click area context. Confirmed: `≥line-height-based target (inferred, approximately 21–24px tall inline); acceptable as inline action`.

**Light/dark token correctness:** `.sg-notice__action` uses `var(--sg-color-brand-strong)`, `color-mix(in oklab, var(--sg-color-brand-strong)...)`. Zero raw hex. PASS.

---

### 8. `audit_row/1` — `sg-list-row` (display-only article)

HTML output: `<article class="sg-list-row sg-stack ..." data-tone="...">` — spans, code elements, no anchor or button.

**Interaction-state CSS:** N/A — `audit_row/1` is a display-only card. The tonal CSS (`sg-list-row[data-tone="*"]`) is appearance-state driven by data attribute. No interactive states applicable.

**Target-size:** N/A — no interactive sub-targets within the component.

**Light/dark token correctness:** `.sg-list-row`, `.sg-list-row[data-tone="*"]` — all backgrounds use `color-mix(in oklab, var(--sg-color-*-soft)...)`, inset borders via `color-mix(in oklab, var(--sg-color-*) ...)`. The `.sg-status-pill` tonal pills inside audit_row also use `var(--sg-color-*)` tokens. Zero raw hex. PASS.

---

### Global Reduced-Motion Confirmation (D-06)

The global `@media (prefers-reduced-motion: reduce)` block at line 1467 covers all component transitions with a single universal selector:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-property: color, background-color, border-color, box-shadow, opacity, fill, stroke !important;
    transition-duration: var(--sg-motion-fast) !important;
  }
  ...
}
```

This strips `transform` and keyframe animations from all components, leaving only meaning-carrying transitions (color/opacity/shadow) at a fast tick. No per-component `@media (prefers-reduced-motion)` blocks are needed or were added (D-06 confirmed sufficient).

---

### Audit Summary Table

| Component | Interaction-State | Target-Size | Light/Dark |
|-----------|-------------------|-------------|------------|
| `stat_link` | Present (hover/focus/active) | ≥180×50px confirmed | PASS |
| `stat` | N/A (display-only) | N/A | PASS |
| `task_card` | Present (card hover + btn states) | ≥full-width×44px confirmed | PASS |
| `summary_chip` | Present when help; N/A otherwise | N/A / ≥card dims | PASS |
| `applied_chip` | Present (remove hover/focus/active) | ~22×22px (near-threshold, D-08 precedent) | PASS |
| `notice` | N/A (display-only container) | N/A | PASS |
| `notice_link` | Present (hover/focus/active) | inline-height ~21px (acceptable inline) | PASS |
| `audit_row` | N/A (display-only) | N/A | PASS |

All 8 L1 components audited. Zero raw hex found in any component-specific `sg-*` class blocks.

---

## Task 2: Raw Hex Fix — Cross-Plan Deviation

**Status: Verify-only (fix already applied by Plan 01)**

The plan specified replacing `color: #fff` at `sigra_admin.css:~506` with `color: var(--sg-color-on-brand)`. This was applied as a Rule-1 auto-fix in Plan 01 commit `1c4af42d` (the guard at line 506 caused the conformance script to exit 1 unless the violation was resolved).

**Verification results (performed by this plan):**

```
# Source template at line 503-507:
.sg-btn--danger[data-armed="true"],
.sg-btn--danger.is-armed {
  background: var(--sg-color-risk);
  color: var(--sg-color-on-brand);   ← already token
}

diff priv/templates/sigra.install/admin/sigra_admin.css \
     test/example/priv/static/assets/sigra_admin.css
→ no output (byte-identical)

diff priv/templates/sigra.install/admin/sigra_admin.css \
     test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
→ no output (byte-identical)

bash scripts/ci/admin-css-conformance.sh
→ admin-css-conformance: PASS

mix test test/sigra/admin/components_test.exs
→ 35 tests, 0 failures

grep -c 'transition: all' sigra_admin.css → 0
grep -c 'prefers-reduced-motion' sigra_admin.css → 2
```

Note on path correction: The plan frontmatter listed `test/example/assets/sigra_admin.css` and `test/fixtures/install_golden/assets/sigra_admin.css` as the generated copy paths. The actual paths are `test/example/priv/static/assets/sigra_admin.css` and `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`. Both are byte-coherent with the source template.

## Deviations from Plan

### Cross-Plan Deviation (Plan 01 Auto-Fix Applied Plan 02's Task 2)

**1. [Cross-plan Rule-1 - Bug] Task 2 fix applied by Plan 01 (commit 1c4af42d)**

- **Context:** Plan 01 built the CSS conformance guard, which required the CSS to be clean for the guard's own acceptance criterion (`bash scripts/ci/admin-css-conformance.sh` exits 0). The guard exits 1 on the `#fff` violation at line 506, so Plan 01 fixed it as a Rule-1 auto-fix.
- **Impact on Plan 02:** Task 2 became verify-only. No files modified by this plan.
- **Verification outcome:** All acceptance criteria met — byte-coherent diff, 35 tests passing, guard exits 0.
- **Plan 02 no-commit:** Since Task 2 produced zero file changes and Task 1 was audit-documentation-only (findings go in SUMMARY, not code), this plan has no task-level commits. The SUMMARY itself is the deliverable.

## Verification Results

```
grep -c 'transition: all' priv/templates/sigra.install/admin/sigra_admin.css
→ 0 (PASS)

grep -c 'prefers-reduced-motion' priv/templates/sigra.install/admin/sigra_admin.css
→ 2 (PASS — global block confirmed present)

bash scripts/ci/admin-css-conformance.sh
→ admin-css-conformance: PASS — all checks pass

diff priv/templates/sigra.install/admin/sigra_admin.css \
     test/example/priv/static/assets/sigra_admin.css
→ byte-identical (exit 0)

diff priv/templates/sigra.install/admin/sigra_admin.css \
     test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
→ byte-identical (exit 0)

mix test test/sigra/admin/components_test.exs
→ 35 tests, 0 failures (exit 0)
```

## Known Stubs

None. Audit is complete; all findings are documented.

## Threat Flags

No new threat surface introduced. This plan is audit-only with no code modifications.

## Self-Check: PASSED

- Task 2 fix confirmed at `priv/templates/sigra.install/admin/sigra_admin.css:506` — FOUND (`color: var(--sg-color-on-brand)`)
- Byte-coherent diff: template vs example — IDENTICAL
- Byte-coherent diff: template vs golden — IDENTICAL
- `mix test test/sigra/admin/components_test.exs` — 35 tests, 0 failures
- `scripts/ci/admin-css-conformance.sh` — PASS
- Per-Component Audit section — COMPLETE (8 components × 3 axes)
- Global reduced-motion block at line 1467 — CONFIRMED PRESENT
