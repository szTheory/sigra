---
phase: 260719-lhs
plan: 01
subsystem: documentation
tags: [exdoc, favicon, mermaid, dark-mode, accessibility]
requires:
  - phase: 260719-iwr
    provides: Architecture and code-walkthrough guides with pinned Mermaid rendering
provides:
  - Rail Accent favicon on every generated ExDoc HTML page
  - Theme-reactive Mermaid diagrams with serialized, failure-safe rerendering
  - Focused contracts for brand, security, accessibility, and fallback behavior
affects: [hexdocs, architecture-guide, documentation-tooling]
tech-stack:
  added: []
  patterns:
    - ExDoc body-class observation drives in-place Mermaid default/dark rerenders
    - Raw Mermaid source remains in the DOM as the first-render fallback
key-files:
  created: []
  modified:
    - mix.exs
    - test/sigra/architecture_guides_contract_test.exs
key-decisions:
  - "Reuse brandbook/favicon.svg unchanged through ExDoc's favicon option."
  - "Retain the pinned Mermaid 11.16.0 UMD/SRI loader while adopting Accrue's serialized, theme-reactive render model."
patterns-established:
  - "Theme rerenders replace wrapper children only after a successful render, preserving the last-good SVG on failure."
requirements-completed: []
coverage:
  - id: D1
    description: Every generated ExDoc page uses the theme-aware Rail Accent favicon.
    verification:
      - kind: integration
        ref: "mix docs --warnings-as-errors; cmp brandbook/favicon.svg doc/assets/favicon.svg; generated page link checks"
        status: pass
    human_judgment: false
  - id: D2
    description: Architecture diagrams follow live ExDoc light/dark state without duplication or lost fallbacks.
    verification:
      - kind: automated_ui
        ref: "agent-browser session sigra-docs-lhs: light/dark toggle, round-trip navigation, CDN abort, and rerender-failure simulation"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-07-19
status: complete
---

# Quick Task 260719-lhs: Sigra ExDoc Brand and Dark Diagrams Summary

**Rail Accent favicon wiring plus default/dark Mermaid palettes that track ExDoc live without sacrificing Sigra's pinned loader or readable fallbacks**

## Performance

- **Duration:** 15 min
- **Completed:** 2026-07-19T19:40:07Z
- **Tasks:** 2
- **Product files modified:** 2

## Accomplishments

- Configured `brandbook/favicon.svg` as ExDoc's favicon; generated pages copy it byte-for-byte to `doc/assets/favicon.svg` and link it as `assets/favicon.svg`.
- Reworked the existing Mermaid hook to select `default`/`dark` from `body.dark`, serialize render events, rerender wrappers in place, and preserve source or last-good SVGs on failures.
- Replaced the light dark-mode panel with a transparent responsive wrapper and subtle theme-aware ring, then verified all four diagrams visually in light and dark.
- Added focused contracts for the favicon's brand metadata/colors and the Mermaid theme, observer, queue, source/theme storage, in-place replacement, security, navigation, accessibility, and EPUB behavior.

## Task Commit

1. **Tasks 1–2: Brand ExDoc and fix dark diagrams** — `2d48d39e` (`docs`)

GSD PLAN, SUMMARY, and STATE were intentionally excluded from the product commit; the root orchestrator owns their closeout.

## Files Modified

- `mix.exs` — ExDoc favicon option, responsive diagram styling, serialized theme-reactive Mermaid hook.
- `test/sigra/architecture_guides_contract_test.exs` — favicon and Mermaid behavior contracts.

The existing `brandbook/favicon.svg` and both guide source files were unchanged. Ignored generated HTML/assets were not committed.

## Verification Evidence

- `source tmp/db.env && mix test test/sigra/architecture_guides_contract_test.exs` — 11 tests, 0 failures.
- `mix format --check-formatted mix.exs test/sigra/architecture_guides_contract_test.exs` — passed.
- `mix docs --warnings-as-errors` — passed; generated HTML and Markdown docs successfully.
- `cmp brandbook/favicon.svg doc/assets/favicon.svg` — passed byte-for-byte.
- Both `doc/architecture.html` and `doc/code-walkthrough.html` contain `<link rel="icon" href="assets/favicon.svg" />`.
- Named `agent-browser` session `sigra-docs-lhs`:
  - light: 4 wrappers, 4 hidden source fallbacks, all stored themes `default`, 4 accessible SVG titles/descriptions, no page overflow;
  - live Dark selection: 4 wrappers, all stored themes `dark`, transparent SVG backgrounds, no duplication or page overflow;
  - architecture → walkthrough → architecture: walkthrough retained favicon and 15 readable excerpts; return yielded exactly 4 dark diagrams and 4 accessible SVGs;
  - blocked Mermaid CDN on fresh load: 0 wrappers and all 4 source diagrams visible/readable;
  - simulated dark→light rerender failure: all 4 last-good SVGs remained byte-identical and wrappers retained their last successful theme.
- Screenshots inspected: `/tmp/sigra-architecture-light.png`, `/tmp/sigra-architecture-dark-clean.png`, `/tmp/sigra-walkthrough-dark.png`, and `/tmp/sigra-architecture-fallback-dark.png`.
- Automation session closed successfully.
- `open -a "Google Chrome" "file:///Users/jon/projects/sigra/doc/architecture.html" "file:///Users/jon/projects/sigra/doc/code-walkthrough.html"` — exit 0. Because the existing Chrome instance did not surface new tabs from that LaunchServices request, an AppleScript fallback created both tabs in the front window and activated Architecture; a URL-only count verified exactly 2 matching visible tabs.

## Decisions Made

- Kept Sigra's exact Mermaid 11.16.0 URL, SRI, crossorigin, strict security, error suppression, HTML-only/EPUB-empty hooks, and global installation guard.
- Kept raw fenced source in the DOM after first render so CDN or initial render failure remains readable; theme failures retain the previous SVG rather than exposing source underneath a stale wrapper.
- Used the current Accrue implementation as the rerendering model while preserving Sigra's stronger loader and fallback guarantees.

## Deviations from Plan

None — the plan was executed as written.

## Issues Encountered

- macOS `open -a` returned success but the already-running Chrome instance retained its existing Tasklane tab. Creating the two file tabs through Chrome's AppleScript interface resolved the visible-open handoff; a follow-up count returned `2` without exposing unrelated tab URLs.

## Residual Concerns

- Rendered diagrams still depend on the pinned jsDelivr asset being reachable, by design. The verified fenced-source fallback covers an unavailable CDN.
- No runtime, template, package, guide prose, diagram source, or brand asset changes were made.

## User Setup Required

None. Both pages are already open in Google Chrome.

---
*Quick task: 260719-lhs*
*Completed: 2026-07-19*
