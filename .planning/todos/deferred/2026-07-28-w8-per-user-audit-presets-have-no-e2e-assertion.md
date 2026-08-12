---
created: 2026-07-28T00:00:00.000Z
status: pending
title: Per-user audit view has presets and Active filters, but no E2E assertion covers them
area: admin-audit
severity: low
audit_finding: W-8
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [AUDIT-01, AUDIT-02]
files:
  - lib/sigra/admin/live/audit_user_live.ex
  - test/example/priv/playwright/tests/admin-audit.spec.ts
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

Phase 228 shipped filter precision to **both** audit LiveViews. The global view is proven
end to end; the per-user view is not.

Proven (`audit_index_live`): `audit_index_live.ex:135` renders
`<h2 id="admin-audit-active-filters">Active filters</h2>`, asserted at
`admin-generated.spec.ts:364-395` including `toHaveCount(1)` on `[name="outcome"]` and
`[name="action_prefix"]` (the duplicate-filter-state defect), preset URL shape, chip text,
and the manual-Apply URL round-trip. Plus `admin-checkpoints.spec.ts:365-372` on
`nav[aria-label="Audit filter presets"]` with `aria-current="page"`.

Not proven (`audit_user_live`): `audit_user_live.ex:155` carries the same Active-filters
region and the same presets. `auth_ui_contract_test.exs:116-131` asserts both LiveViews
statically. But every Playwright spec touching `/admin/users/:id/audit` —
`admin-audit.spec.ts:132`, `admin-checkpoints.spec.ts:312`,
`admin-flow-platform-admin.spec.ts:193` — asserts **results tables only**. No preset link,
no `aria-current`, no chip, no Clear all.

So AUDIT-01's "exactly one effective value per filter" and AUDIT-02's Active-filters
contract are behaviourally verified on one of the two surfaces they apply to.

## Recommended fix

Port the assertion block from `admin-generated.spec.ts:364-395` to the per-user audit view.
The two LiveViews render the same region with the same hooks, so this is largely a copy
with a different starting URL and a user fixture.

Specifically assert, on `/admin/users/:id/audit`:

- `toHaveCount(1)` on `[name="outcome"]` and `[name="action_prefix"]` — the regression that
  motivated Phase 228.
- A preset link navigates and sets `aria-current="page"`.
- The Active-filters region follows the form and renders removable chips + Clear all.
- Manual Apply produces the expected URL, and browser back restores prior state.

There is a related open todo — `2026-07-18-admin-audit-impersonation-filter-not-applying.md`
— worth reading first, since it may be the same surface and could be closed in one pass.

## Related

- [[2026-07-18-admin-audit-impersonation-filter-not-applying]]
- Phase 228 summary: `.planning/phases/228-admin-audit-precision-boundary-pass/228-01-SUMMARY.md`
