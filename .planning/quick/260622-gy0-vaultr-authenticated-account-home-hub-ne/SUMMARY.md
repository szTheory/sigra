---
quick_id: 260622-gy0
status: complete
date: 2026-06-22
---

# Vaultr authenticated account-home hub (`/app`)

## Problem
Logging into the Vaultr demo dead-ended every persona: the homepage lured all 9
toward "Open Sigra Admin", the 7 non-admins bounced through login to a raw
`send_resp(403, "Access denied…")`, post-login landed on the evaluator homepage
(`signed_in_path → ~p"/"`), there was no Vaultr-branded authenticated surface, and
the header always said "Sign in" even when logged in.

## What changed (account-home hub — user-approved scope)
- **New `ExampleWeb.AppLive`** (`/app`) rendered in the existing `<Layouts.app>`
  `vt-app-*` chrome. Greets by `display_name`; a `vt-status-pill` security strip
  (password / TOTP / passkeys / "Connected with <provider>") computed from real
  Sigra state (`Accounts.mfa_enabled?/1`, `passkey_count_for_user/1`, scoped
  `UserIdentity` query); quick actions (settings, sessions, MFA); org cards
  (`Organizations.list_organizations_for_user/1` → `{org, role}`); **conditional**
  platform-admin card (`SigraAdminPolicy.platform_admin?/1` → `/admin`) and per-org
  admin-console links (`admin_org_ids/1` → `/admin/organizations/:slug`); a
  deletion-notice card when `user.deleted_at`.
- **Land here after login**: `signed_in_path/1` `~p"/"`→`~p"/app"` (password /
  magic-link / passkey / `redirect_if_user_is_authenticated`); MFA-return fallbacks
  in `mfa_challenge_controller.ex` + `session_controller.ex` `~p"/"`→`~p"/app"`.
- **Auth-aware headers**: `Layouts.app` and the home action row show name-context +
  "Log out" (+ "Dashboard"/"Open your dashboard") when signed in, "Sign in to
  Vaultr" when not.
- **Graceful admin-denied**: `auth_error_handler.ex` `:insufficient_scope` →
  authenticated non-admin gets flash + `redirect(~p"/app")`; raw 403 kept for
  unauthenticated/non-HTML.
- **CSS**: added `.vt-status-pill--ok` (teal positive) beside the caution base.

## Files
New: `live/app_live.ex`, `test/.../live/app_live_test.exs`.
Changed: `router.ex`, `user_auth.ex`, `controllers/mfa_challenge_controller.ex`,
`controllers/session_controller.ex`, `components/layouts.ex`,
`controllers/page_html/home.html.heex`, `auth_error_handler.ex`,
`priv/static/assets/css/app.css`. Tests updated for the new redirect target:
`session_controller_test.exs`, `passkey_session_controller_test.exs`,
`phase_27_integration_test.exs` (org-admin denial now 302→/app, not 403).

## Scope discipline
- **All changes confined to `test/example`** (the demo). Installer templates
  (`priv/templates/sigra.install/`) intentionally untouched — `/app`, the persona
  landing, and the Vaultr-specific graceful redirect are demo features; a generic
  host app keeps `signed_in_path → "/"`. No golden-diff impact.
- **Deferred**: Frank/Grace auto-redirect to reactivation — `check_account_active`
  is unwired and naive wiring loops (reactivation is in `:require_authenticated`);
  needs path-exempt guard. Filed:
  `.planning/todos/pending/2026-06-22-wire-check-account-active-reactivation.md`.
  Interim coverage: `/app` deletion-notice card.
- **Untouched on purpose**: Dave (locked) keeps the enumeration-safe generic login
  error; enterprise SSO landing (`/organizations`).

## Verification
- `mix test` (full example suite): **216 tests, 0 failures**.
- Live on `:4011` (curl login flow — did not drive the user's browser):
  - alice → `/app` "Welcome back, Alice", security + orgs cards, Log out, NO admin
    card; `GET /admin` → **302 → /app** (graceful).
  - morgan → `/app`, org card with `/admin/organizations/acme-corp` console link, no
    platform card; `GET /admin` → 302 → /app.
  - admin → `/app` with platform-admin card; `GET /admin` → **200**.
  - carol → security strip shows "Linked identity · Connected with Github".
  - Homepage header: logged-in → "Open your dashboard" + "Log out" (no "Sign in");
    logged-out → "Sign in to Vaultr".
