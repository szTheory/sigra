# Phase 187: Individual Components (L1) - Context

**Gathered:** 2026-06-14 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

The **L1 (individual-component) fractal audit-and-improve layer** of the v1.39 DS-COHERENCE
milestone. Take each of the **13 canonical `Sigra.Admin.Components`** through the full fractal
scorecard (shared D1–D11 + the L1 add-ons) and raise every one to **≥ Ratified, target
Award-grade** in light/dark/mobile: emilkowal.ski-aligned micro-interactions, complete and
visually-distinct interaction states, responsive 320–1440, per-component axe-clean, and on-brand
component-level microcopy.

**The 13 components** (`lib/sigra/admin/components.ex`): `stat`, `stat_link`, `task_card`,
`summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`, `notice`,
`notice_link`, `field_help`, `skeleton`, `audit_row`.

**In scope:** COMP-01..06 — per-component scorecard pass; emilkowal.ski micro-interactions;
complete interaction states (default/hover/focus-visible/active/disabled/loading/empty/error as
applicable); per-component axe clean (light+dark); intended-only byte-golden updates; reflow at
320/375/768/1024/1440; component-level microcopy. **PLUS** the in-scope structural fix below.

**IN-SCOPE STRUCTURAL FIX (folded — escalated decision D-01):** Migrate each component's
**visual/state CSS** out of the example-only `app.css` into the **shipped, canonical
`sigra_admin.css`** as part of auditing/improving it, so L1 improvements actually reach generated
hosts. This is a *deliberate scope expansion*, ratified by the user, because an L1 audit that
improves only `app.css` would pass every gallery/Playwright gate while hosts continue to ship
bare components — defeating the milestone's headline distribution goal.

**Critical constraint inherited from Phase 186 (blast-radius control):** Phase 186 is the **ONLY**
phase permitted to change token *values*. Phase 187 **consumes** the ratified `--sg-*` token
layer and may **add net-new tokens** (e.g. motion exit/asymmetry) but must **never re-tune an
existing ratified `--sg-*` value** (doing so trips the 186 lock + `quality-ledger-monotonic.sh`).

**Out of scope:** Token *value* changes (186 only); group/page/flow audits (188–191); the
system-wide microcopy/voice sweep + glossary (Phase 191 — 187 stays component-local); new admin
features/screens/nav; the audit *instruments* themselves (gallery, snapshot lane, allowlists +
canary, ledger, scorecard — all built in 185); the generated auth UI as a target surface; the
deferred Phase-186 review-hardening todo (WR-01..03/IN-02/IN-03 — kept as a separate L0 pass per
the user's decision below).
</domain>

<decisions>
## Implementation Decisions

### Component-CSS source of truth — the central structural fix (COMP-01..03; escalated, ratified)
- **D-01:** **Migrate each component's visual/state CSS from the example-only
  `test/example/priv/static/assets/css/app.css` into the shipped, canonical
  `priv/templates/sigra.install/admin/sigra_admin.css`** as part of auditing/improving that
  component. **VERIFIED FINDING:** every one of the components' visual/state classes —
  `sg-metric` (30 occ in app.css / 0 in shipped), `sg-btn`+states (22/0), `sg-notice` tones (9/0),
  `sg-status-pill` (13/0), `sg-field-help` (10/0), `sg-list-row` (5/0), `sg-metric-link` (5/0),
  `sg-applied-chip` (3/0), `sg-empty-state` (3/0), `sg-skeleton` (2/0), `sg-card-hover` (1/0),
  `sg-code` (3/0) — lives ONLY in `app.css`. Phase 184 extracted tokens + layout primitives +
  structural container classes (`.sg-card`, `.sg-cluster`, `.sg-grid`, `.sg-stack`,
  `.sg-filter-panel`, `.sg-detail-panel`, `.sg-page-title`, `.sg-theme-switch`) but left the
  per-component visual rules behind. Hosts link only `sigra_admin.css`, so they render components
  with layout but no component-level styling — the "sg-* CSS is example-trapped" gap.
- **D-02:** After migrating a component's rules into `sigra_admin.css`, **remove the now-duplicate
  `sg-*` rule from `app.css`** so the example stays a true host mirror (completing Phase 184
  DIST-04's intent — "the example stops sourcing `sg-*` from `app.css`" — for the component layer).
  The example links `default.css` + `sigra_admin.css` + `app.css` (`root.html.heex:10-12`); no
  rule should be defined in both. `app.css` keeps only `vt-*`/Vaultr glue.
- **D-03:** Migration must preserve **cascade-layer placement** — component rules belong in
  `@layer sg-components { … }` inside `sigra_admin.css` (layer order
  `sg-base, sg-components, sg-overrides` at `sigra_admin.css:15`) so they still outrank daisyUI
  `default.css` in the host. Each migrated rule must depend **only on `var(--sg-*)` tokens** — no
  residual `--vt-*` or daisyUI base dependency (the Phase 184 D-03 audit rule; hosts ship neither).
- **D-04:** Every migration touches the **parity surfaces together**:
  `priv/templates/sigra.install/admin/sigra_admin.css` (canonical) ≡
  `test/example/priv/static/assets/sigra_admin.css` (DIST-05 byte-parity test) ≡
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (golden fixture). The
  relocation is expected to be a **visual no-op for the example** (same rules, moved layer) →
  the `snapshot-canary-guard.sh` empty-allowlist should stay green; only a *genuine* L1
  visual/state improvement declares its intended-delta board slug(s) in **both** allowlists,
  verified against the design canary.

### Interaction states, motion, and the 186 token-value lock (COMP-02, COMP-03)
- **D-05:** Give each component **complete, visually-distinct interaction states** per the L1
  add-on (default/hover/focus-visible/active/disabled/loading/empty/error *as applicable*),
  distinguished by more than color alone (shape/size/shadow where relevant); **disabled looks
  disabled and is inert**. Motion is emilkowal.ski-aligned: **exact-property transitions (never
  `transition: all`)**, transform/opacity only, ease-out for enters, **pointer-gated hover**,
  keyboard-frequent paths un-animated, **interruptible**, and `@media (prefers-reduced-motion:
  reduce)` strips movement (extend the existing reduced-motion block at `sigra_admin.css:351-368`).
- **D-06:** Resolve the **two Phase-186-deferred motion refinements HERE** by **adding net-new
  motion tokens, never re-tuning ratified values**: (a) an **exit/enter asymmetry** (faster exit
  than enter — Emil's one explicitly-wanted principle; the budget has no exit composite today,
  only `--sg-transition-enter`/`-press`/`-tone` at `sigra_admin.css:130-137`); (b) a
  **dropdown/tooltip-class duration** faster than the 300ms modal ceiling (`--sg-motion-slow:
  300ms` at ~`:125` stays untouched). Net-new tokens leave all 186-ratified values byte-identical,
  so the lock and monotonic guard hold. If a component genuinely cannot meet a motion principle
  without a value change, **log it as a scorecard exception — do not silently edit a ratified
  value.**

### Byte-golden scoping, gallery state coverage, microcopy (COMP-04, COMP-05, COMP-06)
- **D-07:** **Default to CSS-only improvements → zero byte-golden churn.** The goldens
  (`test/sigra/admin/components_test.exs`, 12 strict literal-string goldens, NO snapshot lib) are
  tied to fixed assigns; CSS/motion changes cannot affect them. Per COMP-04, **goldens update
  only for *intended markup* deltas** — and only when a state genuinely requires markup (e.g. an
  `aria-disabled`/`disabled` attribute, a state-variant class). Any such update lands in the **same
  commit** with a one-line rationale; never regenerate goldens to "make tests pass."
- **D-08:** **Enrich the `/admin/_design` gallery boards** (`design_gallery_live.ex`) with full
  **interaction-state matrices** per component (today most boards render a single default
  instance) so COMP-01/03 state-matrix exhaustiveness is actually rendered and axe-scanned in
  light+dark. This is **legitimate L1 work, not instrument drift** — the gallery exists to render
  "every component in every state." Recapture affected board baselines via
  `snapshot-recapture-gate.sh`; the design canary + `snapshot-allowlist-design` guard the lane.
- **D-09:** **Component microcopy (COMP-06)** — `empty_state`, `notice`, `field_help` text —
  sourced from the **`guides/reference/admin-design-contract.md` per-component copy spec**,
  on-brand and JTBD-serving. The **system-wide voice/IA sweep + one-term glossary is Phase 191**;
  187 stays component-local and must not pre-empt it (avoid synonym drift).
- **D-10:** Verify **reflow at 320/375/768/1024/1440** (COMP-05) and **per-component axe-clean
  light+dark** (COMP-04) on each component's gallery board via the existing
  `admin-design-{chromium,mobile,dark}` lane + axe gate (built in 185). **Raise the L1 ledger
  rows** in `guides/reference/admin-quality-ledger.md` to the achieved tier (machine-parseable
  integer; monotonic-guard floor), evidence-linked.

### Claude's Discretion (planner resolves — below escalation threshold)
- Execution shape: per-component vs. batched-by-similarity (e.g. all chips together) — pick what
  keeps diffs human-meaningful and parity/canary verification clean.
- Exact net-new motion token names/values (within the ratified emilkowal.ski budget; e.g. exit ≈
  150–200ms, dropdown tier ≈ 180ms) and which composites consume them.
- Exact gallery state-matrix board layout/ids per component and which boards (if any) carry an
  intended visual delta requiring an allowlist slug.
- Whether any single component legitimately needs a markup change (and thus a golden update) vs.
  CSS-only — decided per component during the audit.
- Migration sequencing/commit granularity across the parity surfaces (template ↔ example ↔ golden
  fixture) so each commit keeps DIST-05 + `golden_diff` green.

### Folded Todos
None folded. See Reviewed Todos below — the Phase-186 review-hardening todo was **reviewed and
explicitly NOT folded** (user decision: keep as a focused L0 pass).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

Milestone + phase:
- `~/.claude/plans/design-system-stress-test-serialized-candy.md` — approved milestone plan
  (fractal levels, L1 component intent, emilkowal.ski micro-interaction principles, tier vocab)
- `.planning/ROADMAP.md` — Phase 187 detail + success criteria; fractal-level phase map (186–192)
- `.planning/REQUIREMENTS.md` — COMP-01..06 (lines ~43-50)
- `.planning/METHODOLOGY.md` — Decisive Defaulting / escalation-threshold lenses
- `.planning/phases/186-token-foundation-l0/186-CONTEXT.md` — the ratified+locked L0 token layer
  187 consumes; D-08/D-09 (motion budget + the two refinements deferred TO 187); the
  only-186-changes-values constraint
- `.planning/phases/185-audit-infrastructure/185-CONTEXT.md` — the audit instruments 187 applies
  (gallery, `admin-design-*` lane + axe, two allowlists + canary, ledger + monotonic guard,
  scorecard)
- `.planning/phases/184-distribution-parity/184-CONTEXT.md` — the DIST extraction boundary +
  parity machinery this phase extends to the component layer (D-01 layer carry-over, D-02
  app.css-cleanup intent, D-03 token-only-dependency audit, D-11 visual-no-op canary)

Grading + recording instruments (built in 185, applied at L1):
- `guides/reference/admin-fractal-scorecard.md` — shared D1–D11 + **L1 Individual Component
  add-ons** (~lines 47-59): complete/visually-distinct states · reduced-motion strips · per-component
  axe clean · reflow 320–1440
- `guides/reference/admin-quality-ledger.md` — raise the L1 component rows (machine-parseable tier
  integer per the monotonic-guard contract)
- `guides/reference/admin-design-contract.md` — per-component ARIA/motion/copy specs (D6/D10/D11
  source; component microcopy spec for D-09)
- `guides/reference/admin-ui-principles.md`
- `guides/reference/admin-token-reference.md` — the ratified token catalog (186); consume, and add
  rows only for any net-new motion tokens (D-06)

Component + CSS surfaces (the L1 targets):
- `lib/sigra/admin/components.ex` — the 13 lib-owned component functions
- `test/sigra/admin/components_test.exs` — 12 strict byte-goldens (~lines 35-94); the markup
  contract (COMP-04); update only for intended markup deltas
- `priv/templates/sigra.install/admin/sigra_admin.css` — **canonical SHIPPED CSS** (migration
  TARGET): `@layer sg-base, sg-components, sg-overrides` (:15); `@layer sg-components` (:222);
  motion tokens (~:117-137); reduced-motion (~:351-368)
- `test/example/priv/static/assets/sigra_admin.css` — byte-identical mirror (DIST-05 guarded)
- `test/example/priv/static/assets/css/app.css` — **migration SOURCE**: holds all component
  visual/state rules today (`sg-btn` states, `sg-metric`, `sg-notice` tones, `sg-status-pill`,
  `sg-field-help`, `sg-list-row`, `sg-applied-chip`, `sg-empty-state`, `sg-skeleton`,
  `sg-card-hover`, `sg-code`); after migration keeps only `vt-*` glue
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — golden fixture copy
  (kept in parity by `golden_diff_test.exs`)
- `test/example/lib/example_web/components/layouts/root.html.heex` (:10-12) — proves the example
  links the three CSS files; hosts link only `sigra_admin.css`

Verification harness (built 185, recapture as needed):
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — the gallery to enrich with
  state-matrix boards (D-08)
- `test/example/priv/playwright/tests/admin-design.spec.ts` — per-board axe + board capture
- `test/example/priv/playwright/snapshot-allowlist` AND `snapshot-allowlist-design` — declare any
  intended visual-delta board slug in BOTH (steady-state empty)
- `scripts/ci/snapshot-canary-guard.sh`, `scripts/ci/snapshot-recapture-gate.sh`,
  `scripts/ci/quality-ledger-monotonic.sh` — merge-blocking guards
- DIST-05 byte-parity ExUnit (`test/sigra/install/features/admin_test.exs` region) +
  `golden_diff_test.exs` — keep green across every migration commit
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- All audit instruments are already built (185) and the token layer ratified (186): the gallery
  imports the real `Sigra.Admin.Components`; the `admin-design-{chromium,mobile,dark}` lane + axe
  gate scans boards in light+dark; the two allowlists + canary + monotonic ledger guard enforce
  idempotency. 187 *applies* these.
- The Phase 184 DIST machinery (DIST-05 byte-parity test, golden-fixture parity, cascade-layer
  carry-over pattern, visual-no-op canary discipline) is the proven template for the component-CSS
  migration — this phase extends an established pattern, not a novel one.
- The reduced-motion block (`sigra_admin.css:351-368`) and the ratified motion budget (186) are
  the base 187 builds component motion on.

### Established Patterns
- Library-owned admin components ship via `sigra_admin.css` (installer-distributed); the example
  is a **byte-true host mirror** (DIST-04/05), so anything that must reach hosts lives in
  `sigra_admin.css`, not `app.css`. This is the principle that makes D-01/D-02 correct.
- Cascade-layer order (`sg-base, sg-components, sg-overrides`) must be preserved so `sg-*` outranks
  daisyUI; migrated rules depend only on `var(--sg-*)` (Phase 184 D-03).
- Tier cells in the ledger are machine-parseable integers (0 Drift / 1 Ratified / 2 Award-grade);
  a re-run reads the current tier as the floor. Empty-allowlist discipline: intended visual deltas
  declare their board slug; the canary guards the harness.
- emilkowal.ski motion canon (exact-property transitions, transform/opacity only, ease-out enters,
  pointer-gated hover, keyboard paths un-animated, interruptible, reduced-motion strips movement)
  is the project standard, encoded in scorecard D6.

### Integration Points
- Edit (migration TARGET): `priv/templates/sigra.install/admin/sigra_admin.css` `@layer
  sg-components` (component rules in, net-new motion tokens in `:root`).
- Edit (migration SOURCE cleanup): `test/example/priv/static/assets/css/app.css` (remove migrated
  `sg-*` rules; keep `vt-*`).
- Keep in parity: `test/example/priv/static/assets/sigra_admin.css` +
  `test/fixtures/install_golden/tree/.../sigra_admin.css`.
- Enrich: `design_gallery_live.ex` (state-matrix boards); possibly extend
  `admin-design.spec.ts` / `admin-theme.spec.ts` for new state coverage.
- Raise: `guides/reference/admin-quality-ledger.md` (L1 rows). Possibly add token rows to
  `admin-token-reference.md` for net-new motion tokens.
- Maybe edit (only for genuine markup-state needs): `lib/sigra/admin/components.ex` +
  `test/sigra/admin/components_test.exs` goldens together.

### Integration Points — anchors NOT to disturb
- 186-ratified token *values* are frozen (only net-new tokens allowed).
- 185 instruments are contract-frozen: the gallery imports real components; the monotonic guard
  reads ledger tier integers — keep them machine-parseable.
- `components_test.exs` byte-goldens stay the component-markup source of truth — update only for
  intended markup deltas, never to silence a diff.
- DIST-05 byte-parity + `golden_diff` must stay green on every commit.
</code_context>

<specifics>
## Specific Ideas

- The phase's highest-value, non-obvious finding: **the L1 component CSS never shipped.** The
  shipped `sigra_admin.css` carries tokens + layout + container scaffolding only; the actual
  per-component visual/state rules are example-trapped in `app.css`. Without the D-01 migration,
  an L1 "audit + improve" pass would be cosmetic theater — green in the gallery, bare in hosts.
  Folding the migration in is what makes the L1 audit *real* and finally delivers the milestone's
  "styled generated-host" promise at the component level.
- "Award-grade" at L1 means the emilkowal.ski details (asymmetric/interruptible motion,
  pointer-gated hover, exact-property transitions, considered disabled/loading/empty/error
  treatments) are present per component AND shipped — verified in the gallery state-matrix and
  reachable by hosts.
- Motion refinements are additive (net-new tokens), never re-tuning — the 186 value lock and the
  monotonic guard remain the safety rails.
</specifics>

<deferred>
## Deferred Ideas

- Group/page/flow fractal audits (L2 groups → L3 pages → L4 flows) — Phases 188–191.
- System-wide microcopy/voice sweep + one-term-per-concept glossary — Phase 191 (187 stays
  component-local).
- Final ratification / baseline-lock / generated-host parity (`RUN_PARITY=1`) — Phase 192.
- Byte-guarding / de-staling the example `sigra_auth.css` copy (auth-side wart from 184/185/186) —
  out of scope; future maintenance `/gsd-quick` if desired.

### Reviewed Todos (not folded)
- `2026-06-14-phase-186-review-deferred.md` (score 0.6) — hardens the D-11 token-parity test
  extractors (WR-01..03), dedups an `admin-theme.spec.ts` `readNoticeStyles` closure (IN-02), and
  adds a token-reference completeness guard (IN-03). **Reviewed and explicitly NOT folded** (user
  decision): these are orthogonal **L0 token-parity / test-harness robustness** items; the D-11
  tests pass today (brittleness is latent), and folding them dilutes the L1 component focus. Kept
  in the backlog for a dedicated focused L0 pass. (Note: 187 will edit `admin-theme.spec.ts` for
  component-state coverage; if the IN-02 helper duplication is trivially in the way, the planner
  may opportunistically hoist it, but the parity-extractor refactor stays out.)
</deferred>
