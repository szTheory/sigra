---
id: white-label-auth-email-theming
created: 2026-06-22
source: user report (demo /dev/mailbox screenshot — "emails are not really styled")
severity: enhancement
area: lib/sigra email templates + priv/templates/sigra.install/core/emails.ex + Mailglass recipe
---

# White-label themeable transactional auth emails (+ Mailglass refresh)

Sigra's account/auth transactional emails (confirmation, reset, email-change, magic
link, suspicious-login, lockout, deletion, password-changed) should be **white-label
themeable to the same standard as the login/auth screens** — not just a handful of
inline color tokens. Captured for future work; not urgent.

## Three threads

### 1. (Quick win) Fix the demo email drift
`test/example/lib/example/accounts/emails.ex` hardcodes colors + a literal "Example"
wordmark and never calls its `branding()` helper, so the Tasklane demo's emails look
unstyled and off-brand (this is what the user's screenshot shows). Re-sync the example
emails module with the brand-aware installer template (`priv/templates/sigra.install/
core/emails.ex`) so demo emails render the Tasklane profile (logo + teal accent). This
alone makes the demo mailbox look real and is independent of the bigger effort.

### 2. (Main ask) White-label email theming to login-parity
Elevate the email layout (`base_layout/1`, `cta_button/2`, `email_logo_or_name/1` in the
installer template + the `Sigra.EmailTemplates` / `Sigra.Branding` contract) so emails
are themeable like the auth pages:
- Honor the **logo** + full brand palette consistently (today logo only renders if
  `logo_url` is set; demo falls back to a text wordmark).
- Support a **dark-theme email variant** (emails currently use light-theme colors only,
  ignoring the dark profile the login screens support).
- Consider additional email-safe brand tokens (CTA radius, logo width, card treatment)
  and an optional **custom-layout override hook** on `Sigra.EmailTemplates` so host apps
  can fully replace email HTML — and document it (today host apps can edit the generated
  `Emails` module, but it isn't surfaced as a theming path).
- Keep it email-client-safe (inline styles, table layout, Outlook-tested) per
  `doc/auth-branding.md`.

### 3. (Sub-ask) Refresh Mailglass to latest + evaluate as the theming vehicle
- Sigra's Mailglass posture is **recipe-only host-owned wiring** via `Sigra.Mailer`
  (`guides/recipes/companion-libs/mailglass.md`) — confirmed still the supported posture
  (no library adapter, no `--with-mailglass`; PROJECT.md v1.29 corrigendum).
- The recipe pins `mailglass ~> 1.2` (validated 2026-05-27); **latest is 1.8.0
  (2026-06-21)**. Bump the recipe to `~> 1.8` and **re-validate** against 1.8.0.
- Mailglass 1.8 ships **HEEx email components (Outlook-safe) + a LiveView dashboard** —
  evaluate whether routing Sigra's themeable emails through Mailglass's HEEx components
  (in the recipe / host-owned mailer) is the cleanest path to login-parity white-label,
  vs. extending Sigra's own inline-HTML layout. Decide the recommended posture and
  document it; do NOT re-land a library-resident adapter unless that decision is revisited.

## Key files
- `priv/templates/sigra.install/core/emails.ex` (brand-aware installer email layout)
- `test/example/lib/example/accounts/emails.ex` (stale/hardcoded demo emails)
- `lib/sigra/email_templates.ex`, `lib/sigra/branding/profile.ex`, `lib/sigra/branding.ex`,
  `lib/sigra/mailer.ex`, `lib/sigra/delivery.ex`
- `guides/recipes/companion-libs/mailglass.md`, `doc/auth-branding.md`

## Acceptance (when tackled)
Demo mailbox emails render the active brand (logo + palette, light & dark); a documented
override hook exists; the Mailglass recipe references `~> 1.8` and is re-validated; a
clear "Sigra emails vs Mailglass HEEx components" theming recommendation is documented.
