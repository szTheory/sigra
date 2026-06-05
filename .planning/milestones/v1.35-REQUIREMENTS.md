# Requirements: Sigra — v1.35 BRAND-SYSTEM-PRESSURE-TEST

**Defined:** 2026-06-05
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Milestone goal:** Pressure-test Sigra's repo-derived brand posture and commit a self-contained, source-control-friendly brandbook that supports docs, READMEs, landing pages, UI/UX buildout, marketing copy, design tokens, SVG logos, and future collateral without causing repo churn or binary sprawl.

**Status:** Reopened for Phase 167 logo direction review. The first pass produced useful draft collateral but incorrectly skipped human logo option review before marking the milestone complete.

## v1 Requirements

### Evidence And Audit (EVID)

- [x] **EVID-01**: The milestone uses repo truth plus the supplied pressure-test prompt as authoritative source material: README, launch docs, SECURITY, package metadata, Sigra 1.0 contract, admin design contract, and v1.34 admin token/component evidence.
- [x] **EVID-02**: `brandbook/pressure-test-audit.md` provides the requested 14-section critical audit with executive judgment, brand DNA, scorecard, stress tests, gaps, upgrades, tokens, logo, examples, voice, landing/docs blueprint, repo artifacts, action plan, and quality gate.
- [x] **EVID-03**: The audit explicitly distinguishes inherited repo strengths from missing brandbook artifacts, and it avoids recommending a full redesign.

### Brand DNA And Voice (DNA/VOICE)

- [x] **DNA-01**: `brandbook/brand-book.md` codifies brand essence, positioning, audience, promise, non-promise, visual metaphor, design principles, and repo policy.
- [x] **VOICE-01**: The brand book includes say/do-not-say guidance, tone by context, and ready-to-use copy blocks for GitHub, Hex.pm, README, landing page, states, and release announcement.

### Tokens And UI/UX Buildout (TOK/UI)

- [x] **TOK-01**: `brandbook/tokens.json` defines raw palette tokens, semantic color roles, typography, spacing, radius, border, shadow, motion, focus, code, callout, and state tokens.
- [x] **TOK-02**: `brandbook/tokens.css` exposes practical CSS custom properties and small implementation examples for docs/marketing surfaces.
- [x] **UI-01**: The brand book gives component-level guidance for buttons, cards, callouts, code blocks, terminal blocks, badges, diagrams, empty states, error states, success states, docs pages, and landing pages.
- [x] **A11Y-01**: The system documents light/dark usage, contrast expectations, non-color status cues, font durability, SVG accessibility, and no external font dependency.

### Logo And Visual Assets (LOGO/VIS)

- [x] **LOGO-01**: A source-controlled SVG logo system exists: primary lockup, icon-only mark, monochrome mark, favicon, and social card.
- [x] **LOGO-02**: The logo system documents concept, minimum size, clearspace, light/dark/monochrome usage, and misuse rules.
- [x] **VIS-01**: `brandbook/examples/` includes useful SVG specimens for palette, typography, README header, landing hero, docs page, code block, terminal, component states, and architecture diagram.

### Static HTML And Repo Hygiene (HTML/REPO)

- [x] **HTML-01**: `brandbook/index.html` is a static, directly openable HTML brandbook with no build step, CDN, web font, or runtime dependency.
- [x] **REPO-01**: All brand collateral is self-contained under `brandbook/`; no public README/HexDocs/generated-template churn is introduced by the milestone.
- [x] **QA-01**: JSON, SVG XML, HTML parseability, file-size hygiene, and git status are verified after the final artifact edits.

### Ratification Repair (RAT)

- [x] **RAT-01**: v1.35 planning truth is corrected from "complete" to "needs ratification" so the milestone no longer claims completion before logo review.
- [x] **RAT-02**: `brandbook/logo-options/` presents five distinct SVG logo directions with usage notes, risks, and an initial recommendation.
- [ ] **RAT-03**: A human selects or critiques a logo direction before any final logo system replaces the draft collateral.
- [ ] **RAT-04**: The selected/revised logo direction is finalized across primary logo, mark, monochrome mark, favicon, social card, HTML brandbook, and brand-book guidance.
- [ ] **RAT-05**: Final brandbook ratification runs JSON/SVG/HTML/browser/axe/file-size/git hygiene after the selected logo direction lands.

## Out Of Scope

| Feature | Reason |
| --- | --- |
| Public README redesign | The existing README voice is strong; broad public-doc churn would reduce signal. |
| Generated/admin UI changes | The brandbook can cite v1.34 admin discipline, but does not alter runtime or generated UI. |
| PNG/PDF exports | SVG/HTML are source-controlled; raster exports should be generated only for a concrete distribution target. |
| Mascot or illustration suite | Not needed for Sigra's OSS/devtools credibility. |
| Proprietary fonts or embedded assets | Would reduce durability and increase repo burden. |

## Traceability

| Requirement | Phase | Status |
| --- | --- | --- |
| EVID-01 | 161 | Complete |
| EVID-02 | 161 | Complete |
| EVID-03 | 161 | Complete |
| DNA-01 | 162 | Complete |
| VOICE-01 | 162 | Complete |
| TOK-01 | 163 | Complete |
| TOK-02 | 163 | Complete |
| UI-01 | 163 | Complete |
| A11Y-01 | 163 | Complete |
| LOGO-01 | 164 | Complete |
| LOGO-02 | 164 | Complete |
| VIS-01 | 164 | Complete |
| HTML-01 | 165 | Complete |
| REPO-01 | 166 | Complete |
| QA-01 | 166 | Complete |
| RAT-01 | 167 | Complete |
| RAT-02 | 167 | Complete |
| RAT-03 | 167 | Pending human selection |
| RAT-04 | 167 | Pending |
| RAT-05 | 167 | Pending |
