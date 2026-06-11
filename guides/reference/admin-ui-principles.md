# Sigra Admin UI Principles

This guide is the durable working standard for Sigra admin UI changes. It complements the formal [admin design contract](admin-design-contract.md) and the brand source of truth in `brandbook/`.

## Product Frame

The admin UI exists for operators who need to understand scope, find accounts or events, and take safe support actions. It is not a marketing surface.

Primary personas:

- **Platform admin:** starts at `/admin`, checks what needs attention, finds users, investigates audit evidence, and pivots into org scope.
- **Support investigator:** starts from a user or event, keeps scope visible, and needs safe next actions with clear return paths.
- **Org admin:** operates inside one tenant boundary and needs member posture and org-scoped audit evidence without global noise.

Use GOV.UK-style service thinking: start from user needs, make the next action obvious, keep navigation general-to-specific, and prefer simple language over clever labels.

## Information Architecture

- `/admin` is a needs-led launcher: tasks first, posture second, capabilities last.
- Overview pages explain where to go next; list pages help narrow a set; detail pages help decide and act.
- Scope must be visible in shell chrome and in page body on list/detail screens.
- User leaf screens use breadcrumbs for hierarchy and return context. A separate back control is only for leaf screens that cannot express the path as `Overview / Workspace / Item`.
- Progressive reveal is preferred for power-user filters and secondary evidence. Do not make the common path pay for uncommon complexity.

## Design System

- Keep the hand-authored `sg-*` CSS architecture: cascade layers, design tokens, and BEM-style component classes.
- Do not introduce Tailwind as the admin source of truth and do not add one-off override classes when an `sg-*` primitive or component exists.
- Same job means same component. Route reusable markup through `Sigra.Admin.Components` or the admin shell seam.
- Use brand tokens from `brandbook/tokens.*` as the value reference. Preserve existing `--sg-*` names unless a migration is deliberately planned.
- Buttons, chips, pills, inputs, date fields, pagination, notices, empty states, toasts, and command palette controls must share sizing, radius, padding, focus, and motion conventions.
- Status colors must never be the only signal. Pair tone with text, icon/glyph, border, or label.

## Brand Application

- Use the Rail Accent mark/lockup from `brandbook/` for Sigra identity.
- Light surfaces must not use the dark lockup; dark surfaces must not use a black wordmark.
- Ember accent is for Sigra identity, primary actions, selected states, and ownership-boundary emphasis. Do not use it for every heading or icon.
- Keep the admin visual tone quiet, warm, dense, and utilitarian. Brand should make the surface distinct without making operational screens decorative.

## Theme And Motion

- Admin supports **Light**, **Dark**, and **System**. System follows `prefers-color-scheme`; explicit choices persist locally.
- No-JS fallback remains system-driven.
- Motion is purposeful and restrained: press feedback, overlay entrance, toast transitions, and small hover lift on pointer devices.
- Do not animate keyboard-frequent paths such as filter chips, command result navigation, or table/list state changes.
- Use transform/opacity/shadow/color transitions only; never `transition: all`.
- Respect `prefers-reduced-motion` through the global reduced-motion clamp.

## Testing Standard

- UI tests must be fast, deterministic, and non-flaky.
- Prefer role selectors, stable test IDs, and existing `sg-*` hooks. Avoid broad text selectors when a shell control can collide with page controls.
- Use explicit LiveView readiness gates instead of sleeps.
- Browser specs should cover happy paths, main error cases, important boundary states, light/dark/system theme behavior, and no broken admin imagery.
- Screenshot baselines are curated evidence, not a broad pixel regime. Re-record deliberately and pair with behavior/axe checks.
