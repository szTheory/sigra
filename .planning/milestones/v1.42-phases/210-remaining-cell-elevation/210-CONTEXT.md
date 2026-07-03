# Phase 210: Remaining Cell Elevation - Context

**Gathered:** 2026-07-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Elevate the **final remaining ledger cells** to Tier-2 so the whole admin-UI quality fractal
reads bare `2`. Three flip groups, **all pure evidence/ledger authoring — no LiveView code
edits**:

1. **`user-sessions` page (L3)** → Tier-2 (PAGE-03).
2. **3 persona flows (L4)** — `flow-platform-admin`, `flow-support-investigator`,
   `flow-org-admin` → Tier-2 (FLOW-01).
3. **11 `mg-*` meta-component groups (L2)** → Tier-2 — **folded from the never-executed
   Phase 208-03 plan** (GROUP-02), so SC-4 ("every ledger cell is now Tier-2 — the whole
   fractal is complete") is legitimately true at close.

The single automated gate is `scripts/ci/quality-ledger-monotonic.sh --base origin/main`
exiting 0 after the 15 flips. This phase touches **only** `guides/reference/admin-quality-
ledger.md`. Terminal ratification (idempotent recapture, generated-host parity, adversarial
milestone audit) is **Phase 211** (GATE-01/GATE-02). Requirements: **PAGE-03, FLOW-01**
(+ GROUP-02 co-satisfied via the folded 208-03 scope).
</domain>

<decisions>
## Implementation Decisions

### Scope — 15 flips, zero code remediation

- **D-01 (fold 208-03; flip 15 cells total — USER-RATIFIED):** Phase 210 flips **user-sessions
  (1) + 3 flow-\* (3) + 11 mg-\* (11) = 15** ledger cells to bare `2`. The 11 `mg-*` L2 rows are
  still Tier-1 because **Phase 208-03 (fully authored, `208-03-PLAN.md`) was never executed** —
  Phase 208.1 (CI-gate remediation) was inserted and completed instead, leaving 208-03 `[ ]`.
  Folding it here is user-ratified: it matches this phase's name ("Remaining Cell Elevation")
  and SC-4 verbatim, keeps Phase 211 as **pure terminal verification** (no flip-work), and
  avoids reopening a closed phase. The 208-03 plan is self-contained (edits **only** the
  ledger) and executes verbatim here.
- **D-02 (pure evidence/ledger work — NO LiveView edits):** No `lib/sigra/admin/live/*.ex` (or
  any source) file changes this phase. Both Phase-209 `user-sessions` `tighten` findings are
  **already remediated** in current source (commit `869f1997`): `user_sessions_live.ex:107-108`
  renders kicker "Sessions" + entity-name H1 (`{@detail.display_name || @detail.user.email}`,
  matching sibling `user_show_live.ex:48` / `audit_user_live.ex:71`), and the revoke copy
  dropped "They can sign in again." All Tier-2 **automated** proxies for user-sessions are
  already wired and green (axe-while-open + 7 APG gates: `admin-modal-interaction.spec.ts`
  user-sessions confirm-dialog case; glossary-clean: `glossary_test.exs` scopes
  `user_sessions_live`). The phase is evidence-column authoring + column-4 integer flips.

### user-sessions Tier-2 (PAGE-03)

- **D-03 (mirror the `user-show-live` evidence template):** Flip the `user-sessions` row from
  `1` to bare `2` and expand its Evidence column to add the three documented-as-manual "reviewed
  — …" clauses (**motion-tokens / density-rhythm / target-size**) plus **content-equivalence:
  N/A**, exactly mirroring the sibling `user-show-live` row (both own the confirm dialog). The
  row already cites the checkpoint slug + `admin-modal-interaction.spec.ts` (axe-while-open + 7
  APG) + glossary-clean — those stay. **content-equivalence is N/A** (the sessions table is a
  scope-safe control table, not a desktop-table↔mobile-card equivalence pattern like MG-5/6) —
  do not chase an `assertUserResultEquivalence`-style assertion.

### Persona flows Tier-2 (FLOW-01)

- **D-04 (cite Phase-209 panel docs; author NO new per-flow doc):** Flip the 3 `flow-*` rows
  from `1` to bare `2`. Each cell's "persona review doc (from Phase 209)" citation resolves to
  the **roll-up `.planning/v1.42-PERSONA-JTBD-PANEL.md`** plus the **per-surface docs under
  `.planning/uat-evidence/v1.42-persona-jtbd/` that carry that lens's verdicts** — there is **no**
  per-flow persona doc and **none needs to be authored** (the rubric binds each lens 1:1 to a
  flow cell via the roll-up, per `admin-persona-jtbd-rubric.md` + `admin-quality-ledger.md`
  Persona-JTBD cross-reference). The 3 flow specs (`admin-flow-{platform-admin,support-
  investigator,org-admin}.spec.ts`) **already assert the full FLOW-01 checklist**
  (happy/main-error/boundary paths, scope/return-context continuity, full keyboard operability,
  reduced-motion, theme persistence) — the flip is citation + column-4 edit only. **"edge" in
  SC-2 is ROADMAP prose, not a scorecard L4 proxy** (`admin-fractal-scorecard.md` L4 add-ons name
  "happy + main-error + boundary") — do **not** add a net-new unratified "edge" assertion.

### mg-* Tier-2 — folded 208-03 (GROUP-02)

- **D-05 (execute 208-03-PLAN.md verbatim):** Flip the 11 `mg-*` L2 rows (`mg-1`…`mg-11`) from
  `1` to bare `2` with the rich semicolon-delimited evidence template from `208-03-PLAN.md`
  (Task 1), mirroring the freshly-flipped L1 rows. Per-group specifics are already enumerated in
  that plan (right-component exact counts, true state markers, board-cfg-* composite citation).
  Inherit 208's sub-decisions verbatim: **mg-7/mg-8 = isolated-board-only** (no `board-cfg-org`
  composite, intentional per 208 D-06); **mg-3 = deliberate state-N/A notes** (`mg-3-zero-note`/
  `mg-3-loading-note`, 208 D-08); **content-equivalence = mg-5/mg-6 ONLY** (`assertUser`/
  `assertAuditResultEquivalence` green, else N/A, 208 D-07). Source the exact counts + state
  shapes from `208-01-SUMMARY.md` / `208-02-SUMMARY.md`.

### Guardrails

- **D-06 (bare integer `2` only; no decorators):** Column-4 tier values must be a bare `[012]`
  with **no** asterisks/footnotes/checkmarks — a decorated value silently drops the row from the
  `awk -F'|' /^[012]$/` monotonic parse and causes false-pass CI. Applies to all 15 flipped rows.
- **D-07 (monotonic guard green; whole fractal `2`):** `scripts/ci/quality-ledger-monotonic.sh
  --base origin/main` exits 0 after the flips (all moves are `1→2`, allowed increases), and the
  guard self-test (`quality-ledger-monotonic.test.sh`) stays green. At close, **every** L0 + L1
  + L2 + L3 + L4 cell reads bare `2` — the terminal all-Tier-2 state Phase 211 ratifies.
- **D-08 (NO baseline recapture; allowlists empty; canary byte-stable):** Because no LiveView
  DOM changes, **no** Playwright baseline recapture is needed — the `user-sessions` checkpoint
  slug (and all board-* / checkpoint PNGs) stay byte-stable, both snapshot allowlists stay
  empty, and both canaries stay byte-stable. No source→`test/example/`→golden byte-coherence
  work (D-06 of 209) since no source file changes. The `impersonation-banner` canary
  re-designation (Phase 209 rework, commit `eb066b49`) is an **integration/Phase-211** concern,
  **NOT a Phase-210 blocker** — 210's 15 flips are self-contained ledger edits validated against
  phase HEAD.

### Claude's Discretion

- Exact wording of the three documented-as-manual "reviewed — …" clauses for user-sessions
  (bounded by the `user-show-live` sibling template).
- Whether the flow-cell citation lists the roll-up alone or the roll-up + specific per-surface
  doc paths (both satisfy D-04; the per-surface paths add traceability).
- Plan decomposition (e.g. one flip plan for user-sessions + flows, one for the folded 11 mg-*;
  or a single ledger-flip plan covering all 15) — the whole phase edits one file.

### Folded Todos

- None newly folded. The **208-03 flip scope** is folded per D-01/D-05 (a prior-phase plan, not
  a `.planning/todos/` item).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `guides/reference/admin-quality-ledger.md` — **the file this phase edits.** Current tiers:
  `user-sessions` L3 `1` (~:89), 3 `flow-*` L4 `1` (bottom rows), 11 `mg-*` L2 `1` (~:74-84);
  everything else already `2`. "Asserting Tier 2" convention + parsing rules (bare `[012]`,
  forbidden decorators) at ~:34-52; monotonic `awk -F'|'` parse spec.
- `.planning/phases/208-l2-meta-component-group-elevation/208-03-PLAN.md` — **the folded plan
  (D-01/D-05):** execute verbatim. Task 1 = flip 11 mg-* with the full evidence template + per-
  group specifics; Task 2 = monotonic guard verification. Its `must_haves`/`prohibitions` carry
  the mg-7/mg-8 isolated-only, mg-3 state-note, mg-5/6 content-equivalence rulings.
- `.planning/phases/208-l2-meta-component-group-elevation/208-01-SUMMARY.md` +
  `208-02-SUMMARY.md` — per-group audit findings (exact counts, true state markers, cfg-board
  mapping) that become the mg-* evidence strings; the 12 committed board-cfg-* baselines.
- `.planning/phases/209-judgment-level-page-pass/209-CONTEXT.md` — the D-01..D-10 discipline
  this phase inherits (column-4 integer prohibition, allowlist→clear, canary byte-stable,
  source byte-coherence); note D-08 explicitly reserved the user-sessions tier ratchet for 210.
- `.planning/uat-evidence/v1.42-persona-jtbd/*.md` (8 per-surface docs) +
  `.planning/v1.42-PERSONA-JTBD-PANEL.md` (roll-up) — the Phase-209 persona review docs each
  `flow-*` cell cites (D-04). `user-sessions.md` records the two now-resolved tighten findings.
- `guides/reference/admin-persona-jtbd-rubric.md` — the 3-lens ↔ 3-flow 1:1 binding; Lens
  Definitions table maps `flow-platform-admin`/`flow-support-investigator`/`flow-org-admin`.
- `guides/reference/admin-fractal-scorecard.md` — Tier-2 Award-grade Add-on proxy list
  (documented-as-manual designations for motion/density/target-size) + L2 group + L4 flow add-on
  proxy vocabulary the evidence strings use.
- `test/example/priv/playwright/tests/admin-flow-{platform-admin,support-investigator,org-admin}.spec.ts`
  — the 3 flow specs; already assert the full FLOW-01 checklist (D-04).
- `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts` — user-sessions confirm-
  dialog case (axe-while-open + 7 APG gates), already cited by the user-sessions row.
- `lib/sigra/admin/live/user_sessions_live.ex` — read-only confirmation the two 209 findings are
  remediated (:107-108 H1, revoke copy helpers ~:204-210); **not edited this phase** (D-02).
- `scripts/ci/quality-ledger-monotonic.sh` (+ `.test.sh`) — the single automated gate; exits 0
  vs `origin/main` after the flips (D-07).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Every Tier-2 proxy is already wired and green** for all 15 target cells — axe/screenshot
  harnesses, APG gates, content-equivalence assertions, glossary tests, flow specs. This phase
  authors **evidence citations**, it does not build or fix gates.
- **Sibling Tier-2 rows are the copy-template:** `user-show-live` (same confirm dialog) for
  user-sessions; the freshly-flipped L1 rows for the mg-* evidence shape.
- **`208-03-PLAN.md` is a ready-to-run, self-contained plan** — the folded 11-mg-* work needs
  no fresh authoring, just execution.

### Established Patterns
- Column-4 bare-integer discipline + monotonic forward-only guard (v1.41 → 206/207/208/209):
  flips only increase tiers; decorators forbidden.
- "Same job → same component" already satisfied — the cross-page asymmetries were remediated in
  Phase 209; this phase inherits a coherent surface set with no live IA debt.

### Integration Points
- **One file changes:** `guides/reference/admin-quality-ledger.md`. No source, no
  `test/example/` copy, no golden fixture, no Playwright baseline, no allowlist, no canary.
- Monotonic guard compares PR branch vs `origin/main`; all 15 flips are `1→2` increases → guard-
  safe. The terminal all-`2` column is the hand-off state for Phase 211's idempotency proof.

</code_context>

<specifics>
## Specific Ideas

- Phase 210 is deliberately **the last flip phase**; Phase 211 does zero flips (pure gate). This
  is why the 11 mg-* fold lands here, not in 211.
- The user-sessions H1/revoke-copy fixes are **done** (209, commit `869f1997`) — do not re-open
  or re-remediate; only author the manual-proxy evidence and flip the integer.
- Flow cells cite **existing** Phase-209 docs — resist authoring net-new per-flow synthesis docs
  and resist adding an unratified "edge"-path assertion to the flow specs (D-04).

</specifics>

<deferred>
## Deferred Ideas

- **Terminal ratification** — compare-mode zero-drift idempotency, both allowlists empty at
  steady state, both canaries byte-stable, generated-host parity (fresh `phx.new` + `mix
  sigra.install` + admin-acceptance smoke), and the adversarial milestone audit recording the
  persona-JTBD verdicts as Tier-2 evidence — **Phase 211** (GATE-01, GATE-02).
- **`impersonation-banner` canary re-designation post-merge CI reconciliation** — carried by the
  Phase-209 `admin_checkpoint_recapture` rework; an integration/211 concern, not a 210 flip
  blocker (D-08).
- **Library shard-2 `NoopTest` log-capture flake** — parallel-shard flake, milestone-cleanup at
  integration time (re-deferred from 209).

### Reviewed Todos (not folded)
- None matched this phase's flip-only scope beyond the 208-03 plan folded per D-01.
</deferred>
