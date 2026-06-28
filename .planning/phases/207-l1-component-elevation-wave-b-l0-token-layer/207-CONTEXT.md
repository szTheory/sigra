# Phase 207: L1 Component Elevation Wave B + L0 Token Layer - Context

**Gathered:** 2026-06-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Elevate the **5 remaining L1 components** (`empty_state`, `page_back`, `scope_ribbon`,
`field_help`, `skeleton`) on their **isolated `board-*` gallery boards**, plus the **L0
token layer**, to Tier-2 — completing the full 13-component + token-layer elevation. Award-
grade means: every interactive state, motion-token conformant (no `transition: all`,
`prefers-reduced-motion` strips movement), light/dark/system correct, accessible, per-
component axe-clean across chromium/mobile/dark; documented brand-token conformance for L0
(no raw hex/px outside `--sg-*` tokens) with a refreshed `admin-token-reference.md`; the 5
component ledger rows + the `token-layer` row flipped to bare `2`.

This is **component- and token-level work only** on isolated boards. Page composition,
cross-page placement coherence, and the adversarial persona panel are **out of scope** —
they belong to Phase 209 (Judgment-Level Page Pass). L2 meta-component groups are Phase 208.
Requirements: **COMP-02, COMP-03**.
</domain>

<decisions>
## Implementation Decisions

### Scope boundary (component + token, isolated boards only)

- **D-01:** Phase 207 modifies the 5 L1 components on their **isolated `board-*` gallery
  boards only**, plus the L0 token layer. It does **NOT** touch page composition or cross-
  page placement. The `.planning/v1.42-IA-DIAGNOSTIC.md` disposition list (~:246–287) tags
  several **page-composition** findings as "Phase 207 — Audit List elevation" (scope_ribbon
  placement inconsistency across audit pages; applied-chip DOM position; More-filters
  `phx-click` vs `<details>`; quick-toggle Apply expectation gap; "Effective user"
  asymmetric filter). That diagnostic uses **v1.41-era page numbering** — its "feeds 207"
  tag is stale labeling. The **authoritative v1.42 ROADMAP** defines Phase 207 as the 5
  isolated components + token layer; all cross-page page-composition concerns route to
  **Phase 209** (Judgment-Level Page Pass). 207 elevates the `scope_ribbon` *component* on
  its board; the scope_ribbon *placement-across-pages* incoherence is 209's job. Do not pull
  page-recompose work earlier — it collides with 209 and causes duplicate baseline churn.

### Elevation mechanics (mirror Phase 206 verbatim — audit + narrow-gap-fix, not refactor)

- **D-02:** Apply the **identical Phase 206 method**: audit → cite existing gate → narrow-
  gap-fix → ledger-flip → snapshot-recapture. Components stay where they are. Function defs
  live in `lib/sigra/admin/components.ex` (`empty_state` ~:410, `scope_ribbon` ~:465,
  `field_help`, `page_back`, `skeleton`); styling lives in
  `priv/templates/sigra.install/admin/sigra_admin.css` via `sg-*` classes. This is **audit
  → cite → narrow-gap-fix → ledger-flip → recapture**, NOT relocation or restructure.
- **D-03 (edit the source, not the copy):** All CSS/markup edits land in the
  `priv/templates/sigra.install/` **source**, never the generated `test/example/` copy or
  `test/fixtures/install_golden/` tree. Generated copies must stay byte-coherent or
  golden-diff/install tests fail and host apps never receive the elevation via
  `mix deps.update`. (Known template-drift hazard.)

### Per-component axe + boards (success criterion 1) — reuse, don't rebuild

- **D-04:** Per-component, per-project axe is **already wired** for all 5 boards in
  `test/example/priv/playwright/tests/admin-design.spec.ts` (`COMPONENT_BOARDS` ~:100–102;
  `assertBoardScreenshot` runs `assertNoAxeViolations` element-scoped across
  chromium/mobile/dark). 207's job is to keep these boards 0-violation through any CSS
  change and **cite the existing gate** as ledger evidence. State-evidence already renders:
  `field_help` Escape/focus-restore (~:695–712); `skeleton` line/block/card + reduced-motion
  assertion (~:640–677). Add a state-variant board only if an audit surfaces a genuine gap.

### Motion + reduced-motion (success criterion 1) — reuse existing global block + guard

- **D-05 (reduced-motion strategy):** Rely on the **existing global**
  `@media (prefers-reduced-motion: reduce)` block (`sigra_admin.css:~1467`) which strips
  transform/animation (incl. `animation-iteration-count: 1 !important`). The `skeleton`
  infinite shimmer (`sigra_admin.css:~1419`) is the component most likely to have a real
  motion gap — but it is **already** covered by the global strip and has a passing
  reduced-motion assertion (`admin-design.spec.ts:~653–677`). Verify, cite, do not rewrite
  per-component media queries. Reuse the **already-built** `scripts/ci/admin-css-conformance.sh`
  guard (no `transition: all`; no raw hex outside `:root`) — built in Phase 206 (206 D-05).

### COMP-03 token-layer conformance — fold the deferred guard + extend to raw-px

- **D-06 (fold the token-completeness guard):** Fold the pending todo
  `2026-06-18-token-reference-completeness-ci-guard.md` (now `resolves_phase: 207`; 206
  deferred it saying "revisit in 207") into this phase as the **durable COMP-03 proof**: a
  lightweight CI check diffing `--sg-*` `:root` LHS defs in `sigra_admin.css` against the
  documented backtick tokens in `admin-token-reference.md`, failing on divergence. This
  backs the ROADMAP criterion 2 "refreshed `admin-token-reference.md` cites the conformance
  evidence" and prevents the doc's "every `--sg-*` :root property (96/96)" claim
  (`admin-token-reference.md:~3`) from silently rotting.
- **D-07 (extend conformance to raw-px):** COMP-03 requires "no raw hex/**px** outside
  `--sg-*` tokens," but `scripts/ci/admin-css-conformance.sh` currently checks hex only.
  **Extend the guard to catch raw-px** so the full COMP-03 conformance is automated and
  zero-human. **Fallback** (D-07a): if the raw-px sweep proves too noisy/heavy for one
  phase, the completeness guard (D-06) is the load-bearing COMP-03 proof; raw-px may degrade
  to a documented manual review like the existing target-size proxy — but the preferred path
  is the automated px check. Keep the guard shape a low-friction sibling of the existing
  conformance/monotonic scripts (+ `.test.sh` self-test).

### Ledger flip + snapshot discipline (success criteria 3 & 4)

- **D-08:** Flip exactly **6 rows** in `guides/reference/admin-quality-ledger.md` from
  `1`→ bare `2`: the 5 L1 component rows (`empty_state`, `page_back`, `scope_ribbon`,
  `field_help`, `skeleton`) + the `token-layer` (L0) row. Use the **rich semicolon-delimited
  evidence** shape mirroring the 8 freshly-flipped Wave-A rows (~:61–73): 3-project
  axe+screenshot spec citation; motion-tokens "reviewed/guarded — no `transition: all`";
  target-size "reviewed — ≥24×24 CSS px (documented)"; token-conformance citation
  (the completeness guard + raw-px/hex guard from D-06/D-07); `N/A` for inapplicable proxies
  (e.g. content-equivalence for non-table components). Tier column is **bare `2`** — never a
  decorated integer (`2*` breaks the `awk -F'|'` monotonic parse). At close, **all 13 L1
  cells + the L0 cell read `2`**.
- **D-09 (snapshot discipline, v1.41 method):** Any CSS state change forces **recapture of
  the affected `board-*` PNG baselines** through the snapshot-recapture gate. The
  `impersonation-banner` and `board-notice` canaries stay **byte-stable and untouched**;
  **both allowlists empty at phase close**; `scripts/ci/quality-ledger-monotonic.sh
  --base origin/main` exits 0.

### Folded Todos

- **`2026-06-18-token-reference-completeness-ci-guard.md`** (`resolves_phase: 207`, score
  0.6) — folded as the durable COMP-03 conformance proof (D-06). Targets
  `admin-token-reference.md` completeness; 206 explicitly deferred it to 207.

### Claude's Discretion

- Exact per-component interaction-state audit findings and which (if any) genuinely need a
  CSS fix vs already-present (expected: minimal — most state CSS already exists).
- Exact shape of the raw-px extension to `admin-css-conformance.sh` (regex, allowlist for
  legitimately-token-defining `:root` px, output format) — keep it a low-friction sibling.
- Exact shape of the token-completeness diff (parse `:root` LHS vs documented backticks);
  add a sibling `.test.sh` self-test if cheap.
- Precise wording of each ledger evidence string (keep `awk -F'|'` monotonic-guard-safe —
  bare `2` in the tier column).
- Exact per-component documented target-size values (cite real CSS px from the boards).
- Whether the raw-px check (D-07) lands automated or degrades to documented manual review
  (D-07a) — prefer automated; decide during execution based on noise.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/phases/206-l1-component-elevation-wave-a/206-CONTEXT.md` — **the template**;
  D-01…D-09 are the proven Wave-A method this phase mirrors
- `.planning/ROADMAP.md` — Phase 207 success criteria (~:100–105) are authoritative scope
  (component + token, isolated boards); Phase 209 (~:125–135) owns page composition
- `.planning/v1.42-IA-DIAGNOSTIC.md` — advisory; its "feeds 207" page-composition tags use
  stale v1.41 numbering and route to **209**, NOT 207 (see D-01)
- `guides/reference/admin-quality-ledger.md` — the 5 L1 rows + `token-layer` row to flip;
  Tier-2 evidence exemplar = the 8 Wave-A rows (~:61–73)
- `guides/reference/admin-fractal-scorecard.md` — tier vocabulary; L0/L1 motion/
  target-size/token proxies
- `guides/reference/admin-token-reference.md` — claims to document every `--sg-*` :root
  property (96/96, ~:3); COMP-03 requires a refreshed conformance citation
- `lib/sigra/admin/components.ex` — the 5 component function defs (`empty_state` ~:410,
  `scope_ribbon` ~:465, plus `page_back`, `field_help`, `skeleton`)
- `priv/templates/sigra.install/admin/sigra_admin.css` — canonical `sg-*` styling source
  (edit here; the `test/example/` copy is generated). Skeleton shimmer ~:1419; global
  reduced-motion block ~:1467
- `test/example/priv/playwright/tests/admin-design.spec.ts` — `COMPONENT_BOARDS` (~:100),
  `assertBoardScreenshot` (axe + screenshot per board × 3 projects); field_help/skeleton
  state assertions (~:640–712)
- `scripts/ci/admin-css-conformance.sh` (+ `.test.sh`) — motion/hex guard built in 206;
  extend for raw-px (D-07) and pair with the token-completeness diff (D-06)
- `scripts/ci/quality-ledger-monotonic.sh` — monotonic guard (must exit 0 vs origin/main)
- `.planning/todos/pending/2026-06-18-token-reference-completeness-ci-guard.md` — folded
  COMP-03 guard (D-06)
- `guides/reference/admin-design-contract.md`, `guides/reference/admin-ui-principles.md` —
  design system governance
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Per-component axe + screenshot harness already exists** for all 5 boards
  (`COMPONENT_BOARDS` + `assertBoardScreenshot` in `admin-design.spec.ts`), across
  chromium/mobile/dark — success criterion 1 is structurally satisfied today.
- **Interaction-state CSS already present**: `page_back` = `sg-btn sg-btn--ghost sg-btn--sm`
  with hover/focus-visible/active/disabled (`sigra_admin.css:~430–486`); `field_help`
  trigger hover/active/focus-visible (~:894–903) + tooltip panel + committed Escape/focus-
  restore test (`admin-design.spec.ts:~695–712`).
- **Skeleton reduced-motion already safe**: infinite `animation` (~:1419) stripped by the
  global block (~:1467–1477, `animation-iteration-count: 1 !important`); passing reduced-
  motion assertion (`admin-design.spec.ts:~653–677`).
- **`empty_state` / `scope_ribbon` are static** (`components.ex:~410, ~465`; CSS ~:546–568) —
  no interaction states to add.
- **Motion/hex CI guard already built** (`scripts/ci/admin-css-conformance.sh` + `.test.sh`,
  Phase 206) — reuse and extend for raw-px.
- **Token reference doc** claims 96/96 `--sg-*` :root coverage (`admin-token-reference.md:~3`)
  — the completeness-guard fold (D-06) makes that claim self-enforcing.

### Established Patterns
- v1.41 snapshot-recapture-gate + monotonic-ledger methodology (Phases 199–204), reapplied
  in 206 — apply verbatim: edit source CSS → recapture affected board PNGs → canaries
  byte-stable → allowlists empty at close → monotonic guard green.
- Ledger Tier-2 evidence = long semicolon-delimited string; tier column is bare `2`.

### Integration Points
- `priv/templates/sigra.install/` source → generated `test/example/` copy +
  `test/fixtures/install_golden/` tree (keep byte-coherent).
- Token-completeness diff + raw-px check slot beside the existing
  `scripts/ci/admin-css-conformance.sh` / `quality-ledger-monotonic.sh`.
</code_context>

<specifics>
## Specific Ideas

- COMP-03 wants "no raw hex/**px**" — the existing guard only checks hex; the px half is the
  net-new conformance coverage this phase adds (D-07).
- Token-completeness guard should parse `--sg-*` `:root` LHS defs and diff against the
  documented backtick tokens in `admin-token-reference.md` so the "96/96" claim cannot rot.
- Keep new guard scripts low-friction siblings of the existing conformance/monotonic
  scripts (+ `.test.sh` self-tests), not a new convention.
</specifics>

<deferred>
## Deferred Ideas

- **Page-composition / cross-page-placement findings** the IA-diagnostic tags "feeds 207"
  (scope_ribbon placement across audit pages, applied-chip DOM position, More-filters
  `phx-click` vs `<details>`, quick-toggle Apply gap, "Effective user" asymmetric filter) —
  page-level, deferred to **Phase 209** (Judgment-Level Page Pass), per D-01.
- **D-07a fallback**: if the raw-px automated check proves too noisy for one phase, it may
  degrade to a documented manual review (the completeness guard remains the load-bearing
  COMP-03 proof).

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db.md` (score 0.9) — CI-perf
  infrastructure, not component/token DS work. Not folded.
- `2026-06-25-phase200-code-review-deferred.md` (0.6) — token-scoped session revocation +
  admin session-helper de-dupe; page-functionality, not component/token DS. Not folded.
- `2026-06-28-phase205-debt-ci-native-board-baselines.md` (0.6) — admin-design baseline CI
  lane debt; infra, revisit at ratification (211). Not folded.
- Remaining matches (installer/config/example-css todos, score ≤0.4) — unrelated. Not folded.
</deferred>
