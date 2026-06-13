# Sigra Brandbook

This directory is the source-controlled brand system for Sigra. It is intentionally self-contained and mostly text/SVG so the repo gets useful collateral without binary sprawl.

## Open The Brand Book

Open [`index.html`](index.html) directly in a browser. It has no build step, CDN, web font, or runtime dependency.

## Files

| File                                               | Purpose                                                                                                                |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| [`pressure-test-audit.md`](pressure-test-audit.md) | Historical audit that informed the first complete brand system.                                                        |
| [`brand-book.md`](brand-book.md)                   | Durable brand system: strategy, voice, visual rules, tokens, logo usage, UI guidance, copy blocks.                     |
| [`tokens.json`](tokens.json)                       | Token source for raw palette, semantic colors, typography, spacing, radius, states, code/callout roles.                |
| [`tokens.css`](tokens.css)                         | CSS custom properties and small implementation examples for docs/marketing surfaces.                                   |
| [`logo-primary.svg`](logo-primary.svg)                         | D4 Linked Rail primary lockup for light surfaces.                                                                      |
| [`logo-primary-dark.svg`](logo-primary-dark.svg)               | D4 Linked Rail primary lockup for dark surfaces.                                                                       |
| [`logo-primary-subtitle.svg`](logo-primary-subtitle.svg)       | D4 Linked Rail lockup with subtitle line for tall-format contexts.                                                     |
| [`logo-mark.svg`](logo-mark.svg)                               | D4 Linked Rail abstract mark (standalone + favicon contexts).                                                          |
| [`logo-monochrome.svg`](logo-monochrome.svg)                   | Single-ink monochrome typemark for emboss/print contexts.                                                              |
| [`favicon.svg`](favicon.svg)                                   | D4 Linked Rail favicon mark — light/dark via `prefers-color-scheme`.                                                   |
| [`social-card.svg`](social-card.svg)                           | SVG social preview source. Export PNG only when a platform requires it.                                                |
| [`social-card-dark.svg`](social-card-dark.svg)                 | SVG social preview source for dark-background platforms.                                                               |
| [`logo-options/`](logo-options/)                   | Archived logo exploration studies.                                                                                     |
| [`examples/`](examples/)                           | Source-controlled visual specimens for palette, type, README, landing, docs, code, terminal, components, and diagrams. |

## Logo System

The current logo files are the Sigra D4 Linked Rail assets (v2, Phase 181). Use the tight lockup for primary identity, the dark lockup for dark surfaces, and the free-standing mark for lightweight UI accents, favicon, and avatar surfaces. [`logo-options/archive-v1/`](logo-options/archive-v1/) contains archived v1 Rail Accent assets — do not use them. [`logo-options/`](logo-options/) is archive and exploration material, not usage guidance.

The lockup wordmark is outlined from Space Grotesk v2.0 (OFL) wght=700. The SVGs should remain path-only so the logo renders identically without installing fonts or loading a runtime web font.

## Logo System Usage Rules

### Clearspace

Minimum clearspace around the **mark** = 0.25 × rendered mark height.
Minimum margin around the **typemark** = 0.15 × rendered typemark height.

### Minimum Sizes

| Context | Minimum rendered height | Notes |
|---------|------------------------|-------|
| Favicon (kill test) | 16px | Abstract rail glyph; ember block legible from 16px |
| UI accent (mark only) | 24px | Block + stem readable |
| Topbar lockup | 32px | Wordmark legible; 54px is the recommended target |
| Marketing / docs | 120px | Full typemark with subtitle; subtitle text hard to read below 120px |

### Misuse Examples

1. **Incorrect surface:** Using `logo-primary.svg` on a dark background — ink wordmark becomes invisible. Use `logo-primary-dark.svg` on dark surfaces.
2. **Scaling below minimum:** Displaying the typemark below 32px — "sigra" letters are no longer distinguishable; use `favicon.svg` (the abstract mark) instead.
3. **Rectangular container:** Wrapping the mark in a box, badge, or pill — the D4 mark is designed for transparent/colored surfaces without containers.
4. **Wrong ember hue:** Substituting `#c2410c` with a bright orange or red outside hue 15–40° — breaks brand differentiation from Phoenix Framework and Ash.
5. **Rotating or reflecting:** The rail direction (vertical stem, leftward foot, upper-right block) is the spatial system — rotation breaks the visual metaphor.
6. **Live text wordmark:** Recreating "sigra" in any font at runtime — the wordmark is outlined paths that must render identically at all sizes without font loading.

### Palette Values (v2 / D4)

| Context | Glyph fill | Ember accent |
|---------|-----------|--------------|
| Light surface | `#151515` (ink) | `#c2410c` (ember-700) |
| Dark surface | `#f4f1eb` (warm white) | `#fdba74` (ember-300) |
| Monochrome | `#151515` | `#151515` (ember block collapses to solid ink) |
| Favicon / mark | CSS via prefers-color-scheme | CSS via prefers-color-scheme |

## Font Provenance

Round-3 candidate wordmarks are outlined using opentype.js 2.0.0 (MIT) from OFL-licensed variable TTFs. Font binaries are gitignored; only the resulting SVG path data is committed. Each candidate SVG `<desc>` records: font name, version, OFL license, opentype.js version, and generation date.

| Font | Version | License | Source | Used in |
| --- | --- | --- | --- | --- |
| Inter Display | v4.1 | OFL | github.com/rsms/inter | logo-primary.svg (v1), round-3 A4 candidate |
| Space Grotesk | v2.0.0 | OFL | github.com/floriankarsten/space-grotesk | Round-3 A1, B1 candidates |
| Plus Jakarta Sans | v2.7.1 | OFL | github.com/tokotype/PlusJakartaSans | Round-3 A2, C1 candidates |
| Syne | latest | OFL | github.com/google/fonts/tree/main/ofl/syne | Round-3 A3 candidate |
| Geist | v1.7.2 | OFL | github.com/vercel/geist-font | Round-3 B2 candidate |
| Space Grotesk | v2.0.0 | OFL | github.com/floriankarsten/space-grotesk | logo-primary.svg (v2), all D4 production assets |

## Maintenance Rules

- Keep brand assets in `brandbook/`; do not scatter them into `docs/`, `guides/`, or generated templates without a separate implementation decision.
- Prefer SVG, Markdown, JSON, CSS, and HTML. Commit PNG/JPG exports only when a distribution target requires raster.
- Do not add font files or external font/CDN dependencies.
- Do not replace Sigra's current low-BS technical voice with SaaS launch copy.
- Token changes must update both `tokens.json` and `tokens.css`.
- New visual examples must explain what implementation decision they clarify.

## Token Change Policy

`tokens.json` follows semantic versioning on the `version` field:

- **Patch** (`1.0.x`): metadata-only changes — `changed` date, `source` annotation updates.
  No consuming surface requires changes.
- **Minor** (`1.x.0`): new tokens added. Consuming surfaces (`--sg-*` in admin CSS,
  `--sigra-auth-*` in `sigra_auth.css`) may reference the new token but are not required to.
- **Major** (`x.0.0`): token value changed or token removed. Consuming surfaces **must**
  review the diff and update hardcoded fallbacks before shipping.

**Three-surface ember parity rule:** `ember-700: #c2410c` is the canonical accent value
consumed by three independent surfaces — `brandbook/tokens.json`, admin CSS
(`--sg-color-brand`), and auth CSS (`--sigra-auth-light-accent`). Any new surface carrying
the Sigra brand accent must reference the brandbook token rather than hardcoding `#c2410c`.
When the token value changes (major bump), all three surfaces must be updated atomically
in the same PR.

The `meta.changed` date uses ISO 8601 (`YYYY-MM-DD`). It records the last date any token
value or file structure changed — metadata-only patches do not update it.

## Suggested Checks

```sh
jq . brandbook/tokens.json
find brandbook -name '*.svg' -print0 | xargs -0 -n1 xmllint --noout
find brandbook -type f -size +250k -print
```
