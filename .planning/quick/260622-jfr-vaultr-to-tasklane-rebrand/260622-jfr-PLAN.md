---
quick_id: 260622-jfr
title: "Rebrand demo app: Vaultr (secrets vault) → Tasklane (project/work tracker)"
date: 2026-06-22
status: in-progress
---

# Quick Task 260622-jfr — Vaultr → Tasklane rebrand (framing-only)

## Goal
Rebrand the demo app (`test/example`) from "Vaultr — team secrets vault" to
**"Tasklane — a fictional project/work tracker"**, so the demo's own domain is
plainly distinct from auth. The demo stays a **pure auth showcase** (framing only,
no product CRUD): `/app` + marketing copy honestly present this as "the account &
security area of Tasklane." Orgs reframe as **workspaces**; roles/topology unchanged.

Full approved plan: `/Users/jon/.claude/plans/i-got-an-error-eager-hamming.md`.

## Constraints
- **Example-only.** Do NOT touch `priv/templates/**` (installer) or the Sigra
  library → no golden-fixture impact.
- **Keep** the `vt-*` CSS prefix + teal palette, `Example`/`ExampleWeb` modules, OTP
  app `:example`, persona local-parts + roles + org memberships.
- Don't touch Dave's enumeration-safe lockout copy or the deferred
  `check_account_active` reactivation wiring.

## Tasks (atomic commits)

### Task 1 — WS1: user-facing copy Vaultr → Tasklane
- files: `test/example/lib/example_web/controllers/page_html/home.html.heex`,
  `components/layouts.ex`, `controllers/session_html.ex`, `live/app_live.ex`,
  `live/demo/credentials_live.ex`, `live/mfa_challenge_live.ex`,
  `live/reactivation_live.ex`, `controllers/auth/sudo_html.ex`,
  `lib/example/demo/personas.ex` (narrative only), `lib/example/demo/branding.ex`
  (product_name/label/desc/subject/from-name/logo-alt), `config/config.exs`,
  `test/example/README.md`.
- action: product name → "Tasklane"; tagline "Team secrets vault" → "Work tracking
  for teams"; hero subtitle → "fictional project tracker — teams plan and ship work
  together. Its auth is powered by Sigra."; orgs panel heading → "Your workspaces";
  `data-testid="vaultr-login"` → `tasklane-login`.
- verify: `grep -ri "vaultr\|secrets vault\|credential vault\|team secrets\|API keys"
  test/example/lib` → only intended/zero; app compiles.
- done: no user-facing Vaultr/secrets-vault copy remains in lib.

### Task 2 — WS2: persona email domain demo.tasklane.test
- files: `lib/example/demo/personas.ex` (`@demo_domain`), `lib/example/demo/branding.ex`
  (2× `noreply@`).
- action: `demo.vaultr.test` → `demo.tasklane.test`.
- verify: `Personas.email("admin")` == `admin@demo.tasklane.test`; SigraAdminPolicy
  still gates admin/morgan (compares via `Personas.email/1`).
- done: domain flipped; admin policy intact.

### Task 3 — WS3: branding id + logo asset
- files: `lib/example/demo/branding.ex` (`@default_id`/preset `id`), HEEx
  `data-demo-brand-default`, `priv/static/images/vaultr-mark.svg` → `tasklane-mark.svg`
  + all `~p"/images/..."` refs.
- action: brand id `"vaultr"` → `"tasklane"`; rename SVG, update refs; if glyph is
  vault/lock-literal, swap to neutral monogram. **Keep `vt-*` prefix + palette.**
- verify: admin Branding lab label reads "Tasklane"; no dangling vaultr-mark refs.
- done: branding id + logo coherent.

### Task 4 — WS4: tests + Playwright assertions
- files: `test/example/test/example/demo/branding_test.exs`,
  `test/example_web/controllers/page_controller_test.exs` + `session_controller_test.exs`,
  `test/example_web/live/admin_branding_live_test.exs`,
  `test/example_web/live/demo/credentials_live_test.exs`,
  `test/example/priv/playwright/tests/demo-showcase.spec.ts` + the two `admin-flow-*.spec.ts`.
- action: update assertions on "Vaultr"/"team secrets vault"/`@demo.vaultr.test`/brand
  id `"vaultr"`/`data-testid`/logo path → new copy.
- verify: `mix test` (in test/example) green.
- done: suite green.

### Task 5 (optional) — multi-workspace on a non-admin persona
- Add Alice to a second workspace in `seeds.ex` if it doesn't perturb assertions.

## Verification
- Grep guard (no residual user-facing Vaultr/secrets in `test/example/lib`).
- `cd test/example && mix test` → 0 failures.
- Live on :4011 (curl): home/login/`/app`/`/demo/credentials` render Tasklane + new
  copy + `@demo.tasklane.test` + new logo; no Vaultr leakage.
- `git status` shows zero changes under `priv/templates/**` or Sigra core `lib/`.
