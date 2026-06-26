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

## Asserting Tier 2

A maintainer asserts that a ledger cell reached Tier 2 by making two changes together:

1. **Flip the Tier column to `2`** — the bare integer `2` (no decorators, no footnote markers,
   no asterisks). Column-4 must remain a single `[012]` value so the monotonic guard's
   `awk -F'|'` positional parse keeps working. **Decorators in column-4 are forbidden** — they
   break the guard parse and will cause false-pass CI.

2. **Expand the Evidence column** to cite the specific spec/test proving each APPLICABLE
   Tier-2 proxy for that surface. Reference the proxy list in
   `admin-fractal-scorecard.md` → _Tier-2 Award-grade Add-on_ for the full set of proxies and
   their automated/manual gate designations. Example evidence expansion for a page LiveView:
   - axe-while-open: admin-modal-interaction.spec.ts passes
   - APG gates: admin-modal-interaction.spec.ts 7 gates pass
   - content-equivalence: admin-design.spec.ts MG-5/6 + un-skipped equivalence test pass
   - glossary-clean: glossary_test.exs passes
   - motion-tokens: reviewed — no `transition: all`; uses `--sg-duration-*`/`--sg-ease-*`
   - density/rhythm: reviewed — consistent `sg-stack--6`/`--4` cadence
   - target-size: reviewed — all interactive targets ≥ 24×24 CSS pixels

The monotonic guard already treats `2` as a numerically higher integer than `1` and `0`, so
Tier-2 cells are automatically forward-only protected against regression once set.

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
| user-show-live | L3 | 2 | [admin-checkpoints user-detail — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts); axe-while-open + 7 APG focus-trap/restore gates: [admin-modal-interaction.spec.ts](../../test/example/priv/playwright/tests/admin-modal-interaction.spec.ts); desktop↔mobile content-equivalence: admin-design.spec.ts MG-5/6 equivalence test; glossary-clean: glossary_test.exs passes; motion-tokens: reviewed — no `transition: all`; density/rhythm: reviewed — `sg-stack--6` outer, `sg-stack--3` card inner; target-size: reviewed — all interactive targets ≥24×24 CSS px |
| user-sessions | L3 | 1 | [admin-checkpoints user-sessions — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts); axe-while-open + 7 APG focus-trap/restore gates (confirm dialog ownership): [admin-modal-interaction.spec.ts](../../test/example/priv/playwright/tests/admin-modal-interaction.spec.ts); glossary-clean: glossary_test.exs passes |
| audit-index-live | L3 | 1 | [admin-checkpoints audit-explorer — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| audit-user-live | L3 | 1 | [admin-checkpoints user-audit — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| branding-live | L3 | 1 | [admin-modal-interaction: ConfirmDialog APG gates + axe-while-open](../../test/example/priv/playwright/tests/admin-modal-interaction.spec.ts); Phase 191 voice pass: D9 IA (GOV.UK page arch, verb-first, scope-visible), D10 Microcopy (brand-book-aligned, no leaked internals, no synonym drift) |
| flow-platform-admin | L4 | 1 | [admin-flow-platform-admin.spec.ts — platform admin JTBD: happy/error/boundary, scope/return-context, keyboard, reduced-motion, theme-persistence + reload](../../test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts) |
| flow-support-investigator | L4 | 1 | [admin-flow-support-investigator.spec.ts — investigator posture: find→audit→impersonate→return, banner continuity, ConfirmDialog APG gates, theme](../../test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts) |
| flow-org-admin | L4 | 1 | [admin-flow-org-admin.spec.ts — org admin JTBD: tenant-bounded access, 403 permission-denied, empty audit boundary, theme](../../test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts) |

## Terminal Ratification — Phase 192

All ~35 quality-ledger cells are locked at **Tier 1 (Ratified)** as of Phase 192
(2026-06-18). This is the terminal gate of the v1.39 DS-COHERENCE milestone.

**Forward-only guarantee:** The monotonic guard (`scripts/ci/quality-ledger-monotonic.sh
--base origin/main`) protects every cell permanently — no future PR may decrease any tier.
Tier 1 is the minimum floor from this point forward.

**Tier 2 is objectively earnable from this point forward.** The Tier-2 ("Award-grade")
proxies are now defined in `admin-fractal-scorecard.md` → _Tier-2 Award-grade Add-on_ (added
in Phase 199). A cell earns Tier 2 by satisfying all applicable proxies and asserting them
per the _Asserting Tier 2_ convention above. The same monotonic guard that locks Tier 1 as
the floor also protects any Tier-2 cell against regression — `2` is numerically higher than
`1` and the guard already enforces forward-only integers. Phase 192 locked all cells at Tier 1
as the minimum floor; Phase 199 established the objective proxy contract for Tier 2.
Ratcheting individual surfaces to Tier 2 begins in Phases 200-204.

**Proof method:** compare-mode zero-drift idempotency (not force-recapture) — re-rendering
all 6 Playwright projects produces zero PNG delta; both allowlists verified at steady-state
empty; both canaries byte-stable; byte-golden component suite green; monotonic guard green
vs `origin/main`; generated-host parity proven via CI SHA for the admin-acceptance job.
