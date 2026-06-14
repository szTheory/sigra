# Phase 186: Token Foundation (L0) - Context

**Gathered:** 2026-06-14 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

The **L0 (token-layer) fractal audit** of the v1.39 DS-COHERENCE milestone. Adversarially
audit and **ratify** the admin `:root` `--sg-*` token layer (color · type scale · spacing ·
radius · shadow/elevation · control heights · focus ring · z-index · motion) across
Light / Dark / System, validate the motion budget against emilkowal.ski, and preserve
three-surface ember parity so the generated auth UI stays coherent.

**In scope:** TOKEN-01..04, THEME-01 — per-token rationale + brand-ref documentation; WCAG-AA
verification (light + dark); motion-budget ratification; three-surface parity preservation +
guard; L0 ledger row; any token-value deltas declared in the allowlists.

**Critical constraint (blast-radius control):** Phase 186 is the **ONLY** phase in the
milestone permitted to change token *values*. Phases 187–192 consume these tokens but cannot
re-tune them. This makes the parity surfaces and allowlist discipline load-bearing here.

**Out of scope:** Component/group/page/flow audits (187–191); adding new admin
features/screens; the audit *instruments* themselves (built in Phase 185 — the
`/admin/_design` gallery, the `admin-design-*` snapshot lane, the two allowlists + canary, the
monotonic ledger guard, the fractal scorecard); the generated auth UI as a *target* surface
(it is a *coherence constraint* only, via ember parity).
</domain>

<decisions>
## Implementation Decisions

### Ratification deliverable shape (TOKEN-01)
- **D-01:** Author a **new standalone `guides/reference/admin-token-reference.md`** as the home
  for per-token "rationale + brand reference" — one table keyed by token, with columns:
  **token · value · rationale · brand ref** (→ `brandbook/tokens.json` entry). This follows the
  Phase 185 convention of standalone `guides/reference/*.md` siblings (the ledger + scorecard
  were deliberately *not* embedded in the design-contract).
- **D-02:** Do **NOT** carry per-token rationale as inline CSS prose in `sigra_admin.css` (would
  bloat the installer-distributed stylesheet) and do **NOT** inflate the scorecard/contract.
  Terse convention comments already in `sigra_admin.css` stay; the brand-ref ledger is the new
  doc.
- **D-03:** Fill the **L0 token row** in `guides/reference/admin-quality-ledger.md` (which today
  has no L0 row — its lowest level is L1 components), with the achieved tier (machine-parseable
  integer per the 185 monotonic-guard contract) and an evidence link pointing at
  `admin-token-reference.md`. Cross-reference `admin-design-contract.md`; do not rewrite it.

### Scope of token-value changes (TOKEN-01, blast-radius)
- **D-04:** Treat this phase as **documentation-and-test-dominant with near-zero value churn.**
  Dark-mode AA was already remediated at v1.34 close (`--sg-color-brand-strong → #fdba74`,
  inline "~1.88:1 → ≥4.5:1"; tone + soft colors already lightened for dark), and
  `brandbook/tokens.json` already carries the matching dark values. Ratify = **annotate + lock +
  test**, not re-tune.
- **D-05:** If the adversarial audit *does* surface a genuine AA failure or other real defect,
  the value change is **in scope** (186 is the only value-change phase) and **must** declare its
  affected board slug(s) in **both** `test/example/priv/playwright/snapshot-allowlist` **and**
  `snapshot-allowlist-design`, verified against the designated canary board. No silent value
  edits.

### AA verification mechanism (TOKEN-02)
- **D-06:** Verify WCAG-AA with the **already-wired axe lane** (`admin-design.spec.ts` +
  `admin-theme.spec.ts`, tags `wcag2a`+`wcag2aa`, 0 violations on rendered boards in **both**
  light and dark projects) **plus** extending the existing **`contrastRatio()` computed-style
  assertions** in `admin-theme.spec.ts` to cover the specific brand-soft / tone-on-soft pairs the
  gallery renders (where axe may skip due to alpha-compositing on `rgba(...)` soft backgrounds).
- **D-07:** Read "every color token pair passes AA" as **every pair that actually appears in a
  rendered component/group**, NOT the literal cartesian product of all declared tokens. Do
  **NOT** build a net-new offline cartesian token-pair contrast calculator (that would be a new
  instrument, a Phase 185 boundary tension). The gallery renders all components in all tones, so
  rendered coverage is the AA surface.

### Motion-budget ratification (TOKEN-03)
- **D-08:** Motion tokens **already exist** in `sigra_admin.css` (5 durations: press=120ms,
  pop=180ms, fast=140ms, medium=220ms, slow=300ms; 4 easings: ease / ease-out / ease-in /
  ease-spring; 3 composed transitions). External research validated them as **ALIGNED** with
  emilkowal.ski guidance (press 100–160 ✅, pop 180 = his cited dropdown sweet-spot ✅, medium
  220 in his 150–250 dropdown range ✅, slow 300 ✅). Ratify the **existing budget as-is** —
  **document-only, no value change** — recording it in `admin-token-reference.md` + the L0 ledger
  row with the emilkowal.ski validation as rationale.
- **D-09:** Two research-flagged refinements are **deferred to Phase 187 (L1 components)**, NOT
  done here: (a) `overlay=slow=300ms` sits exactly on Emil's "under 300ms" ceiling — defensible
  for a full modal, slightly slow for a dropdown-class surface; (b) the budget encodes no
  **faster-exit-than-enter asymmetry** (the one principle Emil explicitly wants). Adding exit
  tokens is a value/structure change best made when components actually consume motion in 187 —
  capture as a deferred refinement, do not expand 186 scope.

### Three-surface ember parity + the fourth surface (TOKEN-04, THEME-01)
- **D-10:** **No automated parity guard exists today** — `brandbook/tokens.json` ↔ admin
  `--sg-*` ↔ auth `--sigra-auth-*` parity is maintained by hand (grep finds zero scripts/CI/tests
  reading `tokens.json`). There is also a **fourth surface**: admin dark tokens are duplicated in
  two CSS locations that must stay lock-step — the installer-canonical `sigra_admin.css`
  `@media (prefers-color-scheme: dark)` (System) path AND the example
  `test/example/priv/static/assets/css/app.css` `html[data-sg-admin-theme="dark"]`
  (explicit-toggle) path. They are byte-identical today but unguarded.
- **D-11:** **Add a lightweight automated parity assertion** as in-scope insurance for TOKEN-04
  (a small comparison test or CI check is sufficient — exact mechanism is the planner's call).
  Rationale: "three-surface ember parity preserved" / "auth stayed coherent" is a **truth claim**;
  a silent System-vs-explicit-toggle divergence (or admin↔auth↔brandbook drift) would otherwise
  pass review while being actually broken. This is the phase's highest-value structural finding.
- **D-12:** When any token value changes, prove auth coherence by **re-running axe +
  `contrastRatio` on auth surfaces** and updating all four locations together; the new parity
  assertion (D-11) backstops the manual sync.

### Claude's Discretion (planner resolves — all below escalation threshold)
- Exact table schema/columns of `admin-token-reference.md` beyond token·value·rationale·brand-ref.
- Exact mechanism for the D-11 parity assertion (ExUnit comparing extracted CSS vars vs
  `tokens.json`; a shell/CI diff of the dark blocks across the two CSS files; or a Playwright
  computed-style cross-check) — pick the least-surprising fit for the existing harness.
- Which gallery board (if any value changes) is the token-delta canary, and exact slug naming.
- How granular the L0 ledger row is (single L0 row vs per-token-group sub-rows).

### Folded Todos
None — `todo.match-phase 186` returned a single weak 0.2-score match
(`recapture-gate-single-lane.md`) that is a Phase-185 leftover, below the fold threshold. See
Reviewed Todos.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

Milestone + phase:
- `~/.claude/plans/design-system-stress-test-serialized-candy.md` — approved milestone plan
  (fractal levels L0–L4, idempotency model, scorecard rubric, tier vocabulary)
- `.planning/ROADMAP.md` — Phase 186 detail + success criteria; note "186 is the ONLY phase
  allowed to change token *values* (blast-radius control)"
- `.planning/REQUIREMENTS.md` — TOKEN-01..04, THEME-01 (and the scope boundary on auth)
- `.planning/METHODOLOGY.md` — Decisive Defaulting / escalation-threshold lenses
- `.planning/phases/185-audit-infrastructure/185-CONTEXT.md` — the audit *instruments* this phase
  applies (gallery, `admin-design-*` lane, two allowlists, canary, monotonic ledger guard,
  scorecard)

Token surfaces under audit (the four parity surfaces):
- `priv/templates/sigra.install/admin/sigra_admin.css` — THE canonical admin `:root` `--sg-*`
  layer + dark `@media (prefers-color-scheme: dark)` overrides (System path); motion budget at
  ~lines 117-137; dark AA remediation at ~lines 167-204 (`#fdba74` brand-strong)
- `test/example/priv/static/assets/sigra_admin.css` — example copy (byte-parity with installer
  template; the DIST-05 parity test already guards this)
- `test/example/priv/static/assets/css/app.css` — **the fourth surface**: explicit-toggle dark
  block `html[data-sg-admin-theme="dark"] .sg-admin-shell` (~lines 1474-1533+) duplicating the
  dark values; must stay lock-step with the `sigra_admin.css` `@media` System path
- `brandbook/tokens.json` — brand source of truth (ember palette, brand-strong/soft, type,
  motion subset at ~lines 155-160; dark values at ~lines 82-97)
- `priv/templates/sigra.install/core/sigra_auth.css` — auth `--sigra-auth-*` layer (third
  surface; separate namespace, own light/dark/system blocks ~lines 1-103; ember parity target)

Grading + recording instruments (built in 185):
- `guides/reference/admin-fractal-scorecard.md` — the ratified D1–D11 rubric applied at L0
  (D1 Brand color · D2 Brand type · D3 Spacing/radius/shadow · D4 Light/Dark/System · D5 Contrast
  WCAG-AA · D6 Motion quality · …); AA thresholds at ~lines 30-32
- `guides/reference/admin-quality-ledger.md` — tier ledger (add the L0 row; machine-parseable
  tier integer per the monotonic-guard contract)
- `guides/reference/admin-design-contract.md` — token/dimension definitions; dark AA resolution
  note at ~line 207 (cross-reference, do not rewrite)
- `guides/reference/admin-ui-principles.md`

Verification harness:
- `test/example/priv/playwright/tests/admin-design.spec.ts` — axe per board
  (`AxeBuilder...withTags(['wcag2a','wcag2aa']).analyze()`, ~lines 32-43)
- `test/example/priv/playwright/tests/admin-theme.spec.ts` — `contrastRatio(fg,bg)` helper
  (~line 183) used at ~lines 519/536/554/570/675/697; extend for brand-soft/tone-soft pairs
- `test/example/priv/playwright/snapshot-allowlist` and `snapshot-allowlist-design` —
  empty-by-discipline manifests; declare any intended token-delta board slug in BOTH
- `scripts/ci/snapshot-canary-guard.sh`, `scripts/ci/quality-ledger-monotonic.sh` — merge-blocking
  guards (185)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Audit instruments are already built (Phase 185):** the `/admin/_design` gallery renders all
  13 components + MG groups in all tones/states inside the real shell; the
  `admin-design-{chromium,mobile,dark}` lane + axe gate already scans them in light + dark; the
  two allowlists + canary + monotonic ledger guard already enforce idempotency. 186 *applies*
  these, it does not build them.
- The `contrastRatio()` computed-style helper in `admin-theme.spec.ts` is the proven mechanism
  for asserting specific AA pairs that axe can't judge (alpha-composited soft backgrounds).
- The DIST-05 byte-parity test already guards `sigra_admin.css` template ↔ example copy, so the
  installer/example pair is one surface for parity purposes.
- The dark AA work is **already done** (v1.34): `brand-strong #fdba74`, lightened tone/soft
  colors — and `tokens.json` already carries the matching dark values. The audit's likely finding
  is "already compliant," making 186 a documentation-and-lock pass.

### Established Patterns
- Durable design authority lives in standalone `guides/reference/*.md` siblings (ledger +
  scorecard precedent from 185), not embedded in the contract.
- Tier cells in the ledger are machine-parseable fixed-column integers (0 Drift / 1 Ratified /
  2 Award-grade) so the monotonic guard reads old-vs-new reliably; a re-run reads current tier as
  the floor.
- Empty-allowlist discipline: any intended visual/token delta declares its board slug; the canary
  guards the harness.
- emilkowal.ski motion principles are the project motion canon: exact-property transitions (never
  `transition:all`), transform/opacity only, ease-out for enters, never ease-in for UI,
  pointer-gated hover, keyboard-frequent paths un-animated, reduced-motion strips movement
  (already implemented at `sigra_admin.css` ~lines 351-368).

### Integration Points
- New file: `guides/reference/admin-token-reference.md`.
- Edit: `guides/reference/admin-quality-ledger.md` (add L0 row).
- New parity assertion (D-11): some combination of `test/` (ExUnit) and/or `scripts/ci/` +
  `.github/workflows/ci.yml` wiring — planner's call.
- Possible test extension: `test/example/priv/playwright/tests/admin-theme.spec.ts`
  (`contrastRatio` coverage for brand-soft/tone-soft).
- Token-value edits (only if a real defect is found) touch all four parity surfaces together +
  both allowlists.

### Integration Points — anchors NOT to disturb
- Phase 185 instruments are contract-frozen: the gallery imports the real components, the
  monotonic guard reads the ledger's tier integers — keep the ledger machine-parseable.
- `components_test.exs` byte-goldens remain the component-markup source of truth (untouched at L0).
</code_context>

<specifics>
## Specific Ideas

- The most consequential finding is structural, not chromatic: **token parity is currently manual
  across four surfaces** (`tokens.json` ↔ installer/example `sigra_admin.css` System path ↔
  example `app.css` explicit-toggle path ↔ auth `sigra_auth.css`), with the System-vs-toggle
  duplication being a silent-desync risk no test catches today. The phase's durable win is closing
  that gap with a lightweight parity guard (D-11).
- "Ratify" here means **make the implicit explicit and lock it**: every token gets a written
  rationale + brand ref, the motion budget gets its emilkowal.ski validation on record, and the
  whole layer earns its L0 ledger tier — so phases 187–192 build on a frozen, documented
  foundation.
- Motion budget validated as aligned; the two refinements (overlay 300ms boundary; missing
  exit-faster-than-enter asymmetry) are real but belong to L1 (187) where components consume
  motion — captured below, deliberately not pulled into 186.
</specifics>

<deferred>
## Deferred Ideas

- **Motion exit-asymmetry tokens** (faster-exit-than-enter, e.g. overlay exit ≈200ms / panel exit
  ≈150ms) and **revisiting `overlay=300ms`** for dropdown-class surfaces — Phase 187 (L1
  components), where motion is actually applied. Adding exit tokens is a value/structure change
  better made at point of consumption.
- Byte-guarding / de-staling the example `sigra_auth.css` copy (auth-side wart noted in Phase 184
  / 185 deferred) — out of scope; future maintenance `/gsd-quick` if desired. Note the D-11 parity
  guard may partially address auth-surface drift.
- Actual L1–L4 fractal audits (components → groups → pages → flows) — phases 187–191.

### Reviewed Todos (not folded)
- `recapture-gate-single-lane.md` (score 0.2) — a Phase-185 recapture-gate single-lane bug
  tracked against `scripts/ci/snapshot-recapture-gate.sh`. Matched only on the keyword "185", not
  on token/L0 scope; below the fold threshold and orthogonal to the token audit. Left in the todo
  backlog.
</deferred>
