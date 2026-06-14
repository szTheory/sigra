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
      item=gensub(/^ +| +$/, "", "g", $2)
      tier=gensub(/^ +| +$/, "", "g", $4)
      if (tier ~ /^[012]$/) print item ":" tier
    }'
```

Tiers may only increase over time. The monotonic guard fails CI if any tier cell decreases
between the base branch and the PR branch.

## Quality Ledger

| Item | Level | Tier | Evidence |
|------|-------|------|----------|
| stat | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| stat_link | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| task_card | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| summary_chip | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| applied_chip | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| empty_state | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| page_back | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| scope_ribbon | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| notice | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| notice_link | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| field_help | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| skeleton | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| audit_row | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| mg-1-metric-strip | L2 | 1 | [admin-design.spec.ts board-mg-1](#) |
| mg-2-filter-panel | L2 | 1 | [admin-design.spec.ts board-mg-2](#) |
| mg-3-task-grid | L2 | 1 | [admin-design.spec.ts board-mg-3](#) |
| mg-4-alarm-notice | L2 | 1 | [admin-design.spec.ts board-mg-4](#) |
| mg-5-audit-feed | L2 | 1 | [admin-design.spec.ts board-mg-5](#) |
| index-live | L3 | 1 | [admin-checkpoints: global-overview](#) |
| organization-live | L3 | 1 | [admin-checkpoints: org-overview](#) |
| users-index-live | L3 | 1 | [admin-checkpoints: users-index](#) |
| user-show-live | L3 | 1 | [admin-checkpoints: user-detail](#) |
| audit-index-live | L3 | 1 | [admin-checkpoints: audit-index](#) |
| audit-user-live | L3 | 1 | [admin-checkpoints: user-audit](#) |
