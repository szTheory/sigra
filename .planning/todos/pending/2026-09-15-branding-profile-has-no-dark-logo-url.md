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
