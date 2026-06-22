# Vaultr demo: real account screens, full vt-* brand coherence, sudo fix, product identity

## Context
The new `/app` hub routes personas into authenticated sub-screens that are
half-finished or off-brand, breaking the "realistic app consuming Sigra" story:
- **`/users/settings` is a literal stub** ("STUB — NOT FOR PRODUCTION"). The real
  page (email/password/delete, wired to Sigra) already exists as the installer
  template `priv/templates/sigra.install/core/settings_live.ex`; the example just
  never swapped it in.
- **Most authed screens are off-brand** — sessions, MFA settings, org switcher, org
  index/new/settings/members, MFA challenge, sudo all use Tailwind/daisyUI classes
  that don't exist in this build-free `--no-tailwind` demo, so they render unstyled.
- **`/users/settings/mfa` dead-ends**: stale-sudo redirects to `/users/log_in`, which
  bounces an already-authed user to `/app` — so the "re-enter your password" form
  (which exists at `/users/sudo`) is never shown. Same bug ships in the installer
  template → every generated host app inherits it.
- **Two logout buttons** (`AppLive` in-page + header) — redundant.
- **Vaultr's domain was vague.** Decision: **Vaultr = a team credential/secrets
  vault** (companies store & share API keys / passwords / certs across teams). This
  maps 1:1 to what already exists — orgs=teams, roles, audit=access log,
  MFA/passkeys=the lock — and needs no invented product CRUD.

Outcome: every authenticated Vaultr sub-screen is realistic, on-brand (`vt-*`),
coherent with the credential-vault story, and free of dead-ends — a believable
proof of a real app built on Sigra.

## Workstreams (execute in order; each ≈ one commit)

### 0. Vaultr product identity (copy only)
Settle the credential-vault concept across the descriptor copy: `page_html/home.html.heex`
(hero tagline/subtitle, `vt-brand__tag`, identity-grid), `components/layouts.ex`
(`vt-brand__tag` "Fictional cohort app"), `controllers/session_html.ex` (login intro
line), `lib/example/demo/branding.ex` (Vaultr preset description), light touch in
`personas.ex`/`README.md`. Keep it honest demo framing ("secured by Sigra"); no
feature promises the demo can't show.

### 1. vt-* design primitives (`priv/static/assets/css/app.css`)
Add the vocabulary the rebrand needs (all additive; verify each rule actually parses
in-browser per the known app.css orphan-comment gotcha):
- **`.vt-form`** field styles (`.vt-form .input/.label/.select/.textarea/.checkbox`)
  mirroring the existing `.vt-auth .input/.label/...` block (~app.css 1128+) so forms
  render on-brand inside `<Layouts.app>` (not just on the `.vt-auth` login surface).
- **`.vt-alert`** with `--info/--warning/--danger` variants (replaces daisyUI `alert`).
- **`--vt-color-danger`** risk token + **`.vt-btn--danger`** for destructive actions.
- **`.vt-menu`** (a `<details>`-based dropdown) + **`.vt-avatar`** initials chip for the
  org switcher.

### 2. Real Settings page (replace the stub)
Rewrite `lib/example_web/live/settings_live.ex` by adapting the installer template
`priv/templates/sigra.install/core/settings_live.ex`, rendered inside
`<Layouts.app current_scope=… user_organizations=…>` (authed chrome) with `vt-*`
styling instead of `<.sigra_auth_page>`/Tailwind. Sections:
- **Email** — change + cancel-pending (`Example.Accounts.request_email_change/2`,
  `cancel_email_change/1`); confirm-email token flow (wire the confirm route the way
  the example delivers update-email instructions; add the route if missing).
- **Password** — change (`change_password/3`) or set for OAuth-only (`set_password/2`);
  force-password-change banner via `Auth.must_change_password?/1`.
- **Profile / preferences** — edit `display_name` (schema supports it; add a small
  `Example.Accounts.update_display_name/2` + `User` profile changeset if absent). Only
  expose fields that actually persist — no fake prefs.
- **Delete account** — schedule/cancel (`schedule_deletion/2`, `cancel_deletion/2`,
  `deletion_status/1`) with `vt-btn--danger` + confirm.
Reuse the template's event handlers verbatim where possible; swap markup to
`vt-panel` sections + `vt-form` fields + `vt-alert`/`vt-status-pill`.

### 3. Rebrand all demo-reachable authed screens to vt-*
Systematic daisyUI/Tailwind → `vt-*` conversion using the Workstream-1 primitives:
- `components/org_switcher.ex` → `vt-menu` + `vt-avatar` (header, highest visibility).
- `live/auth/session_live.ex` → `vt-panel`/`vt-table` rows + `vt-btn--danger` revoke.
- `live/mfa_settings_live.ex` → `vt-panel` sections, `vt-form`, `vt-status-pill`,
  `vt-alert`, `vt-btn` (largest screen).
- `live/organizations_live/index.ex` + `new.ex`, `live/organization_settings_live.ex`
  + `live/organization_members_live.ex` → `vt-panel`/`vt-form`/`vt-alert`/`vt-btn--danger`.
- `live/mfa_challenge_live.ex` + `controllers/mfa_challenge_html.ex` and
  `controllers/auth/sudo_html.ex` → wrap in the `.vt-auth` surface (these are
  login-style pre/re-auth pages, like the login page reference in `session_html.ex`).
- `live/reactivation_live.ex` → fix the lone `text-gray-700`.
(May land as 2–3 sub-commits: org-switcher+sessions; mfa-settings; org-pages; challenge+sudo.)

### 4. Sudo dead-end fix (demo + Sigra installer + golden)
- Example `lib/example_web/auth_error_handler.ex` `:stale_sudo` → redirect to
  `~p"/users/sudo?return_to=…"` using the original `conn.request_path` (safe local
  path; `SudoController.create` already validates return_to and sends the user back).
- Installer template `priv/templates/sigra.install/core/error_handler.ex` — same fix
  (the bug lives here and propagates to all host apps). Confirm the installer also
  generates the `/users/sudo` route + `SudoController`; the redirect target must exist
  in generated apps.
- Regenerate the install golden fixture; keep phx_new **1.8.7** pinned (per CLAUDE.md).

### 5. Small fixes
- Remove the redundant in-page **Log out** in `AppLive` (keep the header one).
- Sessions realism (light): give the 3 seeded admin sessions believable device +
  geo labels in `lib/example/demo/seeds.ex` so `/users/sessions` reads real (the
  "Unknown device/IP" is dev having no UA-parser/GeoIP DB, not a bug). Optional.

## Verification
- **ExUnit**: full `test/example` suite green (update tests tied to the settings stub
  and to any `:stale_sudo`/redirect assertions). New SettingsLive test (email/password/
  delete/display-name happy paths + OAuth-only set-password branch). Brand-guard
  assertions where practical.
- **Installer**: `golden_diff_test`, `vault_promotion_test`, install fixtures green
  after the error_handler change + fixture regen.
- **Live on :4011** (curl + targeted checks — do NOT drive the user's browser):
  `/users/settings` renders real vt-branded email/password/preferences/delete forms;
  `/users/sessions` vt-branded; `/users/settings/mfa` with stale sudo → lands on a
  vt-branded `/users/sudo` carrying `return_to` → correct password → back to
  `/users/settings/mfa`; org switcher + org pages vt-branded; exactly one Log out.
- **Playwright** (`demo-showcase.spec.ts`): extend to assert authed screens are vt-*
  (no daisyUI `btn`/`menu`/`badge` leakage; settings shows `vt-panel`/`vt-form`; org
  switcher uses `vt-menu`).

## Scope notes
- Large, multi-screen effort — execute as sequenced commits via GSD, verifying each
  workstream before the next; the rebrand (WS3) is the bulk.
- Branding/`vt-*` work and the real settings page are **example-only** (host apps keep
  Tailwind). The **sudo fix is the one piece that propagates to the Sigra installer**
  + golden fixture (user-approved). Per the installer-template-drift rule, don't push
  the vt-* rebrand into `priv/templates/**`.
- Don't touch Dave's enumeration-safe lockout copy; the deferred `check_account_active`
  wiring (Frank/Grace reactivation) stays in its existing todo.
