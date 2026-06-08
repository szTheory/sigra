# Auth Branding

Sigra's generated auth screens and transactional emails are brandable out of the box. Fresh installs get a restrained, accessible default shell instead of unstyled white pages, plus a small token system that covers the common white-label case without taking ownership away from the host app.

Use this recipe when you want to adjust the generated login, registration, password reset, MFA, invitation, settings, OAuth settings, and auth email surfaces.

## Mental Model

Sigra supports three customization lanes:

| Lane | Use when | Where it lives |
|------|----------|----------------|
| **Defaults** | You just need auth in a Phoenix app and do not want to think about design yet. | Generated `SigraAuthComponents` and `priv/static/assets/sigra_auth.css`. |
| **Brand tokens** | You want product name, logo, colors, theme, legal links, and email sender details to match your app. | `Sigra.Config` `:branding` plus the generated `/admin/auth-branding` page. |
| **Full control** | You need a custom layout, design system, markup, CSS, or product-specific flow. | Edit the generated host templates/components/CSS directly. |

The token lane is deliberately constrained. It accepts safe design tokens and common product metadata, not arbitrary HTML or runtime CSS. That keeps pre-auth pages predictable and CSP-friendly while still making the usual white-label job easy.

## Generated Files

New installs include:

```text
lib/my_app_web/components/sigra_auth_components.ex
priv/static/assets/sigra_auth.css
priv/repo/migrations/*_create_sigra_brand_profiles.exs
```

When admin scaffolding is enabled, the installer also mounts:

```text
/admin/auth-branding
```

The auth wrapper is used by generated LiveViews and controller HTML templates. The stylesheet is scoped under `.sigra-auth` and uses CSS variables so it does not become the host app's design system.

## Config Defaults

Set the config defaults in the generated `sigra_config/0` or application config:

```elixir
config :my_app, :sigra_config,
  repo: MyApp.Repo,
  user_schema: MyApp.Accounts.User,
  branding: [
    product_name: "Acme",
    logo_url: "https://cdn.example.com/acme-mark.svg",
    logo_alt: "Acme logo",
    accent_color: "#0f766e",
    accent_foreground: "#ffffff",
    background_color: "#f7f4ee",
    surface_color: "#ffffff",
    text_color: "#171717",
    muted_color: "#6b6258",
    border_color: "#ded8cf",
    support_url: "https://example.com/support",
    privacy_url: "https://example.com/privacy",
    terms_url: "https://example.com/terms",
    email_from_name: "Acme",
    email_from_address: "auth@example.com",
    email_reply_to: "support@example.com",
    theme: :system
  ]
```

`theme` accepts `:system`, `:light`, or `:dark`. System mode follows `prefers-color-scheme`; explicit light or dark sets the auth shell's `data-theme`.

Color values must be six-digit hex strings. Blank optional fields are treated as `nil`.

## Admin Customizer

The generated admin page at `/admin/auth-branding` is for operators who need to tune the product identity without opening code. It edits one global brand profile stored in `sigra_brand_profiles`.

The page includes:

- Product name and optional logo URL.
- Light, Dark, and System mode selection.
- Accent, foreground, background, surface, text, muted, and border color tokens.
- Support, privacy, and terms links.
- Transactional email from name, from address, and reply-to.
- Live previews for an auth form and a transactional email.

The admin profile overrides config defaults. Resetting the profile deletes the global row so config becomes the source of truth again.

## Emails

Generated email templates read the same profile as the auth pages. The sender uses `Sigra.Branding.email_from/1`; the layout, logo/name header, CTA button, and footer links use the resolved profile.

Email clients do not support the same CSS capabilities as browsers, so emails intentionally use inline styles and simple table layout. Keep email branding conservative: high contrast, short product names, and absolute logo URLs.

## Text And Localization

Branding controls product identity and visual tokens; it does not own every
sentence in the auth flow. Generated auth templates use normal Phoenix HEEx and
the `sigra` Gettext domain for user-facing strings, so host apps can customize
wording by editing the generated templates or by maintaining locale files with
`mix gettext.extract` and `mix gettext.merge`.

Keep copy changes in generated host code when they affect product tone, legal
language, or locale-specific grammar. Use the admin branding page for the shared
product name, logo, theme, links, and email sender metadata.

## Full Control

If tokens are not enough, edit the generated host files:

```text
lib/my_app_web/components/sigra_auth_components.ex
priv/static/assets/sigra_auth.css
lib/my_app/accounts/emails.ex
lib/my_app_web/live/*
lib/my_app_web/controllers/*_html.ex
```

That is the advanced lane. Sigra will still supply library primitives for tokens, sessions, MFA, passkeys, OAuth, and plugs, but the host app owns the rendered experience.

Avoid runtime string injection for HTML/CSS. Prefer normal Phoenix components, HEEx templates, verified routes, and ordinary static assets.

## Testing

For browser tests, prefer stable hooks and roles:

```elixir
assert html =~ ~s(data-testid="admin-auth-branding-form")
assert html =~ ~s(data-testid="admin-auth-preview")
assert html =~ ~s(data-testid="admin-email-preview")
```

For unit tests, build profiles directly:

```elixir
profile = Sigra.Branding.from_config(branding: [product_name: "Acme", theme: :dark])

assert profile.product_name == "Acme"
assert profile.theme == :dark
```

Keep auth screenshots in light, dark, and system modes if your product depends on branded screenshots as release evidence.
