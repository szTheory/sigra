# Phase 201: Users Index Elevation - Context

**Gathered:** 2026-06-26 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Award-grade (Tier-1 → Tier-2) elevation of the generated admin **Users Index** page
(`lib/sigra/admin/live/users_index_live.ex`): one coherent filter/search experience, a
non-blocking/demoted metric strip, a content-equivalent **and DRY** desktop-table ⇄ mobile-card
presentation, and honest pagination — proven award-grade across the full viewport/theme/state
matrix including the Phase-199 list-scale fixtures.

In scope (INDEX-01..04):
- Consolidate the filter UI into one coherent panel (search + quick toggles + advanced disclosure
  + applied-filter-chip state), eliminating the detached applied-chips sibling block.
- Demote/slim the "User health" metric strip so search is the dominant first affordance, and reduce
  per-row status pills to the ones that carry operator decision value.
- DRY the duplicated desktop-table and mobile-card per-row presentation behind a shared component,
  preserving table semantics on desktop and `sg-kv` on mobile, with honest pagination proven against
  list-scale fixtures.
- Ratchet the `users-index-live` ledger cell Tier 1 → Tier 2 with proxy evidence and recapture only
  the affected non-canary slugs.

Out of scope (later phases): Audit surfaces (202), consistency propagation to Overviews/Branding/
gallery (203), terminal ratification / allowlist reset / adversarial review (204). This phase does
**not** re-grade any cell other than `users-index-live`, and does **not** touch the data/query layer
beyond what view trimming requires (the `summary_stats`/`list` queries stay functionally intact).
</domain>

<decisions>
## Implementation Decisions

### Filter Consolidation (INDEX-01)
- **D-01:** Merge the three filter-related regions into **one coherent panel**. The form already IS
  one `sg-filter-panel` containing search row (`:157-171`), quick-filter chips cluster (`:173-175`),
  and the "More filters" disclosure (`:177-229`). The **only** detached piece is the applied-filter-chip
  state block (`:236-243`), a sibling `<div>` *after* `</form>` (`:234`). Move the applied-chip row up to
  sit directly under the search row **inside or visually contiguous with** the panel. This is a
  markup/composition reflow — the data is already present: `applied_chips/1` (`:531-550`),
  `any_filter_active?/1` (`:524-528`), `remove_chip_path/4` (`:566-574`), `@quick_filter_keys` /
  `@more_filter_keys` (`:14-15`).
- **D-02:** **Preserve the GET-form submission contract.** Keep `<form method="get" action={index_path}>`
  (`:156`) and quick-filter chips as form checkboxes (`quick_filter/1` `:399-412`, `name={@key}` value
  `"true"`) — do **not** convert chips to `phx-click`. Only `toggle_filters` (`:66-68`) stays a LiveView
  event. Filter/pagination state must stay URL-driven so deep-linking, the `return_to` round-trip in
  `open_user_path/3` (`:606-622`), and pagination URLs (`page_path/3`) keep working. **Risk to verify:**
  if any input ends up outside the `<form>`, search silently stops submitting — the current
  `admin-design.spec.ts` equivalence test navigates with pre-built query strings and would NOT catch a
  broken form. Plan should add/keep a test that actually submits the form.

### Metric Strip Demotion + Pill Reduction (INDEX-02)
- **D-03:** **Slim and demote the "User health" metric strip** (`<section aria-labelledby="users-health-heading">`,
  `:91-149`) — move it **below** the filter/search panel in visual + DOM order (it currently renders first,
  literally burying search, which INDEX-02 prohibits). Do **not** delete it and do **not** hide it behind
  `<details>`. Cut the six `summary_chip`s to the decision-bearing few (default: Total + Locked +
  Deletion-scheduled — the risk/warn-toned ones at `:136`/`:146`), dropping or collapsing the always-"ok"
  Confirmed / MFA-coverage / Passkey-coverage posture KPIs (those belong on the Overview, not gating the
  Users list). `Query.summary_stats/3` (`:171-208`) may stay intact (cheap aggregates); if any chip key is
  dropped from the view, keep `empty_summary_stats/0` (`:465-478`) and `summary_count/2` (`:483-484`) in
  sync so a dropped key can't silently mask a wiring bug. Precedent: Phase 200 slimmed (not deleted) the
  Detail facts row — "slim, don't delete."
- **D-04:** **Reduce per-row `status_pills/1`** (`:415-430`) to decision-bearing signals only. Keep
  `Unconfirmed` (warn), `Locked` (risk), `Deletion scheduled` (warn); **drop the always-present `Confirmed`
  (ok) pill** and **collapse the four-way security pill** (`MFA + passkeys` / `MFA` / `Passkeys` / `No MFA`,
  `:419-425`) to surface only the actionable `No MFA` (or nothing when secured). Rationale: in a list of 45
  users the JTBD is scan-for-exceptions; green pills on nearly every row are noise. This **deliberately
  diverges from User Detail** (which keeps full posture) because the JTBD differs. **Watch:** the
  `assertUserResultEquivalence` token check reads only the first 2 pills (`admin-design.spec.ts:157`), so
  over-pilling won't fail CI — the Tier-2 density/"reviewed" proxy is the only guard; don't over-cut either
  (dropping `Locked` would gut the `needs_review` filter's at-a-glance signal, `query.ex:353-357`).

### DRY Desktop-Table ⇄ Mobile-Card (INDEX-03)
- **D-05:** **DRY the duplicated per-row presentation via a shared function component** (e.g.
  `<.user_row_fields row={row} />`) emitting the field set once — primary_name / email / id / status_pills /
  extra_badges / organization_summary / activity / registered / extra_columns — with the desktop `<td>`
  cells and the mobile `<dl class="sg-kv">` as the only layout-specific shells. **Not** a CSS-only reflow of
  one markup block (that would abandon the desktop table semantics the sort headers + `td:nth-child`
  equivalence selectors depend on, and lose the blessed `sg-kv` mobile pattern). Precedent: the audit feed
  (`admin-audit-desktop-results` / `admin-audit-mobile-results`) keeps separate DOM + proves equivalence via
  a shared token set. Desktop `<tr>` is `:261-295`; mobile `<article>` is `:305-345` (currently hand-duplicated,
  e.g. status pills at `:271-275` vs `:313-317`).
- **D-06 (hard lockstep — frozen column order):** The desktop column order **User / Status / Organizations /
  Activity / Action** (headers `:253-257`) MUST be preserved, because `assertUserResultEquivalence`
  (`admin-design.spec.ts:151-164`) extracts equivalence tokens by **position** — `td:nth-child(3) span`
  (Organizations) and `td:nth-child(4) span` (Activity) at `:158-159`. Any reorder/insert/removal of a
  column MUST update those selectors in the **same** change, or the gate silently reads the wrong cells.
- **D-07 (host-seam contract):** `extra_badges` and `extra_columns` (host hooks `extra_list_badges/1` +
  `extra_list_columns/0`, produced by `decorate_rows/2` `query.ex:534-549`; rendered desktop `:274`/`:287`,
  mobile `:316`/`:335-337`) are a **frozen semver/generated-host contract** that MUST survive in **both** the
  desktop and mobile copies of the DRY refactor. The example returns `[]` (`test/example/lib/example/sigra_admin_users.ex:20,23`)
  so CI will NOT catch a one-sided drop — the same blind spot as Phase 200's `extra_detail_sections`. **Plan
  should** make the example hook emit one non-empty badge + column so the live equivalence spec actually
  exercises the seam. The `badge_text/1` (`:656-658`) and `column_text/2` (`:660-667`, dual map-shape reads)
  helpers are part of the frozen contract.
- **D-08 (honest pagination — already implemented, prove it):** `multi_page?/1` (`:513-517`) →
  `all_results_label/1` single-page text (`:359-364`) vs `<nav>` (`:366-390`) already implements "no
  pagination affordance when nothing to paginate" (INDEX-03's honest clause). This phase **proves** it against
  the Phase-199 list-scale fixtures (36 `loadtest-*` users + 9 personas = 45 → 2 pages at `page_size: 25`,
  Flop `default_limit: 25` `query.ex:65`). The capture harness must boot against a **dev DB with seeds run**
  (seeds are `MIX_ENV=dev`-only, hard-blocked in test) or the checkpoint captures an under-populated
  single-page list and the overflow elevation goes unproven.

### Tier-2 Ratchet & Recapture Blast Radius (INDEX-04)
- **D-09:** Ratchet the `users-index-live` ledger cell — flip column-4 integer `1`→`2` (**bare single
  `[012]` integer, no decorators** — the monotonic guard's positional `awk -F'|'` parse depends on it) at
  `admin-quality-ledger.md:87`, mirroring the `user-show-live` Tier-2 cell at `:88`. Expand its Evidence
  column to cite the **applicable** Tier-2 proxies (per `admin-fractal-scorecard.md` Tier-2 Add-on
  `~:123-167`): content-equivalence (MG-5/6 + the live `assertUserResultEquivalence`), glossary-clean
  (`glossary_test.exs:24` already scopes `users_index_live.ex`), plus documented-as-manual motion-tokens /
  density rhythm (`sg-stack--6`/`--4`) / target-size ≥24px. The **overlay-axe + 7-APG-gate proxies are
  EXEMPT** — the index owns no modal dialog (unlike Detail/Sessions) — cite them as N/A, do not fabricate.
- **D-10:** **Recapture only the affected non-canary slugs through the recapture gate**
  (`snapshot-recapture-gate.sh`), not the canary guard. Blast radius: the **`global-user-index`** checkpoint
  slug (3 PNGs `-chromium`/`-dark`/`-mobile`, `admin-checkpoints.spec.ts:215-216`) and the `mg-5`/`mg-6`
  design-gallery boards if their markup changes. The relevant canary must stay byte-stable. Prove zero-drift
  idempotency (Phase-192/199 method, `admin-quality-ledger.md:115-118`) before baking new baselines. Leave
  allowlists empty at end-of-phase (Phase 204 owns terminal reset; 201 stays green on its own).
- **D-11 (CSS triple-copy lockstep):** Any new/changed `sg-*` CSS must be written **byte-identically** into
  all three currently-identical copies — `priv/templates/sigra.install/admin/sigra_admin.css`,
  `test/example/priv/static/assets/sigra_admin.css`, `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`
  (shared md5, golden-diff gated) — or the install golden-diff test fails and generated hosts get an unstyled
  page (the 184→185 regression class). **Note:** `sg-chevron` (used at `:185`) currently has **zero** CSS
  rules in the triple-copy — it's unstyled; during consolidation either style it or drop it.
- **D-12 (design contract update):** Rewrite the **stale List Archetype block** in
  `admin-design-contract.md:211-243` to document the elevated composition (it already describes markup the
  code does not render — e.g. a `sg-page-copy` line in the metric strip the header `:78-81` doesn't emit).
  Phase 200 set precedent rewriting the Detail Archetype block (`:251-296`).

### Claude's Discretion
- Exact placement of the applied-chip row within/adjacent to the consolidated panel (under the search row
  vs below the quick-filter cluster).
- Exact final metric set on the slimmed strip (Total + Locked + Deletion-scheduled is the default; a single
  compact coverage line is acceptable if it stays subordinate to search).
- Precise reduced pill vocabulary and whether a fully-secured row shows zero security pills vs a quiet marker.
- The shared row-fields component's name, arg shape, and how much layout chrome stays in the desktop/mobile
  shells vs the shared component.
- Whether the example's `extra_list_badges`/`extra_list_columns` seam-coverage hook (D-07) is added this
  phase or tracked — strongly preferred this phase since it's low-cost and closes a real generated-host blind
  spot.
- Whether `sg-chevron` is styled or removed (D-11).
- Microcopy wording (auto-guarded glossary-clean via `glossary_test.exs:24`).

### Folded Todos
- None folded. All 12 matched todos (Playwright per-shard-DB parallelization, PAGE-04 branding scoring,
  UAT demo-DX nits, `mix sigra.migrate_schema`, runtime auth-prefix override, Phase-199 INFO hardening,
  Phase-200 deferred session-revocation hardening, token-reference CI guard, app.css comment corruption,
  white-label email theming) are outside a Users-Index UI elevation — same call Phase 200 made. See Deferred.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `lib/sigra/admin/live/users_index_live.ex` — page under elevation: metric strip (`:91-149`), filter form
  (`:151-234`), detached applied-chip block (`:236-243`), desktop table (`:248-300`), mobile cards (`:305-345`),
  empty state (`:347-358`), honest-pagination (`:359-390`), `quick_filter/1` (`:399-412`), `status_pills/1`
  (`:415-430`), `summary_chip`/`summary_count`/`empty_summary_stats` (`:465-484`), `multi_page?`/`showing_range`/
  `all_results_label` (`:513-522`), `applied_chips`/`any_filter_active?`/`remove_chip_path` (`:524-574`),
  `open_user_path`/`page_path`/`index_path` (`:606-622`), `badge_text`/`column_text` (`:656-667`),
  `@quick_filter_keys`/`@more_filter_keys` (`:14-15`).
- `lib/sigra/admin/users/query.ex` — data loader: Flop `default_limit: 25` (`:65`), `summary_stats/3`
  (`:171-208`), `needs_review` filter (`:353-357`), `decorate_rows/2` host-seam reads (`:534-549`).
- `lib/sigra/admin/users/hooks.ex` + `lib/sigra/admin/users/default_hooks.ex` — `extra_list_badges/1` +
  `extra_list_columns/0` host-seam callbacks that MUST be preserved (D-07).
- `test/example/lib/example/sigra_admin_users.ex` (`:20,23`) — example returns `[]` for both list seams; the
  no-op that hides a one-sided DRY regression (D-07).
- `test/example/priv/playwright/tests/admin-design.spec.ts` (`:151-164`, `:158-159`, `:347-351`) —
  `assertUserResultEquivalence` + the positional `td:nth-child(3)/(4)` selectors (D-06).
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (`:215-216`) — `global-user-index` checkpoint
  slug (3 PNGs) to recapture (D-10).
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — `mg-1` metric-strip / `mg-2` filter /
  `mg-5`/`mg-6` desktop-mobile-equivalence boards (recapture iff markup changes, D-10).
- `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`,
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — the three byte-identical CSS copies
  that must move in lockstep (D-11); `sg-chevron` currently unstyled.
- `guides/reference/admin-design-contract.md` (`:211-243` List Archetype to rewrite, D-12; `:294` host-seam
  blind-spot note).
- `guides/reference/admin-ui-principles.md` — binding IA/motion rules (progressive reveal, same-job-same-component,
  no `transition: all`).
- `guides/reference/admin-fractal-scorecard.md` (`~:123-167`) — Tier-2 Add-on proxy definitions (D-09).
- `guides/reference/admin-quality-ledger.md` (`:14-27` parse rules, cell `:87` to ratchet, `:88` Tier-2
  precedent, `:115-118` idempotency proof method) (D-09, D-10).
- `scripts/ci/snapshot-recapture-gate.sh` + `scripts/ci/snapshot-canary-guard.sh` + `scripts/ci/quality-ledger-monotonic.sh`
  — recapture routing + the positional ledger parse (D-09, D-10).
- `test/sigra/admin/glossary_test.exs` (`:24`) — glossary-clean proxy already scopes `users_index_live`.
- `test/example/lib/example/demo/seeds.ex` (`:11-13`, `:43-47`, `:96-119`) — Phase-199 FIXT-02 list-scale
  cohort (36 `loadtest-*` users) + admin persona ≥25 events that make the index paginate/overflow (D-08).
- `.planning/phases/199-foundation-tier-2-scorecard-stress-fixtures/199-CONTEXT.md` and
  `.planning/phases/200-user-detail-elevation/200-CONTEXT.md` — the Tier-2 instrument, stress fixtures, and
  shared component/lockstep patterns this phase consumes.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The filter form is already a single `sg-filter-panel` (search + quick chips + advanced disclosure); only the
  applied-chip state floats as a detached sibling — consolidation is mostly relocation (D-01).
- `applied_chips/1`, `any_filter_active?/1`, `remove_chip_path/4` already produce the applied-filter state; no
  new data logic needed (D-01).
- Honest pagination is already implemented via `multi_page?/1` + `all_results_label/1` + `showing_range/3`
  (`:513-522`, `:359-390`) — this phase proves it at list-scale, not builds it (D-08).
- `summary_stats/3` computes all six metrics regardless of how many the view renders — slimming the strip needs
  no query change (D-03).
- The audit feed's separate-DOM + shared-token-equivalence pattern is the in-repo precedent for DRY
  desktop/mobile (D-05).
- `glossary_test.exs:24` already scopes `users_index_live` — new microcopy is auto-guarded glossary-clean.

### Established Patterns
- Quality-ledger column-4 = single `[012]` integer (no decorators); the monotonic guard's positional `awk`
  parse depends on it — flipping to `2` is numerically "free" but must stay un-decorated.
- Admin CSS ships installer-template → generated host as `sigra_admin.css`; the three copies are
  byte-parity-gated (golden-diff). Known drift hazard: the template copy lags the example unless hand-propagated.
- Playwright equivalence helpers read row content by **column position** (`td:nth-child`), coupling LiveView
  markup order to the spec — column order is a contract, not a layout detail (D-06).
- List host seams (`extra_list_badges`/`extra_list_columns`) are read-only data callbacks; the example's `[]`
  default won't catch a break — same blind-spot class as Phase 200's `extra_detail_sections` (D-07).
- Seeds are `MIX_ENV=dev`-only (hard-blocked in test); list-scale overflow only renders when the capture
  harness boots a dev DB with seeds run (D-08).

### Integration Points
- New/changed `sg-*` classes → CSS triple-copy + (if structural) gallery boards + design-contract List
  Archetype block + `global-user-index` checkpoint recapture.
- Ledger cell ratchet → monotonic guard (merge-blocking, `--base origin/main`) protects it forward-only.
- Example list-seam hook (`sigra_admin_users.ex`) is the lever to give the equivalence spec real
  `extra_badges`/`extra_columns` coverage (D-07).
</code_context>

<specifics>
## Specific Ideas

- Metric strip default slim set: **Total + Locked + Deletion-scheduled** (the risk/warn-toned chips); coverage
  KPIs (Confirmed/MFA/Passkey %) demoted off the list or into one subordinate line.
- Reduced row pills: **Unconfirmed / Locked / Deletion-scheduled** kept; **Confirmed** dropped; security pill
  collapsed to surface only **No MFA**.
- DRY mechanism: a shared `<.user_row_fields row={row}/>`-style function component, desktop `<td>` + mobile
  `sg-kv` shells only.
- Close the host-seam blind spot by having the example emit one non-empty `extra_list_badges` +
  `extra_list_columns` value (strongly preferred this phase).
</specifics>

<deferred>
## Deferred Ideas

- No scope-creep ideas surfaced — discussion stayed within the Users-Index boundary.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db.md` (ci, 0.9) — CI infra, not UI elevation.
- `2026-06-17-page04-branding-explicit-scoring.md` (admin-ui, 0.6) — Branding workbench scoring, Phase 203 territory.
- `2026-06-19-uat-demo-dx-polish-nits.md` (dx, 0.6) — demo-DX flags, unrelated.
- `2026-06-20-mix-sigra-migrate-schema-helper.md` (installer, 0.6) — installer feature, out of scope.
- `2026-06-20-runtime-auth-prefix-override.md` (config, 0.6) — config feature, out of scope.
- `2026-06-25-phase199-code-review-info-hardening.md` (test, 0.6) — fixture/self-test hardening, not the index page.
- `2026-06-25-phase200-code-review-deferred.md` (admin-ui, 0.6) — token-scoped session-revocation hardening on
  the Phase-200 Sessions surface, not the Users Index.
- `2026-06-18-token-reference-completeness-ci-guard.md` (test, 0.4) — CI guard, unrelated.
- `2026-06-21-app-css-comment-corruption-cleanup.md` (example-css, 0.4) — example app.css cleanup, separate surface.
- `2026-06-22-white-label-auth-email-theming.md` (email, 0.2) — email theming, unrelated.
</deferred>
