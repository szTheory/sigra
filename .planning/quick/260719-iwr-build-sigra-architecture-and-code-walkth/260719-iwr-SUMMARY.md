---
phase: 260719-iwr
plan: "01"
subsystem: documentation
tags: [hexdocs, architecture, mermaid, exdoc, elixir]
requires: []
provides:
  - Boundary-first Sigra architecture guide with four accessible diagrams
  - Source-guided walkthrough with fifteen parseable excerpts
  - Pinned, strict, navigation-safe Mermaid rendering with source fallback
  - Focused documentation drift contracts and discovery wiring
affects: [documentation, installer, authentication, sessions, audit, optional-integrations]
tech-stack:
  added: [Mermaid 11.16.0 as an integrity-pinned documentation asset]
  patterns:
    - ExDoc diagrams keep fenced source visible until rendering succeeds
    - Documentation excerpts are parseable and anchored to current source
key-files:
  created:
    - guides/introduction/architecture.md
    - guides/introduction/code-walkthrough.md
    - test/sigra/architecture_guides_contract_test.exs
  modified:
    - mix.exs
    - README.md
    - guides/introduction/first-hour.md
    - CHANGELOG.md
    - doc/llms.txt
key-decisions:
  - "Document the current generated password-login double-session seam without changing or blessing it."
  - "Use a neutral light diagram surface so the same strict Mermaid output remains legible in both ExDoc themes."
  - "Keep the existing package membership unchanged; the guides are ExDoc inputs, not Hex package files."
patterns-established:
  - "Mermaid lifecycle: render unprocessed fences on exdoc:loaded, mark success, then hide source."
  - "Guide drift contracts validate structure and a compact source-anchor table without freezing prose wholesale."
  - "Walkthrough cut markers act as wildcards; every contiguous segment between them must match dedented current source exactly."
requirements-completed: [ARCH-DOCS]
coverage:
  - id: D1
    description: Architecture and walkthrough teach one accurate system from opposite directions.
    requirement: ARCH-DOCS
    verification:
      - kind: unit
        ref: test/sigra/architecture_guides_contract_test.exs
        status: pass
      - kind: integration
        ref: mix docs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Mermaid diagrams render accessibly across theme and ExDoc navigation while preserving fallback source.
    requirement: ARCH-DOCS
    verification:
      - kind: automated_ui
        ref: agent-browser final named-session light/dark/navigation/fallback review
        status: pass
    human_judgment: false
duration: ~30min
completed: 2026-07-19
status: complete
---

# Quick Task 260719-iwr: Architecture and Code Walkthrough Summary

**A paired HexDocs learning path now explains Sigra's ownership boundary outside-in and traces current implementation values inside-out.**

## Performance

- **Duration:** ~30 minutes
- **Completed:** 2026-07-19
- **Tasks:** 3
- **Product files modified:** 8

## Accomplishments

- Added the architecture guide with the prescribed eleven-part narrative, four accessible Mermaid diagrams, the durable token/session model, and current ownership/security seams.
- Added the code walkthrough with fifteen parseable 8–35-line excerpts, source-reading routes, and explicit internal/generated-code warnings.
- Added an integrity-pinned Mermaid hook, discovery/changelog wiring, tracked ExDoc TOC regeneration, and ten focused drift-contract tests.
- Remediated verifier findings in excerpts 3, 4, 7, 13, and 15 so every omitted interval is explicit and all remaining source segments preserve current formatting.

## Task Commit

1. **Architecture guides, renderer, discovery, and contracts** — `49d027ee` (`docs`)
2. **Source-honest walkthrough excerpts and exact-segment contract** — `76fc21aa` (`docs`)

## Files Created/Modified

- `guides/introduction/architecture.md` — outside-in system model and four diagrams.
- `guides/introduction/code-walkthrough.md` — inside-out fifteen-excerpt source journey.
- `test/sigra/architecture_guides_contract_test.exs` — discovery, structure, parseability, source-anchor, seam, and renderer contracts.
- `mix.exs` — ordered extras and strict Mermaid lifecycle hooks.
- `README.md` and `guides/introduction/first-hour.md` — concise adopter/maintainer discovery routes.
- `CHANGELOG.md` — Unreleased documentation entry.
- `doc/llms.txt` — regenerated v1.3.0 TOC containing both new pages.

## Verification Evidence

- Focused contract after verifier remediation: **10 tests, 0 failures**; the five multi-cut excerpts are checked segment-by-segment against current source.
- Docs: `mix docs --warnings-as-errors` passed; both generated HTML pages exist.
- Full root suite after remediation: **33 doctests, 3 properties, 2418 tests, 0 failures, 12 skipped (3 excluded)**.
- Formatting: changed Elixir files pass `mix format --check-formatted`; `git diff --check` passes.
- Package: temporary `mix hex.build --unpack` passed and contained no planning, test, or input directories; package membership stayed unchanged.
- Browser: walkthrough rendered 15 code blocks with zero horizontal overflow in Light and Dark; architecture rendered four unique diagrams with zero overflow in both themes; both cross-links navigated; a second navigation produced no duplicates; Mermaid-unavailable simulation left the original fenced source visible and unmarked.

## Decisions Made

- Kept diagrams contrast-stable by rendering Mermaid's neutral theme on a light bounded surface in both ExDoc themes.
- Used `accTitle` and `accDescr` in every diagram rather than relying on surrounding prose for accessibility.
- Treated the reference host as executable evidence, never as a public API promise.

## Deviations from Plan

None in product scope. No runtime, template, reference-host, lockfile, package-membership, or legacy-guide changes were made.

## Issues Encountered

- ExDoc initially warned that the Ecto store callback was hidden; the prose was corrected to link the module and name the callback without creating a broken function reference.
- Independent verification found five excerpts with unmarked omissions or source reformatting. Commit `76fc21aa` added the missing `# ...` boundaries, restored exact source formatting, and introduced a regression contract for contiguous excerpt segments.
- The repository-wide `mix format --check-formatted` gate reports extensive pre-existing drift in unrelated runtime, fixture, and test files under the current formatter. Those files were left untouched. The changed Elixir files pass the formatter check.

## Disclosed Existing Mismatches

- The generated password-login path currently creates a session inside `Sigra.Auth.authenticate/3`, drops that metadata in the generated context wrapper, and creates the cookie-backed session again in generated `UserAuth`.
- The older login/logout guide names `auth.user_tokens` for sessions; current canonical session persistence uses `auth.user_sessions`.

## User Setup Required

None.

## Next Phase Readiness

- The guide pair and its contract tests are ready for independent verification.
- A future runtime/template task can repair the disclosed double-session seam and separately correct the stale legacy guide.

---
*Quick task: 260719-iwr*
*Completed: 2026-07-19*
