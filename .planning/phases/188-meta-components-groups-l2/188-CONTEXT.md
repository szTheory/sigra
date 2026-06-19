# Phase 188: Meta-Components / Groups (L2) - Context

**Gathered:** 2026-06-15 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

The L2 meta-component/group audit-and-improve layer of the v1.39 DS-COHERENCE milestone.
Bring the MG-1..MG-11 group catalog to the meta scorecard bar: intra-group rhythm,
no card-in-card nesting, right-component-for-job composition, populated/zero/loading/error
states, content-equivalent desktop-table to mobile-card swaps, and byte-coherent reuse
across pages. Raise the L2 ledger rows with deterministic evidence.

**In scope:** GROUP-01..04; the `/admin/_design` L2 group boards; `admin-design-*`
Playwright coverage for group boards; L2 scorecard/ledger updates; group-level CSS that must
ship to generated hosts; and the folded Phase 186 D-11 parity/test-hardening cleanup.

**Out of scope:** token value changes (Phase 186 only); re-litigating the L1 component
winners ratified in Phase 187; new admin screens/features/navigation; page composition scoring
(Phase 189); flow/persona fixture enrichment (Phase 190); system-wide microcopy/glossary work
(Phase 191); generated auth UI redesign.
</domain>

<decisions>
## Implementation Decisions

### MG Catalog Source Of Truth
- **D-01:** Phase 188 uses the approved `188-UI-SPEC.md` MG-1..MG-11 catalog as the source
  of truth, not the stale current MG-1..MG-5 docs and gallery. Update the gallery,
  `GROUP_BOARDS`, L2 scorecard copy, quality ledger, and evidence links together.
- **D-02:** The final L2 catalog is:
  MG-1 Metric/Summary Strip, MG-2 Filter Panel + Applied-chip Row, MG-3 Task-card Grid,
  MG-4 Alarm Notice Band, MG-5 User Results + Pagination, MG-6 Audit Feed + Pagination,
  MG-7 Organization Member Roster, MG-8 Pending Invitations, MG-9 Identity Header +
  Summary Facts, MG-10 Detail Facts + Membership Panels, and MG-11 Destructive Action +
  Confirmation.

### Shipped Group CSS
- **D-03:** Any L2 group/layout CSS required for MG-1..MG-11 must live in the canonical
  shipped stylesheet `priv/templates/sigra.install/admin/sigra_admin.css`, with
  `test/example/priv/static/assets/sigra_admin.css` and
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` kept byte-identical.
  Do not leave required group styling in example-only `test/example/priv/static/assets/css/app.css`.
- **D-04:** Treat this as the L2 continuation of Phase 187's L1 shipped-CSS migration.
  Current group-level classes that need review for migration include `sg-table`, `sg-kv`,
  `sg-detail-grid`, `sg-confirm-overlay`, `sg-confirm-dialog`, `sg-danger-panel`,
  `sg-search-row`, `sg-form-grid`, `sg-filter-chip`, `sg-summary-facts`, `sg-list`,
  `sg-action-row`, `sg-truncate`, `sg-tabular`, and related table/detail/confirmation rules.
- **D-05:** Migrated group rules belong in the existing `@layer sg-components` structure,
  must depend only on `var(--sg-*)` tokens or established token-safe CSS primitives, and must
  not re-tune Phase 186 token values. Preserve the DIST-05 parity surfaces on every edit.

### Group Boards And State Evidence
- **D-06:** `/admin/_design` must render `board-mg-1` through `board-mg-11` with stable ids.
  Each board should render populated, zero, loading, and error variants when the state is
  reachable. If a state is impossible, document that on the board or in verification notes.
- **D-07:** Add group-level responsive/overflow assertions at 320, 375, 768, 1024, and
  1440px. The current responsive assertion covers `COMPONENT_BOARDS` only; Phase 188 must cover
  group boards too.
- **D-08:** Add explicit MG-5 and MG-6 desktop-table to mobile-card equivalence assertions:
  primary identity/event, status/outcome, secondary facts, action/navigation affordance, and
  identifiers must be present in both representations at the breakpoint.
- **D-09:** Board screenshots remain one composite state-matrix PNG per group per project
  (`admin-design-chromium`, `admin-design-mobile`, `admin-design-dark`), paired with axe
  `wcag2a` and `wcag2aa` scans. Use role selectors, stable ids/test ids, LiveView readiness
  gates, and no sleeps.

### Composition Quality
- **D-10:** Production group markup and scored board content must avoid `.sg-card .sg-card`.
  If a gallery wrapper is needed around a group that itself contains cards, make the wrapper
  unframed or explicitly mark it as an audit-only wrapper excluded from the group score.
- **D-11:** Groups must use the right L1 component for the job: `summary_chip` for metrics,
  `applied_chip` for removable filter state, `task_card` for action prompts, `notice` for
  contextual group alerts, `empty_state` for zero data, `skeleton` for loading, and `audit_row`
  for mobile/compact audit rows. Do not introduce bespoke one-off markup when a ratified
  component covers the job.
- **D-12:** Reused groups across two or more pages must render byte-coherently for equivalent
  data. Named density/scope variants are allowed only when the variant is documented in the
  board label and ledger evidence.

### MG-11 Confirmation Coherence
- **D-13:** Standardize MG-11 on `sg-confirm-overlay` / `sg-confirm-dialog` for the L2
  destructive-confirmation contract. `BrandingLive` already uses this pattern; `UserShowLive`
  currently uses a DaisyUI `<dialog class="modal">` and should be brought into the Sigra-owned
  confirmation pattern if Phase 188 touches MG-11.
- **D-14:** Confirmation copy must name the action and consequence. Destructive actions remain
  visually secondary until explicitly armed/confirmed, with focus-visible treatment and
  Escape/cancel behavior preserved for the page-level follow-up in Phase 189.

### Folded Todos
- **D-15:** Fold `2026-06-14-phase-186-review-deferred.md` into Phase 188. Implement the
  D-11 parity/test-harness hardening as a focused UI-neutral slice: structural dark-block and
  token extractors in `test/sigra/install/features/admin_test.exs`, hoist/dedupe the duplicated
  `readNoticeStyles` helper in `admin-theme.spec.ts`, and add a lightweight
  `admin-token-reference.md` completeness guard if it can be done without expanding product
  scope.
- **D-16:** The folded todo must not change token values or broaden Phase 188 into a new L0
  token audit. It is accepted as test-harness robustness because the user explicitly chose to
  fold it into this phase.

### the agent's Discretion
- Exact migration sequencing for group CSS families, as long as canonical/example/golden CSS
  parity stays green.
- Exact board layout for each MG state matrix, provided it uses stable ids and avoids scored
  card-in-card nesting.
- Exact ledger tier achieved for each L2 row after evidence is produced; monotonic guard rules
  apply.
- Whether MG-11 confirmation standardization lands in the same slice as group CSS migration or
  in a later Phase 188 slice.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Contract
- `.planning/ROADMAP.md` - Phase 188 goal and success criteria.
- `.planning/REQUIREMENTS.md` - GROUP-01..04 and milestone scope exclusions.
- `.planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md` - approved MG-1..MG-11
  UI design contract, state table, desktop/mobile equivalence matrix, copy rules, and
  verification contract.
- `.planning/METHODOLOGY.md` - decisive defaulting and escalation threshold.

### Upstream Decisions
- `.planning/phases/184-distribution-parity/184-CONTEXT.md` - canonical `sigra_admin.css`
  distribution and byte-parity machinery.
- `.planning/phases/185-audit-infrastructure/185-CONTEXT.md` - `/admin/_design`, `admin-design-*`,
  allowlists, canary, scorecard, ledger, and monotonic guard.
- `.planning/phases/186-token-foundation-l0/186-CONTEXT.md` - frozen token-value boundary,
  dark/system parity context, and D-11 parity truth claim.
- `.planning/phases/187-individual-components-l1/187-CONTEXT.md` - shipped L1 component CSS
  migration precedent and L1 component winners.
- `.planning/phases/187-individual-components-l1/187-CSS-INVENTORY.md` - exact L1 migration
  inventory and parity surface pattern.
- `.planning/phases/187-individual-components-l1/187-VALIDATION.md` - final L1 validation
  commands and admin-design evidence shape.

### Design References
- `guides/reference/admin-ui-principles.md` - admin IA, design-system, theme, motion, and
  deterministic testing principles.
- `guides/reference/admin-design-contract.md` - same-job-to-same-component contract, page
  archetypes, and confirmation-dialog warning.
- `guides/reference/admin-fractal-scorecard.md` - D1-D11 scorecard and L2 add-ons; update stale
  MG-1..MG-5 copy to MG-1..MG-11.
- `guides/reference/admin-quality-ledger.md` - L2 ledger rows; update stale MG-1..MG-5 rows and
  evidence links.
- `guides/reference/admin-token-reference.md` - token reference and folded completeness-guard
  target.
- `brandbook/` - Rail Accent brand source of truth.

### Code And Test Surfaces
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` - current group boards
  MG-1..MG-5; expand and harden to MG-1..MG-11.
- `test/example/priv/playwright/tests/admin-design.spec.ts` - `GROUP_BOARDS`, board snapshots,
  axe, component responsive assertion; extend for L2.
- `priv/templates/sigra.install/admin/sigra_admin.css` - canonical shipped admin stylesheet.
- `test/example/priv/static/assets/sigra_admin.css` - byte-identical example mirror.
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` - byte-identical
  generated-host golden mirror.
- `test/example/priv/static/assets/css/app.css` - example-only CSS; remaining L2 group rules must
  be reviewed and migrated when they are required by generated hosts.
- `test/sigra/install/features/admin_test.exs` - admin CSS parity tests and folded D-11 extractor
  hardening target.
- `test/example/priv/playwright/tests/admin-theme.spec.ts` - folded `readNoticeStyles` dedupe
  target.

### Admin LiveViews
- `lib/sigra/admin/live/index_live.ex` - MG-1, MG-3, MG-4 source usage.
- `lib/sigra/admin/live/users_index_live.ex` - MG-1, MG-2, MG-5 source usage.
- `lib/sigra/admin/live/audit_index_live.ex` - MG-2, MG-6 source usage.
- `lib/sigra/admin/live/audit_user_live.ex` - MG-2, MG-6, MG-9 source usage.
- `lib/sigra/admin/live/organization_live.ex` - MG-3, MG-4, MG-7, MG-8 source usage.
- `lib/sigra/admin/live/user_show_live.ex` - MG-9, MG-10, MG-11 source usage and modal drift.
- `lib/sigra/admin/live/branding_live.ex` - existing `sg-confirm-overlay` / `sg-confirm-dialog`
  confirmation precedent.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 187 already proved the pattern for moving audit-relevant visual/state CSS from
  example-only `app.css` into canonical `sigra_admin.css`, then syncing the example and golden
  mirrors.
- The `admin-design-{chromium,mobile,dark}` lane already logs in deterministically, waits for
  LiveView readiness, scans axe, and captures element-scoped board screenshots.
- The L1 component boards already provide reusable state-matrix idioms for labels, deterministic
  open/help states, disabled examples, reduced-motion checks, and no-overflow assertions.
- `Sigra.Admin.Components` provides the L1 pieces that L2 groups should compose rather than
  duplicating: `summary_chip`, `applied_chip`, `task_card`, `notice`, `notice_link`,
  `empty_state`, `skeleton`, `audit_row`, and supporting button/status classes.

### Established Patterns
- Canonical shipped CSS lives in `priv/templates/sigra.install/admin/sigra_admin.css`; example
  and install-golden copies are byte mirrors.
- The example app is allowed to contain example-only host/branding glue, but not required
  generated-host admin group styling.
- L2 board evidence should stay deterministic: stable ids, role selectors, `data-testid` hooks,
  and no sleeps.
- Tier cells in `admin-quality-ledger.md` are machine-parseable integers; the monotonic guard
  treats existing tiers as the floor.
- Empty allowlists are the steady state. Intended visual deltas must be deliberately recaptured
  and canary-guarded.

### Integration Points
- `design_gallery_live.ex`: expand MG boards to MG-1..MG-11 and render state variants.
- `admin-design.spec.ts`: expand `GROUP_BOARDS`, add group responsive checks, add MG-5/MG-6
  equivalence checks, keep axe paired with board snapshots.
- `admin-fractal-scorecard.md`: update stale "5 meta-component group boards" wording to MG-1..MG-11.
- `admin-quality-ledger.md`: replace/expand stale L2 rows and evidence links for MG-1..MG-11.
- `sigra_admin.css` plus its mirrors: migrate required table/detail/filter/confirmation/group
  rules from `app.css`.
- `UserShowLive`: likely MG-11 confirmation standardization target.
- `admin_test.exs`, `admin-theme.spec.ts`, and `admin-token-reference.md`: folded Phase 186
  test-hardening targets.
</code_context>

<specifics>
## Specific Ideas

- The non-obvious risk mirrors Phase 187: an L2 quality pass can look correct in the example
  gallery while generated hosts remain partially unstyled if table/detail/filter/confirmation
  group rules stay in `app.css`.
- The stale MG-1..MG-5 references are not a product decision; they are implementation drift from
  the Phase 185 starter infrastructure and must yield to the approved Phase 188 UI spec.
- `board-mg-3` currently nests task cards inside a `.sg-card` board wrapper; Phase 188 should
  make scored group wrappers unframed where the group contains cards.
- `BrandingLive` already demonstrates the desired `sg-confirm-overlay` pattern for MG-11, while
  `UserShowLive` still shows the modal outlier.
</specifics>

<deferred>
## Deferred Ideas

- Page-level overlay/focus/scroll behavior, page archetype scoring, sticky/scroll behavior, and
  pagination honesty beyond L2 group evidence - Phase 189.
- Flow/persona happy/error/boundary fixture enrichment - Phase 190.
- System-wide microcopy and one-term-per-concept glossary - Phase 191.
- Final generated-host parity and baseline lock - Phase 192.
- Example auth CSS de-staling remains outside this phase unless a separate maintenance task
  promotes it.

### Reviewed Todos (not folded)
None from the displayed match set. The matched Phase 186 D-11 parity cleanup was folded by user
choice.
</deferred>

---

*Phase: 188-meta-components-groups-l2*
*Context gathered: 2026-06-15*
