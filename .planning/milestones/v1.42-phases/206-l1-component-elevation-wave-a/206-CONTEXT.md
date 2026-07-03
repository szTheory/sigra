# Phase 206: L1 Component Elevation Wave A - Context

**Gathered:** 2026-06-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Elevate the **8 highest-reuse L1 components** to Tier-2 on their **isolated `board-*`
gallery boards** — `notice`, `notice_link`, `stat`, `stat_link`, `summary_chip`,
`task_card`, `applied_chip`, `audit_row`. Award-grade means: every interactive state,
motion-token conformant, light/dark/system correct, accessible, per-component axe-clean
across chromium/mobile/dark, with all 8 L1 ledger rows flipped to bare `2`.

This is **component-level work only**. Page composition (Phase 209), L2 meta-component
groups (Phase 208), and the remaining 5 L1 components + L0 token layer (Phase 207) are
out of scope. Requirement: **COMP-01**.
</domain>

<decisions>
## Implementation Decisions

### Scope boundary (component-only)

- **D-01:** Phase 206 modifies the 8 L1 components on their **isolated `board-*` gallery
  boards only**. It does **NOT** touch page composition. The IA diagnostic
  (`.planning/v1.42-IA-DIAGNOSTIC.md`) tags several *page-composition* findings as
  "feeds 206" (users-index applied-chip DOM position; More-filters `phx-click` vs
  `<details>`; quick-toggle Apply expectation gap). These are **page-level** concerns and
  route to **Phase 207** (audit/list page elevation) and **Phase 209** (page judgment
  pass), where they are already tagged. 206 does not pull page-recompose work earlier —
  this keeps the elevation waves clean and avoids collision with 207/209.

### Elevation mechanics (audit + narrow-gap-fix, not refactor)

- **D-02:** Components stay where they are. Function defs live in
  `lib/sigra/admin/components.ex` (`stat_link:53`, `stat:81`, `task_card:113`,
  `summary_chip:169`, `applied_chip:372`, `notice:509`, `notice_link:541`,
  `audit_row:702`); styling lives in `priv/templates/sigra.install/admin/sigra_admin.css`
  via `sg-*` classes. Phase 206 is **audit → cite → narrow-gap-fix → ledger-flip →
  recapture**, NOT relocation or restructure. The plausible *real* gaps are narrow:
  (a) confirm interaction-state CSS exists per interactive component (hover/focus/active/
  disabled), (b) per-component documented target-size, (c) light/dark visual correctness
  via the dark project snapshot.
- **D-03 (edit the source, not the copy):** All CSS/markup edits land in the
  `priv/templates/sigra.install/` **source**, never the generated `test/example/` copy or
  `test/fixtures/install_golden/` tree. Generated copies must stay byte-coherent or
  golden-diff/install tests fail and host apps never receive the elevation via
  `mix deps.update`. (Known template-drift hazard.)

### Per-component axe (success criterion 1)

- **D-04:** Per-component, per-project axe is **already wired** — do not build new axe
  infrastructure. `admin-design.spec.ts` defines `COMPONENT_BOARDS` (~:98) covering all 8;
  the screenshot loop (~:257) runs `assertBoardScreenshot`, which calls
  `assertNoAxeViolations` first (element-scoped, wcag2a/2aa/21a/21aa/22aa), across the 3
  projects `admin-design-chromium`/`-mobile`/`-dark`. 206's job is to keep these boards
  0-violation through any CSS change and **cite the existing gate** as ledger evidence.

### Motion + token verification (success criteria 2 & 3) — build durable guard

- **D-05:** Add a **lightweight durable CI guard** under `scripts/ci/` (grep-based,
  zero-human) that asserts: (a) no `transition: all` anywhere in the admin CSS, and
  (b) no raw hex outside `:root` token definitions. Criterion 2 explicitly permits
  "code review OR automated check"; we choose the automated check because it is reusable
  across the remaining elevation waves (207–211) and matches the zero-human-UAT posture.
  Cite the guard in the ledger evidence strings.
- **D-06 (reduced-motion strategy):** Rely on the **existing global**
  `@media (prefers-reduced-motion: reduce)` block (`sigra_admin.css:~1467`) which strips
  transform/animation while keeping color/bg/border/shadow/opacity transitions. Do **NOT**
  rewrite each component with its own per-component media query — criterion 2's "wrapped in
  `@media (prefers-reduced-motion: reduce)`" is satisfied by the global block. Component
  transitions already reference motion tokens (`--sg-transition-tone`,
  `--sg-transition-press`), so they inherit the global strip.
- **D-07 (token-naming reconciliation):** The CSS uses `--sg-motion-*` / `--sg-ease`
  tokens, but the fractal scorecard proxy text (`admin-fractal-scorecard.md:~164`) names
  non-existent `--sg-duration-*` / `--sg-ease-*` tokens. Treat the real `--sg-motion-*`
  tokens as authoritative. Opportunistically reconcile the scorecard prose while editing
  it, so evidence strings cite real token names.

### Ledger flip + snapshot discipline (success criterion 4)

- **D-08:** Flip all 8 L1 rows in `guides/reference/admin-quality-ledger.md` from `1`→`2`
  with **rich semicolon-delimited evidence** mirroring the existing Tier-2 `index-live`
  row (~:85): 3-project axe+screenshot spec citation; motion-tokens "reviewed/guarded —
  no `transition: all`"; target-size "reviewed — ≥24×24 CSS px (documented-as-manual)";
  token-conformance citation; `N/A` for inapplicable proxies (e.g. content-equivalence for
  non-table components). The new motion/hex guard (D-05) is a citable evidence source.
- **D-09 (snapshot discipline, v1.41 method):** Any CSS state change forces **recapture of
  the affected `board-*` PNG baselines** through the snapshot-recapture gate. The
  `impersonation-banner` and `board-notice` canaries stay **byte-stable and untouched**;
  **both allowlists empty at phase close**; `scripts/ci/quality-ledger-monotonic.sh
  --base origin/main` exits 0.

### Claude's Discretion

- Exact per-component interaction-state audit findings and which (if any) genuinely need a
  CSS fix vs already-present.
- Exact shape of the motion/hex guard script (flags, output format) — pick lowest-friction
  consistent with the existing `quality-ledger-monotonic.sh` self-test shape; add a
  sibling `.test.sh` if cheap.
- Precise wording of each ledger evidence string (keep `awk -F'|'` monotonic-guard-safe —
  bare `2` in the tier column, no decorated integers).
- Whether to reconcile the `--sg-duration-*` scorecard prose now (D-07) or note it for a
  follow-up — prefer fixing in-place if touching the doc anyway.
- Exact per-component documented target-size values (cite real CSS px from the boards).

### Folded Todos

None. The 4 phase-matched todos were reviewed and not folded (see Deferred).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/v1.42-IA-DIAGNOSTIC.md` — advisory persona-panel diagnostic; Section 3
  prioritized disposition list (which findings feed 206 vs 207/209)
- `guides/reference/admin-quality-ledger.md` — the 8 L1 rows to flip (~:61–73); Tier-2
  evidence exemplar `index-live` (~:85)
- `guides/reference/admin-fractal-scorecard.md` — tier vocabulary; L1 add-on motion/
  target-size/token proxies (~:54, :162–165); `--sg-duration-*` doc discrepancy (~:164)
- `guides/reference/admin-persona-jtbd-rubric.md` — the 3-lens × 3-question rubric (Phase
  205 instrument; binding gate is Phase 209, advisory here)
- `lib/sigra/admin/components.ex` — the 8 component function defs
- `priv/templates/sigra.install/admin/sigra_admin.css` — canonical `sg-*` styling source
  (edit here; the `test/example/` copy is generated)
- `test/example/priv/playwright/tests/admin-design.spec.ts` — `COMPONENT_BOARDS`,
  `assertBoardScreenshot` (axe + screenshot per board × 3 projects)
- `test/example/priv/playwright/playwright.config.ts` — the 3 admin-design projects
- `test/sigra/admin/components_test.exs` — byte-golden component suite
- `scripts/ci/quality-ledger-monotonic.sh` — monotonic guard (must exit 0 vs origin/main)
- `guides/reference/admin-design-contract.md`, `guides/reference/admin-ui-principles.md` —
  design system governance
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Per-component axe + screenshot harness already exists** for all 8 boards
  (`COMPONENT_BOARDS` + `assertBoardScreenshot` in `admin-design.spec.ts`), running across
  chromium/mobile/dark — success criterion 1 is structurally satisfied today.
- **State-evidence boards already render** the interactive states:
  `task_card` default/hover/focus/active/disabled (~:543), `applied_chip` (~:573),
  `notice_link` (~:625), `notice` 5 tones (~:607), `audit_row` + reduced-motion (~:636).
- **Global reduced-motion block** (`sigra_admin.css:~1467`) — the single `*,::before,::after`
  rule (sole documented `!important`) that strips transform/animation; zero `transition: all`
  in the codebase today.
- **Interaction-state CSS already present**: `sg-metric-link` hover/focus/active (~:1384),
  applied-chip remove (~:966), notice__action (~:1064), `sg-card-hover` (~:559).
- **Motion tokens** `--sg-motion-*` (36 uses) / `--sg-ease` defined ~:132; hex literals
  appear only inside `:root` token defs (~:58–71).

### Established Patterns
- v1.41 snapshot-recapture-gate + monotonic-ledger methodology (Phases 199–204) — apply
  verbatim: edit source CSS → recapture affected board PNGs → canaries byte-stable →
  allowlists empty at close → monotonic guard green.
- Ledger Tier-2 evidence = long semicolon-delimited string; tier column is bare `2`
  (decorated integers like `2*` would break/confuse the `awk -F'|'` monotonic parse).

### Integration Points
- `priv/templates/sigra.install/` source → generated `test/example/` copy +
  `test/fixtures/install_golden/` tree (keep byte-coherent).
- New motion/hex CI guard slots beside `scripts/ci/quality-ledger-monotonic.sh`.
</code_context>

<specifics>
## Specific Ideas

- Motion/hex guard should follow the lowest-friction shape consistent with the existing
  `quality-ledger-monotonic.sh` (+ its `.test.sh` self-test) so it reads as a sibling, not
  a new convention.
- Ledger evidence strings should cite the new guard as the motion/token conformance proof,
  not just "reviewed by hand".
</specifics>

<deferred>
## Deferred Ideas

- **Page-composition findings tagged "feeds 206"** (applied-chip DOM position, More-filters
  `phx-click` vs `<details>`, quick-toggle Apply expectation gap) — these are page-level,
  deferred to Phase 207 (audit/list) and Phase 209 (page judgment), per D-01.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db.md` (score 0.9) — CI-perf
  infrastructure, not component-DS work. Not folded.
- `2026-06-18-token-reference-completeness-ci-guard.md` (0.6) — about documenting *every*
  token in `admin-token-reference.md` (COMP-03 / Phase 207 territory), distinct from D-05's
  raw-hex-in-components guard. Adjacent but not folded; revisit in 207.
- `2026-06-19-uat-demo-dx-polish-nits.md` (0.6) — demo-DX script polish, unrelated. Not folded.
- `2026-06-25-phase200-code-review-deferred.md` (0.6) — session-revocation/admin helpers,
  page-functionality not component-DS. Not folded.
</deferred>
