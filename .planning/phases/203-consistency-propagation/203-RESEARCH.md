# Phase 203: Consistency Propagation - Research

**Researched:** 2026-06-26
**Domain:** Internal Sigra admin-UI propagation (Phoenix LiveView + `sg-*` design system + Playwright/ExUnit/CI-gate validation)
**Confidence:** HIGH — every CONTEXT.md line-number citation and contract was verified against live source this session.

<user_constraints>
## User Constraints (from CONTEXT.md)

> The Phase 203 CONTEXT.md (D-01..D-12, canonical refs) is plan-ready. This research does NOT re-derive its decisions — it verifies the cited contracts still hold and translates them into planning-ready validation requirements. Copy the decisions verbatim into plans.

### Locked Decisions

**Overviews — component-level alignment to 201 reductions (PROP-01):**
- **D-01 (light pass, NOT recomposition):** Both Overviews already emit the canonical archetype (`index_live.ex:38-75`, `organization_live.ex:48-87` vs `admin-design-contract.md:178-195`). Do NOT restructure composition — change only the component-level divergences below.
- **D-02 (align org roster pills to 201's reduced vocabulary — USER-RATIFIED):** Drop the org roster's always-present green `Confirmed`/`ok` pill (`organization_live.ex:102-106`) that Phase 201 removed (201 D-04; contract `:276`). Reduce to only decision-bearing pills.
- **D-03 (re-evaluate the global "Authentication coverage" chip — USER-RATIFIED):** Re-evaluate the global overview's MFA/passkey coverage chip (`index_live.ex:113-122`) against 201's "demote non-decision-bearing coverage KPIs" decision (201 D-03). Demote/slim per the 201 precedent.
- **D-04 (reuse the shared primitives — same-job → same-component):** Both pages route through shared `summary_chip`/`task_card`/`notice`/`scope_ribbon` (`components.ex:110,166,462,506`). Keep them; do not hand-roll. `users_index_live.ex` privates `user_status_cluster`/`user_name_stack` (`:369,384`) are NOT in `components.ex` — promote only if the org roster genuinely reuses the same pill logic (DRY-driven).

**Branding workbench — full elevation (PROP-01) — USER-RATIFIED "Full" path:**
- **D-05 (route private preview components through `components.ex`):** Promote branding's private `color_field`/`preview_pair`/`detail_input` into `Sigra.Admin.Components` so the workbench obeys UI-principle `:29`. Keep `sg-branding-*`/`sg-tabs` classes; no net-new public components beyond what routing requires.
- **D-06 (add a real branding ConfirmDialog test — the honest-Tier-2 gate):** `branding_live.ex`'s `#restore-defaults-overlay` (`:349-378`) is NOT exercised by `admin-modal-interaction.spec.ts` today (it only opens `#user-session-confirm-overlay`). Add a branding modal-interaction test that opens `#restore-defaults-overlay` and asserts 7 APG gates + axe-clean while open. Prerequisite for the D-08 branding Tier-2 overlay-axe/APG claim.
- **D-07 (add a Branding/Workbench archetype to the design contract — PROP-02):** Contract has exactly four archetypes (Overview/List/Detail/Audit Explorer) and no Workbench block. Add one documenting the elevated composition (tab nav + disclosed panels + per-panel preview rail + ConfirmDialog restore-defaults).

**Ledger ratchet + PAGE-04 fold (PROP-01):**
- **D-08 (ratchet all three cells 1→2 — bare un-decorated integer):** Flip column-4 `1`→`2` for `index-live` (`:85`), `organization-live` (`:86`), `branding-live` (`:92`). Bare single `[012]` integer, no decorators. Expand Evidence to cite only honestly-applicable Tier-2 proxies, mirroring `users-index-live` (`:87`). Overviews → content-equivalence/overlay-axe/7-APG are **N/A**; applicable: glossary-clean, motion-tokens, density-rhythm, target-size. Branding → claims overlay-axe + 7 APG (earned by D-06) + glossary-clean/motion/density/target-size; content-equivalence is N/A. Do NOT fabricate inapplicable proxies.
- **D-09 (fold the PAGE-04 branding-scoring todo):** `resolves_phase: 203`; satisfied by the `branding-live` ratchet + expanded evidence (D-08). The todo's "no separate L3 row exists" premise is stale (the row exists at `:92`).

**Gallery / recapture (PROP-01):**
- **D-10 (recapture only what actually changes):** Primary targets are `global-overview` (`admin-checkpoints.spec.ts:193`) and `org-overview` (`:204`). Gallery analogs MG-3/MG-7/MG-8 recapture ONLY if their mirrored markup actually changes. No branding board/slug exists. Route recapture through `snapshot-recapture-gate.sh` (not canary guard); prove zero-drift idempotency; keep `board-notice`/`impersonation-banner` canaries byte-stable; **leave both allowlists empty** at end-of-phase (204 owns terminal reset).

**Docs / CSS lockstep (PROP-02):**
- **D-11 (UI principles touch-up + glossary):** Update `admin-ui-principles.md` for any evolved interaction pattern (branding routing D-05 / pill alignment D-02/D-03); keep microcopy glossary-clean. Overview archetype block gets a light touch-up iff roster pills change (D-02).
- **D-12 (CSS triple-copy lockstep — hard):** Any new/changed `sg-*` class MUST be byte-identical across all three copies (`priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`, `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`) or the install golden-diff fails (184→185 regression class). Pill-vocabulary reduction may need zero new CSS; only genuinely new affordances trip the gate.

### Claude's Discretion
- Exact reduced pill vocabulary for the org roster; whether the global coverage chip is fully removed vs slimmed/relocated (D-02/D-03) — as long as it matches 201 and renders identically across surfaces.
- Whether `user_status_cluster`/`user_name_stack` get promoted to `components.ex` or the org roster reuses a lighter shared path — DRY-driven (D-04).
- Shared component names / arg shapes for the promoted branding preview components (D-05).
- Exact archetype-block wording for the Branding/Workbench archetype (D-07); which UI-principles lines evolve (D-11).
- Microcopy wording (auto-guarded glossary-clean).

### Deferred Ideas (OUT OF SCOPE)
- Dedicated branding-preview route / net-new shared "roster row" LiveView / net-new public branding components beyond DRY needs — **ruled OUT** by "no net-new surfaces".
- Terminal ratification (allowlist reset to empty, monotonic guard final green, full-surface axe incl. overlays-open, generated-host parity, adversarial milestone review) — owned by **Phase 204**.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROP-01 | Lean Overviews (`index_live.ex`, `organization_live.ex`) + Branding workbench (`branding_live.ex`) match the elevated bar (same-job → same-component, no net-new surfaces); `/admin/_design` gallery + MG-1..MG-11 reflect elevated compositions. | Overview pills verified divergent (org `Confirmed` pill at `organization_live.ex:105`; global coverage chip at `index_live.ex:113-122`). Branding privates verified (`detail_input:493`, `color_field:547`, `preview_pair:579`). Gallery MG-7 verified to NOT mirror the org-roster status pills → likely no MG-7 recapture (see Pitfall 5). Shared primitives + promotion target verified in `components.ex`. |
| PROP-02 | Admin design contract + UI principles docs updated to document evolved archetypes/patterns (forward, never silently); one-term-per-concept glossary stays drift-guarded. | Contract verified to have exactly 4 archetypes (Overview `:172`, List `:211`, Detail `:284`, Audit Explorer `:331`) and NO Workbench block → D-07 gap is real. `glossary_test.exs` verified to already scope all 3 target pages → glossary-clean proxy is satisfiable. |
</phase_requirements>

## Summary

Phase 203 is the **propagation/repeat** phase of the v1.41 ADMIN-UX-ELEVATION arc. Phases 200–202 already established every mechanic this phase reuses: the reduced-pill vocabulary (201), the shared-component promotion pattern (200/202 moved privates into `components.ex`), the bare-integer ledger ratchet protected by the monotonic guard (199 D-03 / 201 D-09 / 202 D-11), the Tier-2 evidence/N-A citation template (`users-index-live` cell), and the `snapshot-recapture-gate.sh` zero-drift routing. There is **no novel technical domain** here — the risk is faithful repetition and not tripping the CI gates.

I verified every line-number and contract CONTEXT.md cites against live source this session. All hold: the org roster's always-on `Confirmed`/`ok` pill (`organization_live.ex:105`), the global coverage chip (`index_live.ex:113-122`), the three branding privates, the untested `#restore-defaults-overlay`, the four-archetype contract with no Workbench block, the three byte-identical CSS copies (shared md5 `9b281962…`), and the monotonic-guard's bare-`[012]` positional `awk -F'|'` parse. Two findings refine CONTEXT.md's "iff markup changes" guidance into concrete planning calls (see Pitfalls 5 and 6).

**Primary recommendation:** Plan as four work-streams mirroring the 200–202 wave shape — (W1) Overview pill alignment + CSS-lockstep check, (W2) branding component promotion + new modal-interaction test, (W3) docs (Workbench archetype + UI-principles touch-up), (W4) the three-cell ledger ratchet + recapture-gate idempotency. The D-06 branding modal test MUST land before the D-08 `branding-live` overlay-axe/APG evidence claim is written (hard dependency). The 202-VALIDATION.md Per-Task Verification Map is the exact template to mirror.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Overview/org roster status pills | Library LiveView (`lib/sigra/admin/live/*`) | Shared components (`components.ex`) | Pills render in lib-owned admin LiveViews; "same-job → same-component" means routing through `components.ex`. |
| Branding preview components | Library shared components (`components.ex`) | Library LiveView (`branding_live.ex`) | D-05 promotes privates from the LiveView into the shared module — the public-surface tier owns reusable markup. |
| ConfirmDialog APG behavior | Client hook (`admin_hooks.js` `ConfirmDialog`) | Library LiveView markup | Focus trap/restore/Escape are JS-hook concerns; the LiveView only emits the `phx-hook` + ARIA contract. Test lives in Playwright (browser tier). |
| `sg-*` CSS classes | Installer template (source of truth) | Example + golden mirrors | CSS ships installer-template → generated host; the three copies are byte-parity-gated (D-12). |
| Ledger tier cells | Docs (`admin-quality-ledger.md`) | CI gate (`quality-ledger-monotonic.sh`) | Tier ratchet is a doc edit; the merge-blocking guard parses column 4 positionally. |
| Visual baselines | Test fixtures (Playwright `*-snapshots/`) | CI gate (recapture/canary scripts) | PNG baselines live with the specs; recapture routed + drift-guarded by the CI scripts. |

## Standard Stack

No external packages are introduced or changed by this phase. This is internal `sg-*` design-system propagation. The relevant toolchain (all already present, all verified at the versions in `CLAUDE.md`):

| Tool | Role in this phase | Verified location |
|------|--------------------|-------------------|
| Phoenix LiveView + HEEx | Admin LiveViews + shared components | `lib/sigra/admin/live/*`, `lib/sigra/admin/components.ex` |
| ExUnit | Glossary drift guard | `test/sigra/admin/glossary_test.exs` (scopes all 3 target pages) |
| Playwright | Modal-interaction (D-06), checkpoints (recapture), design-gallery, theme/generated specs | `test/example/priv/playwright/tests/*` |
| Bash CI gates | monotonic ledger guard, recapture gate, canary guard, install golden-diff | `scripts/ci/*.sh`, `test/sigra/install/golden_diff_test.exs` |

**Installation:** None. No `mix.exs` change.

## Package Legitimacy Audit

> Not applicable — this phase installs no external packages. All work is internal Sigra admin-UI source, docs, tests, and CI-script edits.

## Architecture Patterns

### System Architecture Diagram

```
                     ┌─────────────────────────────────────────────────┐
   PROP-01 (UI)      │  lib/sigra/admin/live/index_live.ex (global)     │
   pill alignment ──▶│  lib/sigra/admin/live/organization_live.ex (org) │──┐
                     └─────────────────────────────────────────────────┘  │ render via
                     ┌─────────────────────────────────────────────────┐  │ shared
   branding full ───▶│  lib/sigra/admin/live/branding_live.ex           │──┤ primitives
   elevation        │   • promote color_field/preview_pair/detail_input │  │
   (D-05/D-06)      │   • #restore-defaults-overlay (ConfirmDialog)     │  ▼
                     └─────────────────────────────────────────────────┘  ┌──────────────────────┐
                                          │                                │ components.ex        │
                                          │ phx-hook="ConfirmDialog"       │ summary_chip/task_card│
                                          ▼                                │ notice/scope_ribbon   │
                     ┌─────────────────────────────────────────────────┐  │ + promoted preview    │
   D-06 test ───────▶│ admin-modal-interaction.spec.ts                  │  └──────────────────────┘
   (7 APG + axe)     │  (today: only #user-session-confirm-overlay)     │           │
                     │  ADD: #restore-defaults-overlay case             │           │ new/changed sg-* ?
                     └─────────────────────────────────────────────────┘           ▼
                                                                          ┌──────────────────────┐
   D-08 ratchet ────▶ admin-quality-ledger.md  cells :85 :86 :92  1→2     │ CSS triple-copy (D-12)│
   (bare int)        │   (Evidence: honest proxies, N/A where true)    │  │  installer == example │
                     └─────────────────┬───────────────────────────────┘  │  == golden  (md5 eq)  │
                                       │ awk -F'|' col4 ^[012]$            └──────────────────────┘
                                       ▼                                              │ golden-diff gate
                     ┌─────────────────────────────────────────────────┐             ▼
   merge gate ──────▶│ quality-ledger-monotonic.sh --base origin/main   │   test/sigra/install/
                     │   (forward-only; tier must not decrease)         │   golden_diff_test.exs
                     └─────────────────────────────────────────────────┘
   D-10 recapture ──▶ snapshot-recapture-gate.sh global-overview org-overview
                     │   (routes slugs per-lane; canaries byte-stable;  │
                     │    allowlists LEFT EMPTY for Phase 204)          │
                     └─────────────────────────────────────────────────┘
   PROP-02 docs ────▶ admin-design-contract.md (+Workbench archetype) · admin-ui-principles.md
                     │   glossary_test.exs stays green (drift guard)    │
                     └─────────────────────────────────────────────────┘
```

### Component Responsibilities

| File | Role | Phase action |
|------|------|--------------|
| `lib/sigra/admin/live/index_live.ex` | Global overview; coverage chip `:113-122` | D-03 demote/slim chip; recapture `global-overview` |
| `lib/sigra/admin/live/organization_live.ex` | Org overview; roster pills `:102-106` | D-02 drop `Confirmed`/`ok` pill `:105`; recapture `org-overview` |
| `lib/sigra/admin/live/branding_live.ex` | Branding workbench (732 lines); privates `:493/:547/:579`; overlay `:349-378` | D-05 promote privates; D-06 test target |
| `lib/sigra/admin/components.ex` | Shared primitives (`:110/:166/:462/:506`) | D-05 promotion destination |
| `lib/sigra/admin/live/users_index_live.ex` | 201 reduced-pill source-of-truth; `user_name_stack:369`, `user_status_cluster:384` | D-04 reference; promote only if DRY-driven |
| `guides/reference/admin-design-contract.md` | 4 archetypes, no Workbench | D-07 add Workbench archetype; D-11 Overview touch-up iff pills change |
| `guides/reference/admin-ui-principles.md` | same-job→same-component `:29`, no `transition: all` `:47` | D-11 evolve for routing/pill alignment |
| `guides/reference/admin-quality-ledger.md` | cells `:85/:86/:92`; template `:87` | D-08 ratchet 1→2 + expand evidence |
| `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts` | 7-APG + axe pattern (user-sessions only) | D-06 add branding case |
| three `sg-*` CSS copies | byte-identical (md5 `9b281962…`) | D-12 lockstep iff new class |

### Pattern 1: Bare-integer ledger ratchet protected by the monotonic guard
**What:** Column 4 of each ledger row is a single bare `[012]` integer (no `Tier 2`, no bold, no parens). The guard's positional `awk -F'|'` parse reads `$4`, trims whitespace, and only counts rows where the trimmed value matches `^[012]$`.
**When to use:** Every D-08 cell flip.
**Example:**
```
# guides/reference/admin-quality-ledger.md — verified current cell (branding-live, :92)
| branding-live | L3 | 1 | [admin-modal-interaction: …] |     # ← flip the bare `1` to bare `2`

# scripts/ci/quality-ledger-monotonic.sh extract (verified)
grep -E '^\| [a-z]' | awk -F'|' '{
  tier=$4; gsub(/^ +| +$/, "", tier)
  if (tier ~ /^[012]$/) print item ":" tier   # decorators silently drop the cell from the guard
}'
```
Run the gate forward-only: `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main`.

### Pattern 2: Tier-2 evidence with honest N/A citations (mirror `users-index-live`, ledger `:87`)
**What:** The Evidence column expands to cite ONLY proxies that apply to that surface; inapplicable proxies are cited explicitly as `N/A — <reason>`.
**When to use:** All three D-08 cells.
**Verified proxy applicability (from `admin-fractal-scorecard.md:135-167`):**
- `overlay-axe` + `7 APG focus-trap/restore gates` — "Surfaces that own a modal dialog are subject to this proxy." → **Branding YES** (owns `#restore-defaults-overlay`); **Overviews N/A** (no modal).
- `desktop↔mobile content-equivalence` — "Surfaces that include a results table with a mobile card fallback are subject." → **All three N/A** (no results table; org roster is a `sg-list`, not the desktop-table⇄mobile-card pattern).
- `glossary-clean` — always applicable (verified: `glossary_test.exs` scopes all 3 pages).
- `motion-tokens` / `density-rhythm` / `target-size` — documented-as-manual; applicable to all three.
**Example citation (Overviews):** mirror `:87` — `glossary-clean: glossary_test.exs scopes index_live/organization_live; motion-tokens: reviewed — no transition: all; density/rhythm: reviewed — sg-stack--N tiers; target-size: reviewed — …(documented-as-manual); content-equivalence: N/A — no results table; overlay-axe: N/A — owns no modal dialog; APG gates: N/A — no overlay`.

### Pattern 3: Shared-component promotion (200/202 precedent)
**What:** Move a private function-component out of a LiveView into `components.ex`, delete the private, update call-sites to `<.name …>`. 202 did exactly this (deleted private `audit_tone/1`/`multi_page?/1`/`format_timestamp/1`; now owned by `components.ex`). 200 introduced `user_name_stack`/`user_status_cluster` as DRY field-slices (still private — the D-04 candidate).
**When to use:** D-05 (branding privates), and D-04 only if the org roster genuinely reuses the reduced-pill logic.

### Pattern 4: ConfirmDialog 7-APG + axe-while-open test (mirror the user-sessions case)
**What:** The verified existing test (`admin-modal-interaction.spec.ts`) opens a trigger, then asserts: (1) overlay visible, (2) initial focus on `[data-sg-confirm-cancel]`, (3a/b/c/d) Tab/Shift+Tab containment + focus stays inside `.sg-confirm-dialog`, (6) `role="dialog"` + `aria-modal="true"` + `aria-labelledby`, (7) axe wcag2a+wcag2aa zero violations WHILE open, (4) Escape closes, (5) focus returns to trigger.
**D-06 adaptation:** the branding dialog uses the SAME contract — `phx-hook="ConfirmDialog"` (`:349`), `data-sg-confirm-cancel` (`:364`), `aria-labelledby="restore-defaults-title"` (`:354`). The new case must (a) navigate to `/admin/branding` as an admin, (b) trigger `open_restore_defaults` (the "Restore config defaults" button at `:340`), (c) assert overlay `#restore-defaults-overlay` visible, (d) assert `aria-labelledby` equals `"restore-defaults-title"` (NOT the user-sessions value), (e) run the same 7 gates. No screenshots.

### Anti-Patterns to Avoid
- **Decorated ledger tier cells** — `Tier 2`, `**2**`, `2 (earned)` all fail the bare-`^[012]$` regex and silently drop the cell from the monotonic guard (it would no longer be protected forward-only). Use a bare `2`.
- **Fabricating an inapplicable Tier-2 proxy** — claiming content-equivalence or overlay-axe on an Overview that owns neither a results table nor a modal. Phase 204's adversarial review fails false claims (CONTEXT.md D-08).
- **Recapturing baselines before proving idempotency** — bake new PNGs only after a zero-drift run; route through `snapshot-recapture-gate.sh`, never the canary guard directly.
- **Touching one CSS copy** — any `sg-*` edit must hit all three byte-identically or the golden-diff fails and generated hosts get an unstyled page.
- **Leaving an allowlist non-empty at phase end** — Phase 204 owns the terminal reset; this phase ends with both snapshot allowlists empty.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Org roster status pills | A bespoke pill cluster on the org overview | The reduced-pill logic from `users_index_live.ex` (`user_status_cluster:384`) — promote to `components.ex` only if DRY-driven (D-04) | Same-job → same-component; the status signal must render identically across surfaces |
| Branding preview rows | More private components inside `branding_live.ex` | Promote `color_field`/`preview_pair`/`detail_input` to `components.ex` (D-05) | UI-principle `:29`; reusable markup routes through `components.ex` |
| ConfirmDialog focus/Escape behavior | New JS in the branding test | Existing `phx-hook="ConfirmDialog"` (already wired on the branding overlay) | The dialog is already capable of passing — only the test is missing |
| Tier-2 evidence wording | Inventing a new evidence format | The `users-index-live` cell template (ledger `:87`) | Keeps the Evidence column consistent and the N/A citations honest |
| Recapture routing | Manual `--update-snapshots` + hand-restoring canaries | `snapshot-recapture-gate.sh <slug>…` | It routes each slug to the owning lane and re-asserts canary byte-stability |

**Key insight:** Everything this phase needs already exists in 200–202's shipped patterns. The failure mode is reinvention, not missing tooling.

## Common Pitfalls

### Pitfall 1: Monotonic-guard bare-integer requirement
**What goes wrong:** A decorated tier cell (`Tier 2`, bold, parens) is silently dropped by the guard's `^[012]$` filter — the cell is no longer protected forward-only and a later PR could quietly downgrade it.
**Why it happens:** The guard is a positional `awk -F'|'` parse of column 4, not a markdown parser (verified `quality-ledger-monotonic.sh:22-27`).
**How to avoid:** Flip to a bare single `2`. Verify: `git show origin/main:guides/reference/admin-quality-ledger.md | grep '^| \(index-live\|organization-live\|branding-live\)'` then `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` (expect PASS, N cells checked).
**Warning signs:** Guard prints fewer cells checked than expected; a cell stops appearing in the guard output.

### Pitfall 2: Compile-time PORT/PG gotcha when booting test/example Playwright
**What goes wrong:** The D-06 modal test (and any local recapture) needs a booted `test/example`; `mix phx.server` with the wrong port frozen into `_build` aborts on `validate_compile_env` before it can recompile.
**Why it happens:** `Example.Organizations` reads `compile_env!` on the endpoint, freezing `http.port` into a compile-time invariant (documented in MEMORY: host-run --dev compile-env port; quick task `260621-in8b`).
**How to avoid:** Set `SIGRA_EXAMPLE_URL=http://localhost:4011` for Playwright (default 4000 collides with Rulestead Docker — Phase 191 decision). For host-run, let `scripts/uat/up.sh --dev` self-heal (it wipes the stale example build on frozen-port mismatch). For a disposable test DB, use `scripts/db/up.sh` + `direnv allow`.
**Warning signs:** `mix phx.server` exits with a `validate_compile_env` mismatch; Playwright connects to the wrong app.

### Pitfall 3: CSS triple-copy md5 parity (the 184→185 regression class)
**What goes wrong:** A new `sg-*` class added to one copy but not all three fails `golden_diff_test.exs`; generated hosts render unstyled.
**Why it happens:** Admin CSS ships installer-template → generated host; the three copies are byte-parity-gated.
**How to avoid:** First decide whether the change needs new CSS at all — pill-vocabulary reduction (D-02/D-03) typically reuses existing classes and needs ZERO new CSS (CONTEXT.md D-12). If a genuinely new affordance is introduced (e.g. promoted branding preview markup), write it byte-identically into all three: `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`, `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`. Verify parity: `md5 -q <three paths>` must print one identical hash three times (currently `9b281962ee8fe33254829c877af00382`). Requires phx_new 1.8.7 installed for golden-diff to pass locally (`mix archive.install --force hex phx_new 1.8.7`).
**Warning signs:** `golden_diff_test` fails; the three md5s diverge.

### Pitfall 4: D-06 test wiring — branding-specific selectors, not user-sessions selectors
**What goes wrong:** Copying the user-sessions test verbatim asserts `#user-session-confirm-overlay` / `aria-labelledby="user-session-confirm-title"`, which the branding dialog does NOT use.
**Why it happens:** The two dialogs share the hook contract but have distinct IDs/labels (verified: branding uses `#restore-defaults-overlay` `:349` and `restore-defaults-title` `:354`).
**How to avoid:** Parameterize the new case on the branding IDs. The trigger is the "Restore config defaults" button (`phx-click="open_restore_defaults"`, `:340`); the cancel is `phx-click="cancel_restore_defaults"` + `data-sg-confirm-cancel` (`:363-364`); the confirm is `phx-click="restore_config_defaults"` (`:371`). Initial-focus and tab-containment assertions can keep the `[data-sg-confirm-cancel]` and `.sg-confirm-dialog button:first/last-of-type` selectors (identical contract). Admin auth: the spec already shows the `platform-admin+…@example.test` email pattern grants platform-admin.
**Warning signs:** Test times out waiting for `#user-session-confirm-overlay`; `aria-labelledby` assertion fails.

### Pitfall 5: MG-7 board does NOT mirror the org-roster status pills → likely no MG-7 recapture
**What goes wrong:** Assuming the D-02 org-roster pill change requires recapturing the MG-7 gallery board, churning a baseline unnecessarily.
**Why it happens:** CONTEXT.md says "recapture MG-7 iff mirrored markup changes." I verified the actual MG-7 markup (`design_gallery_live.ex:935-961`): it renders a member row with ONLY a role pill (`data-tone="info">Owner`) and "Joined …" — it does NOT carry the `Confirmed`/`Unconfirmed`/`Locked`/`Deletion scheduled` pills that `organization_live.ex:102-106` does. The D-02 change (dropping `Confirmed`) therefore does NOT alter MG-7's markup.
**How to avoid:** Plan to recapture only `global-overview` + `org-overview` checkpoint slugs (D-10 primary targets). Treat MG-3/MG-7/MG-8 recapture as a verify-then-skip step: confirm their markup is unchanged (it should be), and DO NOT bake new MG baselines. If a planner adds an MG recapture task, gate it behind an explicit "markup actually changed" check.
**Warning signs:** A recapture diff shows MG-7/MG-8 PNG changes when only Overview pills were touched — that signals an unintended shared-class side effect, investigate before baking.

### Pitfall 6: The `branding-live` ledger cell ALREADY links admin-modal-interaction — but the test doesn't exist yet (D-06 is the prerequisite)
**What goes wrong:** Writing the D-08 `branding-live` Tier-2 evidence (overlay-axe + 7 APG) before the D-06 test exists makes the cell cite a non-existent assertion — a false Tier-2 claim.
**Why it happens:** The current `branding-live` cell (`:92`) already contains the link text `[admin-modal-interaction: ConfirmDialog APG gates + axe-while-open]`, but I verified `admin-modal-interaction.spec.ts` only opens `#user-session-confirm-overlay` — the branding dialog is NOT exercised today. So the existing link is aspirational/misleading at Tier 1.
**How to avoid:** Hard ordering — land the D-06 branding modal case FIRST (it must pass the 7 gates + axe), THEN write the D-08 `branding-live` evidence expansion that cites it. The D-06 test is a true prerequisite for the D-08 branding ratchet, not parallel work.
**Warning signs:** The `branding-live` evidence cites APG gates while `admin-modal-interaction.spec.ts` contains no `#restore-defaults-overlay` reference.

### Pitfall 7: Leaving allowlists non-empty / canaries un-restored
**What goes wrong:** The phase ends with a snapshot allowlist still populated, breaking Phase 204's terminal reset premise, or a canary (`board-notice`/`impersonation-banner`) accidentally modified.
**Why it happens:** Recapture flows temporarily populate allowlists; forgetting to reset them is the 183/197 precedent failure mode.
**How to avoid:** End-of-phase, both allowlists empty (CONTEXT.md D-10); canaries byte-stable. The canary guard forbids modify/delete of an established canary (`snapshot-canary-guard.sh:104`).
**Warning signs:** `git diff` shows a non-empty allowlist or a canary PNG change at phase close.

## Runtime State Inventory

> N/A for the rename/refactor sense — this is not a rename phase. The closest analog is "stored visual baselines + ledger doc state", covered below for completeness.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB/datastore keys change | None |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | `SIGRA_EXAMPLE_URL=http://localhost:4011` for local Playwright (env only; no secret) | Set when booting example for D-06 test / recapture |
| Build artifacts | `test/example` `_build` can freeze a stale compile-env port (Pitfall 2); Playwright `*-snapshots/` PNG baselines for `global-overview`/`org-overview` | Wipe stale example build on port mismatch; recapture 2 checkpoint slugs via the gate |

## Code Examples

### Verify the three target ledger cells against origin/main before ratcheting
```bash
# Source: scripts/ci/quality-ledger-monotonic.sh (verified this session)
git fetch origin main
git show origin/main:guides/reference/admin-quality-ledger.md \
  | grep -E '^\| (index-live|organization-live|branding-live) '
bash scripts/ci/quality-ledger-monotonic.sh --base origin/main   # expect PASS
```

### Confirm CSS triple-copy byte parity
```bash
# Source: CLAUDE.md D-12 contract (verified md5 equal this session)
md5 -q priv/templates/sigra.install/admin/sigra_admin.css \
       test/example/priv/static/assets/sigra_admin.css \
       test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
# → three identical hashes (currently 9b281962ee8fe33254829c877af00382)
```

### Dry-run the recapture-gate slug routing (no Playwright/mix run)
```bash
# Source: scripts/ci/snapshot-recapture-gate.sh (verified RECAPTURE_DRYRUN seam)
RECAPTURE_DRYRUN=1 bash scripts/ci/snapshot-recapture-gate.sh global-overview org-overview
# → prints CK_ALLOW / DESIGN_ALLOW routing; both overviews route to the checkpoint lane
```

### Run the glossary drift guard (proves all 3 pages stay glossary-clean)
```bash
# Source: test/sigra/admin/glossary_test.exs (verified scopes index/organization/branding)
mix test test/sigra/admin/glossary_test.exs
```

## State of the Art

> No external state-of-the-art shift applies. The only "current vs old" deltas are internal v1.41 precedent:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Always-on `Confirmed`/`ok` pill on roster rows | Reduced to decision-bearing pills only | Phase 201 D-04 (contract `:276`) | D-02 drops the org-overview `Confirmed` pill to match |
| Coverage KPI metric chip always shown | Demote/slim non-decision-bearing coverage KPIs | Phase 201 D-03 | D-03 re-evaluates the global coverage chip |
| Decorated tier cells | Bare single `[012]` integer | Phase 199 D-03 / 201 D-09 / 202 D-11 | D-08 must use bare `2` |
| Private per-LiveView field-slices | Promote to `components.ex` when reused | Phase 200/202 | D-05 promotes branding privates; D-04 conditionally promotes status cluster |

**Deprecated/outdated:**
- The PAGE-04 todo's "no separate L3 branding row exists" premise — stale; the `branding-live` row exists at ledger `:92` (D-09).
- The `branding-live` cell's current `admin-modal-interaction` link — aspirational until D-06 lands (Pitfall 6).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dropping the org `Confirmed` pill (D-02) and demoting the coverage chip (D-03) need **zero new CSS** (reuse existing classes) | Pitfall 3 / D-12 | LOW — if a new affordance is added, the triple-copy gate catches it; planner adds a D-12 lockstep task |
| A2 | MG-7/MG-8 markup is unchanged by the Overview pill edits → no MG recapture (verified MG-7 carries only a role pill) | Pitfall 5 | LOW — recapture diff would reveal an unexpected MG change; gate baking behind a "changed" check |
| A3 | The D-04 `user_status_cluster`/`user_name_stack` promotion is likely NOT required (org roster uses a different, lighter pill set than the Users Index rows) — promote only if genuine DRY emerges | D-04 | LOW — DRY-driven by design; speculative promotion is explicitly discouraged by CONTEXT.md |

**Note:** A1–A3 are low-risk because each is caught by an existing automated gate (golden-diff, recapture diff) or is explicitly discretionary per CONTEXT.md. No external/compliance/security assumption is made.

## Open Questions

1. **Exact reduced pill vocabulary for the org roster (D-02 discretion)**
   - What we know: Drop the always-on `Confirmed`/`ok` pill (`:105`); keep decision-bearing pills (`role`, `Locked`, `Deletion scheduled`, `Unconfirmed`). Users Index `status_pills/1` reduced to `Unconfirmed`/`No MFA`/`Locked`/`Deletion scheduled` (STATE: 201 decision).
   - What's unclear: whether `Unconfirmed` (`:106`) stays or is also demoted, and whether the role pill set changes at all.
   - Recommendation: keep `Unconfirmed` (it is decision-bearing) and the role pill; drop only `Confirmed`. Match the 201 `status_pills` reduction. Discretionary — planner decides within the 201 precedent.

2. **Whether the global coverage chip is removed vs slimmed/relocated (D-03 discretion)**
   - What we know: the chip is `overview-metric-auth-coverage` (`:113-122`), an MFA%/passkey% `summary_chip`. 201 demoted (not always deleted) non-decision coverage KPIs.
   - What's unclear: full removal vs keeping a slimmed single metric.
   - Recommendation: demote/slim consistent with the Users Index (which dropped the coverage KPI). If the Users Index removed it entirely, remove it here for "same status signal renders identically"; otherwise slim. Discretionary.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Phoenix toolchain | All ExUnit + compile gates | ✓ (per CLAUDE.md) | ~> 1.18 / ~> 1.8 | — |
| Postgres (test) | ExUnit (glossary etc.) | host-dependent | — | `scripts/db/up.sh` ephemeral PG (dynamic port + direnv) |
| Node + Playwright | D-06 test, recapture, design/theme specs | ✓ (`test/example/priv/playwright`) | per lockfile | — |
| Booted `test/example` on :4011 | D-06 modal test + local recapture | runtime boot | — | `scripts/uat/up.sh --dev` (self-heals compile-env port) |
| phx_new 1.8.7 | install golden-diff (D-12) | must be installed | 1.8.7 | `mix archive.install --force hex phx_new 1.8.7` |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** Test Postgres (ephemeral via `scripts/db/up.sh`); example boot (via `scripts/uat/up.sh --dev`). phx_new 1.8.7 must be pinned locally or golden-diff produces a spurious config.exs byte-diff (1.8.8 `root_tag_attribute`).

## Validation Architecture

> Nyquist validation is ENABLED for this phase. This section maps each change to its automated gate so a VALIDATION.md can be generated. Mirror the 202-VALIDATION.md Per-Task Verification Map structure.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) + Playwright (admin browser specs) + Bash CI gates |
| Config file | `mix.exs` (ExUnit) / `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `mix test test/sigra/admin/` |
| Full suite command | `mix test` + admin Playwright projects (chromium/dark/mobile) + CI gates |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROP-01 | Overview pill alignment compiles cleanly | compile | `cd test/example && mix compile --warnings-as-errors` | ✅ |
| PROP-01 | Overviews/branding stay glossary-clean after edits | unit | `mix test test/sigra/admin/glossary_test.exs` | ✅ (scopes all 3 pages) |
| PROP-01 | Branding component promotion (D-05) compiles + lib unchanged behavior | compile | `mix compile --warnings-as-errors` | ✅ |
| PROP-01 | Branding `#restore-defaults-overlay` 7 APG gates + axe-while-open (D-06) | e2e | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test admin-modal-interaction.spec.ts` | ⚠️ Wave 0 — add branding case |
| PROP-01 | Three ledger cells ratcheted 1→2, forward-only (D-08) | guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ |
| PROP-01 | CSS triple-copy byte parity iff new `sg-*` class (D-12) | golden | `mix test test/sigra/install/golden_diff_test.exs` (requires phx_new 1.8.7) | ✅ |
| PROP-01 | `global-overview` + `org-overview` baselines recaptured, canaries byte-stable, allowlists empty (D-10) | gate | `RECAPTURE_DRYRUN=1 bash scripts/ci/snapshot-recapture-gate.sh global-overview org-overview` (dry-run routing) + full lane out-of-band | ✅ |
| PROP-01 | MG-3/MG-7/MG-8 markup verified unchanged (no recapture) | grep/visual | confirm gallery markup diff is empty before baking any MG baseline (Pitfall 5) | ✅ |
| PROP-02 | Branding/Workbench archetype added to contract (D-07) | grep+unit | `grep -c "Workbench Archetype" guides/reference/admin-design-contract.md && mix test test/sigra/admin/glossary_test.exs` | ✅ |
| PROP-02 | UI-principles touch-up; glossary drift-guard green (D-11) | unit | `mix test test/sigra/admin/glossary_test.exs` | ✅ |

### Sampling Rate
- **Per task commit:** `mix test {touched admin test files}` (ExUnit < ~60s). For the D-06 task: `npx playwright test admin-modal-interaction.spec.ts` against the booted example.
- **Per wave merge:** `mix test test/sigra/admin/` + affected Playwright specs + `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main`.
- **Phase gate:** Full suite + admin browser specs green; recapture idempotency proven (`global-overview`/`org-overview`); both allowlists empty; canaries byte-stable; CSS md5 parity; golden-diff green (phx_new 1.8.7); before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts` — ADD a `#restore-defaults-overlay` branding case (D-06). This is the ONLY net-new test; it is the prerequisite for the D-08 `branding-live` overlay-axe/APG evidence (Pitfall 6). Treat as a first-class task, not scaffolding.
- All other behaviors are covered by existing infrastructure (glossary ExUnit, monotonic guard, golden-diff, recapture gate, compile). No framework install needed.

*Dependency ordering for the planner: D-06 modal test → D-08 branding evidence (hard prereq). D-05 component promotion may introduce new `sg-*` classes → D-12 triple-copy lockstep (conditional). D-02/D-03 pill edits → `global-overview`/`org-overview` recapture (D-10); likely zero new CSS and no MG recapture (Pitfalls 3, 5).*

## Security Domain

> `security_enforcement` not explicitly disabled. This phase is admin-UI presentation propagation; the relevant ASVS surface is narrow and already governed by existing gates.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth-flow change; branding/overview are admin-gated read/config surfaces |
| V3 Session Management | no | Unchanged |
| V4 Access Control | indirect | Admin LiveViews already gated by `SigraAdminPolicy`/`platform_admin?`; D-06 test uses the `platform-admin+…` email convention to reach the surface |
| V5 Input Validation | yes (existing) | HEEx auto-escaping; no `raw/1` in promoted components; branding form already validated via `Profile.new/1` |
| V6 Cryptography | no | Unchanged |

### Known Threat Patterns for {LiveView admin UI}
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stored XSS via branding microcopy / promoted preview markup | Tampering | HEEx auto-escape; no `raw/1` in promoted `color_field`/`preview_pair`/`detail_input` (mirror 202 T-202-02: "no `raw/1` in shared row") |
| Privilege escalation to branding/overview surfaces | Elevation of Privilege | Existing `SigraAdminPolicy` gate (unchanged); test asserts admin email reaches the surface |
| Focus-trap escape / scrim-hidden modal (a11y-as-security adjacency) | — (a11y) | D-06 7-APG gates + axe-while-open prove the dialog is correctly trapped/labelled |

## Sources

### Primary (HIGH confidence — verified in codebase this session)
- `lib/sigra/admin/live/branding_live.ex:340-378` — `#restore-defaults-overlay` ConfirmDialog contract (hook/cancel/labelledby) + privates `detail_input:493`, `color_field:547`, `preview_pair:579`
- `lib/sigra/admin/live/organization_live.ex:95-110` — roster pills incl. always-on `Confirmed`/`ok` (`:105`)
- `lib/sigra/admin/live/index_live.ex:108-127` — `overview-metric-auth-coverage` chip (`:113-122`)
- `lib/sigra/admin/live/users_index_live.ex:365-393` — `user_name_stack`/`user_status_cluster` (D-04 candidates)
- `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts` — verified 7-APG + axe pattern, user-sessions only (D-06 template)
- `guides/reference/admin-quality-ledger.md:85-92` — cells `index-live`/`organization-live` (bare `1`), `users-index-live` (bare `2` template), `branding-live` (bare `1`)
- `guides/reference/admin-design-contract.md` — 4 archetypes (Overview `:172`, List `:211`, Detail `:284`, Audit Explorer `:331`); NO Workbench block
- `guides/reference/admin-fractal-scorecard.md:135-167` — Tier-2 proxy applicability (modal-only vs results-table-only vs always vs documented-as-manual)
- `scripts/ci/quality-ledger-monotonic.sh:22-27` — bare-`^[012]$` positional `awk -F'|'` parse
- `scripts/ci/snapshot-recapture-gate.sh` + `snapshot-canary-guard.sh` — per-lane routing + canary byte-stability
- `test/sigra/admin/glossary_test.exs:21-31` — scopes all 3 target pages
- `test/example/lib/example_web/live/admin/design_gallery_live.ex:935-961` — MG-7 markup (role pill only; does NOT mirror org-roster status pills)
- CSS triple-copy md5 parity verified equal (`9b281962ee8fe33254829c877af00382`)
- `.planning/phases/202-audit-surfaces-elevation/202-VALIDATION.md` — Per-Task Verification Map template to mirror
- `.planning/todos/pending/2026-06-17-page04-branding-explicit-scoring.md` — `resolves_phase: 203`; stale premise (D-09)

### Secondary (project memory / STATE)
- STATE.md Phase 200/201/202 decisions (reduced pills, bare-2 ratchet, content-equivalence N/A precedent, recapture allowlist hygiene)
- MEMORY: compile-env PORT gotcha (`260621-in8b`); SIGRA_EXAMPLE_URL=4011 (Phase 191); phx_new 1.8.7 pin (SEED-004)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; toolchain verified present
- Architecture: HIGH — every cited contract verified against live source
- Pitfalls: HIGH — derived from verified source + STATE/MEMORY precedent (200–202)

**Research date:** 2026-06-26
**Valid until:** ~14 days (internal admin-UI source; stable but the cited line numbers can drift if other PRs touch these files — re-verify cells/overlay IDs before execution if main advances)
