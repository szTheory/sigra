# Phase 179 Context: Outlining Toolchain + Logo Concept Exploration

**Gathered:** 2026-06-12
**Status:** Ready for planning
**Source:** Phase 178 outputs (authoritative) + user kickoff brief

<domain>
## Phase Boundary

Build the reproducible glyph-outlining toolchain and produce 5–7 pre-verified logo candidates presented in a `brandbook/logo-options/round-3/` gallery. Ends when the gallery is committed and ready for the Phase 180 human ratification gate. No final asset buildout (Phase 181), no brandbook/index.html changes (Phase 182), no propagation (Phase 183).
</domain>

<decisions>
## Implementation Decisions

### Authoritative design contract
- `brandbook/logo-v2-design-brief.md` is the single authoritative input: 7 hard constraints, ember hue 15–40° tuning boundary, OFL typeface candidates table (with versions/URLs), "sigra" letterform integration anatomy, 6-row render-critique rubric, Direction A/B/C guidance, round-3 deliverables table.
- `brandbook/pressure-test-audit-v2.md` Section 8 carries the REWORK verdict this phase answers (mark-beside-text construction is the rejected baseline).

### Toolchain (BRAND2-04)
- opentype.js (MIT) glyph-outlining script committed to the repo (e.g. `scripts/brand/outline-wordmark.mjs`); run via the node env at `test/example/priv/playwright/` or npx.
- OFL fonts download to a gitignored temp location; NO font binaries committed; font name/version provenance in SVG `<desc>` and `brandbook/README.md`.

### Candidates (BRAND2-05)
- 5–7 total; ≥2–3 fully integrated typemarks (motif worked INTO letterforms); 1–2 evolved tight lockups (boundary-breaking, no container, close-set type); 1 wildcard allowed.
- Every candidate passes the render-critique loop BEFORE gallery inclusion: Playwright screenshots against `file://` harness pages at 16px, 32px, 54px (admin topbar `<img height="54">` slot is a hard fit target), and hero scale, in light AND dark. Self-critique against the brief's rubric; iterate until clean. Renders are throwaway — never committed.
- Candidates may tune ember shades/secondaries within hue 15–40°; no unrelated palettes.

### Gallery (BRAND2-06)
- `brandbook/logo-options/round-3/` matching round-2 format: standalone `index.html` linking `../../tokens.css`, per-option sections (mark-only where applicable, light/dark lockups, favicon-scale previews), `README.md` rationale table ("what it tests"), status pill/topbar/crumbs chrome.
- Each finalist-grade option shows a with-subtitle preview variant; main lockups remain subtitle-free.

### Claude's Discretion
- Exact candidate concepts/motifs (guided by brief Directions A/B/C and letterform anatomy).
- Script CLI shape, config format, and where the harness HTML lives (throwaway, gitignored or temp).
- Which OFL faces from the brief's table each candidate uses.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design contract
- `brandbook/logo-v2-design-brief.md` — all hard constraints, rubric, fonts, anatomy, deliverables
- `brandbook/pressure-test-audit-v2.md` — Section 8 REWORK verdict + Section 13 action plan

### Format precedents
- `brandbook/logo-options/round-2/index.html` + `README.md` — established gallery format
- `brandbook/logo-primary.svg` — v1 lockup (rejected baseline; also shows outlined-path wordmark conventions and `<title>`/`<desc>` accessibility pattern)

### Infrastructure
- `test/example/priv/playwright/` — node env + Playwright install for `file://` rendering
- `brandbook/tokens.css` — `--sigra-*` tokens the gallery links
</canonical_refs>

<specifics>
## Specific Ideas

- User: "a type treatment with some kind of motif/flourish/playful creative element worked in... a fully worked-in custom type treatment for a really nice fully integrated designed SVG typemark" — not "a shitty icon to the left of basic text."
- Brief's integration points for "sigra": g descender, i tittle, s entry/exit strokes, r shoulder.
- 16px favicon legibility is the kill test; the 54px admin topbar slot must not clip boundary-breaking elements (design viewBox padding that tolerates overflow).
</specifics>

<deferred>
## Deferred Ideas

- Final asset set (subtitle variant file, monochrome, social cards) → Phase 181
- Token version bump / palette propagation → Phases 182–183
- README/social adoption → post-milestone fast-follow
</deferred>

---

*Phase: 179-outlining-toolchain-logo-concept-exploration*
*Context gathered: 2026-06-12 from Phase 178 outputs (no separate discuss-phase needed — design contract already committed)*
