# Phase 187 Component CSS Inventory

Exact source inventory for moving L1 component visual/state rules from the example-only stylesheet into the shipped admin stylesheet.

Source file: `test/example/priv/static/assets/css/app.css`
Target file: `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components`

## stat

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-metric`, `.sg-metric > dt:not(.sg-metric__label)`, `.sg-metric > dd:not([class])`, `.sg-metric__label`, `.sg-metric__value` | `test/example/priv/static/assets/css/app.css:3006-3124` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-metric__number`, `.sg-metric__unit` | `test/example/priv/static/assets/css/app.css:3135-3144` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## stat_link

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-metric-link`, `.sg-metric-link__label`, `.sg-metric-link__value`, `.sg-metric-link:hover`, `.sg-metric-link:focus-visible` | `test/example/priv/static/assets/css/app.css:3262-3293` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## task_card

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-card`, `.sg-card-hover:hover` | `test/example/priv/static/assets/css/app.css:2335-2346` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-btn`, `.sg-btn:focus-visible`, `.sg-btn:active`, `.sg-btn[disabled]`, `.sg-btn[aria-disabled="true"]`, `.sg-btn.is-disabled`, `.sg-btn--primary`, `.sg-btn--secondary`, `.sg-btn--ghost`, `.sg-btn--danger`, `.sg-btn--sm`, `.sg-btn--xs`, `.sg-btn--lg`, `.sg-btn--block`, `.sg-btn--icon`, `.sg-btn--secondary:hover` | `test/example/priv/static/assets/css/app.css:1982-2088` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## summary_chip

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-metric-grid`, `.sg-metric`, `.sg-metric[data-sg-metric-enhanced]`, `.sg-metric[data-sg-metric-help-root]`, `.sg-metric[data-help-open="true"]`, `.sg-metric[data-sg-metric-help-root]:hover`, `.sg-metric[data-sg-metric-help-root]:focus-visible` | `test/example/priv/static/assets/css/app.css:3006-3048` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-metric__label`, `.sg-metric__label-text`, `.sg-metric__icon`, `.sg-metric[data-tone] .sg-metric__icon`, `.sg-metric__icon-svg`, `.sg-metric__icon-text` | `test/example/priv/static/assets/css/app.css:3058-3116` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-metric__value`, `.sg-metric__number`, `.sg-metric__unit`, `.sg-metric__caption`, `.sg-metric__subvalue`, `.sg-metric__help`, `.sg-metric__help[hidden]` | `test/example/priv/static/assets/css/app.css:3124-3190` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## applied_chip

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-applied-chip`, `.sg-applied-chip__remove`, `.sg-applied-chip__remove:hover` | `test/example/priv/static/assets/css/app.css:2680-2707` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## empty_state

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-empty-state` shared surface membership | `test/example/priv/static/assets/css/app.css:2324-2333` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-empty-state`, `.sg-empty-state__title` | `test/example/priv/static/assets/css/app.css:2874-2884` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## page_back

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-btn`, `.sg-btn:focus-visible`, `.sg-btn:active`, `.sg-btn--ghost`, `.sg-btn--ghost:hover`, `.sg-btn--sm` | `test/example/priv/static/assets/css/app.css:1982-2045,2061-2065` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## scope_ribbon

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-muted`, `.sg-text-sm` shared text helpers used by `.sg-scope-ribbon` markup | `test/example/priv/static/assets/css/app.css:2547-2560` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-scope-ribbon` dedicated component hook has no visual rule in `app.css` yet; it inherits shared text helpers above | `test/example/priv/static/assets/css/app.css:2547-2560` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## notice

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-list-row[data-tone="ok"]`, `.sg-list-row[data-tone="warn"]`, `.sg-list-row[data-tone="risk"]`, `.sg-list-row[data-tone="info"]`, `.sg-notice[data-tone="ok"]`, `.sg-notice[data-tone="warn"]`, `.sg-notice[data-tone="risk"]`, `.sg-notice[data-tone="info"]` | `test/example/priv/static/assets/css/app.css:2756-2799` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-notice` | `test/example/priv/static/assets/css/app.css:2801-2808` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## notice_link

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-notice__action`, `.sg-notice__action:hover`, `.sg-notice__action:active`, `.sg-notice__action:focus-visible` | `test/example/priv/static/assets/css/app.css:2810-2851` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## field_help

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-field-help`, `.sg-field-help__trigger`, `.sg-field-help__trigger::before`, `.sg-field-help__trigger:hover`, `.sg-field-help__trigger[aria-expanded="true"]`, `.sg-field-help__trigger:active`, `.sg-field-help__trigger:focus-visible`, `.sg-field-help__icon`, `.sg-field-help__panel`, `.sg-field-help__panel[hidden]` | `test/example/priv/static/assets/css/app.css:2441-2502` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## skeleton

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-skeleton`, `.sg-skeleton::after`, `@keyframes sg-skeleton-shimmer` | `test/example/priv/static/assets/css/app.css:3514-3543` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## audit_row

| Selectors | Source Range | Target | Status |
|-----------|--------------|--------|--------|
| `.sg-list-row`, `.sg-list-row[data-tone="ok"]`, `.sg-list-row[data-tone="warn"]`, `.sg-list-row[data-tone="risk"]`, `.sg-list-row[data-tone="info"]` | `test/example/priv/static/assets/css/app.css:2749-2799` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-status-pill`, `.sg-status-pill[data-tone]`, `.sg-status-pill[data-tone]::before`, `.sg-status-pill__dot` | `test/example/priv/static/assets/css/app.css:1821-1896` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-code`, `.sg-admin-shell code.sg-code`, `.sg-admin-shell code.sg-code:hover` | `test/example/priv/static/assets/css/app.css:2886-2893,3505-3511` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## Shared Blocks

| Selectors | Source Range | Consumers | Target | Status |
|-----------|--------------|-----------|--------|--------|
| `.sg-btn*` | `test/example/priv/static/assets/css/app.css:1982-2088` | `task_card`, `page_back` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-card`, `.sg-card-hover` | `test/example/priv/static/assets/css/app.css:2324-2346` | `task_card`, design board surfaces | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-metric*` | `test/example/priv/static/assets/css/app.css:3006-3190,3262-3293` | `stat`, `stat_link`, `summary_chip` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-list-row[data-tone]`, `.sg-notice[data-tone]` | `test/example/priv/static/assets/css/app.css:2756-2799` | `notice`, `audit_row` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-status-pill*` | `test/example/priv/static/assets/css/app.css:1821-1896` | `audit_row` and any status-badge call sites | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| `.sg-muted`, `.sg-text-sm`, `.sg-code` | `test/example/priv/static/assets/css/app.css:2547-2560,2886-2893,3505-3511` | `scope_ribbon`, `audit_row`, component copy helpers | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |

## Migration Checklist

| Component | Selectors | Source Range | Target | Status |
|-----------|-----------|--------------|--------|--------|
| stat | `.sg-metric`, `.sg-metric__label`, `.sg-metric__value`, `.sg-metric__number`, `.sg-metric__unit` | `test/example/priv/static/assets/css/app.css:3006-3144` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| stat_link | `.sg-metric-link`, `.sg-metric-link__label`, `.sg-metric-link__value`, hover, focus-visible | `test/example/priv/static/assets/css/app.css:3262-3293` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| task_card | `.sg-card`, `.sg-card-hover`, `.sg-btn`, `.sg-btn--primary` | `test/example/priv/static/assets/css/app.css:1982-2088,2335-2346` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| summary_chip | `.sg-metric-grid`, `.sg-metric[data-sg-metric-enhanced]`, `.sg-metric__icon`, `.sg-metric__caption`, `.sg-metric__subvalue`, `.sg-metric__help` | `test/example/priv/static/assets/css/app.css:3006-3190` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| applied_chip | `.sg-applied-chip`, `.sg-applied-chip__remove` | `test/example/priv/static/assets/css/app.css:2680-2707` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| empty_state | `.sg-empty-state`, `.sg-empty-state__title` | `test/example/priv/static/assets/css/app.css:2324-2333,2874-2884` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| page_back | `.sg-btn`, `.sg-btn--ghost`, `.sg-btn--sm` | `test/example/priv/static/assets/css/app.css:1982-2045,2061-2065` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| scope_ribbon | `.sg-scope-ribbon` hook via `.sg-muted`, `.sg-text-sm` | `test/example/priv/static/assets/css/app.css:2547-2560` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| notice | `.sg-notice`, `.sg-notice[data-tone]` | `test/example/priv/static/assets/css/app.css:2756-2808` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| notice_link | `.sg-notice__action` | `test/example/priv/static/assets/css/app.css:2810-2851` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| field_help | `.sg-field-help`, `.sg-field-help__trigger`, `.sg-field-help__panel` | `test/example/priv/static/assets/css/app.css:2441-2502` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| skeleton | `.sg-skeleton`, `.sg-skeleton::after`, `@keyframes sg-skeleton-shimmer` | `test/example/priv/static/assets/css/app.css:3514-3543` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
| audit_row | `.sg-list-row`, `.sg-status-pill`, `.sg-code` | `test/example/priv/static/assets/css/app.css:1821-1896,2749-2799,2886-2893,3505-3511` | `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components` | pending |
