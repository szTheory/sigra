# Requirements: Sigra — v1.38 BRAND-V2

**Defined:** 2026-06-12
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Milestone goal:** Pressure-test the v1.35 brand system with a fresh 14-section critical audit and elevate the Sigra identity with a redesigned, fully integrated logo system — ratified by the maintainer — then propagate it coherently everywhere the existing logo already lives, with zero repo bloat and zero unplanned public-surface churn.

**Hard design constraints (apply to all LOGO2 requirements):** no rectangular background container behind the logomark (boundary-breaking encouraged); logotype sits close to the mark; main lockup carries no subtitle/slogan (a separate subtitle variant is allowed); palette stays ember-anchored but tunable; committed assets are SVG/text only; outlining uses OFL-licensed fonts only and no font binaries are committed.

## v1 Requirements

### Audit v2 (AUDIT2)

- [x] **BRAND2-01**: `brandbook/pressure-test-audit-v2.md` re-runs the full 14-section pressure test (executive judgment, brand DNA, scorecard, surface stress tests, gaps, upgrades, tokens, logo system, visual examples, voice, landing/docs blueprint, artifact plan, action plan, quality gate) against the current brandbook with KEEP/TIGHTEN/REWORK/ADD/REMOVE verdicts, evidence required for every REWORK, and KEEP as the default posture.
- [x] **BRAND2-02**: The audit includes a multi-library brand-architecture section for the szTheory OSS suite (what is shared across Sigra/Accrue/Mailglass/Threadline/Lockspire/Relyra/Rulestead vs unique per library), informed by competitor/ecosystem visual research.
- [x] **BRAND2-03**: A logo v2 design brief encodes the hard constraints: no rectangular container, boundary-breaking allowed, tight logotype proximity, subtitle-free main lockup, integrated-typemark candidates required, ember-anchored tunable palette, OFL typeface freedom.

### Logo Exploration (LOGO2)

- [x] **BRAND2-04**: A committed, reproducible glyph-outlining script (opentype.js, OFL fonts downloaded to a gitignored location) produces wordmark path source; no font binaries are committed and font name/version provenance is documented in SVG `<desc>` and `brandbook/README.md`.
- [x] **BRAND2-05**: 5–7 logo candidates exist, including at least 2 fully integrated custom typemarks (motif worked into the letterforms, not icon-beside-text), each pre-verified through a rendered self-critique loop at 16/32/54px and hero scale in light and dark before presentation.
- [x] **BRAND2-06**: Candidates are presented in a `brandbook/logo-options/round-3/` gallery matching the established round-2 format (standalone `index.html` linking `../../tokens.css` plus a `README.md` rationale table).

### Ratification (RAT2)

- [x] **BRAND2-07**: A human selects the final logo direction, typemark treatment, typeface, and palette tuning at an explicit ratification gate (one refinement round budgeted); the decision and rationale are recorded in the gallery README.

### Ratified System Buildout (SYS2)

- [x] **BRAND2-08**: The full ratified asset set ships: `logo-primary.svg`, `logo-primary-dark.svg`, separate `logo-primary-subtitle.svg`, `logo-mark.svg`, `logo-monochrome.svg`, `favicon.svg`, and social cards (light and dark), each render-verified, with clearspace, minimum sizes, and misuse rules documented.

### Brand Book v2 (BOOK2)

- [x] **BRAND2-09**: `brandbook/index.html` is upgraded to a professional standalone v2 document reflecting all audit verdicts and the ratified logo system, openable directly from disk with no build step, CDN, web font, or runtime dependency, and passing an axe accessibility check.
- [x] **BRAND2-10**: `brandbook/tokens.json` and `brandbook/tokens.css` are updated and version-bumped per ratified decisions with a documented token change policy, and the `brandbook/examples/` specimens embedding the old mark are regenerated.

### Propagation And Parity (PROP2)

- [ ] **BRAND2-11**: The ratified logo is propagated byte-identically to `priv/templates/sigra.install/admin/` and `test/example/priv/static/images/` under unchanged filenames, and all installer/example parity tests pass.
- [ ] **BRAND2-12**: sg-* token values in the example app CSS, `sigra_auth.css` accent defaults, and the admin design contract are re-synced to brandbook tokens (or verified unchanged if the palette was kept).
- [ ] **BRAND2-13**: Admin Playwright baselines are recaptured once via `scripts/ci/snapshot-recapture-gate.sh` with all intended slugs declared, and the snapshot canary guard returns to its empty steady state.
- [ ] **BRAND2-14**: A final hygiene gate verifies JSON/SVG/HTML parseability, file-size limits, no binary sprawl, a small brandbook size delta, green `mix test`, and clean git status.

## Out Of Scope

| Feature | Reason |
| --- | --- |
| README header + GitHub social preview adoption | New public surface, not parity; ships as a `gsd-quick` fast-follow immediately after v1.38 so the milestone stays focused. |
| HexDocs/ExDoc theming, landing page, marketing site | Separate surfaces with their own constraints; the brand book makes them possible, not shipped. |
| PNG export pipeline / committed raster assets | SVG-only policy stands; Playwright renders are QA/gallery-only and not committed. |
| sg-* class-name churn or admin component redesign | Design contract forbids class churn; v1.38 changes token values and logo content only. |
| Sibling-library brandbooks | Audit specifies the suite architecture; building other libraries' brand systems is their own work. |
| Per-org/runtime branding features | Product feature territory already deferred at v1.37. |

## Non-Goals

- Do not mutate README, HexDocs, generated templates, or runtime UI beyond the explicitly scoped propagation surfaces (installer logo files, example app assets, sg-* token values).
- Do not introduce web fonts, font binaries, raster assets, or build steps into `brandbook/`.
- Do not rename logo asset files consumed by the installer, example app, or tests.
- Do not recapture Playwright baselines more than once, and never mid-exploration.

## Traceability

| Requirement | Phase | Status |
| --- | --- | --- |
| BRAND2-01 | Phase 178 | Complete |
| BRAND2-02 | Phase 178 | Complete |
| BRAND2-03 | Phase 178 | Complete |
| BRAND2-04 | Phase 179 | Complete |
| BRAND2-05 | Phase 179 | Complete |
| BRAND2-06 | Phase 179 | Complete |
| BRAND2-07 | Phase 180 | Complete |
| BRAND2-08 | Phase 181 | Complete |
| BRAND2-09 | Phase 182 | Complete |
| BRAND2-10 | Phase 182 | Complete |
| BRAND2-11 | Phase 183 | Pending |
| BRAND2-12 | Phase 183 | Pending |
| BRAND2-13 | Phase 183 | Pending |
| BRAND2-14 | Phase 183 | Pending |
