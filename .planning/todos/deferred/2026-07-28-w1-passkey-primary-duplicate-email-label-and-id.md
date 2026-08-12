---
created: 2026-07-28T00:00:00.000Z
status: pending
title: Passkey-primary login renders two identically-labelled email fields, and four inputs share id="user_email"
area: auth-ui
severity: high
audit_finding: W-1
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [AUTHUI-02, AUTHUI-04, PROOF-03]
files:
  - priv/templates/sigra.install/core/login_html.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/session_html.ex
  - test/sigra/install/generator_passkey_primary_login_test.exs
plan_ready: .planning/quick/260728-d9h-fix-passkey-primary-email-label-and-id/260728-d9h-PLAN.md
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

Two distinct defects on the same page, both in the `@passkey_primary_enabled` branch of
the generated login template.

**(a) Duplicate visible label.** `login_html.ex:44` (the primary passkey form's email
input) is labelled `dgettext("sigra", "Email")`. `password_form/1` at `:111` — rendered at
`:75` inside the collapsed `<details class="sigra-auth-disclosure">` — carries the
identical label. Expanding "Other ways to sign in" produces exactly the collision the
project owner rejected during PROOF-03 visual review of the *non*-passkey branch.

Quick task `260727-v15` (PR #113, `743864c0`) fixed the sibling `<%% else %>` branch only.
The two magic-link forms it touched are mutually exclusive branches, so the passkey
configuration was never covered.

**(b) Duplicate DOM id — broader than (a), and pre-existing.** `@form` and
`@magic_link_form` are *both* built with `as: "user"` (`session_controller.ex:28-29`), so
**every** `f[:email]` on the page derives `id="user_email"`. In the passkey branch that is
four inputs: `:44` (passkey), `:68` (magic link), `:111` (password), and `:136`
(`enterprise_form/1`). The else branch has the same problem at lower count.

This was mis-scoped in the original audit write-up as a two-input passkey-vs-password
collision. It is not — it is a page-wide id cluster that predates v1.46 and that the
v1.46 work neither introduced nor touched.

## Why it was NOT fixed during v1.46 close-out

Owner decision on 2026-07-28: file it with W-2…W-8 and close the milestone rather than
extend close-out scope. Supporting factors:

- `passkey_primary_enabled?` defaults to `false` (`core/auth.ex:831`).
- No browser lane renders this composition — the acceptance smoke installs
  `--no-passkeys` (`scripts/ci/admin-acceptance-smoke.sh:125`), so a fix would ship with
  static proof only.
- Fixing (a) alone takes the id cluster 4 → 3, which closes the label collision but leaves
  a page-wide "no duplicate ids" assertion still failing. Half-fixing invites a repeat of
  the same partial-coverage mistake.

## Recommended fix

A plan is already written and re-verified against the tree — see `plan_ready` above. It is
**scoped to (a) only**; read its "Verified facts" section before touching anything, and
decide deliberately whether to widen to (b).

For (a), template line 44 becomes:

```elixir
<.input field={f[:email]} id="passkey_login_email" type="email" label={dgettext("sigra", "Email for passkey sign-in")} autocomplete="username webauthn" required />
```

Established constraints, all confirmed:

- Explicit `id` wins and stays label-associated — stock phx 1.8 `.input` assigns
  `id: assigns.id || field.id` and renders `<label for={@id}>`.
- `name` is derived separately and stays `user[email]`, so the passkey JS still resolves
  it: `findEmailInput/2` (`passkey_browser.js:114-127`) is `form.querySelector` on
  `input[name='user[email]']:not([data-passkey-email-shadow])`, never id-scoped.
- No ExUnit or Playwright selector needs changing. `admin-generated.spec.ts:71` scopes
  `getByLabel("Email", {exact: true})` to `#login_form` (= `password_form/1`, unchanged);
  the other three sites are on the invitation-accept page.
- `dgettext("sigra", …)` needs no catalog work — the `sigra` domain ships no catalog
  beyond `errors.{pot,po}`.
- Mirror into the golden fixture (anchor on `id="passkey_login_form"`, not line number)
  and prove with `MIX_ENV=test mix sigra.fixture.rebless_golden --check` exit 0.

For (b), the real question is whether `@magic_link_form` and `@form` should stop sharing
`as: "user"`, or whether each form should pass explicit input ids. That is a design call,
not a mechanical fix.

Do **not** restructure toward the example app's hidden-shadow-input pattern
(`test/example/lib/example_web/controllers/session_html.ex:112`). It works there because
the example's visible login form is top-level; here the password form sits inside a
collapsed `<details>`, so pointing the primary passkey action at it would be worse UX.

## Related

- [[2026-07-27-login-wordmark-midword-break-at-320]] — the other deferred PROOF-03 finding.
- W-3 in the same audit — the absent browser coverage that let this survive PR #113.
