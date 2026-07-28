---
phase: 260719-lhs
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mix.exs
  - test/sigra/architecture_guides_contract_test.exs
autonomous: true
requirements: []
quick_task: true

must_haves:
  truths:
    - "Every generated Sigra ExDoc page links to the existing theme-aware Rail Accent favicon."
    - "Architecture diagrams use Mermaid's light or dark theme to match ExDoc immediately and after an in-page theme change."
    - "Mermaid remains pinned, strict, accessible, navigation-idempotent, and source-readable when loading or rendering fails."
    - "The regenerated architecture and walkthrough pages are verified in light/dark and opened as visible Google Chrome tabs."
  artifacts:
    - path: "mix.exs"
      provides: "ExDoc favicon wiring plus theme-reactive Mermaid HTML hooks"
      contains: "favicon: \"brandbook/favicon.svg\""
    - path: "test/sigra/architecture_guides_contract_test.exs"
      provides: "Focused favicon and light/dark Mermaid hook contracts"
      contains: "prefers-color-scheme: dark"
  key_links:
    - from: "mix.exs docs/0"
      to: "brandbook/favicon.svg"
      via: "ExDoc favicon option and automatic asset copy"
      pattern: "favicon: \"brandbook/favicon.svg\""
    - from: "ExDoc body.dark state"
      to: "rendered .sigra-mermaid wrappers"
      via: "serialized MutationObserver rerender using Mermaid dark/default themes"
      pattern: "MutationObserver"
    - from: "doc/architecture.html and doc/code-walkthrough.html"
      to: "doc/assets/favicon.svg"
      via: "generated <link rel=\"icon\">"
      pattern: "assets/favicon.svg"
---

<objective>
Give Sigra HexDocs its ratified Rail Accent favicon and make the architecture diagrams genuinely readable in ExDoc light and dark modes, following the current local Accrue/Mailglass docs patterns while retaining Sigra's stronger pinned/SRI loader, strict security, navigation idempotence, accessibility, and fallback behavior.

This remains documentation configuration only. Reuse `brandbook/favicon.svg` byte-for-byte; do not redraw it, add an ExDoc logo, modify diagram source/prose, package the brandbook, or change runtime code.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@AGENTS.md
@mix.exs
@brandbook/favicon.svg
@test/sigra/architecture_guides_contract_test.exs

Reference behavior inspected locally:
- `/Users/jon/projects/accrue/accrue/mix.exs` is the implementation model: it derives `dark`/`default` from `body.dark`, serializes rendering, observes body-class changes, remembers diagram source/theme, and rerenders existing diagrams without duplication.
- `/Users/jon/projects/mailglass/mix.exs` confirms the same ExDoc favicon option/copy pattern and Mermaid `dark`/`default` choice.
- Sigra's current hook already pins Mermaid 11.16.0 with SRI, sets `securityLevel: "strict"`, listens for `exdoc:loaded`, and hides source only after render success; preserve those guarantees.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Wire the favicon and make Sigra Mermaid theme-reactive with contracts</name>
  <files>mix.exs, test/sigra/architecture_guides_contract_test.exs</files>
  <action>
Add `favicon: "brandbook/favicon.svg"` to `docs/0` beside the existing ExDoc identity/source options. Keep the existing SVG unchanged; it already carries accessible Sigra metadata, ember-700 (`#c2410c`) for light chrome, ember-300 (`#fdba74`) for dark chrome, and a `prefers-color-scheme: dark` rule.

Refactor only the existing Mermaid head/body hooks, using Accrue's current hook as the behavioral model while retaining Sigra's exact 11.16.0 UMD URL, SRI/crossorigin attributes, `securityLevel: "strict"`, `startOnLoad: false`, `suppressErrorRendering: true`, and blank EPUB/non-HTML callbacks:
- Derive the desired Mermaid theme from `document.body.classList.contains("dark") ? "dark" : "default"`; remove the fixed `neutral` theme.
- Serialize render requests through one promise queue so `exdoc:loaded`, CDN load, initial DOM readiness, and theme mutation cannot race.
- Observe only the body's `class` attribute and schedule a rerender when ExDoc toggles theme.
- Preserve each diagram's original source and rendered theme. On a theme change, reinitialize Mermaid for that theme and replace the existing wrapper's SVG in place; never append a second wrapper.
- Keep navigation idempotent: new fenced blocks on `exdoc:loaded` render once, existing wrappers rerender only when their stored theme differs, and graph IDs stay unique.
- Keep the original `<pre><code class="mermaid">` in the DOM and visible until the first SVG succeeds. After success it may stay hidden as Sigra currently does; on initial load/render failure remove pending state and leave readable source visible. On a theme-rerender failure, keep the last successful SVG rather than blanking it.
- Make the wrapper transparent with a subtle light/dark border/ring and responsive overflow so Mermaid's own default/dark palette sits naturally on ExDoc instead of the current light panel in dark mode. Preserve width/overflow behavior and the diagrams' `accTitle`/`accDescr` accessibility.

Extend `Sigra.ArchitectureGuidesContractTest` with focused assertions for the exact favicon path/file, SVG brand metadata/theme rule/colors, dark/default theme selection, body-class MutationObserver, serialized queue, stored source/theme, in-place rerender, and existing fallback-order/idempotence/security/EPUB guarantees. Keep failures actionable and do not overfit whitespace.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra &amp;&amp; source tmp/db.env &amp;&amp; mix test test/sigra/architecture_guides_contract_test.exs &amp;&amp; mix format --check-formatted mix.exs test/sigra/architecture_guides_contract_test.exs</automated>
  </verify>
  <done>The exact Sigra favicon is configured; Mermaid initializes and rerenders with `default`/`dark` as ExDoc changes; diagrams neither duplicate nor disappear on navigation/theme changes/failure; focused contracts, existing accessibility contracts, and scoped formatting pass; the SVG and guide sources are unchanged.</done>
</task>

<task type="auto">
  <name>Task 2: Regenerate, inspect, browser-verify light/dark, and visibly open</name>
  <files>doc/architecture.html, doc/code-walkthrough.html, doc/assets/favicon.svg</files>
  <action>
Run ExDoc with warnings as errors. Verify both guide pages link `assets/favicon.svg`, the copied file exists, and `cmp` proves it is byte-identical to `brandbook/favicon.svg`.

Use a file-access browser session for deterministic review. On architecture, verify four wrappers and four hidden source fallbacks after rendering; inspect screenshots in light and dark; toggle the live ExDoc theme and confirm all wrappers change their stored theme and SVG palette without duplicates. Navigate architecture → walkthrough → architecture and reconfirm exactly four diagrams, accessible SVG labels, responsive width/no page overflow, and working fallback by blocking or disabling Mermaid before a fresh load. Confirm the walkthrough remains readable and carries the favicon link. Close the automation session afterward.

Finally run macOS `open -a "Google Chrome"` with both absolute `file://` URLs so architecture and walkthrough appear as visible tabs for the user. Do not substitute a headless-only handoff. Do not commit ignored generated HTML/assets.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra &amp;&amp; mix docs --warnings-as-errors &amp;&amp; test -f doc/assets/favicon.svg &amp;&amp; cmp brandbook/favicon.svg doc/assets/favicon.svg &amp;&amp; rg -q '&lt;link rel="icon" href="assets/favicon.svg" /&gt;' doc/architecture.html doc/code-walkthrough.html</automated>
    Browser evidence: light and dark screenshots show four legible architecture diagrams; live theme toggle changes all four stored themes with no extra wrappers; round-trip ExDoc navigation still yields four; failure simulation leaves source readable. Then `open -a "Google Chrome" "file:///Users/jon/projects/sigra/doc/architecture.html" "file:///Users/jon/projects/sigra/doc/code-walkthrough.html"` returns successfully.
  </verify>
  <done>Docs build warning-free; both pages link the copied byte-identical favicon; four accessible diagrams are legible and non-duplicated in light/dark, navigation, and live theme changes; fallback remains readable; both pages are open as visible Google Chrome tabs; status contains only declared implementation/GSD artifacts and intentional ExDoc tracked regeneration.</done>
</task>

</tasks>

<verification>
- Focused contract test and scoped formatter pass.
- `mix docs --warnings-as-errors` passes.
- Both generated guide pages link `assets/favicon.svg`; copied/source SVGs compare byte-identical.
- Browser review proves exactly four diagrams in light and dark, in-place theme rerender, round-trip navigation idempotence, accessible output, responsive layout, and source fallback.
- Both generated guide URLs are opened visibly in Google Chrome.
- `git diff -- brandbook/favicon.svg guides/introduction/architecture.md guides/introduction/code-walkthrough.md` is empty and no unrelated files change.
</verification>

<success_criteria>
- Every Sigra HexDocs HTML page uses the theme-aware Rail Accent favicon.
- Architecture diagrams visually match ExDoc light/dark state, including live theme changes, without duplicate/stale wrappers.
- Mermaid remains exactly pinned/SRI-checked, strict, accessible, navigation-aware, HTML-only, and fallback-safe.
- Contracts and browser evidence protect both behaviors, and the user can immediately view the regenerated pages in Google Chrome.
</success_criteria>

<output>
Create `.planning/quick/260719-lhs-use-the-sigra-brand-favicon-for-exdoc-pa/260719-lhs-SUMMARY.md` when implementation is complete.
</output>
