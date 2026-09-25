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
    dark_logo_url: "https://cdn.example.com/acme-mark-reversed.svg",
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

## How Dark-Theme Tokens Resolve

Every `dark_*` token is optional. What happens when you leave one unset differs by
token, and the difference is deliberate — so it is written down here rather than left
to be discovered at the point of use.

### Neutrals fall back to Sigra's dark defaults

`dark_background_color`, `dark_surface_color`, `dark_text_color`, `dark_muted_color`
and `dark_border_color` fall back to Sigra's own dark palette. Your light neutrals are
not reused; a light background is not a dark background.

### The accent is fitted to your dark surface

`dark_accent_color` behaves differently, because an accent carries brand identity in a
way a neutral does not. If you leave it unset:

1. If your `accent_color` already meets 4.5:1 contrast against the resolved dark
   surface, it is used **unchanged**. Your brand colour survives untouched wherever it
   is not actually broken.
2. If it does not, Sigra lightens it by the smallest amount that reaches the target,
   changing lightness only. Hue and saturation are preserved, so the result still reads
   as your colour rather than a generic token.

This matters because most brands pick one accent against their *light* surface and
never choose a second. Reusing that value verbatim on a near-black surface is how a
perfectly legible brand colour becomes an illegible one.

Setting `dark_accent_color` explicitly disables this entirely — an explicit value is
always authority and is never adjusted. The admin customizer shows which of the three
paths applied (explicit, inherited unchanged, or derived), so you can see the resolved
value before deciding whether to pin it.

`accent_foreground` is re-derived only when the derivation broke a pairing that
previously worked. If your foreground was already below target against your own light
accent, that is treated as your choice and is left alone.

## Light and Dark Logos

`logo_url` is the canonical asset. `dark_logo_url` is an optional override used when the
dark theme is active. The fallback is **directional, not symmetric**:

| Surface | Resolves |
|---|---|
| Light auth screen | `logo_url` only |
| Dark auth screen | `dark_logo_url`, falling back to `logo_url` |
| Transactional email | `logo_url` only |

Light deliberately does **not** fall back to `dark_logo_url`. If your only asset is a
reversed, near-white mark, set `dark_logo_url` and leave `logo_url` unset — that is the
intended use. Falling back the other way would paint that near-white mark onto a light
background, which reads as a broken image. Sigra renders its neutral placeholder mark
instead, which is the honest result until you have a positive variant to supply.

**Email always uses `logo_url`, even when `theme` is pinned to `:dark`.** Transactional
email renders on an effectively light surface whatever the reader's OS theme is, and
`prefers-color-scheme` support across mail clients is too inconsistent to vary the asset
on. If `logo_url` is unset, email falls back to the product-name wordmark rather than to
your dark asset.

### How the theme switch is rendered

When `theme` is `:light` or `:dark`, the logo resolves on the server and one `<img>` is
rendered. When `theme` is `:system` and the two themes resolve *different* assets, the
generated component renders both slots, tagged `data-sigra-logo-slot="light"` and
`data-sigra-logo-slot="dark"`, and the stylesheet shows the right one via
`prefers-color-scheme`.

`<picture>` with a dark `<source>` is the obvious approach and is not used, because it
cannot express "placeholder mark in light, logo in dark" — which is exactly the
configuration of a host whose only asset is reversed. If you have replaced the generated
component with your own, `Sigra.Branding.logo/2` and `Sigra.Branding.email_logo/1` give
you the same resolution rules without the markup.

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
