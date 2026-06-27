# Phase 202: Audit Surfaces Elevation - Context

**Gathered:** 2026-06-26 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Award-grade (Tier 1 → Tier 2) elevation of BOTH generated admin audit surfaces —
`lib/sigra/admin/live/audit_index_live.ex` (global) and
`lib/sigra/admin/live/audit_user_live.ex` (per-user) — to a single unified filter
experience with advanced-disclosure (quick toggles folded in), reduced column density
(raw event codes deferred to in-row disclosure, not a primary column), mobile-first
stacking, Export surfaced in the filter action row, and honest pagination proven against
the Phase-199 ≥25-event persona fixture — while the two pages stay **byte-coherent** with
each other in their shared markup/components.

In scope (AUDIT-01..03):
- Converge both pages on one coherent `sg-filter-panel` GET-form with a native
  `<details>` advanced-disclosure; specifically fix `audit_user_live.ex`, which today has
  **three separate forms** (two standalone quick-toggle forms above the main filter form).
- Reduce desktop column density by moving the raw event id + action code out of the
  primary columns into an in-row progressive-disclosure affordance (no new route); reduce
  to human-readable `action_label` + `action_badge` in the primary cells.
- DRY the duplicated desktop-table / pagination `<nav>` / empty-state / helper code that is
  hand-copied between the two LiveViews into shared function components so the shared markup
  is byte-coherent across both pages.
- Prove honest pagination renders multi-page against the ≥25-event admin persona fixture.
- Ratchet the `audit-index-live` and `audit-user-live` ledger cells Tier 1 → Tier 2 with
  applicable Tier-2 proxy evidence, add an Audit Explorer archetype block to the design
  contract, and recapture only the affected non-canary slugs.

Out of scope (later phases): consistency propagation to Overviews/Branding/gallery (203),
terminal ratification / allowlist reset / adversarial review (204). This phase does **not**
re-grade any ledger cell other than the two audit cells, does **not** build a new
audit-event drill-down route, and does **not** touch the audit data/query layer beyond what
view trimming requires (`explorer.ex`/`query.ex` stay functionally intact; the CSV export
column set — including `event_id` — is preserved).
</domain>

<decisions>
## Implementation Decisions

### Filter Consolidation + Advanced-Disclosure + Export (AUDIT-01)
- **D-01:** **Converge both pages on one coherent `sg-filter-panel` form.** `audit_index_live.ex`
  is already close — a single `<form class="sg-filter-panel sg-stack">` (`:58-137`) with quick
  chips in an `sg-cluster` (`:59-80`), advanced fields in `sg-form-grid` (`:82-126`), and Export
  already in the action-row cluster (`:128-132`). The real surgery is **`audit_user_live.ex`,
  which splits the quick toggles (Failures / Impersonation) into two standalone `<form>` elements
  (`:81-108`) that sit *outside and above* the main filter form (`:110-164`) — three forms, not
  one.** Fold those toggles into the main form as GET checkboxes so the per-user page is a single
  panel matching the index page and 201's pattern.
- **D-02:** **Add a native `<details>` advanced-disclosure** holding the text/date fields on both
  pages (neither page has disclosure today — all advanced fields render flat). Quick toggles
  (Failures / Impersonation) stay visible as the folded-in summary controls; text/date filters
  fold into the disclosure. CSS-only `<details>` (no `phx-hook`) to keep reduced-motion/axe risk
  out of scope. If a chevron is used, reuse an existing styled class — `sg-chevron` is unstyled in
  the triple-copy (flagged in 201 D-11).
- **D-03:** **Preserve the GET-form / URL-driven contract.** `handle_params` is the only state path
  (`audit_index_live.ex:25`, `audit_user_live.ex:29`); every filter/sort/page link is a built query
  string (`append_query/2`, `sort_path`, `page_path`), and the checkpoint spec submits via pre-built
  URLs and asserts checkbox `:checked` state (`admin-checkpoints.spec.ts:356-367`). Do **not** convert
  toggles to `phx-click`. Keeps deep-linking, the `?action_prefix=admin.impersonation` checkpoint
  entry path, and the `return_to` round-trip (per-user page) working.
- **D-04:** **Export stays in the filter action row** on both pages — it is **already** there
  (`audit_index_live.ex:131`, `audit_user_live.ex:155-157`), not buried near pagination. The
  "Export surfaced" clause of AUDIT-01 is largely already satisfied; do **not** relocate Export and
  churn markup the checkpoint already asserts (`admin-checkpoints.spec.ts:368` asserts the
  `Export CSV` link visible). Verify it lands in the consolidated action row after the form reflow.

### Column-Density Reduction + Inline Code Disclosure (AUDIT-02)
- **D-05 (drill-down = inline disclosure, NO new route — user-ratified):** "Codes deferred to a
  drill-down" means moving the raw event id (`row.id`) and raw action code (`row.action`) out of the
  **primary desktop columns** (`audit_index_live.ex:168,177`; `audit_user_live.ex:197,206`) into an
  **in-row progressive-disclosure affordance** (expandable row detail / `<details>` / copy-on-demand),
  reusing the mobile card's existing `show_detail`/`show_codes` expansion pattern
  (`components.ex:699-711`). Primary cells keep the human `action_label` + `action_badge`. **No new
  `AuditEventLive` LiveView and no `/admin/audit/:event_id` route** — that would add a generated-host
  router-contract seam disproportionate to a density-reduction phase (the Phase-200 `UserSessionsLive`
  precedent is deliberately NOT followed here). The codes must remain accessible (forensic/regulatory
  users), and the CSV `event_id` column (`csv_export.ex:8,59`) MUST be preserved as the de-facto
  host-visible event-id contract.
- **D-06 (positional-selector lockstep — hard):** Removing/relocating the code column **MUST** update
  the Playwright equivalence selectors in the **same** change. `assertAuditResultEquivalence`
  (`admin-design.spec.ts:166-178`) extracts equivalence tokens from `code.sg-code` (the two raw codes)
  and the Actor column `td:nth-child(3) span`. If the codes leave the primary DOM, `firstTexts(...,
  'code.sg-code', 2)` returns fewer than 2 tokens and the equivalence assertion silently weakens to a
  rubber stamp (the exact 201 D-06 failure mode). The helper also drives MG-6 and the live
  `/admin/audit` + per-user checks (`:354-361`, `:383-388`) — update all in lockstep, and ensure the
  disclosed codes are still extractable by the (revised) selector so content-equivalence stays a real
  proof, not a vacuous one.
- **D-07 (mobile-first stacking):** The mobile card is already DRY via `<.audit_row>`
  (`components.ex:699`); keep it as the canonical mobile presentation and ensure the disclosed codes
  render in the mobile expansion. Desktop reduces to the human columns + inline disclosure; mobile
  stays the stacked `sg-kv`/card form.

### Byte-Coherence Between the Two Pages (AUDIT-02)
- **D-08 (DRY the duplicated shared markup into function components):** The desktop `<table>` body
  is currently **hand-duplicated** between `audit_index_live.ex:154-193` and `audit_user_live.ex:183-222`
  (same 4 columns, same `<td>` internals), as are the pagination `<nav>` (`:216-236` vs `:246-266`),
  the empty state, and ~8 private helpers (`audit_tone/1`, `format_timestamp/1`, `multi_page?/1`,
  `applied_chips/1`, `chip_label/2`, `append_query/2`, `param_value/_`, `humanize_outcome/1`) — the code
  even comments "Unified body — identical to…" (`:243`, `:271`). Extract the shared desktop-table row,
  pagination `<nav>`, and empty-state into **shared function components** (the 201 `<.user_row_fields>`
  precedent) so both pages emit byte-identical shared markup. Shared helpers move to one shared module
  rather than living copy-pasted in both LiveViews.
- **D-09 (preserve legitimate per-page divergence):** "Byte-coherent" applies to the **shared**
  markup/components, NOT to making the two pages wholesale identical. Legitimate differences stay:
  the index `@chip_keys` is 6-key incl. actor/effective_user (`:274`), the per-user `@chip_keys` is
  5-key (`:435`); the per-user page has breadcrumbs, header, and `return_to` plumbing. Keep these;
  align the chip-key lists and column sets that feed the *shared* component so the shared output is
  truly byte-coherent.

### Pagination Proof Against ≥25-Event Fixture (AUDIT-02)
- **D-10 (prove, don't build):** Honest cursor pagination is **already implemented** — `multi_page?/1`
  (`audit_index_live.ex:309-313`, `audit_user_live.ex:475-479`) hides the `<nav>` when there is no
  next/prev cursor (comment explains the no-`total_pages` cursor design). Default page size is 25
  (hidden `page_size=25` at `:134`/`:161`). The ≥25-event admin persona fixture exists (FIXT-01 closed
  Phase 199; `seeds.ex:12-13` documents ">=25 admin self-tied rows"). This phase **proves** multi-page
  renders against that fixture. Today nothing exercises page 2 (`admin-design.spec.ts:370` notes "only
  ~3 audit events"). Capture harness must boot a **dev DB with seeds run** (seeds are `MIX_ENV=dev`-only,
  hard-blocked in test — same constraint as 201 D-08). **Strongly prefer** also adding a deterministic
  ExUnit LiveView test asserting the `<nav>` is present at ≥26 rows / absent at ≤25, so pagination proof
  does not depend solely on a seeded screenshot.

### Tier-2 Ratchet, Recapture Blast Radius & Docs (AUDIT-03)
- **D-11 (ratchet two ledger cells):** Flip the column-4 bare integer `1`→`2` for **both**
  `audit-index-live` (`admin-quality-ledger.md:90`) and `audit-user-live` (`:91`) — **bare single
  `[012]` integer, no decorators** (the monotonic guard's positional `awk -F'|'` parse depends on it;
  201 D-09). Expand each Evidence column to cite the **applicable** Tier-2 proxies
  (`admin-fractal-scorecard.md:135-167`): **content-equivalence** (MG-6 + the live
  `assertAuditResultEquivalence`), **glossary-clean** (both files already scoped at
  `glossary_test.exs:28-29`), plus the documented-as-manual motion-tokens / density-rhythm /
  target-size ≥24px proxies. The **overlay-axe + 7-APG-dialog gates are N/A** — neither audit page
  owns a modal dialog — cite them as N/A (mirroring the `users-index-live` cell at `:87`); do **not**
  fabricate an overlay/dialog pass (false Tier-2 claim fails Phase-204 adversarial review).
- **D-12 (recapture only affected non-canary slugs):** Recapture via `snapshot-recapture-gate.sh`
  (not the canary guard). Blast radius: the **`audit-explorer`** and **`user-audit`** checkpoint slugs
  (3 PNGs each: chromium/dark/mobile) and the **`mg-6`** audit-feed design-gallery board if its markup
  changes. Prove zero-drift idempotency before baking new baselines (Phase-192/199 method). The
  relevant canary stays byte-stable; leave both allowlists empty at end-of-phase (Phase 204 owns the
  terminal reset).
- **D-13 (CSS triple-copy lockstep):** Any new/changed `sg-*` CSS must be written **byte-identically**
  into all three copies — `priv/templates/sigra.install/admin/sigra_admin.css`,
  `test/example/priv/static/assets/sigra_admin.css`,
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (shared md5, golden-diff
  gated) — or the install golden-diff fails and generated hosts get an unstyled page (the 184→185
  regression class). The audit pages reuse existing classes (`sg-filter-panel`, `sg-form-grid`,
  `sg-filter-chip`, `sg-table-panel`, `sg-applied-chip`), so a disclosure-only reflow **may need zero
  new CSS** — but any inline-disclosure chevron / new class triggers the triple-copy gate.
- **D-14 (design contract — ADD an Audit Explorer archetype):** There is **no stale Audit/Explorer
  archetype block to rewrite** — only Overview (`:172`), List (`:211`), and Detail (`:284`) archetypes
  exist in `admin-design-contract.md`. **Add a new Audit Explorer archetype block** documenting the
  elevated composition (unified filter panel + advanced-disclosure + inline-code disclosure +
  byte-coherent shared components + honest pagination). Update the existing `audit_user_live.ex` line
  references the contract already cites (e.g. `:77` applied-chip pattern) so they don't go stale when
  that markup moves. Keep microcopy glossary-clean (auto-guarded, `glossary_test.exs:28-29`).

### Claude's Discretion
- Exact in-row disclosure mechanism for the deferred codes (expandable detail row vs `<details>` in a
  cell vs a copy-icon affordance) — as long as codes stay accessible, equivalence selectors are updated
  in lockstep (D-06), and the CSV `event_id` survives (D-05).
- The shared component names / arg shapes and how much layout chrome stays in each page's shell vs the
  shared component (D-08).
- Which shared module the migrated helpers land in (D-08).
- Whether to add the deterministic ExUnit pagination test in addition to the seeded capture (strongly
  preferred — D-10).
- Whether a disclosure chevron reuses an existing class or `sg-chevron` is styled/avoided (D-13).
- Microcopy wording (auto-guarded glossary-clean).

### Folded Todos
- None folded. All matched todos (branding scoring → Phase 203; Playwright per-shard-DB CI infra;
  Phase-199/200 review-hardening; stale known-failure contract tests; token-reference CI guard; UAT
  demo-DX nits; installer/config features) are outside an audit-surface UI elevation — the same call
  Phases 200 and 201 made. See Deferred.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `lib/sigra/admin/live/audit_index_live.ex` — global audit page: single `sg-filter-panel` form
  (`:58-137`), quick chips (`:59-80`), advanced fields (`:82-126`), Export in action row (`:128-132`),
  desktop table body (`:154-193`), raw codes (`:168` id, `:177` action), pagination `<nav>` (`:216-236`),
  `audit_tone/1` (`:244-246`), `multi_page?/1` (`:309-313`), `@chip_keys` 6-key (`:274`).
- `lib/sigra/admin/live/audit_user_live.ex` — per-user audit page: **THREE forms** — two standalone
  quick-toggle forms (`:81-108`) + main filter form (`:110-164`); desktop table body (`:183-222`),
  raw codes (`:197,206`), Export (`:155-157`), pagination `<nav>` (`:246-266`), `audit_tone/1`
  (`:273-275`), `multi_page?/1` (`:475-479`), `@chip_keys` 5-key (`:435`), `return_to`/breadcrumbs.
- `lib/sigra/admin/components.ex` (`:699-711`) — shared `<.audit_row>` mobile card + `show_codes`/
  `show_detail` flags (the inline-disclosure pattern to extend to desktop, D-05/D-07).
- `lib/sigra/admin/audit/explorer.ex`, `query.ex`, `query_params.ex`, `presenter.ex` — audit data
  loader; `extra_filters` (`explorer.ex:115-181`) are INTERNAL (`subject_user_id`/org scope), **not**
  host callbacks — no audit equivalent of 201's `extra_list_badges` host-seam blind spot (D-09 note).
- `lib/sigra/admin/audit/export.ex` + `csv_export.ex` (`:8,59`) — CSV export column set incl.
  `event_id`; the de-facto host-visible event-id contract that MUST survive the density reduction (D-05).
- `test/example/priv/playwright/tests/admin-design.spec.ts` (`:166-178` `assertAuditResultEquivalence`
  reading `code.sg-code` + `td:nth-child(3) span`; `:334-336` MG-6; `:354-361`, `:383-388` live audit
  checks; `:370` "only ~3 audit events" note) — positional selectors to update in lockstep (D-06, D-10).
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (`:356-368`) — audit checkpoint entry
  (`?action_prefix=admin.impersonation`, checkbox `:checked` asserts, `Export CSV` visible) + the
  `audit-explorer` / `user-audit` checkpoint slugs to recapture (D-03, D-12).
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — `mg-6` audit-feed board (recapture
  iff markup changes, D-12).
- `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`,
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — the three byte-identical CSS
  copies that must move in lockstep (D-13).
- `guides/reference/admin-quality-ledger.md` (`:14-27` parse rules, `:87` `users-index-live` Tier-2
  template incl. N/A proxies, cells `:90`/`:91` to ratchet, `:115-118` idempotency proof method) (D-11, D-12).
- `guides/reference/admin-fractal-scorecard.md` (`:135-167`) — Tier-2 Add-on proxy definitions (D-11).
- `guides/reference/admin-design-contract.md` (Overview `:172` / List `:211` / Detail `:284` archetypes —
  NO Audit block yet; `:77` audit applied-chip ref to keep current) — add Audit Explorer archetype (D-14).
- `guides/reference/admin-ui-principles.md` — binding IA/motion rules (progressive reveal,
  same-job-same-component, no `transition: all`).
- `scripts/ci/snapshot-recapture-gate.sh` + `snapshot-canary-guard.sh` + `quality-ledger-monotonic.sh`
  — recapture routing + the positional ledger parse (D-11, D-12).
- `test/sigra/admin/glossary_test.exs` (`:28-29`) — glossary-clean proxy already scopes both audit pages.
- `test/example/lib/example/demo/seeds.ex` (`:12-13`) — ≥25-event admin persona fixture (FIXT-01) that
  makes the audit pages paginate (D-10).
- `.planning/phases/201-users-index-elevation/201-CONTEXT.md` and
  `.planning/phases/200-user-detail-elevation/200-CONTEXT.md` — the lockstep/proxy/recapture invariants
  and shared-component patterns this phase repeats.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `audit_index_live.ex` is already a single `sg-filter-panel` with Export in the action row — the
  consolidation work is concentrated on `audit_user_live.ex` (collapse its 3 forms into 1) + adding a
  `<details>` disclosure to both (D-01, D-02).
- The mobile `<.audit_row>` component (`components.ex:699-711`) is already DRY and already has the
  `show_codes`/`show_detail` expansion — the inline-code-disclosure pattern to extend to desktop (D-05).
- Honest cursor pagination is already implemented via `multi_page?/1` on both pages — this phase proves
  it at ≥25-event scale, not builds it (D-10).
- `explorer.ex`/`query.ex`/`presenter.ex` produce a fixed row shape with no host injection point — no
  density-refactor data-loss risk of the 201 `extra_list_badges` kind (D-09).
- Both pages are already glossary-scoped (`glossary_test.exs:28-29`) — new microcopy is auto-guarded.

### Established Patterns
- Quality-ledger column-4 = single `[012]` integer (no decorators); monotonic guard's positional `awk`
  parse depends on it — flip to `2` un-decorated (D-11).
- Admin CSS ships installer-template → generated host as `sigra_admin.css`; the three copies are
  byte-parity-gated (golden-diff). Template copy lags the example unless hand-propagated (D-13).
- Playwright equivalence helpers read row content by **column position** (`td:nth-child`) and by
  `code.sg-code` — column order / code presence is a contract, not a layout detail (D-06).
- Seeds are `MIX_ENV=dev`-only (hard-blocked in test); ≥25-event overflow only renders when the capture
  harness boots a dev DB with seeds run (D-10).
- The two audit LiveViews carry explicit "identical to…" duplication comments (`:243`/`:271`) — the
  duplication is known and intentional-pending-DRY; this phase is where it gets factored (D-08).

### Integration Points
- New/changed `sg-*` classes → CSS triple-copy + (if structural) `mg-6` gallery board + new Audit
  Explorer design-contract block + `audit-explorer`/`user-audit` checkpoint recapture.
- Two ledger-cell ratchets → monotonic guard (merge-blocking, `--base origin/main`) protects them
  forward-only.
- The CSV export (`csv_export.ex`) is the host-visible event-id contract — UI density reduction must not
  remove `event_id` from the CSV (D-05).
- `assertAuditResultEquivalence` is shared across MG-6 + both live audit checks — one selector change
  ripples to all three (D-06).
</code_context>

<specifics>
## Specific Ideas

- Drill-down for deferred codes = **inline progressive disclosure, no new route** (user-ratified):
  reuse the mobile card's `show_detail`/`show_codes` expansion pattern; keep CSV `event_id` intact.
- Primary desktop columns reduce to human `action_label` + `action_badge`; raw id/action move to the
  in-row disclosure.
- DRY mechanism: shared function components for the desktop-table row + pagination `<nav>` + empty
  state, plus a shared helper module — both pages emit byte-identical shared markup while keeping
  legitimate per-page divergence (breadcrumbs/return_to/chip-key set).
- Add a deterministic ExUnit pagination test (`<nav>` present at ≥26 rows / absent at ≤25) alongside
  the seeded capture so pagination proof isn't screenshot-only.
</specifics>

<deferred>
## Deferred Ideas

- A dedicated `AuditEventLive` / `/admin/audit/:event_id` drill-down route was explicitly considered
  and **declined** for this phase — it would add a generated-host router-contract seam disproportionate
  to a density-reduction phase. Could be revisited as its own phase if forensic per-event detail becomes
  an adopter need.

### Reviewed Todos (not folded)
- `2026-06-17-page04-branding-explicit-scoring.md` (admin-ui, 0.6) — Branding workbench scoring, Phase 203 territory.
- `2026-06-20-playwright-parallelization-per-shard-db.md` (ci, 0.6) — CI infra, not UI elevation.
- `2026-06-25-phase199-code-review-info-hardening.md` (test, 0.6) — fixture/self-test hardening, not the audit pages.
- `2026-06-25-phase200-code-review-deferred.md` (admin-ui, 0.6) — token-scoped session-revocation hardening on the Phase-200 Sessions surface, not audit.
- `2026-06-26-stale-known-failure-contract-tests.md` (general, 0.6) — test-infra cleanup surfaced by Phase 201, not audit-UI.
- `2026-06-18-token-reference-completeness-ci-guard.md` (test, 0.4) — CI guard, unrelated.
- `2026-06-19-uat-demo-dx-polish-nits.md` (dx, 0.4) — demo-DX flags, unrelated.
- `2026-06-20-mix-sigra-migrate-schema-helper.md` (installer, 0.4) — installer feature, out of scope.
- `2026-06-20-runtime-auth-prefix-override.md` (config, 0.4) — config feature, out of scope.
</deferred>
