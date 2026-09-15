---
created: 2026-09-15T00:00:00.000Z
status: pending
title: Branding profile has no dark_logo_url, so no logo value is correct in both themes
area: auth-ui
severity: major
files:
  - lib/sigra/branding/profile.ex
  - lib/sigra/branding.ex
  - lib/sigra/config.ex
  - lib/sigra/admin/components.ex
  - lib/sigra/admin/live/branding_live.ex
  - priv/templates/sigra.install/core/sigra_auth_components.ex
  - priv/templates/sigra.install/core/emails.ex
  - guides/recipes/auth-branding.md
source: 2026-09-15 — reported by an early adopter integrating Sigra into a production app; verified against main 1afd37f0
related:
  - .planning/todos/pending/2026-06-22-white-label-auth-email-theming.md
---

## What

`Sigra.Branding.Profile` carries seven theme-specific `dark_*` colour tokens but a
single `logo_url` / `logo_alt` pair shared by both themes. Theme-dependent *colour*
was designed for; theme-dependent *imagery* was not. There is no occurrence of
`dark_logo_url` anywhere in `lib/`.

Brands ship logos as positive and reversed variants. A host that has only a reversed
(near-white) mark renders correctly on Sigra's dark theme and effectively invisibly on
the light-theme background, which defaults to a warm off-white. The inverse holds for a
host with only a positive mark. **There is no value of `logo_url` that is correct in
both themes**, so this has no config-level workaround.

The reported real-world consequence: the adopter set no logo at all and accepted
Sigra's placeholder mark on a production login page. That is the part worth weighting —
the missing token is not cosmetic polish, it is the reason a live product is shipping
unbranded auth.

## Solution

Add `dark_logo_url`, falling back to `logo_url` when unset — the same fallback shape
every colour token already uses. Consider whether `dark_logo_alt` is warranted or
whether alt text is legitimately theme-independent (it likely is; prefer the smaller
surface unless there is a real case).

### Rendering is the non-obvious part

Colour tokens can resolve server-side because they are emitted as CSS custom properties
under both a light and a dark block, so `theme: :system` is settled in the browser by
`prefers-color-scheme`. **An `<img src>` cannot be swapped by a CSS custom property the
same way.** So:

- When `theme` is `:system` *and* the resolved light/dark logo URLs differ, render
  `<picture>` with `<source media="(prefers-color-scheme: dark)">` and an `<img>`
  fallback.
- When `theme` is pinned to `:light` or `:dark`, or both URLs resolve the same, render
  a plain `<img>` — no reason to pay for `<picture>`.
- **Email HTML should not use `<picture>`.** `prefers-color-scheme` support across mail
  clients is poor and inconsistent; the email layout should resolve one logo. Decide and
  document which (pinned theme when set, else the light variant). This overlaps the
  dark-theme-email thread in the related white-label email theming todo — worth reading
  that before implementing so the two do not contradict each other.

### Surface to change

- `lib/sigra/branding/profile.ex` — `@type t`, `@defaults`, `validate_optional_string/2`
  call, and `to_map/1` round-trip.
- `lib/sigra/config.ex` — the NimbleOptions `branding` schema. Note the key list appears
  in **two** places in this file; both need the new key or the docs and validation drift.
- `lib/sigra/branding.ex` — a resolver for the theme-appropriate logo, mirroring
  `color_tokens/2`.
- `lib/sigra/admin/components.ex` — the logo render (`sigra-auth__logo` /
  `sigra-auth__mark` fallback) and the branding form field.
- `lib/sigra/admin/live/branding_live.ex` — the permitted-field list and the form input.
- `priv/templates/sigra.install/core/sigra_auth_components.ex` and `.../core/emails.ex` —
  the generated host copies. These drift from the hand-maintained `test/example/`; keep
  both in step.
- `test/fixtures/install_golden/tree/**` — golden regeneration. Requires the pinned
  `phx_new 1.8.8` archive locally or `golden_diff_test` fails on spurious byte diffs.
- `guides/recipes/auth-branding.md` — document the new token and the `<picture>` behavior.

## Why it matters beyond one adopter

Every host with a real brand hits this the moment they enable both themes. The current
shape quietly forces a choice between "wrong logo in one theme" and "no logo at all",
and the second is what a careful integrator will pick.

## Resolved design questions (adopter answered 2026-09-15)

Three open questions were put back to the reporting adopter. All three are now settled,
and one of them is a hard constraint that the obvious implementation would violate.

### 1. Email must resolve the LIGHT slot only — never fall back to the dark asset

**This is a must-have, not a preference.** The email path must resolve `logo_url` and
only `logo_url`, and must degrade to the placeholder/wordmark when it is unset. It must
**not** reach for `dark_logo_url` under any "use whichever one is set" rule.

The reason is the exact asymmetric case this feature exists to serve. A host whose only
logo asset is a one-colour reversed (near-white) mark will, after this change, set
`dark_logo_url` and deliberately leave `logo_url` unset — that is the *correct* use of
the new token, and the dark-to-light fallback direction is wanted on the auth screens.
But if the email layout resolves "whichever logo is set", that host gets a white mark on
a white email surface in every transactional email: invisible, and strictly worse than
the placeholder, because a blank space where a logo should be reads as a broken image
rather than as a deliberate neutral mark.

So the fallback is **directional, not symmetric**:
- Auth screens: dark slot falls back to light slot (and vice versa) — fine, because the
  surface behind it is theme-matched.
- Email: light slot only, degrade to placeholder when unset — because the email surface
  is effectively always light regardless of the reader's OS theme.

Optional additive escape hatch, if a configurable email logo is ever wanted: an
`email_logo_url` falling back to `logo_url`, matching the shape of everything else here.
Not required — the must-have is only that email never silently uses the dark asset.

### 2. `<picture>` is unconstrained — ship it

No CSP, CDN, or image-proxy constraint on the adopter's side (verified against their
source, not assumed). `<picture>` with `<source media="(prefers-color-scheme: dark)">` is
fine to emit.

Caveat worth recording: this adopter renders their **own** copy of the generated auth
component rather than Sigra's, driving it from profile tokens via
`Sigra.Branding.css_variables/1`. So they are not a `<picture>` consumer today — the
emission reaches them only if they later re-adopt the generated component. Two things
follow: (a) `css_variables/1` is live public API for at least one real host, treat it as
such; (b) the installer-template change still matters to them as the thing they would
re-adopt, so it should not be treated as lower priority than the lib change.

### 3. No `dark_logo_alt` — ship without it

Confirmed. Their positive and reversed marks are the same mark in different colourways,
so alt text is identical by construction. The case that *would* break that theory — a
host shipping a full wordmark for light and a glyph-only mark for dark — is real but
hypothetical here, and not worth the surface until someone actually has it. Revisit only
against a concrete report.

### Rejected interim workaround, recorded so it is not re-suggested

Setting `logo_url` to the reversed variant and pinning `theme: :dark` until the release
lands was offered and **declined**, correctly: pinning the theme forces dark auth screens
on every user including those who prefer light — a product-wide behavior change to work
around a branding gap on one surface. The neutral placeholder is the cheaper and more
honest interim state. Do not re-propose theme pinning as a workaround for a logo gap.
