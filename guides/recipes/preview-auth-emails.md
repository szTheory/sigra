# Preview the auth emails

Sigra sends 18 distinct auth-related emails. Before customizing copy, layout, or templates, you'll want to *see* what each one looks like. This recipe covers two preview paths — one for live development, one for snapshot review.

> **Active milestone signal:** EMAIL-RAILS is the current milestone, and a browser-accessible email-preview catalog is one of its named deliverables (SEED-008). Until that ships, the workflow below is the supported path.

---

## The full email catalog

Sigra's generated mailer (`Example.Accounts.Emails` in the example app) ships these 18 emails:

| Category | Email |
|---|---|
| **Onboarding** | Confirmation (link + code), Magic link |
| **Account security** | Password reset, Password changed, Suspicious login, Lockout notification |
| **MFA lifecycle** | MFA enabled, MFA disabled, MFA lockout, Backup-code used |
| **Passkeys** | Passkey registration |
| **Email change** | Email-change confirmation, Email-change notification, Email changed |
| **Account lifecycle** | Deletion scheduled, Deletion cancelled, Deletion finalized |
| **OAuth-only flows** | OAuth-only password-reset request guidance |
| **Multi-tenant** | Organization invitation |

## Path 1 — Live preview during dev

The example app uses Swoosh's local adapter in dev (`config :example, Example.Mailer, adapter: Swoosh.Adapters.Local`). Every email is captured in memory and visible at:

```
http://localhost:4000/dev/mailbox
```

**Workflow:**

1. Boot the example app — `cd test/example && mix phx.server`
2. Trigger the flow whose email you want to see (register an account → confirmation; request password reset → reset link; enable MFA → MFA-enabled notification; etc.)
3. Refresh `/dev/mailbox` — the email appears in the inbox with HTML and plaintext renderings

This is the easiest path for "what does *this specific* email look like in *this specific* state." It's how you'd validate copy changes during a live dev session.

## Path 2 — Frozen snapshot review

For visual-regression review or "show me all 18 at once," Sigra ships a snapshot task:

```bash
cd test/example
mix sigra.email.snapshot
```

This regenerates HTML fixtures into `test/example/priv/email_snapshots/` covering the 9-template matrix used by Playwright visual-regression tests. Open any of the generated `.html` files in your browser to see the rendered email.

Use this when:
- Reviewing a copy change across all emails
- Verifying a layout tweak didn't break unrelated templates
- Sharing email previews with a designer or copywriter without spinning up the full app

The frozen snapshots are committed; CI re-runs the task and diffs to detect regressions.

## Customizing the email body or layout

Auth emails are *generated* into your host app, not bolted into the library. Each email lives as a function in your generated `MyApp.Accounts.Emails` (or `MyApp.MailerNotifier`) module — find it, edit it, ship it.

For the underlying template the function renders, look in `lib/my_app_web/templates/` (controller-style) or inline HEEx in the email function (LiveView-style, depending on which generator flag you used).

Override seam pattern:

```elixir
# Generated into lib/my_app/accounts/emails.ex
def confirmation_email(user, url) do
  new()
  |> to(user.email)
  |> from({"Acme", "no-reply@acme.com"})
  |> subject("Welcome to Acme — confirm your email")
  |> html_body(confirmation_html(user, url))
  |> text_body(confirmation_text(user, url))
end
```

Edit any of `to/from/subject/html_body/text_body` to customize. The library never re-emits this file — your edits stick.

## Coming soon — browser preview catalog

EMAIL-RAILS' planned scope (see `.planning/MILESTONE-ARC.md`) includes a dev-only LiveView at `/dev/sigra/emails` that lists all 18 templates with sample data and toggles for dark mode, locale, and variant. The current recommendation is to evaluate Mailglass adoption (SEED-005) first — Mailglass already ships an admin/preview LiveView for transactional email. Track:

- **SEED-005** — `.planning/seeds/SEED-005-mailglass-mailer-adapter.md`
- **SEED-008** — `.planning/seeds/SEED-008-email-preview-catalog.md`

Until then, paths 1 and 2 above are the supported preview surfaces.
