---
created: 2026-06-04T00:00:00.000Z
status: pending
title: lighten --sg-color-brand-strong in dark mode (global brand-on-brand-soft WCAG gap)
area: test/example/priv/static/assets/css
files:
  - test/example/priv/static/assets/css/app.css
source: 158-05 execution (axe caught it on the active filter chip after the chip-state fix)
---

## Finding (Phase 158, surfaced by the automated axe gate)

The dark-mode token block (`app.css` ~L160-184) lightens the tone tokens
(`--sg-color-ok/warn/risk/info`) "so pills/rows keep WCAG AA contrast (dark-mode
tinted backgrounds need light tone text)" — but it never lightens
`--sg-color-brand-strong` (stays `#9a3412`). Every `background: var(--sg-color-brand-soft);
color: var(--sg-color-brand-strong);` combination therefore fails AA in dark mode
(~1.88:1 on the dark brand-soft tint `#412718`).

This was **dormant** until Phase 158: the AuditIndexLive quick-filter chip had an
atom-key bug (`@current_params[:action_prefix]` against a string-keyed map) that
meant `.sg-filter-chip:has(input:checked)` never rendered, so the active-chip
foreground never appeared and axe never saw it. Fixing the chip-state bug
(158-05) made the active chip render → axe flagged the latent contrast violation.

A **narrow, scoped fix** was applied in 158-05 for the immediate failure:
a dark-mode override `.sg-filter-chip:has(input:checked) { color: #fdba74; }`.
That clears the active filter chip only.

## Risk

The same `brand-soft` + `brand-strong` combination is used by other components
in `app.css` (e.g. ~L360-361, L409-410, L450, L517-518, L612-613, L1360-1361 —
badges, tabs, nav, breadcrumb hover, etc.). Any of those that render on a dark
checkpoint (or in a real dark-mode session) has the same latent AA failure. The
narrow chip fix does not address them.

## How to apply

Make a deliberate design-system decision (the global fix has wide visual blast
radius and will re-record several dark baselines):

- **Preferred (root cause):** add `--sg-color-brand-strong` to the dark `:root`
  override with a lightened brand orange (e.g. ~`#fdba74`/`#fb923c`, verified
  ≥4.5:1 on `--sg-color-brand-soft`), mirroring the existing tone-token
  lightening. Then drop the narrow per-chip override (no longer needed) and
  re-record the affected dark admin-checkpoint baselines, declaring each slug in
  `test/example/priv/playwright/snapshot-allowlist` and approving via
  `scripts/ci/snapshot-recapture-gate.sh`.
- **Or** keep token unchanged and add scoped dark overrides per affected
  component (more rules, but smaller blast radius per change).

Either way, re-run the axe gate (it now runs on every admin checkpoint) to
confirm 0 violations across chromium/mobile/dark.
