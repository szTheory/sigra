---
created: 2026-09-15T00:00:00.000Z
status: pending
title: Dark token fallback is asymmetric, so the default dark theme is a palette nobody chose
area: auth-ui
severity: minor
files:

  - lib/sigra/branding.ex
  - guides/recipes/auth-branding.md

source: 2026-09-15 — reported by an early adopter integrating Sigra into a production app; verified against main 1afd37f0
related:

  - .planning/todos/pending/2026-09-15-branding-profile-has-no-dark-logo-url.md

audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
---

## What

In `Sigra.Branding.color_tokens/2`, the `:dark` clause resolves an unset `dark_*` token
**two different ways depending on which token it is**:

```elixir
accent_color:     profile.dark_accent_color || profile.accent_color,

# ^ falls back to the host's LIGHT value

background_color: profile.dark_background_color || Map.fetch!(@dark_color_defaults, :background_color),

# ^ falls back to SIGRA's DARK default

```

Accent and accent-foreground inherit the host's light values; the five neutrals
(background, surface, text, muted, border) inherit Sigra's dark defaults.

Each rule is individually defensible. The composite is not. A host that sets only
`accent_color` — the most likely configuration, and the starting point the branding
guide documents — gets **their light-tuned accent against Sigra's dark neutrals**. An
accent chosen to sit on a warm off-white is not an accent chosen to sit on a near-black
surface; contrast and saturation both land wrong.

The problem is not that this is possible, it is that it is the **default** rather than
an opt-in, and it is reached by following the documented happy path. At the point of use
it reads as a bug even though both halves are intentional.

## Solution

**Decided: contrast-aware derivation.** For an unset `dark_accent_color`:

1. Compute the contrast of the host's `accent_color` against the *resolved* dark surface
   (resolved, not the default — the host may have set `dark_surface_color`).
2. If it already meets the contrast target, keep the host's accent unchanged. Brand
   fidelity wins whenever it is not actually broken.
3. Otherwise lighten it **minimally** until it passes — preserve hue and as much
   saturation as possible so it still reads as the brand colour, rather than snapping to
   a generic token.
4. Re-derive `accent_foreground` (black vs white) against the *adjusted* accent, since an
   adjusted accent can flip which foreground is legible. Do this only when
   `dark_accent_foreground` is unset; an explicit host value is authority.

Pure Elixir, no new dependency — relative luminance and a contrast ratio are a few lines,
and lightness adjustment is straightforward in HSL/OKLCH.

### Why this over the alternatives

- **A Sigra dark-accent default** (symmetric with the neutrals) is simpler and more
  predictable, but a host that set `accent_color` and nothing else would lose their brand
  colour entirely in dark mode. That trades one surprising default for another, and the
  new one discards information the host explicitly gave us.
- **Documenting it only** is the cheapest, but the adopter's point stands: they read the
  code, understood both halves were intentional, and still filed it. Documentation does
  not fix a default that is wrong on the documented path.

### Notes for implementation

- An explicitly-set `dark_*` value must always win untouched. Derivation applies only to
  the unset case.
- Derivation must be deterministic and cheap — `color_tokens/2` is on the pre-auth render
  path, so no surprises there.
- Worth exposing the derived result in the admin branding UI so an operator can see what
  dark mode will actually use and override it if they disagree.
- Document the final rule in `guides/recipes/auth-branding.md` at the point of use. Even
  with derivation in place, the resolution order should be written down.

## Adopter confirmation (2026-09-15)

The reporting adopter confirmed they will leave `dark_accent_color` **unset** and let the
derivation run, rather than pinning a value. Their reasoning is worth keeping, because it
validates the design choice and tells us what makes it acceptable:

- Their accent was chosen against a warm off-white light surface. They have no
  independently-chosen dark accent, so a derived value is better-founded than anything
  they would guess today. This is the common case, not an unusual one — hosts pick one
  brand accent against their light surface and have never had reason to choose a second.
- **Surfacing the derived value in the admin branding UI is explicitly what makes the
  derivation safe for them to accept.** They intend to review the derived result there
  and pin explicitly only if they dislike it. So the admin-UI surfacing is not a nice-to-
  have that can be dropped to a follow-up — it is the escape hatch that makes automatic
  derivation trustworthy rather than magic. Treat it as in-scope with the derivation.
- They independently reached the same rejection of the "Sigra dark-accent default" option
  and for the same reason: discarding a brand colour the host explicitly supplied is the
  worse default.

Confirms the `explicit value always wins untouched` rule matters in practice — it is the
thing that lets a host opt out of derivation after reviewing it.
