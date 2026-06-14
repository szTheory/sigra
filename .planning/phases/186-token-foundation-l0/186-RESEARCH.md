# Phase 186: Token Foundation (L0) - Research

**Researched:** 2026-06-14
**Domain:** CSS custom-property token layer audit; WCAG-AA verification; parity guard implementation; quality ledger authoring
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Author a new standalone `guides/reference/admin-token-reference.md` with columns: token · value · rationale · brand ref (→ `brandbook/tokens.json` entry). Follows the Phase 185 guides/reference/*.md sibling convention.

**D-02:** No per-token rationale as inline CSS prose in `sigra_admin.css`. Terse convention comments already present stay; brand-ref ledger is the new doc.

**D-03:** Fill the L0 token row in `guides/reference/admin-quality-ledger.md` (no L0 row exists today; lowest is L1). Tier integer is machine-parseable per the 185 monotonic-guard contract. Evidence link points at `admin-token-reference.md`. Cross-reference `admin-design-contract.md`; do not rewrite it.

**D-04:** Phase is documentation-and-test-dominant with near-zero value churn. Dark-mode AA was remediated at v1.34 (brand-strong → #fdba74). Ratify = annotate + lock + test, not re-tune.

**D-05:** If the adversarial audit surfaces a genuine AA failure, the value change is in scope and MUST declare affected board slug(s) in BOTH `snapshot-allowlist` and `snapshot-allowlist-design`. No silent value edits.

**D-06:** Verify WCAG-AA with the already-wired axe lane (`admin-design.spec.ts` + `admin-theme.spec.ts`, tags wcag2a+wcag2aa, 0 violations, both light and dark projects) PLUS extending the existing `contrastRatio()` computed-style assertions in `admin-theme.spec.ts` to cover brand-soft / tone-on-soft pairs.

**D-07:** "Every color token pair passes AA" means every pair that actually appears in a rendered component/group — NOT the cartesian product. Do NOT build a net-new offline cartesian contrast calculator.

**D-08:** Motion tokens already exist (5 durations, 4 easings, 3 composed transitions). Ratify existing budget as-is — document-only, no value change. Record emilkowal.ski validation as rationale in `admin-token-reference.md` + L0 ledger row.

**D-09:** Two refinements DEFERRED to Phase 187: (a) overlay=300ms boundary; (b) faster-exit-than-enter asymmetry. Not in Phase 186 scope.

**D-10:** No automated parity guard exists today across the four surfaces. The fourth surface (app.css explicit-toggle dark block) is unguarded vs sigra_admin.css @media dark block.

**D-11:** Add a lightweight automated parity assertion as in-scope insurance for TOKEN-04. Exact mechanism is the planner's call (ExUnit extracting CSS vars vs tokens.json, a shell/CI diff of the dark blocks across the two CSS files, or a Playwright computed-style cross-check).

**D-12:** When any token value changes, re-run axe + contrastRatio on auth surfaces and update all four locations together. New parity assertion backstops the manual sync.

### Claude's Discretion (planner resolves)

- Exact table schema/columns of `admin-token-reference.md` beyond token·value·rationale·brand-ref.
- Exact mechanism for the D-11 parity assertion.
- Which gallery board (if any value changes) is the token-delta canary, and exact slug naming.
- How granular the L0 ledger row is (single L0 row vs per-token-group sub-rows).

### Deferred Ideas (OUT OF SCOPE)

- Motion exit-asymmetry tokens and revisiting overlay=300ms — Phase 187.
- Byte-guarding the example `sigra_auth.css` copy — future /gsd-quick.
- Actual L1–L4 fractal audits — phases 187–191.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOKEN-01 | The `:root` token layer (color, type scale, spacing, radius, control heights, elevation/shadow, focus ring, z-index) is audited and ratified, each token carrying a documented rationale + brand reference | admin-token-reference.md authoring; brandbook/tokens.json is the brand-ref source; sigra_admin.css :root block is the canonical token set |
| TOKEN-02 | Every color token pair passes WCAG AA in light AND dark (axe-verified), including text on brand-soft surfaces | Existing axe lane (admin-design.spec.ts + admin-theme.spec.ts) is the primary mechanism; contrastRatio() extension covers alpha-composited soft pairs that axe skips |
| TOKEN-03 | Motion-budget tokens (durations + easings) validated against emilkowal.ski timing/easing guidance and ratified as the project motion budget | Existing budget already validated as ALIGNED; ratification is documentation-only in admin-token-reference.md |
| TOKEN-04 | Three-surface ember parity preserved across any token change; auth surfaces remain coherent | D-11 parity assertion covers the System vs explicit-toggle dark gap; auth surface coherence via D-12 re-run on auth surfaces |
| THEME-01 | Tokens render correctly across Light, Dark, and System with no theme-ignoring hardcoded values; dark uses lightened brand-strong (#fdba74) | Axe dark project + admin-design-dark Playwright project; contrastRatio assertions confirm brand-strong values; existing DIST-05 byte-parity guards installer↔example sigra_admin.css |
</phase_requirements>

---

## Summary

Phase 186 is a documentation-and-lock pass on the admin `:root` `--sg-*` token layer. The WCAG-AA remediation is already complete (v1.34), and `brandbook/tokens.json` already carries the matching dark values. The audit's expected finding is "already compliant" — the deliverable is making the implicit explicit: authored rationale, emilkowal.ski motion validation on record, and a durable L0 ledger row so phases 187–192 build on a frozen, documented foundation.

The phase's highest-value structural work is closing the unguarded parity gap (D-11). Four token surfaces must stay lock-step: (1) `priv/templates/sigra.install/admin/sigra_admin.css` `:root` + `@media (prefers-color-scheme: dark)` System path; (2) its byte-identical example copy `test/example/priv/static/assets/sigra_admin.css` (already guarded by DIST-05); (3) `test/example/priv/static/assets/css/app.css` explicit-toggle dark block at `.sg-admin-shell[data-theme="dark"]` / `html[data-sg-admin-theme="dark"] .sg-admin-shell` (lines 1512–1543, unguarded); and (4) `priv/templates/sigra.install/core/sigra_auth.css` auth `--sigra-auth-*` ember-family parity (unguarded). The token values across surfaces are currently identical (verified by grep diff), but a silent divergence has no test catching it.

The recommended parity assertion mechanism is ExUnit — a new `describe` block in `test/sigra/install/features/admin_test.exs` mirroring the DIST-05 pattern, extracting and comparing the `--sg-*` custom-property sets from the dark blocks in both CSS files. This is the least-surprising fit: ExUnit already guards the installer↔example `sigra_admin.css` byte-parity at this level, it runs in the standard `mix test` suite (wired to the `library_tests` CI job), and it requires zero new CI wiring.

**Primary recommendation:** Author `guides/reference/admin-token-reference.md`, fill the L0 ledger row, extend `contrastRatio()` in `admin-theme.spec.ts` for tone-on-soft pairs, and add an ExUnit dark-block parity assertion — then run the full axe lane to ratify the token layer as Tier 1.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Token value authorship | CSS / :root layer (sigra_admin.css) | brandbook/tokens.json (brand source) | CSS :root is the runtime token layer; tokens.json is the semantic brand reference that CSS values must trace to |
| Dark mode System path | sigra_admin.css @media (prefers-color-scheme: dark) | — | OS-level system preference; handled at :root before any shell attribute |
| Dark mode explicit-toggle path | app.css .sg-admin-shell[data-theme="dark"] | Shell LiveView (data-theme attr) | The shell LiveView writes data-theme; app.css scopes dark overrides to the shell element |
| Installer↔Example parity | DIST-05 ExUnit test | CI library_tests job | Already guarded at the file level; new D-11 guard extends to the dark sub-block |
| System↔Explicit dark parity (new D-11) | ExUnit (admin_test.exs) | CI library_tests job | Same ExUnit tier as DIST-05; no new CI job needed |
| WCAG AA verification | Playwright axe (admin-design-dark project) | contrastRatio() computed-style assertions | axe handles structural HTML+CSS pairs; contrastRatio() is required for alpha-composited rgba() soft backgrounds that axe cannot resolve |
| Motion ratification | guides/reference/admin-token-reference.md | L0 ledger row | Document-only; motion tokens are correct as-is, ratification is authoring not code |
| L0 ledger record | guides/reference/admin-quality-ledger.md | monotonic guard CI | Monotonic guard reads the ledger; ledger is the single source of tier truth |

---

## Standard Stack

This phase introduces no new packages. All work uses existing project infrastructure.

### Core Files (the four parity surfaces)

| File | Role | Lines of Interest |
|------|------|-------------------|
| `priv/templates/sigra.install/admin/sigra_admin.css` | Canonical admin :root token layer + System dark path | :root tokens: 20–165; light color-scheme: 164; motion: 117–137; dark @media: 167–204 |
| `test/example/priv/static/assets/sigra_admin.css` | Byte-identical example copy (guarded by DIST-05) | Same as template |
| `test/example/priv/static/assets/css/app.css` | Example-only vt-* + sg-admin explicit-toggle dark block | Light-shell block: 1473–1510; Dark-shell block: 1512–1543 |
| `priv/templates/sigra.install/core/sigra_auth.css` | Auth --sigra-auth-* ember-parity surface | Light defaults: 1–38; dark override: 56–77; system @media: 79–103 |
| `brandbook/tokens.json` | Brand source of truth for ember palette, semantics, motion subset | dark semantic values: 69–98; motion subset: 155–160 |

### Grading and Guard Files

| File | Role |
|------|------|
| `guides/reference/admin-quality-ledger.md` | Machine-parseable tier record; add L0 row here |
| `guides/reference/admin-fractal-scorecard.md` | D1–D11 rubric applied at L0 |
| `guides/reference/admin-design-contract.md` | Cross-reference only; dark AA note at line 207 |
| `scripts/ci/quality-ledger-monotonic.sh` | Reads tier integers from ledger; fails CI on decrease |
| `scripts/ci/snapshot-canary-guard.sh` | Enforces empty-allowlist discipline; canary=board-notice (design lane) |
| `test/example/priv/playwright/snapshot-allowlist` | Admin-checkpoints delta declarations (steady-state empty) |
| `test/example/priv/playwright/snapshot-allowlist-design` | Admin-design delta declarations (steady-state empty) |

### Verification Files

| File | Role |
|------|------|
| `test/example/priv/playwright/tests/admin-design.spec.ts` | axe per board (wcag2a+wcag2aa, 0 violations, 3 projects) |
| `test/example/priv/playwright/tests/admin-theme.spec.ts` | contrastRatio() computed-style assertions; extend for brand-soft/tone-soft |
| `test/sigra/install/features/admin_test.exs` | DIST-05 parity test home; add D-11 dark-block parity assertion here |

### New File

| File | Role |
|------|------|
| `guides/reference/admin-token-reference.md` | Per-token rationale + brand-ref table (D-01 deliverable) |

---

## Package Legitimacy Audit

No external packages are installed in this phase. All work uses existing project dependencies.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
brandbook/tokens.json
        │
        │ (brand source — hex values, semantic aliases, motion subset)
        ▼
sigra_admin.css :root { --sg-* }          ←── admin-token-reference.md
        │                                        (rationale + brand-ref table)
        ├─── @media prefers-color-scheme: dark   (System path, lines 167-204)
        │           │
        │           │  [D-11 ExUnit parity assertion — new]
        │           ▼
        │    app.css .sg-admin-shell[data-theme="dark"]  (explicit-toggle, lines 1512-1543)
        │
        ├─── example copy: test/example/.../sigra_admin.css
        │           │  [DIST-05 ExUnit byte-parity — existing]
        │           ▼
        │    (byte-identical, already guarded)
        │
        └─── auth surface: sigra_auth.css --sigra-auth-*
                    │  [ember parity — no automated guard today]
                    ▼
             (D-11 parity assertion covers ember value cross-check)

Verification flow:
  mix test → admin_test.exs → DIST-05 + new D-11 dark-block parity assertion
  Playwright admin-design-{chromium,mobile,dark} → axe (wcag2a+wcag2aa, 0 violations)
  Playwright admin-theme.spec.ts → contrastRatio() assertions (brand-soft, tone-on-soft)
  CI snapshot_drift_guard → snapshot-allowlist + snapshot-allowlist-design (if any value changes)
  CI quality_ledger_monotonic → admin-quality-ledger.md (L0 row, tier ≥ 1)
```

### Recommended Project Structure

No structural changes. All work is within existing directories:

```
guides/reference/
├── admin-token-reference.md     # NEW — D-01 deliverable
├── admin-quality-ledger.md      # EDIT — add L0 row (D-03)
├── admin-fractal-scorecard.md   # READ — rubric reference
└── admin-design-contract.md     # READ — cross-reference only

test/sigra/install/features/
└── admin_test.exs               # EDIT — add D-11 parity assertion

test/example/priv/playwright/tests/
└── admin-theme.spec.ts          # EDIT — extend contrastRatio() for soft pairs
```

### Pattern 1: Ledger Row Format (machine-parseable tier integer)

The monotonic guard (`scripts/ci/quality-ledger-monotonic.sh`) reads tier values using:

```bash
grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md \
  | awk -F'|' '{
      item=gensub(/^ +| +$/, "", "g", $2)
      tier=gensub(/^ +| +$/, "", "g", $4)
      if (tier ~ /^[012]$/) print item ":" tier
    }'
```

**Critical parsing rules (VERIFIED by reading quality-ledger-monotonic.sh):**

- Column 4 (1-indexed in `|`-delimited rows) is the tier cell
- Tier must be a single bare integer: `0`, `1`, or `2` — no decorators, no text
- Row must start with `| [lowercase-letter]` to be parsed (the item slug)
- Blank items or items starting with uppercase are skipped

**L0 row format for the ledger:**

```markdown
| token-layer | L0 | 1 | [admin-token-reference.md](admin-token-reference.md) |
```

The item key (`token-layer`) must start with a lowercase letter. `L0` goes in the Level column (column 3). The tier integer `1` (Ratified) goes in column 4. The evidence link goes in column 5.

**Tier vocabulary:**
- `0` = Drift (fails one or more scorecard axes)
- `1` = Ratified (meets the v1.34 contract bar; passes all required axes)
- `2` = Award-grade (emilkowal.ski-level micro-interaction quality; delightful in detail)

Phase 186 target is Tier 1 (Ratified). Tier 2 would require award-grade motion micro-interactions that are deferred to Phase 187.

[VERIFIED: reading quality-ledger-monotonic.sh and admin-quality-ledger.md]

### Pattern 2: ExUnit Dark-Block Parity Assertion (D-11 recommended approach)

The DIST-05 test in `admin_test.exs` is the established pattern for CSS parity. The D-11 parity assertion extends this pattern to compare the `--sg-*` custom property set extracted from the sigra_admin.css `@media` dark block vs the app.css explicit-toggle dark block.

**Recommended implementation approach:** Extract all lines matching `--sg-` from each block, sort them, and assert equality. This is value-equivalence, not byte-equivalence (the two blocks have different selectors and different indentation, so byte comparison would always fail). The guard catches any divergence in property names or values, which is the actual risk.

```elixir
# Source: test/sigra/install/features/admin_test.exs — add as new describe block
describe "D-11 System↔explicit-toggle dark-block parity" do
  test "admin dark @media block and app.css explicit-toggle dark block declare identical --sg-* values" do
    # Canonical System path: @media (prefers-color-scheme: dark) in sigra_admin.css
    # Lines ~167-204 — extract just the --sg-* declarations
    admin_css = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
    # app.css explicit-toggle dark: .sg-admin-shell[data-theme="dark"] block
    # Lines ~1512-1543 — extract just the --sg-* declarations
    app_css = File.read!("test/example/priv/static/assets/css/app.css")

    admin_dark_props = extract_dark_media_props(admin_css)
    app_dark_props = extract_explicit_dark_props(app_css)

    assert admin_dark_props == app_dark_props,
           "Dark token values diverged between System path (@media) and explicit-toggle path — " <>
             "update both blocks together when changing any dark token"
  end

  defp extract_dark_media_props(css) do
    # Extract the @media (prefers-color-scheme: dark) { :root { ... } } block
    # then pull --sg-* lines, normalize whitespace, sort
    css
    |> extract_block_after("@media (prefers-color-scheme: dark)")
    |> extract_custom_properties()
  end

  defp extract_explicit_dark_props(css) do
    # Extract the .sg-admin-shell[data-theme="dark"] { ... } block
    # then pull --sg-* lines, normalize whitespace, sort
    css
    |> extract_block_after(~s|html[data-sg-admin-theme="dark"] .sg-admin-shell|)
    |> extract_custom_properties()
  end

  defp extract_block_after(css, marker) do
    # Find the marker, then extract the next { ... } block
    # Implementation: find marker offset, scan forward for balancing braces
    # ...
  end

  defp extract_custom_properties(block) do
    block
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "--sg-"))
    |> Enum.map(&String.trim/1)
    |> Enum.sort()
  end
end
```

[ASSUMED — the exact helper implementation (extract_block_after/2) is the planner's discretion. The approach above is the recommended direction based on the pattern established by DIST-05 in admin_test.exs.]

**Alternative D-11 mechanisms considered:**

| Mechanism | Fit | Why Not Recommended |
|-----------|-----|---------------------|
| ExUnit CSS extraction (above) | HIGH | Matches DIST-05 pattern; runs in mix test; no new CI wiring |
| Shell/CI diff script in scripts/ci/ | MEDIUM | Works but adds a new CI step to wire; the guard would be in snapshot_drift_guard job not in library_tests |
| Playwright computed-style cross-check | LOW | Requires a running server and 3 browser projects; slow; overkill for a token-value equality check |

The ExUnit approach is recommended because it matches the established DIST-05 pattern, runs fast (filesystem reads only, no server), and is wired to the existing `library_tests` CI job with no new YAML required.

### Pattern 3: contrastRatio() Extension for Soft Pairs (D-06)

The existing `contrastRatio()` helper in `admin-theme.spec.ts` (line 183) already asserts AA (4.5:1) for:
- `notice_link` text color on notice background (lines 519, 536, 554, 570)
- metric `.sg-metric__value` color on `sg-summary-chip` background (lines 675, 697)
- search button text/background hover (line 946)

**Pairs the gallery renders that axe may skip (alpha-composited rgba() soft backgrounds):**

Axe cannot resolve contrast on computed `color-mix(in oklab, var(--sg-color-*-soft) 62%, var(--sg-color-panel))` backgrounds because the alpha is composited at render time. The gallery renders all four tones (ok, warn, risk, info) in both `notice` and `sg-list-row` components. These are the pairs needing explicit `contrastRatio()` coverage:

| Component | Light pair | Dark pair | axe misses? |
|-----------|-----------|-----------|-------------|
| `.sg-notice[data-tone="ok"]` text on color-mix(ok-soft 62%, panel) bg | `--sg-color-ok` (#176b43) on ~#f0faf7 composite | `--sg-color-ok` (#5dd1a0) on ~#1c2320 composite | YES — rgba bg |
| `.sg-notice[data-tone="warn"]` text on color-mix(warn-soft 62%, panel) bg | `--sg-color-warn` (#a15c00) on ~#fff3d4 composite | `--sg-color-warn` (#f5c451) on ~#221e19 composite | YES — rgba bg |
| `.sg-notice[data-tone="risk"]` text on color-mix(risk-soft 62%, panel) bg | `--sg-color-risk` (#b42318) on ~#fff5f5 composite | `--sg-color-risk` (#f8a39c) on ~#201b1b composite | YES — rgba bg |
| `.sg-notice[data-tone="info"]` text on color-mix(info-soft 62%, panel) bg | `--sg-color-info` (#1d4ed8) on ~#f0f3ff composite | `--sg-color-info` (#9db8f5) on ~#1b1e25 composite | YES — rgba bg |
| `.sg-summary-chip` with tone on brand-soft bg | `--sg-color-brand-strong` (#9a3412) on `#fff0e8` | `--sg-color-brand-strong` (#fdba74) on rgba(243,90,16,0.16) composite | YES (dark only) |

[VERIFIED: reading app.css lines 2756–2799 for tone rendering pattern; sigra_admin.css dark block lines 167–204 for dark values; reading components.ex for tone-chip assignment.]

The extension approach: add a `test("tone notice and chip pairs meet WCAG AA in light and dark")` block in `admin-theme.spec.ts` that navigates to `/admin/_design`, reads the computed background and color of each tone notice element in both light and dark states, and asserts `contrastRatio(...) >= 4.5`.

### Anti-Patterns to Avoid

- **Inline CSS prose for rationale:** Per D-02, do not add verbose comments to `sigra_admin.css`. The CSS already has terse convention comments (e.g., `/* Dark-mode brand-strong: lightened to clear WCAG AA...`); the full rationale table belongs in `admin-token-reference.md`.
- **Byte-equality for the D-11 parity check:** The two dark blocks have different selectors and indentation, so byte-equality would always fail. Compare extracted and sorted `--sg-*` custom property sets instead.
- **Cartesian product contrast calculator:** Per D-07, do not build an offline tool that checks all possible token pairs. The gallery renders every component in every tone; rendered coverage is the AA surface.
- **Editing admin-design-contract.md:** Per D-03, cross-reference only; do not rewrite the contract.
- **Adding motion exit tokens in Phase 186:** Per D-09, deferred to Phase 187.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WCAG AA verification | Custom contrast calculator | axe (admin-design.spec.ts) + contrastRatio() extension | axe is already wired and authoritative; contrastRatio() covers the alpha-composite gap |
| Token parity enforcement | CI bash diff script | ExUnit test in admin_test.exs (D-11) | ExUnit is already the established pattern for DIST-05; no new CI job needed |
| Tier monotonicity enforcement | Manual review | quality-ledger-monotonic.sh (already wired in CI) | Shell guard already reads the tier integers; just write a correct tier integer in the new L0 row |
| Snapshot regression prevention | Manual eyeball | snapshot-canary-guard.sh + empty allowlists | Guards are already wired; declare slug in both allowlists if any token value changes |

---

## Common Pitfalls

### Pitfall 1: Ledger Tier Cell with Non-Integer Content

**What goes wrong:** Adding "Tier 1" or "Ratified" or "1 (Ratified)" to the tier column causes the monotonic guard's `awk` to skip the row (`tier ~ /^[012]$/` fails), silently disabling monotonicity enforcement for the L0 row.

**Why it happens:** The tier vocabulary table in the ledger uses tier names ("Ratified", "Award-grade") in prose, which looks natural to copy into the tier cell.

**How to avoid:** The tier column (column 4 in the pipe-delimited table) must contain a bare `0`, `1`, or `2` with no surrounding text, asterisks, or labels. The Evidence column is where explanatory text goes.

**Warning signs:** Run `grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md | awk -F'|' '{print $4}'` — if the L0 row's tier cell prints anything other than `0`, `1`, or `2`, the guard will skip it.

[VERIFIED: reading quality-ledger-monotonic.sh extract_tiers function]

### Pitfall 2: Snapshot Drift Without Allowlist Declaration

**What goes wrong:** If the adversarial audit surfaces a real AA failure requiring a token value change, re-recording the affected gallery board PNGs without adding the slug to both `snapshot-allowlist` and `snapshot-allowlist-design` causes `snapshot_drift_guard` to fail CI with "unintended snapshot change".

**Why it happens:** The empty-allowlist discipline requires that any intended visual delta is declared in the same PR diff. Both allowlists use different slug formats (the design allowlist uses hyphenated filename forms, not LiveView board IDs — `board-stat-link` not `board-stat_link`).

**How to avoid:** When any token value changes, add the affected board slug(s) to BOTH `snapshot-allowlist` (for admin-checkpoints PNGs) AND `snapshot-allowlist-design` (for admin-design PNGs). Slugs are derived from the PNG filename stem: `board-stat_link` → `board-stat-link`.

**Warning signs:** `scripts/ci/snapshot-canary-guard.sh` log shows "unintended snapshot change: <slug>".

### Pitfall 3: Comparing Dark Blocks Byte-by-Byte

**What goes wrong:** The `@media (prefers-color-scheme: dark) { :root { ... } }` block in sigra_admin.css uses 4-space indentation inside the `:root` selector. The `html[data-sg-admin-theme="dark"] .sg-admin-shell { ... }` block in app.css uses 2-space indentation. A byte-equality comparison of the blocks always fails even when values are identical.

**Why it happens:** The two blocks serve different selectors, so their surrounding whitespace differs by design.

**How to avoid:** Extract just the `--sg-*` custom property declarations, strip leading whitespace, sort, and compare the sorted sets.

**Warning signs:** If the D-11 parity assertion fails on a clean repo where the verified token values are identical, the extraction logic is comparing structural formatting, not token values.

### Pitfall 4: Treating admin-token-reference.md as an Authoritative Runtime Source

**What goes wrong:** If future tooling treats `admin-token-reference.md` as the source of truth for token values (e.g., a sync script that rewrites sigra_admin.css from the doc), it creates a loop where the documentation drives the implementation.

**Why it happens:** The rationale table documents values that already exist in CSS; copying them into the doc creates the appearance of a bidirectional contract.

**How to avoid:** `admin-token-reference.md` is a documentation artifact. The canonical runtime source is `sigra_admin.css`. Values in the doc are copied from CSS, not authoritative over it. The D-11 parity assertion is the enforcement mechanism, not the doc.

---

## D-11 Parity Assertion — Structural Finding

This section documents the exact dark-block boundaries for the planner to write a precise comparison.

### Surface 1: sigra_admin.css `@media` System path (canonical)

- **File:** `priv/templates/sigra.install/admin/sigra_admin.css`
- **Dark block start:** Line 167 — `@media (prefers-color-scheme: dark) {`
- **Dark block end:** Line 204 — closing `}` of the outer @media rule
- **Inner :root block:** Lines 168–203
- **Custom properties declared:** 27 `--sg-*` properties (verified by grep extraction)
- **Indentation:** 4 spaces inside `:root { ... }`

### Surface 2: app.css explicit-toggle dark path (fourth surface, UNGUARDED)

- **File:** `test/example/priv/static/assets/css/app.css`
- **Dark block start:** Line 1512 — `.sg-admin-shell[data-theme="dark"],`
- **Line 1513:** `html[data-sg-admin-theme="dark"] .sg-admin-shell {`
- **Dark block end:** Line 1543 — closing `}`
- **Custom properties declared:** 27 `--sg-*` properties (verified by grep extraction)
- **Indentation:** 2 spaces

### Value parity status (VERIFIED 2026-06-14)

All 27 `--sg-*` custom property declarations are value-identical between the two blocks. The only differences are: (a) different selectors/indentation (expected); (b) comments in the sigra_admin.css block are absent from the app.css block (also expected). The sets are currently lock-step.

[VERIFIED: extracted and sorted --sg-* declarations from both blocks; diff shows only indentation differences]

### Ember parity: auth surface (sigra_auth.css) vs admin tokens

The shared "ember" values between admin and auth surfaces:

| Semantic concept | Admin token | Admin value | Auth token | Auth value |
|-----------------|-------------|-------------|------------|------------|
| Accent (light) | `--sg-color-brand` | `#c2410c` | `--sigra-auth-accent` | `#c2410c` (default) |
| Risk (light) | `--sg-color-risk` | `#b42318` | `--sigra-auth-risk` | `#b42318` |
| Warn (light) | `--sg-color-warn` | `#a15c00` | `--sigra-auth-warn` | `#a15c00` |
| Ok (light) | `--sg-color-ok` | `#176b43` | `--sigra-auth-ok` | `#176b43` |
| Risk (dark) | `--sg-color-risk` | `#f8a39c` | `--sigra-auth-risk` | `#f8a39c` |
| Warn (dark) | `--sg-color-warn` | `#f5c451` | `--sigra-auth-warn` | `#f5c451` |
| Ok (dark) | `--sg-color-ok` | `#5dd1a0` | `--sigra-auth-ok` | `#5dd1a0` |
| Bg (dark) | `--sg-color-subtle` | `#171614` | `--sigra-auth-bg` | `#171614` (default) |
| Surface (dark) | `--sg-color-panel` | `#1f1d1a` | `--sigra-auth-surface` | `#211f1c` (near-match, not identical) |
| Text (dark) | `--sg-color-ink` | `#f4f1eb` | `--sigra-auth-text` | `#f4f1eb` (default) |

The auth surface panel dark value `#211f1c` vs admin panel `#1f1d1a` is a known near-match (slightly different). The critical semantic alignment is the tone/risk/warn/ok/info values and the ink/bg values — those are identical. This constitutes "ember parity" — not pixel-for-pixel identity, but coherent family membership.

[VERIFIED: reading sigra_auth.css lines 1–103 and sigra_admin.css lines 57–203]

---

## Motion Budget Ratification (TOKEN-03)

The existing motion token set in `sigra_admin.css` (lines 117–137) is:

| Token | Value | emilkowal.ski validation | Category |
|-------|-------|--------------------------|----------|
| `--sg-motion-press` | 120ms | ALIGNED — press 100–160ms range | Micro-interaction |
| `--sg-motion-pop` | 180ms | ALIGNED — "dropdown sweet-spot" per Emil | Pop/bounce |
| `--sg-motion-fast` | 140ms | ALIGNED — within 100–200ms fast range | General fast |
| `--sg-motion-medium` | 220ms | ALIGNED — 150–250ms dropdown range | Panel/reveal |
| `--sg-motion-slow` | 300ms | MARGINAL — at Emil's "under 300ms" ceiling; acceptable for full modals | Overlay |
| `--sg-ease` | cubic-bezier(0.2, 0, 0, 1) | ALIGNED — general UI ease | Default |
| `--sg-ease-out` | cubic-bezier(0.23, 1, 0.32, 1) | ALIGNED — enters use ease-out | Enter |
| `--sg-ease-in` | cubic-bezier(0.4, 0, 1, 1) | NOTED — Emil says never use ease-in for UI enters; acceptable for exits | Exit only |
| `--sg-ease-spring` | cubic-bezier(0.34, 1.4, 0.64, 1) | ALIGNED — micro-delight, pointer-gated | Delight |
| `--sg-transition-press` | transform fast ease | ALIGNED — exact-property, transform only | Press |
| `--sg-transition-tone` | color+bg+shadow fast ease | ALIGNED — exact-property | Color shift |
| `--sg-transition-enter` | opacity+transform medium ease-out | ALIGNED — exact-property, ease-out enters | Reveal |

**Ratification verdict:** ALIGNED. Document as Tier 1 Ratified in `admin-token-reference.md` and the L0 ledger row. The overlay=300ms boundary and exit-asymmetry refinements are deferred to Phase 187 per D-09.

[ASSUMED — emilkowal.ski validation principles are from research done in the CONTEXT.md discuss phase; not re-verified via live web lookup in this session. The CONTEXT.md records them as validated.]

---

## Token Value Survey (for admin-token-reference.md authoring)

The `:root` token categories in `sigra_admin.css` that need rationale in `admin-token-reference.md`:

| Category | Token count | brandbook/tokens.json ref |
|----------|-------------|--------------------------|
| Spacing scale (4px base) | 10 (`--sg-space-1` through `--sg-space-12`) | `space.*` |
| Type scale | 8 sizes + 4 weights + 4 leading + 3 tracking | `typography.*` |
| Color — neutrals | 7 (`--sg-color-ink`, `--sg-color-muted`, `--sg-color-subtle`, `--sg-color-panel`, `--sg-color-panel-alt`, `--sg-color-line`, `--sg-color-line-strong`) | `semantic.light.color.*` |
| Color — brand | 9 (brand, brand-strong, brand-solid, brand-fill-hover, brand-fill-active, brand-soft, on-brand, on-brand-solid, logo tokens) | `semantic.light.color.accent*`, `raw.color.ember-*` |
| Color — semantic status | 8 (risk, risk-soft, warn, warn-soft, ok, ok-soft, info, info-soft) | `semantic.light.color.{error,warning,success,info}*` |
| Radii | 5 (`--sg-radius-xs` through `--sg-radius-full`) | `radius.*` |
| Control heights | 4 (`--sg-control-xs` through `--sg-control-lg`) | (not in tokens.json — component-tier sizing) [ASSUMED] |
| Elevation/shadow | 4 (`--sg-elev-inset`, `--sg-elev-1`, `--sg-elev-2`, `--sg-elev-3`) | `shadow.*` (partial match) |
| Motion | 5 durations + 4 easings + 3 composed transitions | `motion.*` (fast, medium, ease, ease-out; press/slow/spring/ease-in are admin-extended) |
| Focus ring | 2 (`--sg-focus-ring`, `--sg-focus-ring-offset`) | `semantic.light.color.focus` |
| Z-index ladder | 5 (`--sg-z-base` through `--sg-z-toast`) | (not in tokens.json — layout-tier concern) [ASSUMED] |
| Layout | 3 (`--sg-container-max`, `--sg-breakpoint-lg`, `--sg-measure`) | (not in tokens.json) [ASSUMED] |
| Component sizing | 6 (pill, bottom-nav) | (not in tokens.json — component-tier) [ASSUMED] |

Note: `brandbook/tokens.json` covers colors, spacing, radius, typography, and the core motion subset. Control heights, z-index ladder, layout tokens, and component sizing tokens have no direct `tokens.json` equivalent — their rationale will reference the design contract or be documented as admin-layer decisions.

[VERIFIED: reading sigra_admin.css :root block lines 20–165 and brandbook/tokens.json]

---

## Blast Radius: Token Value Change Procedure (D-04, D-05, D-12)

If the adversarial audit surfaces a genuine AA failure (the expected finding is "already compliant"), the edit set is:

1. **All four parity surfaces together:**
   - `priv/templates/sigra.install/admin/sigra_admin.css` — change the token in `:root` (light) and `@media (prefers-color-scheme: dark)` (System path)
   - `test/example/priv/static/assets/sigra_admin.css` — copy-paste update (byte-parity with installer; DIST-05 will catch if missed)
   - `test/example/priv/static/assets/css/app.css` — update `.sg-admin-shell[data-theme="light"]` and `.sg-admin-shell[data-theme="dark"]` blocks (lines 1473–1543)
   - `priv/templates/sigra.install/core/sigra_auth.css` — update if the auth ember-family value is affected
   - `brandbook/tokens.json` — update the corresponding semantic value

2. **Declare affected board slugs in BOTH allowlists:**
   - `test/example/priv/playwright/snapshot-allowlist` — board slugs for admin-checkpoints PNGs (e.g., `global-overview`, `org-overview`)
   - `test/example/priv/playwright/snapshot-allowlist-design` — board slugs for admin-design PNGs (e.g., `board-notice`, `board-summary-chip`) — note: use hyphenated forms from PNG filenames, not LiveView board IDs

3. **Re-run verification:**
   - `mix test` → DIST-05 + D-11 parity assertions must pass
   - Playwright admin-design + admin-checkpoints → axe must be 0 violations; re-record affected boards

4. **Update admin-token-reference.md:** Update the token's value cell with the new value and note the reason for change.

---

## Validation Architecture

> nyquist_validation is enabled (config.json: `"nyquist_validation": true`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework (ExUnit) | ExUnit (built-in Elixir) |
| Config file | `mix.exs` test configuration |
| Quick run command | `mix test test/sigra/install/features/admin_test.exs` |
| Full suite command | `mix test` |
| Framework (Playwright) | Playwright (test/example/priv/playwright) |
| Quick Playwright run | `cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-dark` |
| Full Playwright run | `cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts tests/admin-theme.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOKEN-01 | Each token has a rationale + brand-ref in admin-token-reference.md | Documentation + L0 ledger row | `mix test test/sigra/install/features/admin_test.exs` (no code assertion — L0 row verified by monotonic guard) | ❌ Wave 0: create guides/reference/admin-token-reference.md |
| TOKEN-01 | L0 row appears in quality ledger with Tier 1 integer | CI monotonic guard | `bash scripts/ci/quality-ledger-monotonic.sh` | ✅ guard exists; ❌ Wave 0: L0 row not yet in ledger |
| TOKEN-02 | All color pairs pass WCAG AA in light and dark (rendered components) | axe + computed-style | `cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-dark` | ✅ spec exists |
| TOKEN-02 | Tone-on-soft pairs pass AA (alpha-composited, axe misses these) | computed-style contrastRatio | `cd test/example/priv/playwright && npx playwright test tests/admin-theme.spec.ts` | ❌ Wave 0: extend admin-theme.spec.ts with tone-soft contrastRatio assertions |
| TOKEN-03 | Motion budget tokens documented with emilkowal.ski rationale | Documentation | N/A — doc review; no automated assertion | ❌ Wave 0: create admin-token-reference.md motion section |
| TOKEN-04 | System dark path and explicit-toggle dark path declare identical --sg-* values | ExUnit parity assertion | `mix test test/sigra/install/features/admin_test.exs` | ❌ Wave 0: add D-11 describe block to admin_test.exs |
| TOKEN-04 | Auth ember-family values match admin equivalents | ExUnit cross-check OR documented in admin-token-reference.md | `mix test test/sigra/install/features/admin_test.exs` | ❌ Wave 0: add auth parity check (lightweight, covers key ember values) |
| THEME-01 | Admin renders correctly in Light, Dark, System (no hardcoded values) | Playwright axe (3 projects) | `cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark` | ✅ spec and 3 projects exist |
| THEME-01 | dark brand-strong is #fdba74 (not the light #9a3412) | ExUnit assertion on extracted dark block | `mix test test/sigra/install/features/admin_test.exs` | ❌ Wave 0: include in D-11 parity block (verifies the specific value is correct) |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/install/features/admin_test.exs` (ExUnit only; fast, no server)
- **Per wave merge:** `mix test` (full ExUnit suite) + Playwright admin-design lane + Playwright admin-theme assertions
- **Phase gate (before /gsd:verify-work):** Full suite green + axe 0 violations in all 3 admin-design projects + monotonic guard passing

### Wave 0 Gaps

- [ ] `guides/reference/admin-token-reference.md` — new file; covers TOKEN-01 rationale requirement
- [ ] L0 row in `guides/reference/admin-quality-ledger.md` — covers TOKEN-01 ledger requirement (INFRA-04 contract)
- [ ] D-11 describe block in `test/sigra/install/features/admin_test.exs` — covers TOKEN-04 parity requirement; no new file, adds to existing file
- [ ] contrastRatio() tone-soft extension in `test/example/priv/playwright/tests/admin-theme.spec.ts` — covers TOKEN-02 alpha-composited pairs; no new file, extends existing spec

---

## Security Domain

> security_enforcement is absent from config.json (treated as enabled).

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Token layer is CSS/design; no auth logic |
| V3 Session Management | No | CSS tokens have no session involvement |
| V4 Access Control | No | Token layer has no access control surface |
| V5 Input Validation | No | No user input in this phase |
| V6 Cryptography | No | No cryptographic operations in CSS token authoring |

Security domain is not applicable to this phase. The phase touches CSS custom properties and documentation only. No auth flows, user data, tokens (security), or server-side logic are modified.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Dark AA fix at component level (scoped .sg-filter-chip override) | Global :root dark block override (`--sg-color-brand-strong: #fdba74`) | v1.34 (Phase 160) | Single source of truth; all dark brand-soft surfaces fixed at once |
| Manual parity verification across 4 CSS surfaces | DIST-05 byte-parity (installer↔example sigra_admin.css) + new D-11 parity assertion (System↔explicit-toggle dark) | v1.34 for DIST-05; Phase 186 for D-11 | Machine-enforced; drift caught before merge |
| No quality tier record | admin-quality-ledger.md + monotonic guard | Phase 185 | Re-runs cannot regress tier; forward-only quality model |
| No per-token documentation | admin-token-reference.md (Phase 186) | Phase 186 | Phases 187–192 build on documented, ratified foundation |

**Deprecated/outdated:**
- Component-scoped brand-strong dark override (`.sg-filter-chip` block): superseded by the global `:root` dark block override at v1.34. The comment in sigra_admin.css at line 183 notes this explicitly.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | emilkowal.ski motion validation principles recorded in CONTEXT.md are accurate (press 100–160 ✅, pop 180ms ✅, medium 220ms ✅, slow 300ms ✅) | Motion Budget Ratification | If the principles are misremembered, the "ALIGNED" ratification would be incorrect. Low risk: the CONTEXT.md was authored by a research-backed discuss phase. |
| A2 | Control heights, z-index ladder, layout tokens, and component sizing tokens have no direct brandbook/tokens.json equivalent | Token Value Survey | If tokens.json has entries for these, the admin-token-reference.md brand-ref column for these rows should point there rather than noting "admin-layer decision". Low impact: documentation-only. |
| A3 | The exact ExUnit helper implementation for extracting dark block CSS properties (extract_block_after/2) is straightforward to implement | D-11 Parity Assertion | If the CSS block extraction logic is non-trivial (e.g., due to nested braces), the planner may need a different approach such as line-range extraction using a known anchor string. Mitigation: the exact line ranges (167–204 and 1512–1543) are verified and stable enough to use directly. |

---

## Open Questions

1. **Single L0 row vs per-token-group sub-rows in the ledger**
   - What we know: CONTEXT.md marks this as Claude's Discretion; the monotonic guard reads any row whose first cell starts with a lowercase letter
   - What's unclear: Whether a single `| token-layer | L0 | 1 | ... |` row is sufficient, or whether per-group rows (e.g., `| token-color | L0 | ... |`, `| token-motion | L0 | ... |`) would provide more granular rollback targets for phases 187–192
   - Recommendation: Use a single `| token-layer | L0 | 1 | ... |` row. The entire `:root` layer is ratified as a unit in Phase 186; per-group rows would be premature granularity before any per-group defects are found. Phase 187 can add per-component rows.

2. **Auth surface parity assertion scope**
   - What we know: sigra_auth.css uses `--sigra-auth-*` namespace, not `--sg-*`; the shared "ember" values are risk/warn/ok/info + bg/ink; surface panel dark value is near-match not identical (#211f1c vs #1f1d1a)
   - What's unclear: Whether the D-11 parity assertion should assert auth-ember-family values explicitly or simply document the known near-match and leave it to the axe lane on auth surfaces
   - Recommendation: Add a lightweight auth ember cross-check (risk, warn, ok, info light+dark values only) to the D-11 describe block in admin_test.exs. Skip panel/surface values since the near-match is a known intentional difference. Document the near-match in admin-token-reference.md.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | mix test (ExUnit) | ✓ | ~> 1.18 | — |
| Playwright | axe + contrastRatio assertions | ✓ (test/example/priv/playwright) | configured in playwright.config.ts | — |
| PostgreSQL | mix test (admin_test.exs runs async, no DB) | ✓ (required by full mix test) | 15.x | — |
| Running Phoenix server | Playwright tests | Required at test time | Boot via `mix phx.server` in test/example | — |

**Missing dependencies with no fallback:** None.

The D-11 ExUnit parity assertion (comparing CSS file contents) requires no server and no database — it is a filesystem read test, equivalent to DIST-05.

---

## Sources

### Primary (HIGH confidence)

- `priv/templates/sigra.install/admin/sigra_admin.css` — canonical :root token block (lines 20–165), dark @media block (lines 167–204), motion tokens (lines 117–137) [VERIFIED: file read]
- `test/example/priv/static/assets/css/app.css` — explicit-toggle dark block (lines 1512–1543), light-shell block (lines 1473–1510) [VERIFIED: file read]
- `brandbook/tokens.json` — brand semantic tokens, dark values (lines 69–98), motion subset (lines 155–160) [VERIFIED: file read]
- `priv/templates/sigra.install/core/sigra_auth.css` — auth --sigra-auth-* layer, ember parity values (lines 1–103) [VERIFIED: file read]
- `scripts/ci/quality-ledger-monotonic.sh` — tier integer parsing rules; `extract_tiers()` awk block [VERIFIED: file read]
- `guides/reference/admin-quality-ledger.md` — current ledger state (no L0 row; lowest is L1) [VERIFIED: file read]
- `guides/reference/admin-fractal-scorecard.md` — D1–D11 rubric; AA thresholds (lines 30–32) [VERIFIED: file read]
- `test/sigra/install/features/admin_test.exs` — DIST-05 parity test pattern (lines 317–328) [VERIFIED: file read]
- `test/example/priv/playwright/tests/admin-design.spec.ts` — axe gate (lines 32–43), board IDs [VERIFIED: file read]
- `test/example/priv/playwright/tests/admin-theme.spec.ts` — contrastRatio() helper (line 183), existing assertions (lines 519, 536, 554, 570, 675, 697, 946) [VERIFIED: file read]
- `scripts/ci/snapshot-canary-guard.sh` — allowlist slug parsing, canary check [VERIFIED: file read]
- `.github/workflows/ci.yml` — snapshot_drift_guard (lines 1106–1132), quality_ledger_monotonic (lines 1134–1156) CI jobs [VERIFIED: file read]
- `.planning/phases/186-token-foundation-l0/186-CONTEXT.md` — locked decisions D-01..D-12 [VERIFIED: file read]

### Secondary (MEDIUM confidence)

- `test/example/priv/playwright/snapshot-allowlist` and `snapshot-allowlist-design` — empty-by-discipline state confirmed [VERIFIED: file read]
- Token value parity between sigra_admin.css dark @media block and app.css explicit-toggle dark block — confirmed identical via grep extraction and sort comparison [VERIFIED: bash comparison]
- Ember-family value alignment between admin and auth surfaces — verified key values match; panel surface near-match documented [VERIFIED: grep comparison]

---

## Metadata

**Confidence breakdown:**
- D-11 parity finding (exact line ranges, value equivalence): HIGH — verified by direct file reads and grep extraction
- Ledger tier format: HIGH — verified by reading quality-ledger-monotonic.sh awk logic
- AA verification mechanism: HIGH — verified by reading admin-design.spec.ts and admin-theme.spec.ts
- Motion budget validation: MEDIUM — emilkowal.ski principles are from discuss-phase research, not re-verified in this session (tagged ASSUMED)
- Soft-pair axe coverage gap: HIGH — rgba() and color-mix() alpha-composited backgrounds confirmed in CSS; axe's inability to resolve these is documented behavior [ASSUMED for axe's exact behavior on color-mix() — HIGH confidence based on known axe limitations with alpha]
- Token-reference doc shape: HIGH — follows established guides/reference/*.md sibling convention from Phase 185

**Research date:** 2026-06-14
**Valid until:** Stable (CSS token layer; no fast-moving ecosystem dependencies)

---

## RESEARCH COMPLETE

**Phase:** 186 - Token Foundation (L0)
**Confidence:** HIGH

### Key Findings

1. **D-11 gap confirmed and bounded:** The System-vs-explicit-toggle dark token divergence is the highest-value structural risk. The 27 `--sg-*` custom property values are currently identical between `sigra_admin.css` @media dark block (lines 167–204) and `app.css` explicit-toggle dark block (lines 1512–1543). No test catches a future divergence. The recommended guard is an ExUnit describe block in `admin_test.exs` that extracts, sorts, and compares the `--sg-*` sets — matching the DIST-05 pattern, requiring no new CI wiring.

2. **AA audit likely "already compliant":** Dark-mode AA was remediated at v1.34 (`--sg-color-brand-strong` → `#fdba74`; tone/soft colors lightened). The adversarial audit's expected finding is "ratify, not re-tune." The contrastRatio() extension for tone-on-soft pairs is the main test gap.

3. **Tone-on-soft pairs need explicit contrastRatio() assertions:** axe cannot evaluate contrast on `color-mix(in oklab, var(--sg-color-*-soft) 62%, var(--sg-color-panel))` computed backgrounds. All four tones (ok, warn, risk, info) in both `notice` and status pill components need explicit computed-style assertions in `admin-theme.spec.ts`.

4. **L0 ledger row format is strict:** Tier column must be a bare integer (`0`, `1`, or `2`). The monotonic guard's awk uses `tier ~ /^[012]$/` — any decoration silently disables enforcement for that row.

5. **Motion budget is validated ALIGNED:** All 5 durations and 4 easings match emilkowal.ski principles. The two deferred refinements (overlay 300ms boundary, exit-asymmetry) are Phase 187 work.

### File Created

`.planning/phases/186-token-foundation-l0/186-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| D-11 parity finding (line ranges, values) | HIGH | Direct file reads + grep comparison |
| L0 ledger tier format | HIGH | Read quality-ledger-monotonic.sh awk |
| AA verification mechanism | HIGH | Direct read of spec files |
| Motion budget alignment | MEDIUM | Discuss-phase research, not re-verified live |
| Soft-pair axe gap | HIGH | CSS confirmed alpha-composited; axe limitation well-known |

### Open Questions

- Single L0 ledger row vs per-token-group sub-rows (Recommendation: single row)
- Auth ember parity assertion scope (Recommendation: risk/warn/ok/info only, skip near-match surface/panel values)

### Ready for Planning

Research complete. Planner can now create PLAN.md files.
