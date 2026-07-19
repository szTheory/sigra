---
quick_id: 260718-t7o
title: "Bring the MFA settings page to Tasklane brand standard (root-cause fix)"
status: complete
---

# MFA brand polish — root `<.button>` default fix + panel/empty-state (example-only)

One-liner: Changed the example core `<.button>` default so class-less buttons render Tasklane teal
(`vt-btn vt-btn--primary`) instead of daisyUI purple, then branded the MFA settings unenrolled Two-Factor
section as a `vt-panel` and swapped the passkey empty-state to a reusable `.vt-empty-state` pattern.

## Scope confirmation

- **All changes under `test/example/`.** No `priv/templates/`, no `test/fixtures/`, no `*.png` touched.
- **Core-components mirror check (Task 1 pre-flight):** The installer does NOT ship a `core_components.ex`
  template — it ships `priv/templates/sigra.install/core/sigra_auth_components.ex` plus per-page HTML modules.
  `grep` for `btn-primary btn-soft` across `priv/templates` + `test/fixtures` returned nothing, and no
  golden references `vt-btn--primary`. So the example's `core_components.ex` is example-only and this change
  requires **no golden re-bless**.

## Task 1 — root fix: core `<.button>` default → Tasklane teal

`test/example/lib/example_web/components/core_components.ex` (`def button/1`): replaced the daisyUI variant
map (`%{"primary" => "btn-primary", nil => "btn-primary btn-soft"}` + `["btn", ...]`) with
`assign_new(assigns, :class, fn -> "vt-btn vt-btn--primary" end)`. Explicit `class=` still overrides via
`assign_new`; the `:variant`/`:class`/`:rest` attrs remain declared.

### Bounded no-regression review of listed bare-`<.button>` sites

| Site | Finding | Action |
|------|---------|--------|
| `auth/session_live.ex` (73/82/94) | Already explicit `vt-btn--danger` / `vt-btn--danger-solid` | Unaffected — no change |
| `confirmation_live.ex` (50/84) | Already explicit `btn btn-primary w-full` (daisyUI, deferred to SEED-010) | Unaffected — no change |
| `organization_members_live.ex` (372) | Already explicit `vt-btn` (disabled state) | Unaffected — no change |
| `organization_members_live.ex` (425) | "Load more" has explicit `class="mt-4"` (pre-existing, unstyled) | Unaffected — no change |
| `organization_settings_live.ex` (262) "Enable SSO-only" | Bare → now teal; primary, pairs with 269 ghost "Disable SSO-only" | Kept teal default |
| `organization_settings_live.ex` (345) "Save draft" | Bare → now teal; commit action | Kept teal default |
| `organization_settings_live.ex` (348) "Validate" | Bare; genuinely secondary/diagnostic action between two commit buttons | **Changed → `vt-btn vt-btn--ghost`** |
| `organization_settings_live.ex` (355) "Activate" | Bare → now teal; primary commit action | Kept teal default |

**Only one button changed in the review:** `organization_settings_live.ex` "Validate" → ghost. All other
listed sites either carry explicit classes (unaffected by the default) or are genuine primary CTAs left on
the new teal default.

## Task 2 — MFA settings polish

`test/example/lib/example_web/live/mfa_settings_live.ex`:
- `render_enrollment_start/1`: rewrote the bare `<div>` + `<.header>` + `mt-6` block as a `vt-panel` with
  `vt-panel__header` (kicker "Two-factor" + serif `vt-panel__title` + `vt-copy`) and an explicit
  `class="vt-btn vt-btn--primary"` button. `phx-click="begin_enrollment"` preserved exactly.
- Passkey empty-state: swapped `vt-alert` + `vt-panel__title` for `.vt-empty-state` / `.vt-empty-state__title`.
  Kept the test-asserted string "No passkeys added yet"; `id="passkeys"` / `id="add-passkey-button"` untouched.

## Task 3 — CSS: reusable empty-state

`test/example/priv/static/assets/css/app.css` (after `.vt-alert--danger`): added `.vt-empty-state` and
`.vt-empty-state__title` per PLAN. Referenced `--sg-*` tokens are defined in `sigra_admin.css` and already
consumed throughout app.css.

## Task 4 — SEED

Skipped by executor (docs — orchestrator to plant/commit SEED-010). Not committed as code.

## Verification

- `cd test/example && mix compile --warnings-as-errors` → clean (both commits).
- `git diff --stat` → 4 files, all under `test/example/`; no `priv/templates`, no `test/fixtures`, no `*.png`.
- `mix test test/example_web/live/passkey_settings_live_test.exs test/example_web/smoke/mfa_totp_test.exs
  --include example_app` → **13 tests, 0 failures** (DB up via `tmp/db.env`, port 53988).
  (Pre-existing `/dev/mailbox` route warning in `settings_live.ex` is unrelated and out of scope.)

## Deviations from Plan

None affecting behavior. Task 4 (SEED doc) left to the orchestrator per plan note.

## Commits

- `5dab3219` feat(260718-t7o): default class-less `<.button>` to Tasklane teal (+ Validate ghost)
- `e8735dd3` feat(260718-t7o): brand MFA settings unenrolled state + empty-state (+ CSS)

## Self-Check: PASSED

- core_components.ex, mfa_settings_live.ex, organization_settings_live.ex, app.css — all present and modified.
- Commits 5dab3219 and e8735dd3 exist in `git log`.
