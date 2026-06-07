# v1.36 ADMIN-BRAND-THEME-POLISH Requirements

## Goal

Bring Sigra's admin UI into alignment with the ratified Rail Accent brand system while preserving the v1.34 needs-led admin journey and `sg-*` design-system architecture.

## Requirements

- [x] **BRAND-01:** Admin shell uses the ratified Rail Accent mark/lockup assets instead of a placeholder glyph.
- [x] **BRAND-02:** Admin UI tokens remain aligned with `brandbook/tokens.*` for palette, typography, radius, focus, shadow, and motion.
- [x] **THEME-01:** Admin shell exposes explicit Light, Dark, and System modes.
- [x] **THEME-02:** Theme selection persists locally and no-JS fallback remains system-driven through `prefers-color-scheme`.
- [x] **THEME-03:** Light and dark mode use correct logo/foreground contrast, including dark surfaces.
- [x] **UX-01:** Default `/admin` remains a needs-led launcher for operator jobs, not a decorative landing page.
- [x] **UX-02:** Global, org, users, user detail, user audit, and audit explorer flows keep scope and next action obvious.
- [x] **DS-01:** New UI work uses existing `sg-*` tokens/components or promotes reusable primitives; no one-off override drift.
- [x] **DS-02:** Buttons, chips, controls, inputs, date fields, pagination, notices, empty states, and command palette follow the same size, radius, padding, focus, and motion contracts.
- [x] **DOC-01:** Durable admin UI principles live in a dedicated guide linked from agent entrypoints.
- [x] **DOC-02:** `guides/reference/admin-design-contract.md` records the brand/theme additions and test obligations.
- [x] **TEST-01:** Browser tests cover explicit theme selection, persisted preference, system fallback, and accessible control semantics.
- [x] **TEST-02:** Admin checkpoint coverage remains deterministic across desktop, mobile, and dark.
- [x] **TEST-03:** Verification avoids brittle sleeps/selectors and continues using LiveView readiness, role selectors, and stable `sg-*` hooks.

## Non-Goals

- Do not redesign non-admin demo/auth/organization screens.
- Do not introduce Tailwind as the admin source of truth.
- Do not add web fonts, frontend frameworks, or third-party component libraries.
- Do not expand Sigra into hosted identity/control-plane behavior.
