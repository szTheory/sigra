---
id: SEED-003
status: deferred
planted: 2026-06-08
planted_during: v1.37 auth branding polish
trigger_when: Before adding admin-managed auth copy overrides, locale-aware auth routing, or multi-language auth/email customization
scope: Medium
---

# SEED-003: Auth Copy And Locale Hardening

## Why This Matters

The v1.37 auth branding pass made generated auth screens and emails brandable through validated visual/product tokens. It deliberately kept user-facing wording in generated Phoenix templates and Gettext files instead of adding a runtime copy map to `Sigra.Branding.Profile`.

That is the right default for Phoenix: host apps own generated templates, links, legal language, and product-specific tone. A future milestone may still need a more complete i18n and copy-management story for teams that want admin-managed wording or multi-language auth/email flows.

## When to Surface

Surface this seed when a milestone mentions any of:

- admin-managed auth text
- custom login/register/reset copy without editing templates
- multi-language generated auth screens
- locale-specific transactional emails
- RTL auth UI
- per-organization auth wording

Do not surface it for ordinary visual branding changes. Product name, logo, colors, links, and email sender details are already covered by `Sigra.Branding.Profile`.

## Candidate Scope

- Audit generated login, registration, confirmation, reset, MFA, passkey, OAuth, invitation, and email templates for complete `dgettext("sigra", ...)` coverage.
- Document locale setup for controller requests, LiveView mounts, and transactional email generation.
- Add or verify generated Gettext catalogs and `mix gettext.extract` / `mix gettext.merge` workflow.
- Decide whether admin-managed copy is worth supporting. If yes, use semantic, validated keys with Gettext fallback rather than arbitrary HTML or loose string maps.
- Define how localized custom links, legal copy, and RTL direction interact with generated auth layouts.

## Breadcrumbs

- `guides/recipes/auth-branding.md` — current three-lane branding model and text/localization note.
- `priv/templates/sigra.install/core/login_html.ex` — login copy now uses the `sigra` Gettext domain.
- `priv/templates/sigra.install/core/emails.ex` — email templates already combine branding tokens and Gettext strings.
- `lib/sigra/branding/profile.ex` — visual/product token schema; do not add copy fields without revisiting this seed.
