# Admin Quality Ledger

Machine-parseable quality tier record for Sigra's admin UI surfaces. Updated by phases
186-192 as fractal quality audits progress.

## Tier Vocabulary

| Tier | Name | Description |
|------|------|-------------|
| 0 | Drift | Fails one or more scorecard axes; visible regressions vs v1.34 contract |
| 1 | Ratified | Meets the v1.34 contract bar; passes all required axes; no obvious gaps |
| 2 | Award-grade | emilkowal.ski-level micro-interaction quality; coherent on-brand copy; pixel-considered spacing; delightful in detail |

## Parsing Rules

The **tier** column (column 4, 1-indexed in `|`-delimited rows) contains a single integer
(`0`, `1`, or `2`) with no decorators. The monotonic guard (`scripts/ci/quality-ledger-monotonic.sh`)
reads tier values using:

```bash
grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md \
  | awk -F'|' '{
      item=$2; gsub(/^ +| +$/, "", item)
      tier=$4; gsub(/^ +| +$/, "", tier)
      if (tier ~ /^[012]$/) print item ":" tier
    }'
```

Tiers may only increase over time. The monotonic guard fails CI if any tier cell decreases
between the base branch and the PR branch.

## Quality Ledger

| Item | Level | Tier | Evidence |
|------|-------|------|----------|
| token-layer | L0 | 1 | [admin-token-reference.md](admin-token-reference.md) |
| stat | L1 | 1 | [board-stat admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| stat_link | L1 | 1 | [board-stat_link admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| task_card | L1 | 1 | [board-task_card admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| summary_chip | L1 | 1 | [board-summary_chip admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| applied_chip | L1 | 1 | [board-applied_chip admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| empty_state | L1 | 1 | [board-empty_state admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| page_back | L1 | 1 | [board-page_back admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| scope_ribbon | L1 | 1 | [board-scope_ribbon admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| notice | L1 | 1 | [board-notice admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| notice_link | L1 | 1 | [board-notice_link admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| field_help | L1 | 1 | [board-field_help admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| skeleton | L1 | 1 | [board-skeleton admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| audit_row | L1 | 1 | [board-audit_row admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts), [components_test.exs](../../test/sigra/admin/components_test.exs) |
| mg-1-metric-summary-strip | L2 | 1 | [board-mg-1 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, responsive overflow, canary-clean snapshots |
| mg-2-filter-panel-applied-chips | L2 | 1 | [board-mg-2 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, byte-coherently reused chips, responsive overflow |
| mg-3-task-card-grid | L2 | 1 | [board-mg-3 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, no card-in-card nesting, responsive overflow |
| mg-4-alarm-notice-band | L2 | 1 | [board-mg-4 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, responsive overflow, canary-clean snapshots |
| mg-5-user-results-pagination | L2 | 1 | [board-mg-5 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, content-equivalent desktop/mobile results, responsive overflow |
| mg-6-audit-feed-pagination | L2 | 1 | [board-mg-6 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, content-equivalent desktop/mobile audit feed, byte-coherently reused feed |
| mg-7-organization-member-roster | L2 | 1 | [board-mg-7 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, responsive overflow, canary-clean snapshots |
| mg-8-pending-invitations | L2 | 1 | [board-mg-8 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, responsive overflow, canary-clean snapshots |
| mg-9-identity-header-summary-facts | L2 | 1 | [board-mg-9 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, responsive overflow, canary-clean snapshots |
| mg-10-detail-facts-membership-panels | L2 | 1 | [board-mg-10 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, responsive overflow, canary-clean snapshots |
| mg-11-destructive-action-confirmation | L2 | 1 | [board-mg-11 admin-design.spec.ts](../../test/example/priv/playwright/tests/admin-design.spec.ts) — catalog states/right components, byte-coherently reused confirmation, canary-clean snapshots |
| index-live | L3 | 1 | [admin-checkpoints global-overview — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| organization-live | L3 | 1 | [admin-checkpoints org-overview — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| users-index-live | L3 | 1 | [admin-checkpoints global-user-index — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| user-show-live | L3 | 1 | [admin-checkpoints user-detail — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts); [admin-modal-interaction: 7 APG gates + axe-while-open](../../test/example/priv/playwright/tests/admin-modal-interaction.spec.ts) |
| audit-index-live | L3 | 1 | [admin-checkpoints audit-explorer — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| audit-user-live | L3 | 1 | [admin-checkpoints user-audit — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| branding-live | L3 | 1 | [admin-modal-interaction: ConfirmDialog APG gates + axe-while-open](../../test/example/priv/playwright/tests/admin-modal-interaction.spec.ts); Phase 191 voice pass: D9 IA (GOV.UK page arch, verb-first, scope-visible), D10 Microcopy (brand-book-aligned, no leaked internals, no synonym drift) |
| flow-platform-admin | L4 | 1 | [admin-flow-platform-admin.spec.ts — platform admin JTBD: happy/error/boundary, scope/return-context, keyboard, reduced-motion, theme-persistence + reload](../../test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts) |
| flow-support-investigator | L4 | 1 | [admin-flow-support-investigator.spec.ts — investigator posture: find→audit→impersonate→return, banner continuity, ConfirmDialog APG gates, theme](../../test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts) |
| flow-org-admin | L4 | 1 | [admin-flow-org-admin.spec.ts — org admin JTBD: tenant-bounded access, 403 permission-denied, empty audit boundary, theme](../../test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts) |
