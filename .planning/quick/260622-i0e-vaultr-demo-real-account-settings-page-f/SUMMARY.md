---
quick_id: 260622-i0e
status: complete
date: 2026-06-22
---

# Vaultr demo: real account screens, vt-* brand coherence, sudo fix, product identity

## Problem
The `/app` hub routed personas into sub-screens that were a literal stub
(`/users/settings`), off-brand (daisyUI classes inert in the build-free
`--no-tailwind` demo → unstyled), or dead-ended (sudo). Vaultr's domain was vague.

## Decisions
- **Vaultr = a team credential/secrets vault** (the coherent product behind the
  orgs/roles/audit/MFA surfaces — no invented CRUD).
- **Sudo fix propagates to the Sigra installer** (real bug in every host app),
  not just the demo.

## What shipped (6 commits)
- **WS0 identity** (`eab0479f`): credential-vault copy across home hero/tags,
  layout/login brand tags, branding preset.
- **WS1 vt-* primitives** (`eab0479f`, `661e1407`): `.vt-form` fields, `.vt-alert`
  (info/warning/danger), `--vt-color-danger` + `.vt-btn--danger`/`--danger-solid`,
  `.vt-menu` dropdown + `.vt-avatar`, menu helpers.
- **WS2 real Settings** (`eab0479f`): replaced the stub with a working
  `<Layouts.app>` + vt-* page — Profile (display_name), Email (request + pending +
  cancel, with a real confirmation link delivered to the dev mailbox via new
  `/users/settings/confirm-email/:token`), Password (change / set), Delete account.
  Added `User.profile_changeset/2`, `Accounts.{change_display_name,
  update_display_name,deliver_email_change_confirmation}`.
- **WS3 rebrand** (`661e1407`, `3a91549a`, `bb63f21a`): org switcher, sessions,
  reactivation, sudo, organizations index/new/settings/members, MFA challenge, MFA
  settings → vt-*. Sessions/MFA-settings/org-pages that rendered with NO chrome now
  wrap in `<Layouts.app>`. Fixed a latent reactivation bug (log_out used `navigate`
  on a DELETE route → `href`+`method=delete`).
- **WS4 sudo dead-end** (`6dae6d1d`): `:stale_sudo` → `/users/sudo?return_to=<path>`
  (was `/users/log_in`, which bounced authed users to `/app`). Fixed in the example
  AND the installer template `priv/templates/sigra.install/core/error_handler.ex` +
  golden fixture; tests updated.
- **WS5** (`bb63f21a`): removed the redundant in-page Log out in AppLive.

## Verification
- `mix test` (example): **216 tests, 0 failures** (3 updated to new behavior:
  org zero-state copy, 2 stale-sudo redirects).
- Install golden diff: my `auth_error_handler` fixture edit matches byte-for-byte;
  the only diff is the **pre-existing** phx_new 1.8.8-vs-1.8.7 `config.exs`
  `root_tag_attribute` drift (CI pins 1.8.7, green) — not a regression.
- **Live on :4011** (admin): `/users/settings` (vt-form/panel), `/users/sessions`,
  `/organizations` all 200 + vt-*; `/users/settings/mfa` with stale sudo →
  **`/users/sudo?return_to=%2Fusers%2Fsettings%2Fmfa`** (the fix, end-to-end).

## Deferred (filed todo)
`vaultr-authed-rebrand-residuals`: MFA-settings deep enrollment sub-forms +
org-members `<dialog class="modal">` internals + invite form inputs still use some
daisyUI utilities (functional, partially styled); `mfa_challenge_html`/controller
(not router-wired) not rebranded; sessions seeded device/geo labels show "Unknown"
in dev (no UA-parser/GeoIP DB) — optional realism polish.
