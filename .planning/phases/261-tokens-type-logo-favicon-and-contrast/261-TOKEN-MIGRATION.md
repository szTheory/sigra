# Phase 261: Token Migration (old to new)

The one reviewed old-to-new table for the Kiln token values (BTOK-01, BTOK-08). It is applied by hand to `priv/templates/sigra.install/admin/sigra_admin.css` and enforced by `test/sigra/brand/token_migration_test.exs`, which parses the table below, compares every row with what the stylesheet declares in the right block, and fails when the two diverge. Token names are frozen (ADR 005): values change and names are only added.

Cell vocabulary (the test reads exactly this):

- A cell holding a value is one backticked literal: a hex, an `rgba()`, a number, a font stack or the focus ring string.
- `kept` (in a New column): the value is unchanged. The Old column holds the literal it keeps.
- `inherited` (Old dark): the dark `@media` block did not declare the token at HEAD, so dark took the `:root` value.
- `none` (Old columns): the token did not exist.
- `n/a`: the token has no dark column (weights, theme-invariant font tokens).

Disposition is one of `changed`, `kept, no book equivalent`, `forced`, `additive`, `deferred:261-04`. Source is the `brand/tokens.json` path, or the two named source-gap citations: dark selected `#33281F` is read from `brand.json contrastPairs[selected-row]` (the `tokens.json` file has no entry for it) and dark control edge `#8B7D72` is read from `BRAND.md control-edge` (the book states it in prose and in the contrast notes only). Each literal is held once and never invented.

The two font rows were `deferred:261-04` until plan 261-04 shipped their declarations; both now read `additive`, and the test compares their New light cell with the `:root` value (New dark is `n/a`: theme-invariant).

## Old to new table

| Token | Old light | New light | Old dark | New dark | Source | Disposition |
|-------|-----------|-----------|----------|----------|--------|-------------|
| `--sg-weight-regular` | `450` | `400` | n/a | n/a | book type rules allow 400, 600 and 700 only; tokens.json has no weight token | changed |
| `--sg-weight-medium` | `600` | kept | n/a | n/a | book type rules allow 400, 600 and 700 only; tokens.json has no weight token | kept, no book equivalent |
| `--sg-weight-semibold` | `700` | kept | n/a | n/a | book type rules allow 400, 600 and 700 only; tokens.json has no weight token | kept, no book equivalent |
| `--sg-weight-bold` | `800` | `700` | n/a | n/a | book type rules allow 400, 600 and 700 only; tokens.json has no weight token | changed |
| `--sg-color-ink` | `#151515` | `#1F1A17` | `#f4f1eb` | `#F3EEE8` | color.light.soot / color.dark.chalk | changed |
| `--sg-color-muted` | `#686868` | `#5F554D` | `#bdb5aa` | `#B8ABA0` | color.secondary.muted-soot / color.secondary.muted-chalk | changed |
| `--sg-color-subtle` | `#f6f5f2` | `#F7F3EE` | `#171614` | `#17120F` | color.light.paper / color.dark.char | changed |
| `--sg-color-panel` | `#ffffff` | kept | `#1f1d1a` | `#221B17` | color.light.white / color.dark.char-surface | changed |
| `--sg-color-panel-alt` | `#fbfaf7` | kept | `#25221e` | kept | no book equivalent | kept, no book equivalent |
| `--sg-color-line` | `rgba(21, 21, 21, 0.1)` | `#DDD3C8` | `rgba(255, 255, 255, 0.1)` | `#3A2F28` | color.light.paper-line / color.dark.char-line (becomes opaque) | changed |
| `--sg-color-line-strong` | `rgba(21, 21, 21, 0.16)` | kept | `rgba(255, 255, 255, 0.16)` | kept | no book equivalent; control edges move to `--sg-color-control-edge` | kept, no book equivalent |
| `--sg-color-brand` | `#c2410c` | kept | inherited | `#F08A55` | color.light.kiln / color.dark.kiln-bright | changed |
| `--sg-color-brand-strong` | `#9a3412` | kept | `#fdba74` | `#F08A55` | color.secondary.kiln-deep / color.dark.kiln-bright | changed |
| `--sg-color-brand-solid` | `#9a3412` | kept | `#fdba74` | `#F08A55` | color.secondary.kiln-deep / color.dark.kiln-bright | changed |
| `--sg-color-brand-fill-hover` | `#c74712` | kept | `#c74712` | `#F4A27C` | color.code.keyword-dark (Char on the old dark fill is 3.84:1; on this 9.12:1) | forced |
| `--sg-color-brand-fill-active` | `#9a3412` | kept | `#9a3412` | `#E07A45` | derived, no tokens.json entry: a darker Kiln Bright (Char on the old dark fill is 2.54:1; on this 6.23:1) | forced |
| `--sg-color-brand-soft` | `#fff0e8` | kept | `rgba(243, 90, 16, 0.16)` | kept | no book equivalent | kept, no book equivalent |
| `--sg-color-on-brand` | `#ffffff` | kept | inherited | `#17120F` | color.dark.char (Char on Kiln Bright is 7.50:1; white is 2.48:1) | changed |
| `--sg-color-on-brand-solid` | `#ffffff` | kept | `#151515` | `#17120F` | color.dark.char | changed |
| `--sg-logo-rail-accent` | `#fdba74` | kept | inherited | kept | no book equivalent; fills the theme-switch active segment | kept, no book equivalent |
| `--sg-logo-rail-ember` | `#c2410c` | kept | `#f97316` | `#F08A55` | color.logo.kiln / color.logo.kiln-bright (no CSS consumer; name frozen) | changed |
| `--sg-logo-core` | `#9a3412` | `#1F1A17` | `#f4f1eb` | `#F3EEE8` | color.light.soot / color.dark.chalk (no CSS consumer; name frozen) | changed |
| `--sg-color-risk` | `#b42318` | kept | `#f8a39c` | kept | no book equivalent; the ember-parity assertion pins it to sigra_auth.css | kept, no book equivalent |
| `--sg-color-risk-soft` | `#fff1f0` | kept | `rgba(248, 113, 113, 0.16)` | kept | no book equivalent | kept, no book equivalent |
| `--sg-color-warn` | `#a15c00` | kept | `#f5c451` | kept | no book equivalent; the ember-parity assertion pins it to sigra_auth.css | kept, no book equivalent |
| `--sg-color-warn-soft` | `#fff7e6` | kept | `rgba(245, 196, 81, 0.16)` | kept | no book equivalent | kept, no book equivalent |
| `--sg-color-ok` | `#176b43` | kept | `#5dd1a0` | kept | no book equivalent; the ember-parity assertion pins it to sigra_auth.css | kept, no book equivalent |
| `--sg-color-ok-soft` | `#ecfdf3` | kept | `rgba(52, 211, 153, 0.16)` | kept | no book equivalent | kept, no book equivalent |
| `--sg-color-info` | `#1d4ed8` | kept | `#9db8f5` | kept | no book equivalent | kept, no book equivalent |
| `--sg-color-info-soft` | `#eef2ff` | kept | `rgba(120, 150, 245, 0.16)` | kept | no book equivalent | kept, no book equivalent |
| `--sg-focus-ring` | `0 0 0 3px color-mix(in oklab, var(--sg-color-brand) 35%, transparent)` | `0 0 0 var(--sg-focus-ring-offset) var(--sg-color-subtle), 0 0 0 calc(var(--sg-focus-ring-offset) + 2px) var(--sg-color-brand-strong)` | inherited | `0 0 0 var(--sg-focus-ring-offset) var(--sg-color-subtle), 0 0 0 calc(var(--sg-focus-ring-offset) + 2px) var(--sg-color-brand-strong)` | brand.json contrastPairs[focus] (the old 35% halo is 1.67:1 on Paper; the ring is Kiln Deep 6.61:1 light, Kiln Bright 7.50:1 dark) | forced |
| `--sg-focus-ring-offset` | `2px` | kept | inherited | kept | no book equivalent | kept, no book equivalent |
| `--sg-status-active` | none | `#1D6B3C` | none | `#86C99B` | color.status.active-text-light / color.status.active-text-dark | additive |
| `--sg-status-unconfirmed` | none | `#7A5F00` | none | `#D6B957` | color.status.unconfirmed-text-light / color.status.unconfirmed-text-dark | additive |
| `--sg-status-locked` | none | `#7A5F00` | none | `#D6B957` | color.status.locked-text-light / color.status.locked-text-dark | additive |
| `--sg-status-deleting` | none | `#7A5F00` | none | `#D6B957` | color.status.deleting-text-light / color.status.deleting-text-dark | additive |
| `--sg-status-suspended` | none | `#5F554D` | none | `#B8ABA0` | color.status.suspended-text-light / color.status.suspended-text-dark | additive |
| `--sg-color-selected` | none | `#EADFD2` | none | `#33281F` | color.secondary.selected-paper; dark from brand.json contrastPairs[selected-row] | additive |
| `--sg-color-selected-edge` | none | `#C2410C` | none | `#F08A55` | color.light.kiln / color.dark.kiln-bright | additive |
| `--sg-color-current-tab` | none | `#9A3412` | none | `#F08A55` | color.secondary.kiln-deep / color.dark.kiln-bright | additive |
| `--sg-color-sunken` | none | `#EFE9E1` | none | `#120E0C` | color.secondary.sunken-paper / color.code.ground-dark | additive |
| `--sg-color-control-edge` | none | `#857569` | none | `#8B7D72` | color.secondary.control-edge; dark from BRAND.md control-edge | additive |
| `--sg-font-sans` | none | `inherit` | none | n/a | font.sans (theme-invariant; light `:root` only; the host's typeface by default) | additive |
| `--sg-font-mono` | none | `ui-monospace, 'SF Mono', Consolas, monospace` | none | n/a | font.mono (theme-invariant; light `:root` only; a system mono stack by default) | additive |

## Orange-family convergence

The book has two oranges for the admin (Kiln `#C2410C`, Kiln Bright `#F08A55`) and a deep tone for text (Kiln Deep `#9A3412`). The template carries a few more orange values that are not in the book. They are state or legacy variants kept so that this phase changes values and nothing else; Phase 262 owns layout and decides which of them retire.

| Value | Where it lives | What it is | Phase 262 disposition |
|-------|----------------|------------|-----------------------|
| `#fdba74` | `--sg-logo-rail-accent`; fills the theme-switch active segment (and its glow) in Light and Dark | legacy light orange, no longer a brand-strong value | revisit: replace the segment fill with a book value, or retire the token's last consumer |
| `rgba(243, 90, 16, 0.16)` | dark `--sg-color-brand-soft` | legacy translucent orange tint behind ghost buttons, nav hover and chips | revisit with the soft-ground state pairs; Kiln Bright on it is 5.59:1 over Char Surface |
| `#c74712` | light `--sg-color-brand-fill-hover` | hover fill, a half step above Kiln; white on it is 4.84:1 | keep or fold into one hover rule when the primary button is reworked |
| `#F4A27C` | dark `--sg-color-brand-fill-hover` (new) | forced: the lighter Kiln tone (`color.code.keyword-dark`); Char on it is 9.12:1 | keep, or retire together with the light `#c74712` |
| `#E07A45` | dark `--sg-color-brand-fill-active` (new) | forced: a darker Kiln Bright; Char on it is 6.23:1 | keep, or retire together with the light active fill |

## Known deviations not adopted

Recorded here so nobody "fixes" them silently. Each changes how copy reads or how the layout is spaced, so Phase 262 owns it.

| Book role | Book value | Shipped value | Disposition |
|-----------|------------|---------------|-------------|
| Body leading | 1.55 | 1.5 | Not adopted; layout phase may revisit. |
| Dense text | 13px / 1.4 | 14px / 1.5 | Not adopted. |
| Label | 600, 0.02em, sentence case, never capitals | 700, 0.04em, uppercase on `.sg-table th`, `.sg-page-kicker`, `.sg-theme-switch__button` | Not adopted; it changes how copy reads, so Phase 262 owns it. |
| Heading | 28px / 1.2 / -0.015em | 18px section, 25.6 to 38.4px page title, tracking 0 | Not adopted. |
| Minimum text size | 12px | `--sg-text-2xs` is 11px; consumers are the theme-switch buttons, `.sg-status-pill::before` and `.sg-meta-label` | Not adopted; frozen, Phase 262. |
| Minimum text size | 12px | about 9px on `.sg-metric__icon-text` (0.56rem) | Not adopted; frozen, Phase 262. |
| Spacing | multiples of 4px | frozen `--sg-space-5`, `--sg-space-7` and `--sg-space-10` (20, 28 and 40px) and the pill and code pads (3px, 10px, 2px, 1px) | Existing and unchanged. "Multiple of 4" applies to `--sg-space-*` only. |

Semantic tones are all kept, not mapped to the book's Active green and ochre: the ember-parity assertion pins admin `risk`, `warn` and `ok` equal to the `sigra_auth.css` fallbacks and `sigra_auth.css` is not edited (ADR 005 decision 1). The book's status colors ship as the additive `--sg-status-*` tokens; pointing status pills at them is Phase 262.

The additive tokens (`--sg-status-*`, `--sg-color-selected`, `--sg-color-selected-edge`, `--sg-color-current-tab`, `--sg-color-sunken`, `--sg-color-control-edge`) are defined and tested token to token. Plan 261-04 gave two of them a consumer: `--sg-color-sunken` is the table-header ground and `--sg-color-control-edge` is the edge of interactive controls. The other eight have no CSS consumer in this phase; consumers arrive in Phase 262.

## Not edited

- `priv/templates/sigra.install/core/sigra_auth.css` and every `--sigra-auth-*` name.
- `Sigra.Branding.Profile` and its defaults.
- `Sigra.Config` and its defaults.
