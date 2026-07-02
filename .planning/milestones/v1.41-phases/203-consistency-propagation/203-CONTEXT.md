# Phase 203: Consistency Propagation - Context

**Gathered:** 2026-06-26 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

The **final propagation phase** of the v1.41 ADMIN-UX-ELEVATION arc (Phases 200 User Detail,
201 Users Index, 202 Audit Surfaces already shipped Tier-2). Roll the *already-established*
elevated bar — component patterns, archetypes, and Tier-2 proxies from 200–202 — onto the three
not-yet-elevated admin surfaces, update the design docs to document the evolved/new archetypes,
and ratchet their ledger cells. **Same-job → same-component; NO net-new surfaces.**

Targets (PROP-01, PROP-02):
- **Overviews** — `lib/sigra/admin/live/index_live.ex` (global), `lib/sigra/admin/live/organization_live.ex`
  (org). Both already emit the canonical Overview archetype; this is a **component-level alignment pass**,
  not a recomposition.
- **Branding workbench** — `lib/sigra/admin/live/branding_live.ex` (732 lines). The heaviest lift:
  bespoke composition with no archetype, private preview components, and an untested ConfirmDialog.
- **Design gallery / MG-1..MG-11** — `test/example/lib/example_web/live/admin/design_gallery_live.ex`;
  recapture the boards that mirror any changed composition.
- **Docs** — `guides/reference/admin-design-contract.md` + `guides/reference/admin-ui-principles.md`
  (document evolved/new archetypes "forward, never silently"); glossary stays drift-guarded.

Out of scope (Phase 204 owns it): terminal ratification, allowlist reset to empty, monotonic guard
final green, full-surface axe incl. overlays-open, generated-host parity, adversarial milestone review.
This phase leaves both snapshot allowlists **empty** at end (204 owns the terminal reset).

**Explicit NON-goals (scope guardrail — "no net-new surfaces"):** no dedicated branding-preview
route, no new shared "roster row" LiveView, no new admin route/LiveView of any kind, no promoting
branding's private preview components into net-new public components beyond what DRY genuinely
requires, and no re-grading any ledger cell other than the three named below.
</domain>

<decisions>
## Implementation Decisions

### Overviews — component-level alignment to the 201 reductions (PROP-01)
- **D-01 (light pass, NOT recomposition):** Both Overviews already emit the canonical archetype the
  contract documents (`index_live.ex:38-75`, `organization_live.ex:48-87` vs `admin-design-contract.md:178-195`).
  The Overview archetype block is **current, not stale** (unlike the List block 201 had to rewrite). Do
  NOT restructure the page composition — change only the component-level divergences below.
- **D-02 (align org roster pills to 201's reduced vocabulary — USER-RATIFIED):** Drop the org roster's
  always-present green `Confirmed`/`ok` pill (`organization_live.ex:102-106`) that Phase 201 explicitly
  removed (201 D-04; contract `:276`), so the same status signal renders the **same way** on the org
  overview and the Users Index. Reduce to only the decision-bearing pills.
- **D-03 (re-evaluate the global "Authentication coverage" chip — USER-RATIFIED):** Re-evaluate the
  global overview's MFA/passkey "Authentication coverage" metric chip (`index_live.ex:113-122`) against
  201's "scan-for-exceptions, demote non-decision-bearing coverage KPIs" decision (201 D-03). Demote/slim
  per the 201 precedent rather than keeping a coverage KPI the Users Index already dropped.
- **D-04 (reuse the shared primitives — same-job → same-component):** Both pages already route through
  the shared `summary_chip`/`task_card`/`notice`/`scope_ribbon` primitives (`components.ex:110,166,462,506`).
  Keep them; do not hand-roll. Where the org roster pills duplicate logic the Users Index now shares,
  prefer the shared path. NOTE: `users_index_live.ex` privates `user_status_cluster`/`user_name_stack`
  (`:369,384`) are NOT yet in `components.ex` — promote to a shared component only if the org roster
  genuinely reuses the same pill logic (DRY-driven, not speculative).

### Branding workbench — full elevation (PROP-01) — USER-RATIFIED "Full" path
- **D-05 (route private preview components through `components.ex`):** Promote branding's private
  `color_field` / `preview_pair` / `detail_input` (`branding_live.ex`) into `Sigra.Admin.Components`
  (or the shared component module) so the workbench obeys UI-principle `:29` (reusable markup routes
  through `components.ex` or the shell seam) — same-job → same-component. Keep `sg-branding-*`/`sg-tabs`
  classes; do not invent net-new public components beyond what this routing requires.
- **D-06 (add a real branding ConfirmDialog test — the honest-Tier-2 gate):** `branding_live.ex`'s
  `#restore-defaults-overlay` dialog (`:349-378`) is **NOT** exercised by `admin-modal-interaction.spec.ts`
  today — that spec only opens the user-sessions dialog (`#user-session-confirm-overlay` /
  `#user-session-confirm-title`, `:99,167`). Add a branding-specific modal-interaction test that opens
  `#restore-defaults-overlay` and asserts the **7 APG gates** (focus trap + restore, Escape, click-outside
  dismiss, `aria-labelledby="restore-defaults-title"`, no scrim-hidden state) + **axe-clean while open**.
  The dialog already uses the same `phx-hook="ConfirmDialog"` + `data-sg-confirm-cancel` contract
  (`:349,364`), so it is capable of passing — it just isn't tested. This test is the prerequisite for the
  branding Tier-2 overlay-axe/APG proxy claim (D-09).
- **D-07 (add a Branding/Workbench archetype to the design contract — PROP-02):** The contract has exactly
  four archetypes (Overview `:172`, List `:211`, Detail `:284`, Audit Explorer `:331`) and **no Workbench
  block**. Add a new Branding/Workbench archetype documenting the elevated composition (tab nav + disclosed
  panels + per-panel preview rail + ConfirmDialog restore-defaults). This satisfies PROP-02's "document any
  evolved/new archetypes, forward never silently."

### Ledger ratchet + PAGE-04 branding-scoring fold (PROP-01)
- **D-08 (ratchet all three cells 1→2 — bare un-decorated integer):** Flip column-4 `1`→`2` for
  `index-live` (`admin-quality-ledger.md:85`), `organization-live` (`:86`), and `branding-live` (`:92`).
  **Bare single `[012]` integer, no decorators** — the monotonic guard's positional `awk -F'|'` parse
  depends on it (202 D-11 / 201 D-09). Expand each Evidence column to cite **only honestly-applicable**
  Tier-2 proxies (`admin-fractal-scorecard.md:135-167`), mirroring the `users-index-live` template (`:87`):
  - **Overviews (`index-live`, `organization-live`):** own no results table and no modal →
    content-equivalence, overlay-axe, and the 7 APG-dialog gates are **N/A** (cite as N/A like `:87`).
    Applicable proxies: glossary-clean, motion-tokens (no `transition: all`), density/whitespace rhythm,
    target-size ≥24px (documented-as-manual).
  - **Branding (`branding-live`):** owns a real ConfirmDialog → claims **overlay-axe + 7 APG gates** earned
    by the D-06 test, plus glossary-clean, motion-tokens, density-rhythm, target-size. Content-equivalence
    is **N/A** (no desktop/mobile results table).
  Do NOT fabricate a proxy that doesn't apply (false Tier-2 claim fails Phase-204 adversarial review).
- **D-09 (fold the PAGE-04 branding-scoring todo):** `.planning/todos/pending/2026-06-17-page04-branding-explicit-scoring.md`
  carries `resolves_phase: 203` and was deferred by 200/201/202. **Fold it here** — satisfied by the
  `branding-live` cell ratchet + expanded evidence (D-08). The todo's "no separate L3 row exists" premise
  is already stale (the row exists at `:92`); resolving = expanding that row's evidence, not adding a row.

### Design gallery / MG boards + recapture (PROP-01)
- **D-10 (recapture only what actually changes):** Primary checkpoint targets are the `global-overview`
  (`admin-checkpoints.spec.ts:193`) and `org-overview` (`:204`) slugs — recapture because the Overview pills
  change (D-02/D-03). The gallery analogs — MG-3 task-card grid (`design_gallery_live.ex:556`), MG-7 member
  roster (`:934`), MG-8 pending invitations (`:964`) — recapture **only if** their mirrored markup actually
  changes. **No branding board and no branding checkpoint slug exist** → branding's visual blast radius is
  limited to existing `admin-generated.spec.ts` / `admin-theme.spec.ts` assertions plus the new D-06
  modal-interaction spec (interaction-only, no screenshots). Route recapture through
  `snapshot-recapture-gate.sh` (not the canary guard); prove zero-drift idempotency before baking new
  baselines; keep `board-notice` / `impersonation-banner` canaries byte-stable; **leave both allowlists
  empty** at end-of-phase (204 owns the terminal reset).

### Docs / CSS lockstep (PROP-02)
- **D-11 (UI principles touch-up + glossary):** Update `admin-ui-principles.md` for any evolved
  interaction pattern introduced by the branding routing (D-05) or pill alignment (D-02/D-03); keep
  microcopy glossary-clean (auto-guarded). The Overview archetype block in the contract gets a light
  touch-up iff the roster pills change (D-02).
- **D-12 (CSS triple-copy lockstep — hard):** Any new/changed `sg-*` class MUST be written
  **byte-identically** into all three copies — `priv/templates/sigra.install/admin/sigra_admin.css`,
  `test/example/priv/static/assets/sigra_admin.css`,
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (shared md5, golden-diff gated)
  — or the install golden-diff fails and generated hosts get an unstyled page (the 184→185 regression
  class, 202 D-13). Both pill alignment and component routing reuse existing classes where possible — a
  pill-vocabulary reduction may need **zero new CSS**; only genuinely new affordances trip the gate.

### Claude's Discretion
- Exact reduced pill vocabulary for the org roster and whether the global "Authentication coverage" chip is
  fully removed vs slimmed/relocated (D-02/D-03) — as long as it matches the 201 precedent and the same
  status signal renders identically across surfaces.
- Whether `user_status_cluster`/`user_name_stack` get promoted to `components.ex` or the org roster reuses
  a lighter shared path — DRY-driven, not speculative (D-04).
- Shared component names / arg shapes for the promoted branding preview components (D-05).
- Exact archetype-block wording for the Branding/Workbench archetype (D-07) and which UI-principles lines
  evolve (D-11).
- Microcopy wording (auto-guarded glossary-clean).

### Folded Todos
- `2026-06-17-page04-branding-explicit-scoring.md` (`resolves_phase: 203`) — **folded** into the
  `branding-live` Tier-2 ratchet + expanded evidence (D-08, D-09).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `lib/sigra/admin/live/index_live.ex` — global overview: archetype body (`:38-75`), the
  "Authentication coverage" MFA/passkey chip to re-evaluate (`:113-122`). Ledger cell `index-live`.
- `lib/sigra/admin/live/organization_live.ex` — org overview: archetype body (`:48-87`), the hand-rolled
  roster pill set incl. always-on `Confirmed`/`ok` to drop (`:102-106`). Ledger cell `organization-live`.
- `lib/sigra/admin/live/branding_live.ex` — branding workbench (732 lines): tab nav + 3 panels + preview
  rail; private `color_field`/`preview_pair`/`detail_input` to promote (D-05); `#restore-defaults-overlay`
  ConfirmDialog (`:349-378`, `phx-hook="ConfirmDialog"` `:349`, `data-sg-confirm-cancel` `:364`,
  `restore-defaults-title` `:354`) — untested, needs the D-06 spec. Ledger cell `branding-live`.
- `lib/sigra/admin/components.ex` — shared primitives `summary_chip` (`:110`), `task_card` (`:166`),
  `notice` (`:462`), `scope_ribbon` (`:506`); the destination for promoted branding preview components (D-05).
- `lib/sigra/admin/live/users_index_live.ex` (`:369` `user_status_cluster`, `:384` `user_name_stack`) —
  the 201 reduced-pill source-of-truth (private, NOT in components.ex); promote only if DRY-driven (D-04).
- `guides/reference/admin-design-contract.md` — four archetypes (Overview `:172`/`:178-195`, List `:211`,
  Detail `:284`, Audit Explorer `:331`); **no Workbench block** — add Branding/Workbench archetype (D-07);
  Overview block touch-up iff pills change (D-11). Reduced-pill rule at `:276`.
- `guides/reference/admin-ui-principles.md` — same-job→same-component (`:29`), no `transition: all` (`:47`)
  — evolve for branding routing / pill alignment (D-11).
- `guides/reference/admin-quality-ledger.md` — cells `:85` index-live, `:86` organization-live,
  `:92` branding-live (all bare `1`, ratchet to `2`, D-08); `:87` users-index-live Tier-2 template incl.
  N/A proxies; `:14-27` positional parse rules.
- `guides/reference/admin-fractal-scorecard.md` (`:135-167`) — Tier-2 Add-on proxy definitions (D-08).
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — MG-3 task-card grid (`:556`),
  MG-7 member roster (`:934`), MG-8 pending invitations (`:964`) — recapture iff markup changes (D-10).
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — `global-overview` (`:193`),
  `org-overview` (`:204`) slugs to recapture (D-10); no branding slug.
- `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts` — tests user-sessions dialog only
  (`#user-session-confirm-overlay`/`#user-session-confirm-title`, `:99,167`); extend with a branding
  `#restore-defaults-overlay` case (D-06).
- `test/example/priv/playwright/tests/admin-generated.spec.ts`, `admin-theme.spec.ts` — existing branding
  coverage (the only branding visual asserts today; D-10).
- `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`,
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — three byte-identical CSS copies,
  golden-diff gated; move in lockstep (D-12).
- `scripts/ci/snapshot-recapture-gate.sh` + `snapshot-canary-guard.sh` + `quality-ledger-monotonic.sh` —
  recapture routing + positional ledger parse (D-08, D-10).
- `test/sigra/admin/glossary_test.exs` — glossary-clean proxy (verify it scopes the three target pages).
- `.planning/todos/pending/2026-06-17-page04-branding-explicit-scoring.md` (`resolves_phase: 203`) —
  folded into D-08/D-09.
- `.planning/phases/202-audit-surfaces-elevation/202-CONTEXT.md`,
  `.planning/phases/201-users-index-elevation/201-CONTEXT.md`,
  `.planning/phases/200-user-detail-elevation/200-CONTEXT.md` — the lockstep / proxy / recapture
  invariants and shared-component patterns this phase repeats.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Both Overviews already route through the shared `summary_chip`/`task_card`/`notice`/`scope_ribbon`
  primitives (`components.ex:110,166,462,506`) and already emit the canonical Overview archetype — the
  work is pill-vocabulary alignment, not composition (D-01..D-04).
- Branding's ConfirmDialog already uses the same `phx-hook="ConfirmDialog"` + `data-sg-confirm-cancel`
  contract as the (tested) user-sessions dialog — it is capable of passing the 7 APG gates + axe-while-open;
  only the test is missing (D-06).
- The `users-index-live` ledger cell (`:87`) is the exact Tier-2 evidence template (incl. how to cite N/A
  proxies) for the three new ratchets (D-08).

### Established Patterns
- Quality-ledger column-4 = single bare `[012]` integer (no decorators); monotonic guard's positional `awk`
  parse depends on it — flip to `2` un-decorated (D-08).
- The design contract documents archetypes "forward, never silently"; a new composition (the workbench)
  with no archetype block is a PROP-02 gap that must be filled (D-07).
- Admin CSS ships installer-template → generated host; the three copies are byte-parity-gated (golden-diff,
  184→185 regression class) — any new `sg-*` class moves in lockstep across all three (D-12).
- Recapture routes through `snapshot-recapture-gate.sh` with zero-drift idempotency proof; allowlists left
  empty for the terminal Phase-204 reset (D-10).

### Integration Points
- Overview pill changes → `global-overview`/`org-overview` checkpoint slugs (+ MG-7/MG-8 iff mirrored) → CSS
  triple-copy iff a new class is introduced.
- Branding preview-component promotion → `components.ex` public surface + UI-principles doc + (possibly)
  new `sg-*` classes → CSS triple-copy.
- Three ledger-cell ratchets → monotonic guard (merge-blocking, `--base origin/main`) protects them
  forward-only.
- New branding modal-interaction spec → no screenshots, but gates the branding overlay-axe/APG Tier-2 proxy.
</code_context>

<specifics>
## Specific Ideas

- **Branding = full elevation (user-ratified):** route the private preview components through
  `components.ex` (D-05), add a real `#restore-defaults-overlay` APG + axe-while-open test (D-06), add a
  Branding/Workbench archetype to the contract (D-07), then ratchet `branding-live` to Tier 2 (D-08).
- **Overviews = align pills, recapture (user-ratified):** drop the org roster's always-on green
  `Confirmed`/`ok` pill and demote the global "Authentication coverage" chip to match 201's reductions
  (D-02/D-03), making "same-job → same-component" literally true across admin status signals; recapture
  `global-overview` + `org-overview` (D-10).
- All three target ledger cells flip 1→2 with honestly-applicable proxies and N/A justifications mirroring
  the `users-index-live` template — Overviews cite content-equivalence/overlay/APG as N/A; branding earns
  overlay-axe/APG from the new test (D-08).
- The PAGE-04 branding-scoring todo is closed by the branding cell's expanded evidence, not a new ledger
  row (D-09).
</specifics>

<deferred>
## Deferred Ideas

- A dedicated branding-preview route / net-new shared "roster row" LiveView / net-new public branding
  components beyond DRY needs — explicitly **ruled OUT** by the "no net-new surfaces" scope guardrail.
- Terminal ratification (allowlist reset to empty, monotonic guard final green, full-surface axe incl.
  overlays-open, generated-host parity, adversarial milestone review) — owned by **Phase 204**.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db.md` (ci, 0.9) — CI infra, not a UI-elevation surface.
- `2026-06-25-phase200-code-review-deferred.md` (admin-ui, 0.9) — token-scoped session-revocation hardening
  on the Phase-200 Sessions surface, not an Overview/Branding propagation concern.
- `2026-06-26-per-user-audit-pagination-test-coverage.md` (admin-ui, 0.9) — per-user audit pagination test
  hardening, a Phase-202 audit-surface follow-on, not 203 scope.
- `2026-06-26-audit-mobile-baseline-recapture-phase204.md` (admin-ui, 0.7) — explicitly Phase-204 baseline
  recapture work (blocked on `.vt-status-pill` axe contrast).
- `2026-06-18-token-reference-completeness-ci-guard.md` (test, 0.6) — CI guard, unrelated to this propagation.
</deferred>
