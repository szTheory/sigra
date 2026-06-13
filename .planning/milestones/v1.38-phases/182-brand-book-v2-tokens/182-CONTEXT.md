# Phase 182 Context: Brand Book v2 + Tokens

**Gathered:** 2026-06-12
**Status:** Ready for planning
**Source:** Phase 178 audit verdicts + Phase 181 ratified assets + brandbook scout

<domain>
## Phase Boundary

Upgrade the brand-collateral documents to v2: make `brandbook/index.html` a professional standalone document reflecting the Phase 178 audit verdicts and the ratified D4 Linked Rail logo system; version-bump `tokens.json` + regenerate `tokens.css` + document a token change policy; refresh `brand-book.md` with the audit's ADD/TIGHTEN sections; update any `examples/` specimen that still draws the old v1 mark; refresh `README.md`'s Files table (carried from Phase 181); run an axe pass on `index.html`. Ends when all brandbook docs are coherent v2 and axe is clean. NO propagation into installer/example/sg-*/Playwright baselines — that is Phase 183.
</domain>

<decisions>
## Implementation Decisions

### What is ALREADY done (do not redo)
- The production logo SVGs at `brandbook/*.svg` are ALREADY the ratified v2 D4 Linked Rail assets (Phase 181). `index.html` references them by filename (favicon.svg, logo-primary.svg, logo-primary-dark.svg, logo-mark.svg) — those references already resolve to v2. Do NOT regenerate logo assets.
- `README.md` already states v2 assets exist and archive-v1/ holds v1. Its Files *table*, however, still labels 5 entries "Rail Accent" and omits `logo-primary-subtitle.svg` + `social-card-dark.svg` — fix the table (carry-forward from Phase 181).

### index.html v2 (BRAND2-09)
- Standalone, opens from disk, NO build/CDN/web-font/runtime dependency (it already links only `tokens.css` — keep it that way). Embedded `<style>` + `--sigra-*` tokens.
- Reflect audit verdicts in the document content: expand the `#logo` section into a proper logo-system section showing the multi-lockup set (primary, dark, subtitle variant, mark-only, monochrome, favicon, social cards) with the integrated-typemark anatomy (rail-block tittle + linked g-tail), clearspace, minimum sizes, and misuse examples; add a szTheory **suite architecture** section (shared-vs-per-library brand decision framework naming all 7 libs); surface the new subtitle/monochrome/social-card assets that index.html does not yet show.
- Existing 8-section structure (#judgment #dna #tokens #logo #examples #voice #blueprint #artifacts) is sound — extend, don't rewrite wholesale.

### Tokens (BRAND2-10)
- `tokens.json`: increment `version` (currently `1.0.0`) and add a `changed` date to `meta`. Token VALUES default unchanged (Phase 181 ratified palette with no micro-tuning; three-surface ember parity at #c2410c is confirmed). If Phase 181 had recorded any palette change it would be synced here — it did not, so values hold.
- `tokens.css`: regenerate/re-sync from tokens.json (it is hand-maintained — no generator script exists; keep it hand-synced and add a provenance header comment noting it derives from tokens.json vN).
- **Token change policy:** add a section to `README.md` (or a companion doc) describing how token values are versioned (semver on tokens.json `version`), what a bump means for consumers (admin sg-*, auth sigra_auth.css), and that consuming surfaces reference the brandbook token rather than hardcoding hex.

### Specimens (BRAND2-09 criterion 4)
- Audit every `brandbook/examples/*.svg`. The one known stale file is `examples/landing-hero.svg`, which DRAWS the old Rail Accent mark inline (staggered vertical bars + horizontal core line) — update it to the D4 Linked Rail mark geometry. Verify the other 8 specimens (palette, readme-header, docs-page, code-block, architecture-diagram, terminal, typography, component-states) embed no stale v1 mark; regenerate any that do. Most are conceptual (no mark) and only need verification.

### axe (BRAND2-09 criterion 2)
- axe-core + @axe-core/playwright are installed at `test/example/priv/playwright/node_modules`. No file:// brandbook harness exists yet. Create a throwaway/committed-as-appropriate axe check that serves `brandbook/` over a local http server (e.g. python http.server or a tiny node static serve) and runs AxeBuilder against `index.html`, asserting zero violations. The harness/script may live under `scripts/brand/`; do NOT commit screenshots. Decide whether the axe runner is a committed script (preferred, reproducible) or throwaway — committed is better for re-runs in Phase 183.

### Claude's Discretion
- Exact prose of the suite-architecture and token-change-policy sections.
- Whether the axe runner is a new committed `scripts/brand/axe-brandbook.mjs` or folded into the existing playwright project (committed script preferred for self-containment).
- index.html layout details for the expanded logo-system section (must stay dependency-free).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Audit + design source
- `brandbook/pressure-test-audit-v2.md` — Section 6 (Recommended Brand Book Upgrades): the ADD/TIGHTEN list index.html + brand-book.md must reflect; Section 8 logo REWORK
- `brandbook/logo-v2-design-brief.md` — typemark anatomy, constraints, OFL font provenance
- `brandbook/logo-options/round-3/README.md` — Ratification (Phase 180) decision

### Documents to edit
- `brandbook/index.html` — sections #judgment…#artifacts; embedded style; tokens.css link
- `brandbook/brand-book.md` — Visual System / Voice / blueprints; line ~96 stale "Inter Display Black" font ref → Space Grotesk v2.0
- `brandbook/README.md` — Files table refresh + token change policy section
- `brandbook/tokens.json` (version + changed) / `brandbook/tokens.css` (re-sync + header)
- `brandbook/examples/landing-hero.svg` (stale Rail Accent mark) + audit of the other 8

### Tooling
- `test/example/priv/playwright/` — axe-core + @axe-core/playwright; admin-checkpoints.spec.ts shows the AxeBuilder + assertNoAxeViolations pattern
- `scripts/brand/` — brand toolchain home (outline-wordmark.mjs, critique-render.mjs); axe runner can live here
</canonical_refs>

<specifics>
## Specific Ideas

- The integrated-typemark is now a formal lockup class — document its anatomy (rail-block tittle, g-tail extended to align under the tittle = one bracketing rail system) in both index.html and brand-book.md.
- Three-surface ember parity rule: ember-700 #c2410c is consumed by brandbook tokens, admin `--sg-color-brand`, and auth `--sigra-auth-light-accent`; document that future surfaces reference the token, not a hardcoded hex (this sets up Phase 183's sync).
- Watch repo bloat: brandbook/ is ~588KB, dominated by round-2/3/4 exploration galleries (history, leave them). Keep index.html dependency-free and SVG-only; no raster.
</specifics>

<deferred>
## Deferred Ideas

- Propagation into priv/templates, test/example, sg-* tokens, sigra_auth.css, admin-design-contract → Phase 183
- Playwright admin baseline recapture → Phase 183
- README header / GitHub social preview adoption → post-milestone fast-follow
- Sibling-library brandbooks (suite architecture documents the framework; building them is separate work)
</deferred>

---

*Phase: 182-brand-book-v2-tokens*
*Context gathered: 2026-06-12 from Phase 178 audit + Phase 181 assets + brandbook scout (no separate discuss-phase — verdicts already committed)*
