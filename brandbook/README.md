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
| [`logo-primary.svg`](logo-primary.svg)             | Primary Rail Accent lockup for light surfaces.                                                                         |
| [`logo-primary-dark.svg`](logo-primary-dark.svg)   | Primary Rail Accent lockup for dark surfaces.                                                                          |
| [`logo-mark.svg`](logo-mark.svg)                   | Free-standing Rail Accent mark for UI accents.                                                                         |
| [`logo-monochrome.svg`](logo-monochrome.svg)       | One-color Rail Accent mark for restricted contexts.                                                                    |
| [`favicon.svg`](favicon.svg)                       | Browser/favicon source using the same Rail Accent mark geometry.                                                       |
| [`social-card.svg`](social-card.svg)               | SVG social preview source. Export PNG only when a platform requires it.                                                |
| [`logo-options/`](logo-options/)                   | Archived logo exploration studies.                                                                                     |
| [`examples/`](examples/)                           | Source-controlled visual specimens for palette, type, README, landing, docs, code, terminal, components, and diagrams. |

## Logo System

The current logo files are the Sigra Rail Accent assets. Use the tight lockup for primary identity, the dark lockup for dark surfaces, and the free-standing mark for lightweight UI accents, favicon, and avatar surfaces. [`logo-options/`](logo-options/) is archive material, not usage guidance.

The lockup wordmark is outlined from Inter Display Black v4.1. The SVGs should remain path-only so the logo renders identically without installing fonts or loading a runtime web font.

## Font Provenance

Round-3 candidate wordmarks are outlined using opentype.js 2.0.0 (MIT) from OFL-licensed variable TTFs. Font binaries are gitignored; only the resulting SVG path data is committed. Each candidate SVG `<desc>` records: font name, version, OFL license, opentype.js version, and generation date.

| Font | Version | License | Source | Used in |
| --- | --- | --- | --- | --- |
| Inter Display | v4.1 | OFL | github.com/rsms/inter | logo-primary.svg (v1), round-3 A4 candidate |
| Space Grotesk | v2.0.0 | OFL | github.com/floriankarsten/space-grotesk | Round-3 A1, B1 candidates |
| Plus Jakarta Sans | v2.7.1 | OFL | github.com/tokotype/PlusJakartaSans | Round-3 A2, C1 candidates |
| Syne | latest | OFL | github.com/google/fonts/tree/main/ofl/syne | Round-3 A3 candidate |
| Geist | v1.7.2 | OFL | github.com/vercel/geist-font | Round-3 B2 candidate |

## Maintenance Rules

- Keep brand assets in `brandbook/`; do not scatter them into `docs/`, `guides/`, or generated templates without a separate implementation decision.
- Prefer SVG, Markdown, JSON, CSS, and HTML. Commit PNG/JPG exports only when a distribution target requires raster.
- Do not add font files or external font/CDN dependencies.
- Do not replace Sigra's current low-BS technical voice with SaaS launch copy.
- Token changes must update both `tokens.json` and `tokens.css`.
- New visual examples must explain what implementation decision they clarify.

## Suggested Checks

```sh
jq . brandbook/tokens.json
find brandbook -name '*.svg' -print0 | xargs -0 -n1 xmllint --noout
find brandbook -type f -size +250k -print
```
