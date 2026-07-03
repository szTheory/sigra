# Phase 207: L1 Component Elevation Wave B + L0 Token Layer - Research

**Researched:** 2026-06-28
**Domain:** Admin design-system elevation (audit → cite gate → narrow-gap-fix → ledger-flip → snapshot-recapture); CI conformance guards; `sg-*` cascade-layer CSS
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Phase 207 modifies the 5 L1 components on their isolated `board-*` gallery boards only, plus the L0 token layer. It does NOT touch page composition or cross-page placement. The `.planning/v1.42-IA-DIAGNOSTIC.md` "feeds 207" page-composition tags use stale v1.41 numbering and route to **Phase 209**. The scope_ribbon *component* on its board is in-scope; scope_ribbon *placement-across-pages* incoherence is 209's job.
- **D-02:** Apply the identical Phase 206 method: audit → cite existing gate → narrow-gap-fix → ledger-flip → snapshot-recapture. Components stay where they are. Function defs live in `lib/sigra/admin/components.ex`; styling lives in `priv/templates/sigra.install/admin/sigra_admin.css` via `sg-*` classes. NOT relocation or restructure.
- **D-03 (edit the source, not the copy):** All CSS/markup edits land in `priv/templates/sigra.install/` source, never the generated `test/example/` copy or `test/fixtures/install_golden/` tree. Generated copies must stay byte-coherent or golden-diff/install tests fail.
- **D-04:** Per-component, per-project axe is already wired for all 5 boards in `admin-design.spec.ts` (`COMPONENT_BOARDS`; `assertBoardScreenshot` runs `assertNoAxeViolations` across chromium/mobile/dark). 207's job is to keep these boards 0-violation and cite the existing gate as ledger evidence. Add a state-variant board only if an audit surfaces a genuine gap.
- **D-05 (reduced-motion strategy):** Rely on the existing global `@media (prefers-reduced-motion: reduce)` block (`sigra_admin.css:~1467`) which strips transform/animation (incl. `animation-iteration-count: 1 !important`). `skeleton` shimmer is already covered with a passing reduced-motion assertion. Verify, cite, do not rewrite per-component media queries. Reuse the already-built `scripts/ci/admin-css-conformance.sh` guard.
- **D-06 (fold the token-completeness guard):** Fold the pending todo `2026-06-18-token-reference-completeness-ci-guard.md` as the durable COMP-03 proof: a lightweight CI check diffing `--sg-*` `:root` LHS defs in `sigra_admin.css` against the documented backtick tokens in `admin-token-reference.md`, failing on divergence.
- **D-07 (extend conformance to raw-px):** Extend the guard to catch raw-px outside `--sg-*` tokens so the full COMP-03 conformance is automated. **Fallback (D-07a):** if the raw-px sweep is too noisy/heavy for one phase, the completeness guard (D-06) is the load-bearing COMP-03 proof; raw-px may degrade to a documented manual review.
- **D-08:** Flip exactly 6 rows in `guides/reference/admin-quality-ledger.md` from `1`→ bare `2`: the 5 L1 component rows + the `token-layer` (L0) row. Use the rich semicolon-delimited evidence shape mirroring the 8 Wave-A rows. Tier column is bare `2` — never decorated (`2*` breaks the `awk -F'|'` monotonic parse).
- **D-09 (snapshot discipline, v1.41 method):** Any CSS state change forces recapture of affected `board-*` PNG baselines through the snapshot-recapture gate. `impersonation-banner` and `board-notice` canaries stay byte-stable and untouched; both allowlists empty at phase close; `scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0.

### Claude's Discretion
- Exact per-component interaction-state audit findings and which (if any) genuinely need a CSS fix vs already-present (expected: minimal).
- Exact shape of the raw-px extension to `admin-css-conformance.sh` (regex, allowlist, output format).
- Exact shape of the token-completeness diff (parse `:root` LHS vs documented backticks); add a sibling `.test.sh` self-test if cheap.
- Precise wording of each ledger evidence string (keep `awk -F'|'` monotonic-guard-safe — bare `2`).
- Exact per-component documented target-size values (cite real CSS px from the boards).
- Whether the raw-px check (D-07) lands automated or degrades to documented manual review (D-07a) — prefer automated.

### Deferred Ideas (OUT OF SCOPE)
- Page-composition / cross-page-placement findings the IA-diagnostic tags "feeds 207" (scope_ribbon placement across audit pages, applied-chip DOM position, More-filters `phx-click` vs `<details>`, quick-toggle Apply gap, "Effective user" asymmetric filter) — deferred to **Phase 209**.
- D-07a fallback: raw-px automated check may degrade to documented manual review.
- L2 meta-component group elevation — **Phase 208**.
- Reviewed-but-not-folded todos: playwright-parallelization (0.9, CI-perf), phase200-code-review-deferred (0.6, page-functionality), phase205-debt-ci-native-board-baselines (0.6, infra, → Phase 211).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-02 | The 5 remaining L1 components reach Tier-2: axe-clean across chromium/mobile/dark; no `transition: all`; motion respects `prefers-reduced-motion` | Per-component audit (below) confirms all interaction-state CSS already present; existing axe+screenshot harness already gates all 5 boards; existing motion guard + global reduced-motion block already cover all 5. Expected work: cite-only + ledger flip; near-zero genuine CSS gaps. |
| COMP-03 | L0 token layer has documented brand-token conformance (no raw hex/px outside `--sg-*` tokens; light/dark/system parity); `admin-token-reference.md` refreshed to cite conformance evidence | (a) hex conformance already guarded by `admin-css-conformance.sh`; (b) **net-new:** raw-px extension (D-07) — but 38 raw-px occurrences exist, nearly all legitimate idioms (see Common Pitfalls); (c) **net-new:** token-completeness diff guard (D-06) — CSS `:root` and doc backticks currently match 100/100 exactly; (d) doc refresh to cite the new guards. |
</phase_requirements>

## Summary

Phase 207 is a **cite-and-flip** elevation, not a build. Every success-criterion mechanism the phase needs already exists in the repo and is green at baseline: the per-component axe+screenshot harness gates all 5 target boards across chromium/mobile/dark; the motion/hex conformance guard exits 0; the monotonic ledger guard exits 0 (36 cells vs `origin/main`); the global reduced-motion block strips the only animated component (`skeleton` shimmer) and has a passing assertion. A full code-level audit of all 5 components against the three Tier-2 L1 proxies (interaction-state, target-size, light/dark token correctness) found **zero genuine CSS gaps** — `empty_state` and `scope_ribbon` are static (no states to add), `page_back` inherits full hover/focus-visible/active/disabled from base `.sg-btn`, `field_help` has explicit hover/active/focus-visible, and `skeleton` is reduced-motion-safe via the global block. The CONTEXT.md citations are substantially accurate; only line numbers drifted slightly (documented below) and a few UI-SPEC motion-timing/weight claims are off (advisory, not blocking).

The genuinely net-new work is COMP-03's two CI guards. The **token-completeness guard (D-06)** is low-risk and high-value: the `:root` token set and the doc backtick set currently match **100/100 exactly** (CONTEXT's "96/96" is a stale paraphrase — actual is 100 unique `--sg-*` tokens across 2 `:root` blocks), so the guard would exit 0 today and pins the doc against future rot. The **raw-px extension (D-07)** is the only risky piece: a naive "no raw px outside `:root`" sweep flags **38 occurrences, nearly all legitimate** — media-query breakpoints, 1px hairline borders, box-shadow offset/blur/spread, micro `translateY(-1px)` nudges, `border-radius: 999px` pills, and `1px` visually-hidden clip patterns. An aggressive px guard would be all-noise; the recommendation is a **narrowly-scoped px check (color/size-token-eligible contexts only) with an inline allowlist, or D-07a manual-review fallback** with the completeness guard as the load-bearing COMP-03 proof.

**Primary recommendation:** Mirror Phase 206's 4-plan shape — (1) build the D-06 completeness guard + `.test.sh`, and either a narrowly-scoped D-07 px extension or the documented D-07a fallback; (2) run the 5-component audit and apply the (expected zero) fixes byte-coherently across all 3 CSS copies; (3) recapture only the genuinely-affected `board-*` PNGs through the recapture gate with allowlist-then-clear discipline (likely **zero** PNGs change if no CSS edits land); (4) flip the 6 ledger rows to bare `2` with rich evidence strings and refresh `admin-token-reference.md` to cite the new guards. Then prove monotonic guard exits 0 vs `origin/main`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 5 L1 component markup (`empty_state`, `page_back`, `scope_ribbon`, `field_help`, `skeleton`) | Lib-owned Phoenix function components (`lib/sigra/admin/components.ex`) | — | Components are lib-owned; only the shell wrapper is generated. Edits here ship to host apps via `mix deps.update`. |
| `sg-*` component styling + tokens | CSS source template (`priv/templates/sigra.install/admin/sigra_admin.css`) | Generated copies (test/example, install_golden) | Source-of-truth is the template; generated copies must stay byte-coherent (D-03). |
| Per-component axe + screenshot gate | Playwright (`test/example/priv/playwright/tests/admin-design.spec.ts`) | — | The gate of record for criterion 1; runs in the generated example app. |
| Motion/hex/px conformance | CI guard scripts (`scripts/ci/admin-css-conformance.sh` + new D-06/D-07 siblings) | — | Static analysis over the CSS template; merge-blocking. |
| Tier ledger + monotonic protection | `guides/reference/admin-quality-ledger.md` + `scripts/ci/quality-ledger-monotonic.sh` | — | Forward-only tier record; `awk -F'|'` parse contract. |
| Snapshot recapture discipline | `scripts/ci/snapshot-recapture-gate.sh` + `snapshot-canary-guard.sh` + allowlists | — | Zero-human stand-in for HTML-report review; canary-protected. |

## Standard Stack

No new packages. This phase is pure CSS/HEEx/Elixir/bash edits to files already in the repository.

| Tool | Already Present | Purpose This Phase |
|------|-----------------|--------------------|
| `scripts/ci/admin-css-conformance.sh` | yes (Phase 206) `[VERIFIED: file read]` | Extend with raw-px check (D-07) — or leave as-is and fall back to D-07a |
| `scripts/ci/quality-ledger-monotonic.sh` | yes (Phase 185) `[VERIFIED: file read]` | Prove no tier regression; bare-`2` parse contract |
| `scripts/ci/snapshot-recapture-gate.sh` + `snapshot-canary-guard.sh` | yes `[VERIFIED: file read]` | Recapture affected board PNGs zero-human |
| Playwright `admin-design.spec.ts` | yes `[VERIFIED: file read]` | axe + screenshot gate for all 5 boards × 3 projects |
| (new) token-completeness guard `scripts/ci/admin-token-completeness.sh` + `.test.sh` | **build this phase** | D-06 — diff `:root` LHS tokens vs doc backticks |

**Installation:** none — no `mix.exs` change, no npm add. (Confirmed by UI-SPEC Registry Safety: no shadcn, no external registries.)

## Package Legitimacy Audit

**Not applicable.** Phase 207 installs no external packages (npm, Hex, or otherwise). All work is edits to files already in the repository. No package-legitimacy gate required.

## Architecture Patterns

### System Architecture Diagram

```
                    EDIT (source of truth)
priv/templates/sigra.install/admin/sigra_admin.css ──┐
lib/sigra/admin/components.ex (5 component defs)      │
                                                      │ (manual byte-coherent copy, D-03)
                                ┌─────────────────────┼─────────────────────┐
                                ▼                     ▼                     ▼
        test/example/priv/static/assets/      test/fixtures/install_golden/  (served example asset)
              sigra_admin.css                  tree/.../sigra_admin.css
                   │                                  │
                   │ booted example app               │ regenerated by mix sigra.install
                   ▼                                  ▼
        ┌──────────────────────┐            ┌──────────────────────┐
        │ admin-design.spec.ts │            │ golden_diff_test.exs │
        │ axe + screenshot      │            │ byte-diff vs fixture  │
        │ board-* × 3 projects  │            │ (@moduletag :golden)  │
        └──────────┬───────────┘            └──────────────────────┘
                   │ deliberate --update-snapshots
                   ▼
        ┌────────────────────────────────────┐     ┌─────────────────────────────┐
        │ snapshot-recapture-gate.sh          │────▶│ snapshot-canary-guard.sh    │
        │ (compare 3 projects, run goldens)   │     │ canary board-notice byte-   │
        └────────────────────────────────────┘     │ stable; allowlist-then-clear │
                                                    └─────────────────────────────┘

        STATIC ANALYSIS (no app boot):
        admin-css-conformance.sh ── no transition:all; no raw hex (+ raw-px D-07)
        admin-token-completeness.sh (NEW, D-06) ── :root tokens == doc backticks
        quality-ledger-monotonic.sh ── awk -F'|' col4 tier never decreases (bare 0/1/2)
```

### Recommended Plan Structure (mirror Phase 206's 4-plan shape)
```
207-01  CI guards: D-06 completeness guard + .test.sh; D-07 raw-px extension OR D-07a fallback decision
207-02  5-component audit + (expected-zero) byte-coherent CSS fixes across 3 copies
207-03  Snapshot recapture of genuinely-affected board PNGs (likely zero) + doc refresh
207-04  Ledger flip: 6 rows → bare 2 with rich evidence; monotonic guard exits 0
```
(206 used exactly this: 01 = conformance guard, 02 = audit, 03 = (recapture/doc), 04 = ledger flip. `[VERIFIED: 206 SUMMARY files]`)

### Pattern: Sibling CI guard script shape (for the new D-06 guard)
```bash
# Source: scripts/ci/admin-css-conformance.sh (the proven sibling)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# --help / unknown-arg → exit 2; fail() → "name: FAIL: ..." to stderr, exit 1
# PASS/FAIL prefix on every status line; positional or --flag arg; hermetic .test.sh with mktemp fixtures
```

### Anti-Patterns to Avoid
- **Decorating the tier cell** (`2*`, `2 ✓`, `~2`): the monotonic guard's `awk -F'|'` reads col 4 and only matches `^[012]$`. A decorated value is silently dropped from the guard → the row loses regression protection. Always write a bare `2`.
- **Editing the generated `test/example/` or `install_golden/` copy directly:** breaks D-03 byte-coherence → golden_diff and install tests fail. Edit the template; copy to all 3.
- **Adding per-component `@media (prefers-reduced-motion)` blocks:** the global block at `sigra_admin.css:~1467` already covers every transition/animation. 206 D-06 confirmed this; do not duplicate.
- **An aggressive "no raw px anywhere" guard:** 38 legitimate px occurrences exist (borders, breakpoints, shadows, nudges, pills, clip). A naive sweep is all-noise — see Common Pitfalls.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-component axe gate | New axe harness or per-board tests | Existing `assertBoardScreenshot` / `assertNoAxeViolations` in `admin-design.spec.ts` | Already gates all 5 boards × 3 projects against full WCAG 2.1/2.2 AA tags |
| Reduced-motion stripping | Per-component media queries | Global `@media (prefers-reduced-motion: reduce)` block (`sigra_admin.css:~1467`) | One block already strips all transform/animation incl. skeleton shimmer |
| transition:all / raw-hex guard | New linter | `scripts/ci/admin-css-conformance.sh` (extend for px) | Proven; awk `:root` tracker already handles dual light/dark `:root` |
| Recapture review | Manual HTML-report inspection | `snapshot-recapture-gate.sh` (zero-human, canary-protected) | All-green == approval; canary `board-notice` enforces no collateral drift |
| Tier regression detection | Manual ledger review | `quality-ledger-monotonic.sh --base origin/main` | Forward-only `awk -F'|'` guard |

**Key insight:** This phase's entire toolchain was built in Phases 185/199–204/206. The job is to *use and cite* it, plus add two small sibling guards (one trivially-passing today, one possibly-deferred).

## Runtime State Inventory

> This is a doc/CSS/CI elevation phase — not a rename/refactor/migration. No stored data, live-service config, OS-registered state, secrets, or build artifacts embed any renamed string. **None found in all categories** — verified: the only "state" is the byte-coherence relationship between the 3 `sigra_admin.css` copies (all currently identical, md5 `7e60bc4c…`) and the committed `board-*` PNG baselines, both handled by D-03/D-09 mechanisms below.

## Per-Component Audit (verified against current source)

Legend: Present = CSS rule confirmed | N/A = static/display-only | Gap = expected state CSS missing.

### 1. `empty_state/1` — `sg-empty-state` (static container) `[VERIFIED: components.ex:410-417, sigra_admin.css:546-550, 1086-1096]`
- HTML: `<div class="sg-empty-state sg-stack sg-stack--3"><p class="sg-empty-state__title">…</p>{slot}</div>`.
- **Interaction-state:** N/A — static display container, no hover/focus/active/disabled.
- **Motion:** none. No transition/animation.
- **Target-size:** N/A — not interactive (any CTA inside is the caller's `sg-btn`).
- **Light/dark tokens:** `border: 1px dashed var(--sg-color-line-strong)`; `background: var(--sg-color-panel)`; `color: var(--sg-color-muted)`; title `var(--sg-color-ink)`. **Zero raw hex.** PASS.
- **CONTEXT claim ("static, no states"): ACCURATE.** Drift: CONTEXT cited CSS "~:546–568" — actual `.sg-empty-state` surface is 546-550; the `__title` block is at 1086-1096. Minor.

### 2. `page_back/1` — `sg-btn sg-btn--ghost sg-btn--sm` (anchor button) `[VERIFIED: components.ex:438-444, sigra_admin.css:437-462, 486-513]`
- HTML: `<a class="sg-btn sg-btn--ghost sg-btn--sm" href={return_to}><span aria-hidden="true">&larr;</span> {label}</a>`.
- **Interaction-state (all inherited from base `.sg-btn`):**
  - hover: `.sg-btn--ghost:hover` (490-493) `background: var(--sg-color-brand-soft); color: var(--sg-color-brand-strong)` — **Present**. NOTE: not wrapped in `@media (hover: hover)`, so it fires on touch too; consistent with other `sg-btn` variants (only `--secondary` card-lift hover is hover-gated). Acceptable.
  - focus-visible: `.sg-btn:focus-visible` (449-452) `box-shadow: var(--sg-focus-ring)` — **Present**.
  - active: `.sg-btn:active` (453-456) `transform: scale(0.96)` — **Present**.
  - disabled: `.sg-btn[disabled], [aria-disabled="true"], .is-disabled` (457-462) `opacity: 0.5; pointer-events: none` — **Present**.
- **Motion:** base `.sg-btn` `transition: var(--sg-transition-tone), var(--sg-transition-press)` (447) — specific properties, **no `transition: all`.**
- **Target-size:** `sg-btn--sm` `min-height: var(--sg-control-sm)` = 2.25rem = **36px** (509-510). Above the 24×24 documented threshold; below the full 44px WCAG 2.5.8 target but acceptable per 206 D-08 dense-admin precedent. (UI-SPEC says "≥28px" — actual is 36px; cite 36px.)
- **Light/dark tokens:** all `var(--sg-color-*)`. PASS.
- **CONTEXT claim ("full states already"): ACCURATE.** Drift: CONTEXT cited hover/focus/active/disabled at "~:430–486" — they live on base `.sg-btn` (449-462) + `--ghost` (486-493). Effectively correct.

### 3. `scope_ribbon/1` — `sg-scope-ribbon sg-muted sg-text-sm` (static span) `[VERIFIED: components.ex:465-469, sigra_admin.css:565-568]`
- HTML: `<span class="sg-scope-ribbon sg-muted sg-text-sm">{copy}</span>`.
- **Interaction-state:** N/A — decorative inline span; spec explicitly asserts it has no `[href]`/`[role=link]`/`[tabindex]` (admin-design.spec.ts:602-604).
- **Motion:** none.
- **Target-size:** N/A — not interactive.
- **Light/dark tokens:** `color: var(--sg-color-muted); font-size: var(--sg-text-sm)`. **Zero raw hex.** PASS.
- **CONTEXT claim ("static, no states"): ACCURATE** (cited ~:465, ~:546–568; actual block 565-568).

### 4. `field_help/1` — `sg-field-help` / `__trigger` / `__panel` (button + tooltip) `[VERIFIED: components.ex:581-632, sigra_admin.css:866-932]`
- HTML: `<span class="sg-field-help" data-sg-field-help-root><button type="button" class="sg-field-help__trigger" aria-label="Help: {label}" aria-controls={id} aria-expanded …><svg …/></button><span id={id} class="sg-field-help__panel" role="tooltip" hidden={!open}>{slot}</span></span>`.
- **Interaction-state:**
  - hover: `.sg-field-help__trigger:hover, [aria-expanded="true"]` (894-896) `color: var(--sg-color-brand-strong)` — **Present**.
  - active: `.sg-field-help__trigger:active` (898-900) `transform: scale(0.96)` — **Present** (UI-SPEC said `scale(0.96)`; matches — UI-SPEC color section's "scale(0.96)" is right, the "scale(0.96)" press is the same value, **not** 0.96 vs a different number; consistent).
  - focus-visible: `.sg-field-help__trigger:focus-visible` (901-903) `box-shadow: var(--sg-focus-ring)` — **Present**.
  - disabled: N/A (help trigger always available).
- **Motion:** trigger `transition: color … , transform …` (885-887) specific properties; panel `transition: var(--sg-transition-tooltip)` (926) — **no `transition: all`.** Escape-close + focus-restore proven by `admin-design.spec.ts:695-711`.
- **Target-size:** visible trigger is `1.125rem × 1.125rem` = **18×18 CSS px** (877-878), BUT a `::before { inset: -0.6875rem }` (889-892) expands the hit area by 11px on each side → effective **~40×40 CSS px** touch target. **Cite the 40px expanded hit-area, not 18px**, as the target-size evidence (above 24×24). UI-SPEC's "≥24×24 (near-threshold)" undersells it — the expanded target is comfortably ≥24.
- **Light/dark tokens:** trigger/panel all `var(--sg-color-*)`. **Zero raw hex.** PASS. (Minor: panel uses `--sg-weight-medium`=600 at line 921 — a pre-existing usage; UI-SPEC says "don't introduce medium for these components" but this is not a new introduction. Advisory only; leave unchanged.)
- **CONTEXT claim ("full states already, trigger hover/active/focus-visible ~:894–903"): ACCURATE** (exact line match).

### 5. `skeleton/1` — `sg-skeleton` + `::after` shimmer `[VERIFIED: components.ex:655-659, sigra_admin.css:1401-1425, 1467-1484]`
- HTML: `<div class="sg-skeleton {class}"></div>` (no inline motion).
- **Interaction-state:** N/A — visual placeholder; containing section carries `aria-busy="true"` (spec asserts skeleton itself never carries `aria-busy`: admin-design.spec.ts:649-650).
- **Motion:** `.sg-skeleton::after` (1408-1420) `animation: sg-skeleton-shimmer var(--sg-motion-slow) var(--sg-ease) infinite` + `@keyframes sg-skeleton-shimmer { to { transform: translateX(100%) } }` (1421-1425). Composite-safe (transform-only on `::after`). **Stripped under reduced-motion** by the global block (1467-1477): `*, *::before, *::after { animation-duration: 0.01ms !important; animation-iteration-count: 1 !important }` — the `*::after` selector covers the shimmer pseudo-element. **Proven by `admin-design.spec.ts:653-677`** (emulates `reducedMotion: 'reduce'`, reads `::after` computed style, asserts `animationName === 'none' || maxDurationMs <= 1` AND every `iterationCount === '1'`).
- **Target-size:** N/A.
- **Light/dark tokens:** `background: color-mix(in oklab, var(--sg-color-line) 60%, transparent)`; gradient uses `var(--sg-color-panel)`. **Zero raw hex.** PASS.
- **CONTEXT claim ("infinite shimmer ~:1419 stripped by global block ~:1467; passing assertion ~:653–677"): ACCURATE** (exact line match).

**Audit verdict:** ZERO genuine CSS gaps across all 5 components. CONTEXT's "expected: minimal — most state CSS already exists" is confirmed as **none needed**. The phase is cite-and-flip; if 207-02 lands no CSS edit, **no board PNG changes** and the recapture step (D-09) is a no-op verification.

## COMP-03 Token Layer — Net-New Work (the substance of this phase)

### D-06: Token-completeness guard (LOW risk, HIGH value — build it)

**Current state (verified):**
- CSS `:root` token defs: **100 unique `--sg-*` tokens** across **2 `:root` blocks** (light at `sigra_admin.css:20`, dark inside `@media (prefers-color-scheme: dark)` at `:176`). 127 total def-lines (27 tokens redefined in dark). `[VERIFIED: awk extraction over template]`
- Doc backtick tokens in `admin-token-reference.md`: **100 unique `` `--sg-*` `` tokens.** `[VERIFIED: grep over doc]`
- **`comm` diff: ZERO divergence** — every `:root` token is documented; every documented token exists in `:root`. The completeness guard **would exit 0 today.**
- **CORRECTION to CONTEXT/todo:** both claim "96/96". The actual current count is **100/100**. `admin-token-reference.md:3` does NOT contain a literal "96/96" string — it says "every `--sg-*` custom property in the `:root` layer" with no number. The "96" is a stale paraphrase from the 2026-06-18 todo. The refreshed doc (COMP-03 criterion 2) should either cite the guard (self-enforcing, no number) or state the verified count 100.

**Recommended guard shape (`scripts/ci/admin-token-completeness.sh` + `.test.sh`):**
```bash
# Sibling of admin-css-conformance.sh. Two sorted sets, diff, fail on divergence.
# Set A: tokens defined in :root  (reuse the proven awk :root tracker, INVERTED to emit
#         in-root lines, then: grep -oE '^\s*--sg-[a-z0-9-]+\s*:' | grep -oE -- '--sg-[a-z0-9-]+' | sort -u)
# Set B: tokens documented in backticks in admin-token-reference.md
#         (grep -oE '`--sg-[a-z0-9-]+`' DOC | tr -d '`' | sort -u)
# comm -23 A B  -> "in CSS but undocumented" (fail)
# comm -13 A B  -> "documented but not in CSS" (fail, stale doc row)
```
Self-test (`.test.sh`, mirroring the existing one): hermetic mktemp fixtures — (1) matched sets → exit 0; (2) CSS token missing from doc → exit 1; (3) doc token absent from CSS → exit 1; (4) dual light/dark `:root` both scanned → exit 0; (5) no real-repo side effects.

### D-07: Raw-px extension (HIGH noise risk — recommend narrow scope or D-07a fallback)

**Noise measurement (verified):** A naive "any `Npx` outside `:root`" sweep flags **38 occurrences**, of which essentially **all are legitimate CSS idioms that should NOT be tokenized:**

| Idiom | Example (line) | Count (approx) | Tokenize? |
|-------|----------------|----------------|-----------|
| Media-query breakpoints | `@media (min-width: 1024px)` (301, 589, 594, 684), `(max-width: 640px)` (1432) | 5 | No — breakpoints aren't design tokens |
| Hairline / accent borders | `1px solid` (437, 775), `2px solid` (357), `3px solid` (805) | ~8 | No — 1px is a sub-token primitive |
| Box-shadow offset/blur/spread | `0 12px 24px -18px var(--…)` (467, 472, 477), `inset 0 0 0 1px` (340, 352, 713, 721, 858, 946), `inset 3px 0 0 0` (999, 1010, 1021, 1032) | ~14 | No — shadow geometry, not a color/size token |
| Micro transform nudges | `translateY(-1px)` (534, 561, 715, 1386) | 4 | No — sub-pixel motion idiom |
| Pill radius | `border-radius: 999px` (881) | 1 | No — idiomatic pill |
| Visually-hidden clip | `1px`/`-1px`/`width:1px;height:1px` (1210-1212, 1450-1453) | ~6 | No — a11y clip pattern |

**Assessment:** an aggressive px guard is ~100% false-positive. There is no actual COMP-03 violation hiding in these 38 — they are all `box-shadow`, `border`, `@media`, `transform`, `clip`, and `border-radius` contexts, not raw font-sizes or spacing that bypass the `--sg-space-*`/`--sg-text-*` token scales. One borderline case: `font-size: 1.5rem` (1439) is a raw *rem* (not px) at a mobile breakpoint — a candidate for `--sg-text-*` tokenization but out of D-07's "px" scope and pre-existing.

**Recommendation (Claude's discretion D-07/D-07a):** Do **NOT** ship a blanket px guard. Two viable paths:
1. **Narrow automated (preferred if cheap):** restrict the px check to property contexts where a token IS expected — e.g. `font-size:`, `gap:`, `padding:`/`margin:` shorthand values, `width:`/`height:` of non-clip elements — and explicitly skip `box-shadow`, `border`, `border-radius`, `transform`, `@media`, and `clip`. Pair with a short inline allowlist of intentional exceptions. This catches a *future* raw `padding: 12px` while staying quiet today (current file has zero such violations in those contexts).
2. **D-07a documented manual review (acceptable fallback):** if the narrow regex proves fiddly within one phase, document raw-px conformance as a manual review (like the existing target-size "documented-as-manual" proxy) and make the **D-06 completeness guard the load-bearing automated COMP-03 proof.** CONTEXT explicitly authorizes this.

Decide during execution based on how clean the narrow regex comes out. Either way, COMP-03 is automatable via D-06 alone; D-07 is the bonus, not the gate.

## Common Pitfalls

### Pitfall 1: Decorated tier cell breaks the monotonic guard silently
**What goes wrong:** Writing `2*` or `2 ✓` in the ledger tier column.
**Why:** `quality-ledger-monotonic.sh` parses `awk -F'|'`, takes col 4, and only accepts `tier ~ /^[012]$/`. A decorated value fails the regex → the row is dropped from `HEAD_TIERS`, losing regression protection (and the guard still exits 0, hiding it).
**How to avoid:** Bare integer `2` only. `[VERIFIED: quality-ledger-monotonic.sh:23-27]`
**Warning signs:** Cell count printed by the guard drops below the expected total.

### Pitfall 2: Editing only the source CSS, forgetting the 2 generated copies
**What goes wrong:** Edit `priv/templates/.../sigra_admin.css` but not `test/example/priv/static/assets/sigra_admin.css` and `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`.
**Why:** golden_diff_test (`@moduletag :golden`) regenerates install output and byte-diffs vs the fixture; the booted example serves its own copy for Playwright. Divergence → golden/install/Playwright failures.
**How to avoid:** Edit the template, then copy byte-for-byte to both generated paths in the same commit. All 3 currently share md5 `7e60bc4c302d496d98f270ccba7d1766`. Regenerate fixture via `mix test test/sigra/install/golden_diff_test.exs --only snapshot` then commit the tree if structure changed. `[VERIFIED: diff -q all 3 identical; golden_diff_test.exs:118-129]`
**Warning signs:** `golden_diff_test` byte mismatch; example board renders unstyled (the Phase 184/185 CSS-split lesson) or stale (the Phase 190 JS-bundle-drift lesson).

### Pitfall 3: Aggressive raw-px guard floods CI with false positives
**What goes wrong:** A "no px anywhere outside `:root`" check fires on 38 legitimate borders/shadows/breakpoints.
**Why:** px is the correct unit for hairlines, shadow geometry, breakpoints, and clip patterns — none are design tokens.
**How to avoid:** Scope the px check to token-eligible contexts only, or use the D-07a manual-review fallback. `[VERIFIED: 38-occurrence sweep over template]`
**Warning signs:** Guard fails on the current clean file with a wall of border/shadow lines.

### Pitfall 4: Recapturing PNGs that didn't need to change (canary collateral)
**What goes wrong:** Running `--update-snapshots` broadly re-records unaffected boards, including the `board-notice` canary.
**Why:** D-09 requires both canaries byte-stable and both allowlists empty at close; the recapture gate's `snapshot-canary-guard.sh --canary board-notice --require-all` fails if an un-allowed slug changed OR an allowed slug didn't.
**How to avoid:** Only recapture genuinely-affected slugs; restore any incidental PNGs; add slugs to `snapshot-allowlist-design` only during the recording PR and clear before close. **Slug naming gotcha:** allowlist slugs use HYPHENS — `board-field_help` (board id) → `board-field-help` (PNG slug); copy the slug from the committed PNG filename, not from `COMPONENT_BOARDS`. `[VERIFIED: snapshot-allowlist-design comment block; snapshot-recapture-gate.sh:88-95]`
**Warning signs:** `snapshot-canary-guard: FAIL` naming `board-notice` or an unlisted slug.

### Pitfall 5: phx_new archive version mismatch fails golden tests locally
**What goes wrong:** A newer phx_new archive (e.g. 1.8.8) injects extra config and produces a spurious golden byte-diff.
**Why:** CI pins phx_new 1.8.7 (SEED-004).
**How to avoid:** `mix archive.install --force hex phx_new 1.8.7` before running install/golden tests. Do NOT regenerate the fixture to "fix" it. `[CITED: CLAUDE.md local-dev section]`

## Code Examples

### Reuse the proven `:root`-tracking awk for the D-06 token extraction
```bash
# Source: scripts/ci/admin-css-conformance.sh:90-145 (CHECK 2 awk) — INVERT emit logic
# (emit=1 when in_root) to collect token-definition lines instead of suppressing them.
awk '
BEGIN { in_root=0; root_entry_depth=0; brace_depth=0 }
{ line=$0; emit=0
  if (in_root) { n=split(line,c,""); for(i=1;i<=n;i++){if(c[i]=="{")brace_depth++; if(c[i]=="}"){brace_depth--; if(brace_depth<root_entry_depth)in_root=0}}; emit=1 }
  else if (line ~ /:root[[:space:]]*\{/) { in_root=1; root_entry_depth=brace_depth+1
    n=split(line,c,""); for(i=1;i<=n;i++){if(c[i]=="{")brace_depth++; if(c[i]=="}")brace_depth--}; emit=0 }
  else { n=split(line,c,""); for(i=1;i<=n;i++){if(c[i]=="{")brace_depth++; if(c[i]=="}")brace_depth--}; emit=0 }
  if(emit) print line }' "$CSS_FILE" \
  | grep -oE '^[[:space:]]*--sg-[a-z0-9-]+[[:space:]]*:' | grep -oE -- '--sg-[a-z0-9-]+' | sort -u
```

### Ledger evidence-string template (mirror Wave-A rows 61-63, bare `2`)
```
| empty_state | L1 | 2 | admin-design.spec.ts assertBoardScreenshot board-empty_state — 3 projects (admin-design-chromium / -mobile / -dark) × toHaveScreenshot + assertNoAxeViolations (wcag2a/2aa/21a/21aa/22aa) — 0 violations; motion-tokens: guarded — scripts/ci/admin-css-conformance.sh exits 0; no transition: all; inherits global @media (prefers-reduced-motion: reduce) strip at sigra_admin.css:~1467; target-size: N/A — static display container; token-conformance: admin-css-conformance.sh exits 0 (no raw hex outside :root) + admin-token-completeness.sh exits 0 (100/100 :root tokens documented); interaction-state: N/A — static; content-equivalence: N/A; overlay-axe: N/A; APG: N/A |
```
(For `token-layer` L0 row: lead with `admin-token-completeness.sh exits 0 — 100/100 :root --sg-* tokens documented in admin-token-reference.md` + the hex/px conformance citation; target-size/interaction-state N/A.)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Human reviews Playwright HTML report before committing baselines | `snapshot-recapture-gate.sh` all-green == approval (zero-human) | Phase 158+ | This phase recaptures with no human UAT |
| Manual ledger tier review | `quality-ledger-monotonic.sh` forward-only `awk -F'|'` guard | Phase 185 | Bare-`2` contract is load-bearing |
| Hex-only CSS conformance | hex + (this phase) px conformance + token-completeness | Phase 206 → 207 | COMP-03 becomes self-enforcing |

**Deprecated/outdated:**
- The "96/96" token count (CONTEXT, todo, and any doc prose): superseded by the **verified 100/100**.
- IA-diagnostic "feeds 207" page tags: stale v1.41 numbering → route to **Phase 209** (D-01).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The narrow-scoped D-07 px regex (skip border/shadow/breakpoint/transform/clip) can be made clean within one phase; else D-07a fallback | COMP-03 / D-07 | Low — CONTEXT pre-authorizes the D-07a manual-review fallback; D-06 carries COMP-03 regardless |
| A2 | No new `board-*` PNG baselines change (because the audit found zero CSS gaps) | Snapshot discipline | Low — if a tiny fix does land, recapture only that slug; gate enforces correctness |
| A3 | `--sg-weight-medium` (600) on the field_help panel is acceptable pre-existing usage, not something this phase must remove | field_help audit | Low — UI-SPEC note is about *introducing* medium on these components; panel copy predates this phase |

*All other findings are [VERIFIED] against source or [CITED] from project docs.*

## Open Questions

1. **Does the served example asset (build-free bundle) differ from `test/example/priv/static/assets/sigra_admin.css`?**
   - What we know: the example is `--no-tailwind` build-free; memory notes a JS-bundle-drift hazard (Phase 190) where the served `app.js` lagged source unless hand-propagated.
   - What's unclear: whether `sigra_admin.css` is served directly (it lives under `priv/static/assets/`, so likely yes) or rebundled.
   - Recommendation: if any CSS edit lands, boot the example and run the live `admin-design.spec.ts` (compile-time PORT/PG caveats per memory) to confirm the served board renders the change — do not trust the static copy alone. If no CSS edit lands, moot.

2. **Will a tiny field_help target-size note (40px expanded hit-area) prompt the planner to add a state-variant board?**
   - What we know: D-04 says add a board only on a genuine gap; none found.
   - Recommendation: no new board; cite the existing `board-field_help` axe gate + the `::before` hit-area math in the ledger evidence.

## Environment Availability

> This phase's automated gates run static analysis (bash guards over CSS/markdown) + Playwright over the booted example. The bash guards need no services. The recapture gate needs the example app + Postgres.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash + awk + grep + comm | D-06/D-07 guards, monotonic guard | ✓ (used in this research) | system | — |
| Node + Playwright | axe + screenshot recapture (only if CSS changes) | assumed ✓ (existing lane) | repo-pinned | recapture is a no-op if no CSS edit |
| Postgres (test) | booting example for Playwright recapture | per CLAUDE.md (scripts/db/up.sh) | 15+ | disposable-PG fallback (memory) |
| phx_new archive | golden_diff/install tests (only if CSS/template structure changes) | must pin 1.8.7 | 1.8.7 (SEED-004) | `mix archive.install --force hex phx_new 1.8.7` |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** Postgres saturation → disposable-PG; phx_new version → pin 1.8.7.

## Validation Architecture

> nyquist_validation is ENABLED (`.planning/config.json: nyquist_validation: true`). Every success criterion maps to an automated, zero-human gate.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Playwright (admin-design lane) + bash CI guards + ExUnit (golden/component) |
| Config file | `test/example/priv/playwright/playwright.config.*` (projects: admin-design-chromium/-mobile/-dark) |
| Quick run command | `bash scripts/ci/admin-css-conformance.sh && bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` |
| Full suite command | `bash scripts/ci/snapshot-recapture-gate.sh <affected-slug…>` (boots example, 3 projects, goldens) |

### Success Criterion → Automated Proof Map
| # | Success Criterion | Concrete Automated Proof |
|---|-------------------|--------------------------|
| 1 | 5 components axe-clean across chromium/mobile/dark; no `transition: all`; reduced-motion respected | `admin-design.spec.ts` → `assertBoardScreenshot('board-{empty_state,page_back,scope_ribbon,field_help,skeleton}')` runs `assertNoAxeViolations` (wcag2a/2aa/21a/21aa/22aa, lines 55-69) + `toHaveScreenshot` × 3 projects (77-93); skeleton reduced-motion assertion (653-677); field_help Escape+focus-restore (695-711); motion guard `admin-css-conformance.sh` CHECK 1 (no `transition: all`) |
| 2 | L0 token conformance (no raw hex/px outside `--sg-*`; light/dark/system parity); `admin-token-reference.md` cites evidence | `admin-css-conformance.sh` CHECK 2 (no raw hex outside `:root`) **+ NEW** `admin-token-completeness.sh` (100/100 `:root` tokens == doc backticks) **+ NEW** narrow D-07 px check OR documented D-07a manual review; doc refreshed to cite both guards |
| 3 | 5 component rows + `token-layer` row flipped to bare `2`; monotonic guard exits 0 | `quality-ledger-monotonic.sh --base origin/main` exits 0 (`awk -F'|'` col-4 bare-integer parse; 36 cells at baseline) |
| 4 | All 13 L1 cells + L0 cell read `2` | Same monotonic guard + visual ledger inspection; entire L0/L1 column == `2` |

### Sampling Rate
- **Per task commit:** `admin-css-conformance.sh` + `admin-token-completeness.sh` + `quality-ledger-monotonic.sh --base origin/main` (all sub-second static checks).
- **Per recapture (only if CSS edits land):** `snapshot-recapture-gate.sh <slug>` (boots example, 3 projects, goldens, canary guard).
- **Phase gate:** all guards exit 0; both allowlists empty; canaries byte-stable; full L0/L1 ledger column reads `2`.

### Wave 0 Gaps
- [ ] `scripts/ci/admin-token-completeness.sh` — NEW, covers COMP-03 criterion 2 (D-06). Build in 207-01.
- [ ] `scripts/ci/admin-token-completeness.test.sh` — NEW hermetic self-test (mirrors `admin-css-conformance.test.sh`).
- [ ] (optional) raw-px extension to `admin-css-conformance.sh` (D-07) OR a documented manual-review note in `admin-token-reference.md` (D-07a).
- *Everything else (axe harness, screenshot lane, motion/hex guard, monotonic guard, recapture gate, golden/component tests) already exists and is green — no Wave 0 work.*

## Security Domain

> `security_enforcement` is not set in `.planning/config.json` (absent = enabled). However, Phase 207 ships **no auth-path, input-handling, crypto, session, or access-control code** — it edits admin CSS tokens, 5 display/help/loading components, CI guard scripts, a markdown doc, and the ledger. No user-facing data flows, no untrusted input, no secrets.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no auth code touched) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — (no user input; guard scripts read repo files only) |
| V6 Cryptography | no | — |
| V12/V14 Build & Config | minor | CI guard scripts use `set -euo pipefail`, hermetic mktemp fixtures, no network/eval; follow the proven `admin-css-conformance.sh` shape |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Bash guard injection via crafted filename arg | Tampering | Quote all expansions; positional/`--flag` arg only; no `eval`; mirror existing guard (already does this) |
| Doc/CSS drift hiding a real token regression | Repudiation | D-06 completeness guard makes the "all tokens documented" claim self-enforcing |

**No threat model expansion required** — this is a design-system/CI hygiene phase with no security-sensitive surface.

## Sources

### Primary (HIGH confidence — verified via file read / command this session)
- `lib/sigra/admin/components.ex:410-717` — all 5 component defs `[VERIFIED]`
- `priv/templates/sigra.install/admin/sigra_admin.css` — 437-513 (btn), 546-568/1086-1096 (empty_state/scope_ribbon), 866-932 (field_help), 1401-1425/1467-1484 (skeleton + reduced-motion), 20/176 (`:root` blocks), 123-143 (motion/transition tokens) `[VERIFIED]`
- `test/example/priv/playwright/tests/admin-design.spec.ts:55-103, 585-725` — axe helper, COMPONENT_BOARDS, state assertions `[VERIFIED]`
- `scripts/ci/admin-css-conformance.sh` (+ `.test.sh`) — full read; awk `:root` tracker `[VERIFIED]`
- `scripts/ci/quality-ledger-monotonic.sh:23-27` — `awk -F'|'` bare-integer parse contract `[VERIFIED]`
- `scripts/ci/snapshot-recapture-gate.sh` + `snapshot-canary-guard.sh` + both allowlist files — recapture/canary discipline `[VERIFIED]`
- `guides/reference/admin-quality-ledger.md:58-72` — 6 target rows + Wave-A exemplar (61-63) `[VERIFIED]`
- `guides/reference/admin-token-reference.md:3-39` — doc structure + backtick tokens `[VERIFIED]`
- Commands run: 100/100 token diff (`comm`), 38-occurrence raw-px sweep, 3-copy md5 byte-coherence, both guards green vs origin/main `[VERIFIED]`

### Secondary (HIGH — project planning docs)
- `.planning/phases/207-…/207-CONTEXT.md`, `207-UI-SPEC.md` — locked decisions, design contract `[CITED]`
- `.planning/phases/206-…/206-0{1,2,4}-SUMMARY.md` — the proven Wave-A method `[CITED]`
- `.planning/ROADMAP.md:95-140` — Phase 207-209 authoritative scope `[CITED]`
- `.planning/todos/pending/2026-06-18-token-reference-completeness-ci-guard.md` — folded D-06 `[CITED]`
- `CLAUDE.md` (local-dev, phx_new 1.8.7 pin) `[CITED]`

## Metadata

**Confidence breakdown:**
- Per-component audit: HIGH — every claim verified against current source line-by-line.
- COMP-03 token guards: HIGH — 100/100 diff and 38-occurrence px sweep both run this session.
- Snapshot/ledger discipline: HIGH — all scripts and allowlists read in full; guards confirmed green at baseline.
- D-07 automated-vs-manual decision: MEDIUM — depends on how clean the narrow regex comes out in execution; D-07a fallback is pre-authorized.

**Research date:** 2026-06-28
**Valid until:** 2026-07-28 (stable — internal CSS/CI; only risk is line drift from intervening commits)
