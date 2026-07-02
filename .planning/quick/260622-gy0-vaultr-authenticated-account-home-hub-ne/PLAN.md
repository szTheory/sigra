# Vaultr authenticated account-home hub (`/app`)

## Context
Logging into the Vaultr demo as any persona dead-ends: the homepage dangles
"Open Sigra Admin" to everyone, 7/9 personas who click it bounce through login to
a raw `send_resp(403, "Access denied…")`, post-login goes to the evaluator homepage
(`signed_in_path → ~p"/"`), there's no Vaultr-branded authenticated surface, and the
header always says "Sign in" even when logged in. Goal (user-approved scope:
**account-home hub**): a thin, brand-consistent `/app` that greets each persona and
routes them into Sigra's *real* surfaces with cards shown only when their scope allows.

## Changes

1. **New `ExampleWeb.AppLive`** (`lib/example_web/live/app_live.ex`) rendered inside
   `<Layouts.app>` (`vt-app-*` chrome already exists). mount loads from
   `@current_scope.user`:
   - greeting `user.display_name || user.email`
   - security posture (`vt-status-pill`): MFA (`Example.Accounts.mfa_enabled?/1`),
     passkey (`passkey_count_for_user/1`), OAuth providers (scoped `UserIdentity`
     query), password always; "Add two-factor" nudge when no MFA.
   - quick actions: Account settings (`/users/settings`), Active sessions
     (`/users/sessions`).
   - organizations: `Example.Organizations.list_organizations_for_user/1` →
     `{org, role}` cards (manage → `/organizations/:slug/...`).
   - conditional admin cards: platform (`SigraAdminPolicy.platform_admin?/1` →
     `/admin`); per-org admin (`admin_org_ids/1` → `/admin/organizations/:slug`).
   - deletion-notice card when `user.deleted_at` (link to `/users/reactivation`) —
     loop-free coherence for Frank/Grace without pipeline surgery.

2. **Route + land-after-login** (`router.ex`, `user_auth.ex`):
   - `live "/app", AppLive, :home` in a `scope "/"` `[:browser, :require_authenticated]`
     `live_session` with `:ensure_authenticated` on_mount.
   - `signed_in_path/1`: `~p"/"` → `~p"/app"` (covers password/magic-link/passkey login
     + `redirect_if_user_is_authenticated`).
   - MFA-return fallbacks `~p"/"` → `~p"/app"` in `mfa_challenge_controller.ex:48` and
     `session_controller.ex:283` (TOTP/passkey-MFA personas).

3. **Auth-aware headers** (`layouts.ex` `Layouts.app`; `page_html/home.html.heex`):
   when `@current_scope` present → persona name + "Log out"
   (`<.link href={~p"/users/log_out"} method="delete">`) + "Dashboard" (`/app`);
   when nil → "Sign in to Vaultr". Keep homepage "Open Sigra Admin" (evaluator
   affordance — the graceful redirect removes its dead-end).

4. **Graceful admin-denied** (`auth_error_handler.ex` `:insufficient_scope`): if
   `conn.assigns[:current_scope].user` present → flash + `redirect(~p"/app")`; else keep
   the hard 403 (unauthenticated / JSON).

5. **Minimal CSS** (`app.css`): `.vt-status-pill--ok` modifier (teal positive) beside
   the existing caution-styled `.vt-status-pill`.

## Out of scope (tracked)
- **Frank/Grace auto-redirect to reactivation**: the `check_account_active` plug exists
  but is unwired; wiring it into `:require_authenticated` loops (reactivation lives in
  that pipeline) → needs loop-safe path exemptions → **defer to a todo**. `/app`
  deletion card covers coherence meanwhile.
- **Dave (locked)**: keep generic "Invalid email or password" — enumeration-safe Sigra
  security behavior; do not weaken for demo flavor.
- Enterprise SSO landing (`/organizations`) — separate org-scoped flow, untouched.

## Verification
- Per-persona live on `:4011` (curl/Playwright, no driving the user's browser):
  alice → `/app`, account home, NO admin card, header "Log out"; admin@ → `/app` +
  "Sigra Admin" → `/admin` 200; morgan@ → `/app` + Acme console → 200; bob@ → `/app`,
  Beta Labs owner card, MFA pill, no console; alice clicking `/admin` → flash → `/app`
  (no raw 403).
- ExUnit: new AppLive test; update post-login redirect assertions `~p"/"`→`~p"/app"`
  (`session_controller_test.exs:110`, `passkey_session_controller_test.exs:177,185`);
  full example suite green. Logout assertions stay `~p"/"`.
