# Sigra Brandbook

This directory is the source-controlled brand system for Sigra. It is intentionally self-contained and mostly text/SVG so the repo gets useful collateral without binary sprawl.

## Open The Brand Book

Open [`index.html`](index.html) directly in a browser. It has no build step, CDN, web font, or runtime dependency.

## Files

| File | Purpose |
| --- | --- |
| [`pressure-test-audit.md`](pressure-test-audit.md) | Critical audit of the current repo-derived brand system. |
| [`brand-book.md`](brand-book.md) | Durable brand system: strategy, voice, visual rules, tokens, logo usage, UI guidance, copy blocks. |
| [`tokens.json`](tokens.json) | Token source for raw palette, semantic colors, typography, spacing, radius, states, code/callout roles. |
| [`tokens.css`](tokens.css) | CSS custom properties and small implementation examples for docs/marketing surfaces. |
| [`logo-primary.svg`](logo-primary.svg) | Primary mark + wordmark lockup. |
| [`logo-mark.svg`](logo-mark.svg) | Icon-only mark for square contexts. |
| [`logo-monochrome.svg`](logo-monochrome.svg) | One-color mark for restricted contexts. |
| [`favicon.svg`](favicon.svg) | Browser/favicon source. |
| [`social-card.svg`](social-card.svg) | SVG social preview source. Export PNG only when a platform requires it. |
| [`logo-options/`](logo-options/) | Phase 167 logo direction review archive; Option A was selected. |
| [`examples/`](examples/) | Source-controlled visual specimens for palette, type, README, landing, docs, code, terminal, components, and diagrams. |

## Ratification Status

The current logo files are ratified Phase 167 assets. The selected direction is **Option A: Core Rails**, which represents Sigra's library-owned protected core framed by visible host-owned code rails. [`logo-options/`](logo-options/) remains as review history and comparison collateral.

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
find brandbook -name '*.svg' -maxdepth 2 -print0 | xargs -0 -n1 xmllint --noout
find brandbook -type f -size +250k -print
```
