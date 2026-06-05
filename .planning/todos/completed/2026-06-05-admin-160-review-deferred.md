---
created: 2026-06-05T00:00:00.000Z
status: completed
completed_at: 2026-06-05
completion_evidence: Accepted Phase 160 stat-link semantics, added needs_review/1 spec, shared overview runtime config, and left CSS-only optional spot checks to completed milestone evidence.
title: Phase 160 code-review deferred findings (WR-02, WR-04, IN-01, IN-02)
area: lib/sigra/admin, test/example/priv/static/assets/css
files:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin.ex
  - test/example/priv/static/assets/css/app.css
source: 160-REVIEW.md (WR-02, WR-04, IN-01, IN-02)
---

## Context

Phase 160 code review found 1 blocker + 4 warnings + 2 info. The verified blocker
(CR-01: needs_review filter dead code) and verified security finding (WR-01: or_where
cross-org leak) were fixed in commit `8231f840`, with regression coverage (WR-03). These
remaining items were deferred — none block the phase goal or the v1.34 milestone close.

## Deferred findings

### WR-02 — "Locked" stat tile mislabels its destination
`index_live.ex:112-116` / `organization_live.ex:111-115`: the "Locked" stat tile shows
`@summary_counts.locked` (locked-only count) but links to `?needs_review=true`
(locked∪deleted). Count and landing view no longer match. **Note:** the href change was
explicitly directed by 160-01-PLAN.md task 2 (all three locked CTAs → needs_review). This
is a UX/semantics judgment call, not a clear bug — decide whether the stat tile should
revert to `?locked=true` (label-accurate) while the explicit "Review risky accounts" CTA
keeps `?needs_review=true`.

### WR-04 — Stale empty CSS rule in dark media query
`app.css:893-896`: removing the scoped chip override left an empty
`.sg-filter-chip:has(input:checked) {}` inside `@media (prefers-color-scheme: dark)`.
Cosmetic dead code. The 160-01 plan said to keep the wrapper block with an updated comment,
so this was intentional-ish; trim if desired. **Touching app.css will require re-recording
the affected dark checkpoint baseline** — only do this bundled with other intentional CSS work.

### IN-01 — needs_review/1 helper key-drift hardening (optional)
`lib/sigra/admin.ex`: add `@spec needs_review(map()) :: non_neg_integer()` + a doctest
pinning the `{locked, deleted}` contract from `Query.summary_counts/2`.

### IN-02 — dark `#fdba74` contrast spot-check (optional)
Confirm `--sg-color-brand-strong: #fdba74` clears WCAG-AA not just on the filter chip but
on every dark reuse (`.sg-applied-chip`, `.sg-badge--brand`, link/hover states). The axe
gate (160-03) ran against the captured checkpoints; reuses not on a captured page weren't
independently asserted.
