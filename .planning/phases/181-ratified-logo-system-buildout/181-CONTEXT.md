# Phase 181 Context: Ratified Logo System Buildout

**Gathered:** 2026-06-12
**Status:** Ready for planning
**Source:** Phase 180 ratification record (authoritative) + milestone plan

<domain>
## Phase Boundary

Build the complete production logo asset set from the ratified **D4 Linked Rail** design, render-verify every file, document usage rules (clearspace, minimum sizes, ≥4 misuse examples), and archive the superseded v1 assets. Ends when all assets and docs are committed. No brandbook/index.html rewrite (Phase 182), no token changes beyond what the assets themselves need (Phase 182), no propagation into installer/example (Phase 183).
</domain>

<decisions>
## Implementation Decisions

### Ratified design (LOCKED — do not reopen)
- **D4 Linked Rail** (see `brandbook/logo-options/round-3/README.md` "## Ratification (Phase 180)" and `brandbook/logo-options/round-4/d4-linked-rail-*.svg`): Space Grotesk v2.0 (OFL) wght 700 outlined "sigra"; ember rail-block tittle; g tail extended to x=557 with its tip aligned under the tittle's left edge — one bracketing rail system around "ig".
- **Mark/favicon:** the abstract rail glyph from `d4-linked-rail-favicon.svg` (ink stem + leftward foot + ember block, no letter). The "ig" crop is permanently retired (Instagram confusion).
- **Palette:** ember-anchored; fine-tuning permitted ONLY within hue 15–40° and only where it measurably improves contrast/small-size legibility; light-surface favicon accent is ember-700 `#c2410c`. Any value change must be recorded for Phase 182's token bump and Phase 183's sg-* sync.
- Hard constraints from the design brief still bind: no rectangular container, subtitle-free main lockup, tight logotype proximity, boundary-breaking tolerated by viewBox padding (54px admin topbar slot must not clip).

### Asset set (BRAND2-08 / roadmap success criteria)
Seven+ files under `brandbook/`: `logo-primary.svg`, `logo-primary-dark.svg`, `logo-primary-subtitle.svg` (the ONLY variant with subtitle), `logo-mark.svg`, `logo-monochrome.svg`, `favicon.svg`, `social-card.svg` + a dark social card variant (naming per existing conventions; check what exists today). SVG-only; no raster; no font binaries; font provenance in each `<desc>` plus `<title>` accessibility pattern matching v1 conventions.

### Render verification
- Every asset re-verified through the committed Playwright `file://` harness at its intended sizes: favicon at 16/32px (kill test), primary at hero + inline + 54px topbar slot, social cards at thumbnail scale; light AND dark. Renders are throwaway — never committed. Executor must Read the PNGs, not just run the harness.

### Usage rules + archive
- Clearspace (defined in mark-relative units), minimum sizes, and ≥4 misuse examples documented in `brandbook/README.md` (companion markdown is acceptable per roadmap; index.html integration is Phase 182's job).
- v1 assets MOVED (git mv, not duplicated) into an archive location under `brandbook/logo-options/` (e.g. `archive-v1/`) with a deprecation note; working set contains only ratified v2 files. Do NOT touch `priv/templates/` or `test/example/` copies — that is Phase 183.

### Claude's Discretion
- Exact subtitle text/styling for the subtitle variant (existing brand voice: "Phoenix auth that ships" appears in round galleries).
- Social card composition (must feature the D4 lockup + mark; OG-standard 1200×630 viewBox).
- Monochrome strategy (single-ink rendition of the linked-rail system that keeps the tittle/tail geometry legible without color).
- Whether minor palette micro-tuning is warranted at all — default is no change.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Ratified design
- `brandbook/logo-options/round-3/README.md` — Ratification (Phase 180) section: the binding decision
- `brandbook/logo-options/round-4/d4-linked-rail-typemark.svg` + `-dark` + `-favicon` siblings — the exact source geometry
- `brandbook/logo-v2-design-brief.md` — hard constraints + render-critique rubric

### Existing assets / conventions
- `brandbook/logo-primary.svg` (v1, to be replaced + archived) — `<title>`/`<desc>` accessibility + outlined-path conventions
- `brandbook/README.md` — Font Provenance table to extend; usage rules land here
- `brandbook/examples/social-card.svg` (if present) — current social card naming/composition

### Toolchain
- `scripts/brand/outline-wordmark.mjs`, `scripts/brand/critique-render.mjs` — committed toolchain (opentype.js 2.0.0 pitfalls already fixed: parse-not-loadSync, variation.set before outlining, toPathData object form)
- `test/example/priv/playwright/` — node env for `file://` rendering
</canonical_refs>

<specifics>
## Specific Ideas

- 16px favicon legibility is the kill test; the abstract rail glyph passed it in round-4 — preserve its geometry, only re-tune if a size-specific optical correction is needed.
- The 54px admin topbar `<img>` slot is a hard fit target for `logo-primary*.svg` (viewBox padding tolerates tail overflow below baseline).
- Maintainer quality bar: "knock it out of the park" — assets must look intentional and crafted, never like a glitch or accidental cutoff (the A3 rejection).
</specifics>

<deferred>
## Deferred Ideas

- brandbook/index.html v2 + tokens version bump → Phase 182
- Installer/example propagation + sg-* sync + Playwright baseline recapture → Phase 183
- README header / GitHub social preview adoption → post-milestone fast-follow
</deferred>

---

*Phase: 181-ratified-logo-system-buildout*
*Context gathered: 2026-06-12 from the Phase 180 ratification record (no separate discuss-phase needed — design decision is locked)*
