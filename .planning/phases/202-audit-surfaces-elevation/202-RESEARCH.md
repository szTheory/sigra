# Phase 202: Audit Surfaces Elevation - Research

**Researched:** 2026-06-26
**Domain:** Phoenix LiveView admin-UI elevation (Elixir/HEEx) — DRY shared function components, content-equivalence proof contracts, Tier-2 quality-ledger ratchet, snapshot-recapture blast radius
**Confidence:** HIGH (all claims verified against live code this session; no external/registry deps — this is an in-repo refactor phase)

> No package research applicable: Phase 202 installs nothing, adds no dependency, and runs
> entirely against the existing Sigra codebase. The `## Package Legitimacy Audit`,
> `## Standard Stack`, and `## Environment Availability` sections are therefore N/A and omitted
> (no external dependencies — purely code/markup/doc changes). This is the same posture Phases
> 200 and 201 took.

<user_constraints>
## User Constraints (from CONTEXT.md)

> CONTEXT.md (202-CONTEXT.md) is in **assumptions mode** with 14 locked decisions (D-01..D-14).
> These are LOCKED — research verifies and equips them, it does not re-open them.

### Locked Decisions (verbatim intent)

**Filter Consolidation + Advanced-Disclosure + Export (AUDIT-01)**
- **D-01:** Converge both pages on one coherent `sg-filter-panel` form. Index is already a single panel; the real surgery is `audit_user_live.ex`, which has THREE forms (two standalone quick-toggle forms `:81-108` outside/above the main filter form `:110-164`). Fold the toggles into the main form as GET checkboxes.
- **D-02:** Add a native CSS-only `<details>` advanced-disclosure holding the text/date fields on both pages. Quick toggles (Failures / Impersonation) stay visible as folded-in summary controls. No `phx-hook`. If a chevron is used, reuse an existing styled class — `sg-chevron` is unstyled in the triple-copy.
- **D-03:** Preserve the GET-form / URL-driven contract. `handle_params` is the only state path. Do NOT convert toggles to `phx-click`. Keeps deep-linking, the `?action_prefix=admin.impersonation` checkpoint entry path, and the `return_to` round-trip working.
- **D-04:** Export stays in the filter action row on both pages — it is already there. Do NOT relocate Export. Verify it lands in the consolidated action row after the form reflow.

**Column-Density Reduction + Inline Code Disclosure (AUDIT-02)**
- **D-05:** Drill-down = inline disclosure, NO new route (user-ratified). Move raw event id (`row.id`) and raw action code (`row.action`) out of the primary desktop columns into an in-row progressive-disclosure affordance, reusing the mobile card's `show_detail`/`show_codes` pattern. Primary cells keep human `action_label` + `action_badge`. No `AuditEventLive`, no `/admin/audit/:event_id`. CSV `event_id` MUST be preserved.
- **D-06:** Positional-selector lockstep (HARD). Removing/relocating the code column MUST update the Playwright equivalence selectors in the SAME change. `assertAuditResultEquivalence` extracts tokens from `code.sg-code` (2 codes) + Actor column `td:nth-child(3) span`. If codes leave the primary DOM, `firstTexts(..., 'code.sg-code', 2)` returns <2 tokens and the assertion silently weakens to a rubber stamp (the 201 D-06 failure mode). Update MG-6 + live `/admin/audit` + per-user checks in lockstep; disclosed codes must stay extractable by the revised selector.
- **D-07:** Mobile-first stacking. Mobile card is already DRY via `<.audit_row>`; keep it canonical and ensure disclosed codes render in the mobile expansion. Desktop reduces to human columns + inline disclosure.

**Byte-Coherence (AUDIT-02)**
- **D-08:** DRY the duplicated shared markup into function components. Desktop `<table>` body, pagination `<nav>`, empty state, and ~8 private helpers are hand-duplicated. Extract shared desktop-table row, pagination `<nav>`, empty-state into shared function components (201 `<.user_row_fields>` precedent). Shared helpers move to one shared module.
- **D-09:** Preserve legitimate per-page divergence. Byte-coherence applies to SHARED markup, not wholesale identity. Index `@chip_keys` is 6-key; per-user is 5-key; per-user has breadcrumbs/header/`return_to`. Align the chip-key lists and column sets feeding the shared component.

**Pagination Proof (AUDIT-02)**
- **D-10:** Prove, don't build. Honest cursor pagination is already implemented (`multi_page?/1` hides `<nav>` when no next/prev cursor). Default page size 25. The ≥25-event admin persona fixture exists (FIXT-01). Capture harness must boot a dev DB with seeds run (seeds are `MIX_ENV=dev`-only, hard-blocked in test). STRONGLY PREFER also adding a deterministic ExUnit LiveView test asserting `<nav>` present at ≥26 rows / absent at ≤25.

**Tier-2 Ratchet, Recapture & Docs (AUDIT-03)**
- **D-11:** Ratchet two ledger cells. Flip column-4 `1`→`2` for `audit-index-live` (`:90`) and `audit-user-live` (`:91`) — bare single `[012]` integer, no decorators. Cite applicable Tier-2 proxies: content-equivalence, glossary-clean, motion-tokens / density-rhythm / target-size (manual). Overlay-axe + 7-APG-dialog gates are N/A (neither page owns a modal) — cite as N/A, do not fabricate.
- **D-12:** Recapture only affected non-canary slugs via `snapshot-recapture-gate.sh` (not canary guard). Blast radius: `audit-explorer` + `user-audit` checkpoint slugs (3 PNGs each) + `mg-6` board iff markup changes. Prove zero-drift idempotency. Leave both allowlists empty at end-of-phase.
- **D-13:** CSS triple-copy lockstep. Any new/changed `sg-*` CSS must be byte-identical across all three copies or golden-diff fails (184→185 unstyled-host regression class). Audit pages reuse existing classes, so a disclosure-only reflow may need zero new CSS — but any chevron / new class triggers the gate.
- **D-14:** Design contract — ADD an Audit Explorer archetype block (no stale block to rewrite; only Overview/List/Detail exist). Document the elevated composition. Update existing `audit_user_live.ex` line refs the contract already cites. Keep microcopy glossary-clean.

### Claude's Discretion
- Exact in-row disclosure mechanism for deferred codes (expandable detail row vs `<details>` in a cell vs copy-icon) — as long as codes stay accessible, equivalence selectors update in lockstep (D-06), CSV `event_id` survives (D-05).
- Shared component names / arg shapes; how much layout chrome stays in each page's shell vs the shared component (D-08).
- Which shared module the migrated helpers land in (D-08).
- Whether to add the deterministic ExUnit pagination test in addition to the seeded capture (strongly preferred — D-10).
- Whether a disclosure chevron reuses an existing class or `sg-chevron` is styled/avoided (D-13).
- Microcopy wording (auto-guarded glossary-clean).

### Deferred Ideas (OUT OF SCOPE)
- A dedicated `AuditEventLive` / `/admin/audit/:event_id` drill-down route — explicitly considered and DECLINED for this phase (would add a generated-host router-contract seam disproportionate to a density-reduction phase). Revisitable as its own phase later.
- Consistency propagation to Overviews/Branding/gallery → Phase 203.
- Terminal ratification / allowlist reset / adversarial review → Phase 204.
- 9 reviewed-not-folded todos (branding scoring, Playwright per-shard-DB, Phase-199/200 hardening, stale known-failure contract tests, token-reference CI guard, UAT demo-DX nits, installer/config features) — all outside an audit-surface UI elevation.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUDIT-01 | Global + per-user audit filters are a single form with advanced-disclosure (quick toggles folded in), Export surfaced to the filter action row. | Index is already a single `sg-filter-panel` with Export in the action row (`audit_index_live.ex:58-137`); per-user has 3 forms to collapse (`audit_user_live.ex:81-108` + `:110-164`). Native `<details>` disclosure has no existing CSS (3 "details" CSS hits are false positives — `sg-summary-facts`); see Pitfall 6. |
| AUDIT-02 | Row/column density reduced (codes deferred to drill-down), mobile-first stacked, pagination proven on ≥25-event fixture; two pages byte-coherent. | Codes at `audit_index_live.ex:168,177` / `audit_user_live.ex:197,206`; mobile `<.audit_row show_codes>` (`components.ex:699-714`) is the pattern to extend to desktop; CSV `event_id` is independent of LiveView render (`csv_export.ex:59` reads presenter map). Pagination already honest (`multi_page?/1`); deterministic ExUnit proof seam already exists (`admin_audit_index_live_test.exs` inserts events + `page_size=1`). |
| AUDIT-03 | Both surfaces award-grade across full matrix; `audit-index-live` + `audit-user-live` ledger cells ratcheted to Tier 2. | Ledger cells `admin-quality-ledger.md:90,91` (both Tier 1); `users-index-live:87` is the exact N/A-proxy template; Tier-2 proxy defs `admin-fractal-scorecard.md:132-165`. |
</phase_requirements>

## Summary

Phase 202 is an **in-place refactor + DRY + ratchet** phase with zero new dependencies, zero new
routes, and (very likely) zero new CSS. The CONTEXT.md is exhaustive at file:line precision and —
verified against the live code this session — **its cited line ranges are accurate**. The work is
concentrated in two LiveViews that are ~90% hand-duplicated of each other, plus three doc/test
lockstep gates that the previous two phases (200, 201) have already battle-tested.

The single highest-risk item is **D-06 (positional-selector lockstep)**: the shared Playwright
helper `assertAuditResultEquivalence` (`admin-design.spec.ts:166-178`) extracts content-equivalence
tokens by reading `code.sg-code` (×2) and `td:nth-child(3) span` (×3) out of the desktop table.
Moving the two raw codes into an in-row disclosure WILL change where `code.sg-code` lives. Unless the
disclosed `code.sg-code` elements stay inside the `[data-testid="admin-audit-desktop-results"]`
container AND the helper is updated in the same change, the assertion silently degrades to a vacuous
rubber stamp — the exact failure 201 D-06 warned about. This one helper drives THREE call sites
(gallery MG-6, live `/admin/audit`, live per-user audit), so one selector edit ripples to all three.

The second-highest-value, lowest-risk recommendation: **add a deterministic ExUnit LiveView
pagination test** (D-10, "strongly preferred"). The existing `admin_audit_index_live_test.exs`
already demonstrates the exact seam — it inserts audit events directly via the example `Repo` and
drives `page_size` to force pagination — so a `<nav> present at ≥26 / absent at ≤25` test is a
~30-line addition that makes the pagination proof independent of the seeded screenshot (which depends
on a dev DB the test environment hard-blocks).

**Primary recommendation:** Promote the duplicated desktop-table row + pagination `<nav>` +
empty-state into PUBLIC function components in `lib/sigra/admin/components.ex` (NOT private to a
LiveView — two separate LiveViews must share them, unlike 201's single-page private slices), move the
~8 duplicated helpers to one shared module, defer codes into an in-row `<details>` (or expandable row)
whose `code.sg-code` stays inside the desktop results container, update `assertAuditResultEquivalence`
in lockstep, add a deterministic ExUnit pagination test, ratchet both ledger cells to bare `2` with
N/A overlay/APG proxies, add the Audit Explorer archetype, and recapture only `audit-explorer` /
`user-audit` (+ `mg-6` iff markup moves).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Filter form rendering + GET submission | Frontend Server (LiveView render) | Browser (native form GET) | URL-driven state; `handle_params` is the only state path (D-03). No client JS. |
| Advanced-disclosure (`<details>`) | Browser (native element) | — | CSS-only, no `phx-hook` (D-02); browser owns open/close state. |
| Inline code disclosure | Browser (native `<details>` or CSS) | Frontend Server (markup) | Codes rendered server-side into DOM; reveal is client-native (D-05/D-07). |
| Audit data load + cursor pagination | API / Backend (`Explorer`/`query.ex`) | Database | Already implemented; phase does not touch it (D-10). Functionally intact. |
| CSV export (incl. `event_id`) | API / Backend (`csv_export.ex` + controller) | — | Independent of LiveView render; reads presenter map, not DOM (D-05). |
| Content-equivalence proof | Test harness (Playwright) | — | Positional DOM selectors are a contract, not a layout detail (D-06). |
| Tier ratchet / forward-only guard | Maintainer docs + CI guard | — | `awk -F'|'` positional parse of ledger column-4 (D-11). |

## Verification of CONTEXT.md Line Citations (drift audit)

> Research priority 1: confirm exact current structure against cited lines; flag drift so the
> planner doesn't anchor to stale numbers. **Verdict: citations are ACCURATE.** Minor additional
> findings below — none invalidate a citation, but the planner should know them.

| CONTEXT.md citation | Live verification | Status |
|---------------------|-------------------|--------|
| `audit_index_live.ex` single `sg-filter-panel` `:58-137` | `<form ... class="sg-filter-panel sg-stack">` opens `:58`, closes `:137` | ✅ exact |
| index quick chips `sg-cluster` `:59-80`, advanced `sg-form-grid` `:82-126`, Export `:128-132` | confirmed verbatim | ✅ exact |
| index desktop table body `:154-193`, raw codes `:168`(id)/`:177`(action), pagination `<nav>` `:216-236` | confirmed | ✅ exact |
| index `audit_tone/1` `:244-246`, `multi_page?/1` `:309-313`, `@chip_keys` 6-key `:274` | confirmed; `@chip_keys ~w(actor effective_user action_prefix outcome from to)` | ✅ exact |
| `audit_user_live.ex` THREE forms: two quick-toggle `:81-108` + main filter `:110-164` | confirmed: forms at `:82-94`, `:95-107`, `:110-164` | ✅ exact |
| per-user desktop table `:183-222`, raw codes `:197,206`, Export `:155-157`, pagination `:246-266` | confirmed | ✅ exact |
| per-user `audit_tone/1` `:273-275`, `multi_page?/1` `:475-479`, `@chip_keys` 5-key `:435` | confirmed; `~w(actor action_prefix outcome from to)` | ✅ exact |
| `components.ex` `<.audit_row>` + `show_codes`/`show_detail` `:699-711` | `def audit_row` `:699`; `show_codes` codes at `:710-711` | ✅ exact |
| `csv_export.ex` `event_id` `:8,59` | header `:8`, row map `:59` (`"event_id" => event.id`) | ✅ exact |
| `glossary_test.exs:28-29` scopes both audit pages | `:28` audit_index_live, `:29` audit_user_live | ✅ exact |
| ledger cells `:90` audit-index-live, `:91` audit-user-live (both Tier 1); `:87` users-index-live Tier-2 template | confirmed | ✅ exact |
| seeds `:12-13` ">=25 admin self-tied rows … FIXT-01" | confirmed; also notes `MIX_ENV == :test` raise-guard | ✅ exact |
| `assertAuditResultEquivalence` `admin-design.spec.ts:166-178` reads `code.sg-code`×2 + `td:nth-child(3) span`×3 | confirmed; also reads `data-tone` parity `:175-177` | ✅ exact |
| checkpoint entry `admin-checkpoints.spec.ts:356-368` (`failures`/`impersonation` chips, `:checked`, Export CSV) | confirmed `:349-379`; slug captures at `:378`(audit-explorer)/`:343`(user-audit) | ✅ exact |

**Additional findings the planner should know (not drift, but useful):**

1. **`from`/`to` input-type divergence between the two pages.** Index uses `type="date"`
   (`audit_index_live.ex:119,124`); per-user uses `type="text"` with placeholder `2026-05-01`
   (`audit_user_live.ex:143,148`). The index also has an **Effective user** field (`:88-91`) and a
   standalone **Action prefix** text field that the per-user page orders differently. When aligning
   the shared advanced-disclosure fieldset, decide explicitly whether to converge on `type="date"`
   (better DX) — this is a per-page divergence (D-09) only if intentionally kept; otherwise align it.
   `[VERIFIED: live code]`

2. **`return_to` hidden input appears TWICE in the per-user page** — once in each standalone toggle
   form (`:83`, `:96`) and once (conditionally) in the main form (`:160`, `:if={@return_to}`). When
   collapsing to one form, the `return_to` plumbing must survive exactly once and keep the
   round-trip working (D-03). `[VERIFIED: live code]`

3. **The two LiveViews already carry literal duplication comments** confirming intent-to-DRY:
   `audit_index_live.ex:243` / `audit_user_live.ex:271` ("Unified body — identical to…"). The CONTEXT
   cited `:243`/`:271` for these — accurate. `[VERIFIED: live code]`

4. **The duplicated private helpers are NOT fully identical across the two files** — `append_query/2`,
   `audit_tone/1`, `multi_page?/1`, `format_timestamp/1`, `param_value/_`, `present_param?/2`,
   `humanize_outcome/1` ARE byte-identical; but `applied_chips/1`/`chip_label/2`/`@chip_keys` differ by
   the chip-key set (6 vs 5), and the per-user file has extra path helpers (`return_to`, breadcrumbs,
   `clear_path`, `export_params`). The shared module should host the truly-identical helpers; the
   chip-key list is the legitimate per-page divergence (D-09). `[VERIFIED: live code]`

5. **`audit_tone/1` is ALREADY public in `components.ex`** (`:723-725`, used by `audit_row/1`) AND
   privately re-declared in BOTH LiveViews (`audit_index_live.ex:244-246`, `audit_user_live.ex:273-275`)
   — the comments even say "Unified body — identical to Components.audit_tone/1." The DRY pass can delete
   both private copies if the shared table-row component calls the components one. `[VERIFIED: live code]`

## Architecture Patterns

### System Data Flow (unchanged by this phase)

```
URL (?outcome=&action_prefix=&actor=&from=&to=&cursor=&page_size=25&order_by=&order_direction=)
   │  (GET form submit  OR  deep-link  OR  chip-remove <a>  OR  page/sort <a>)
   ▼
LiveView.handle_params/3   ── the ONLY state path (D-03) ──────────────────────────┐
   │                                                                                │
   ▼                                                                                │
Explorer.list_events/3  (index)  /  Explorer.list_subject_events/4  (per-user)      │ no change
   │   → {rows, meta(cursor: prev/next/current_page), current_params}               │ (D-10)
   ▼                                                                                │
render/1                                                                            │
   ├── sg-filter-panel  (1 form: quick-toggle checkboxes + <details> advanced)  ◄── D-01/D-02
   ├── applied_chips  (navigation-only <a>, inside form region)                      │
   ├── desktop table  ──► <.audit_table_row row=...>  (NEW shared component)     ◄── D-08
   │       td1 Occurred · td2 Event(action_label+badge) · td3 Actor · td4 Outcome    │
   │       + in-row code disclosure (id + action)  ── code.sg-code STAYS in DOM  ◄── D-05/D-06
   ├── mobile cards   ──► <.audit_row show_detail show_codes>  (EXISTING shared)  ◄── D-07
   ├── <.audit_empty_state>   (NEW shared component)                             ◄── D-08
   └── <.audit_pagination_nav meta=...>  (NEW shared component)                  ◄── D-08

CSV export path (SEPARATE — NOT through LiveView render):
   GET /admin/audit/export.csv → AuditExportController → CSVExport.dump/1
       → reads presenter row map "event_id" => event.id  (csv_export.ex:59)   ◄── D-05 (survives)
```

### Pattern 1: Shared per-row component, SEPARATE DOM, token equivalence (the DRY mechanism)

**What:** Desktop `<table>` and mobile card list render from the same row data but in separate DOM
subtrees. Equivalence is proven by a Playwright helper that extracts tokens from the desktop subtree
and asserts each appears in the mobile subtree — NOT by markup identity.

**When to use:** D-08 shared desktop-table row. This is exactly the audit feed's own existing pattern
(mobile via `<.audit_row>`, desktop hand-coded) being completed to share BOTH directions.

**Critical divergence from the 201 precedent:** In 201, `user_name_stack/1` and `user_status_cluster/1`
are **private function components inside `users_index_live.ex`** (`:369`, `:384`) because only ONE
LiveView uses them. Phase 202 has TWO separate LiveViews (`AuditIndexLive`, `AuditUserLive`) that must
emit byte-identical shared markup — so the shared row/nav/empty-state components MUST be **public in
`lib/sigra/admin/components.ex`** (the same module that already owns the public `audit_row/1`), or in a
new public component module both `import`. Private-to-one-LiveView does not satisfy cross-page
byte-coherence. `[VERIFIED: live code — users_index_live.ex:369,384 private vs components.ex:699 public]`

```elixir
# Source: lib/sigra/admin/components.ex:699-714 (existing public component — the shape to mirror)
attr :row, :map, required: true
attr :show_detail, :boolean, default: false
attr :show_codes, :boolean, default: false
def audit_row(assigns) do
  ~H"""
  <article class={["sg-list-row sg-stack sg-stack--2", @class]} data-tone={audit_tone(@row)} {@rest}>
    ...
    <code :if={@show_codes} class="sg-code">{@row.id}</code>
    <code :if={@show_codes} class="sg-code">{@row.action}</code>
  </article>
  """
end
```

### Pattern 2: In-row code disclosure that keeps `code.sg-code` extractable (D-05 + D-06)

**What:** The two raw codes (`row.id`, `row.action`) move out of the primary `<td>` flow into an
inline progressive-disclosure affordance, but the `<code class="sg-code">` elements must remain inside
the `[data-testid="admin-audit-desktop-results"]` container so the equivalence selector still finds 2.

**Recommended mechanism (Claude's Discretion resolved):** a **native `<details>` inside the Event
cell** (or an expandable secondary row), with `<summary>` as the affordance and the two
`<code class="sg-code">` lines inside the disclosure body. This:
- keeps both `code.sg-code` nodes inside the desktop results container (D-06 selector still returns 2),
- is CSS-only / no `phx-hook` (consistent with D-02's reduced-motion/axe posture),
- mirrors the mobile `<.audit_row show_codes>` reveal pattern (D-07),
- reduces visible density (codes hidden until opened) without removing them (forensic users + D-05).

**Why `<details>`-in-cell over a separate expandable `<tr>`:** a sibling `<tr>` would change the
`td:nth-child` positional indexing risk surface and complicate `data-tone` row parity
(`assertAuditResultEquivalence:175` reads `tbody tr` first row). Keeping the disclosure WITHIN the
Event cell leaves the 4-column `td:nth-child` contract (Occurred=1, Event=2, Actor=3, Outcome=4)
frozen. `[VERIFIED: spec reads td:nth-child(3) span = Actor, 3rd td]`

**Why NOT a copy-icon-only affordance:** a copy button that holds the code only in a JS handler /
`data-` attribute (not as visible `code.sg-code` text) would make `firstTexts(..., 'code.sg-code', 2)`
return 0 tokens → vacuous equivalence. Keep the codes as real `code.sg-code` text nodes.

### Pattern 3: Native `<details>` advanced-disclosure (D-02)

**What:** Text/date filter fields fold into a `<details><summary>More filters</summary>…</details>`;
quick toggles (Failures / Impersonation) stay outside as always-visible summary controls.

**CSS note (D-13):** there is **NO existing `<details>`/`<summary>` styling** in the three
`sigra_admin.css` copies (the 3 `grep details` hits are false positives matching `sg-summary-facts`).
Browser-default `<details>` rendering works without any CSS. If the disclosure needs visual polish
(chevron, panel chrome), that CSS must be written **byte-identically into all three copies** or the
golden-diff gate fails (D-13). **Recommendation:** rely on browser-default `<details>` open/close + the
existing `sg-filter-panel`/`sg-form-grid` chrome → **zero new CSS** → golden-diff stays green. Do NOT
introduce `sg-chevron` (confirmed 0 rules in all three copies — `grep -c sg-chevron` → 0).
`[VERIFIED: grep on 3 CSS copies, md5 all 9b281962ee8fe33254829c877af00382]`

### Anti-Patterns to Avoid

- **Converting toggles/chips to `phx-click`** (breaks D-03: deep-linking, checkpoint entry path,
  `return_to` round-trip, and the `:checked`-state checkpoint assertions). Everything stays GET/URL.
- **Making the shared row component private to one LiveView** (cannot be shared across two — must be
  public, Pattern 1).
- **Moving codes into a non-`code.sg-code` affordance** (vacuous equivalence — Pitfall 1).
- **Adding a `<tr>` detail row that shifts `td:nth-child` indexing** (breaks positional selectors).
- **Relocating Export** (D-04 — already in the action row; checkpoint asserts it visible).
- **Decorating ledger column-4** (e.g. `2 ✓` or `2*`) — breaks the `awk -F'|'` parse (Pitfall 5).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Show/hide advanced filters | A `phx-hook` JS toggle or LiveView assign | Native `<details>`/`<summary>` (D-02) | No reduced-motion/axe risk, no client state, no event round-trip; URL stays the only state path. |
| Inline code reveal | A custom clipboard/JS widget | Native `<details>` in-cell holding `code.sg-code` (D-05) | Keeps codes as real DOM text (equivalence stays a real proof) and reuses the mobile reveal idiom. |
| Pagination proof | A new seeded fixture or screenshot-only check | Deterministic ExUnit LiveView test inserting N events + `page_size` (existing `admin_audit_index_live_test.exs` seam) | Test-env-independent; no dev-seed dependency; <30s. |
| Cursor pagination | Reimplementing total-pages math | Existing `multi_page?/1` (already honest) | Already implemented; phase proves, does not build (D-10). |
| Tone derivation | Re-declaring `audit_tone/1` per page | Public `Components.audit_tone/1` (already exists `:723`) | Two private copies already exist to DELETE; one source of truth. |

**Key insight:** This phase is almost entirely *deletion of duplication* and *promotion to shared
components*. The strongest temptation to resist is building new infrastructure (a route, a JS hook, a
new fixture) when the existing primitives (native `<details>`, the existing ExUnit insert-events seam,
the existing `multi_page?/1`, the existing public `audit_row/1`/`audit_tone/1`) already cover the work.

## Validation Architecture

> REQUIRED (Nyquist Dimension 8). `workflow.nyquist_validation` not disabled — section included.
> Every AUDIT-01/02/03 success criterion mapped to its proof below.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) for LiveView/data; Playwright (`@playwright/test`) for visual/equivalence/checkpoint |
| ExUnit config | `test/example/test/example_web/live/admin_audit_index_live_test.exs` (`use ExampleWeb.ConnCase, async: false`) — runs in the EXAMPLE app, which has a live DB |
| Playwright config | `test/example/priv/playwright/` (chromium / dark / mobile projects); `SIGRA_EXAMPLE_URL` default `http://localhost:4011` |
| Quick run (ExUnit) | `cd test/example && mix test test/example_web/live/admin_audit_index_live_test.exs` |
| Full suite (Playwright) | `cd test/example/priv/playwright && npx playwright test admin-design.spec.ts admin-checkpoints.spec.ts` |
| Golden-diff gate | `mix test test/sigra/install/...` (3-copy CSS byte parity) |
| Monotonic guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` |

### Success-criterion → proof map

| Req / Criterion | Behavior to prove | Test type | Concrete proof |
|-----------------|-------------------|-----------|----------------|
| AUDIT-01 single form | Per-user page emits ONE `<form>` (not 3); quick toggles submit as GET checkboxes | ExUnit + Playwright | ExUnit: assert exactly one `sg-filter-panel` form & both toggles inside it; `admin-checkpoints.spec.ts:356-367` asserts chip `:checked` state survives URL entry |
| AUDIT-01 advanced-disclosure | Text/date fields inside `<details>`; toggles outside | Playwright | checkpoint capture (audit-explorer/user-audit) + structural assertion `<details>` present |
| AUDIT-01 Export in action row | Export CSV link in consolidated action row | Playwright | `admin-checkpoints.spec.ts:368` `getByRole('link', {name:'Export CSV'})` visible; `admin-design.spec.ts:365` Export attached |
| AUDIT-02 density reduction | Raw id/action NOT in primary cell flow; human label/badge primary | Playwright (visual) | recaptured `audit-explorer`/`user-audit` baselines + `mg-6` (if markup) |
| AUDIT-02 codes still accessible + equivalent | `code.sg-code` ×2 still extractable in desktop container; appears in mobile too | Playwright | `assertAuditResultEquivalence` (`admin-design.spec.ts:166-178`) — `firstTexts(desktop,'code.sg-code',2)` returns 2; drives MG-6 (`:334`) + live `/admin/audit` (`:354-361`) + per-user (`:383-388`). **Update in lockstep (D-06).** |
| AUDIT-02 mobile-first stacking | Mobile cards render disclosed codes; desktop hidden on mobile project | Playwright | `admin-checkpoints.spec.ts:371-377` per-project layout swap; `<.audit_row show_codes>` |
| AUDIT-02 byte-coherence | Both pages emit byte-identical shared row/nav/empty-state | ExUnit (render) + visual | Render-compare shared component output; `mg-6` byte-coherence |
| AUDIT-02 pagination on ≥25 fixture | `<nav>` present at ≥26 rows, absent at ≤25 | **ExUnit (NEW — D-10 strongly preferred)** | New deterministic test inserting 26 events → assert `<nav>` / `multi_page?` true; insert ≤25 → assert absent. Seam exists: `admin_audit_index_live_test.exs` inserts events + drives `page_size`. PLUS seeded capture (`admin-design.spec.ts:354-392`) against dev DB. |
| AUDIT-03 glossary-clean | No banned synonyms in either audit file | ExUnit | `glossary_test.exs:28-29` (both files already scoped) |
| AUDIT-03 content-equivalence proxy | Desktop↔mobile equivalence green | Playwright | `assertAuditResultEquivalence` (above) |
| AUDIT-03 motion/density/target-size | Manual proxies | Manual (documented) | grep no `transition: all`; `sg-stack--6`/`--3` rhythm; targets ≥24px |
| AUDIT-03 overlay-axe + APG | N/A — no modal on either page | N/A | cite N/A in ledger (mirror `users-index-live:87`) — do NOT fabricate (D-11) |
| AUDIT-03 ratchet forward-only | column-4 `1`→`2`, bare integer | CI guard | `quality-ledger-monotonic.sh --base origin/main` parses `awk -F'|'` column-4 `[012]` |
| AUDIT-03 CSS lockstep | 3 copies byte-identical | ExUnit golden-diff | install golden-diff (md5 parity) — likely no-op (zero new CSS) |
| AUDIT-03 recapture idempotency | Zero-drift on re-render | Manual gate | `snapshot-recapture-gate.sh audit-explorer user-audit [mg-6]`; canaries byte-stable; allowlists empty at end |

### Recommended NEW deterministic ExUnit pagination test (D-10)

The cleanest pagination proof reuses the existing `admin_audit_index_live_test.exs` insert seam — it
inserts events directly via the example `Repo` (no dev seeds needed) and drives `page_size`:

```elixir
# Source pattern: test/example/test/example_web/live/admin_audit_index_live_test.exs:145-161
# NEW test (sketch):
test "pagination nav renders at >=26 events and is absent at <=25", %{conn: conn} do
  admin = platform_admin_fixture()
  for _ <- 1..26, do: insert_audit_event(%{actor_id: admin.id, effective_user_id: admin.id})
  html_26 = conn |> log_in_user(admin) |> get("/admin/audit") |> html_response(200)
  assert html_26 =~ ~s(aria-label="Next page")   # <nav> present (multi_page? true)
  # then a <=25 case (fresh sandbox / filtered) asserting refute on the nav
end
```
Default `page_size=25` is set as a hidden input (`audit_index_live.ex:134`). With 26 self-tied rows,
the cursor `meta.next_page` is non-nil → `multi_page?/1` true → `<nav>` renders. This proof is
independent of `MIX_ENV=dev` seeds. `[VERIFIED: live test seam + multi_page?/1:309-313]`

### Seeds / capture constraint (D-10)

- Seeds are **`MIX_ENV=dev`-only**, hard-blocked in test by a two-layer raise guard
  (`seeds.ex:19-20` documents the `MIX_ENV == :test` raise in `priv/repo/seeds.exs`).
  `[VERIFIED: seeds.ex:1-21]`
- The ≥25-event admin persona fixture (FIXT-01) lives in seeds (`>=25 admin self-tied rows`,
  `seeds.ex:12-13`). The Playwright seeded path (`admin-design.spec.ts:368-392`) filters
  `/admin/users?q=admin%40demo.tasklane.test` to deterministically reach the ≥25-event admin (the
  harness login user has only ~3 events, `:370`), then clicks "View full audit". `[VERIFIED]`
- Therefore the **screenshot/Playwright pagination path needs a booted dev DB with seeds run**; the
  **ExUnit path does not** (it inserts its own rows). Recommend BOTH (D-10): ExUnit for deterministic
  CI proof, seeded capture for the visual baseline.

## Tier-2 Proxy Applicability (D-11)

> Research priority 6: confirm which Tier-2 Add-on proxies genuinely apply. Mirror the
> `users-index-live` cell (`admin-quality-ledger.md:87`).

| Tier-2 proxy (`admin-fractal-scorecard.md:132-165`) | Applies to audit pages? | Evidence to cite |
|------------------------------------------------------|--------------------------|------------------|
| Overlay-open axe-clean | **N/A** — neither page owns a modal dialog | cite N/A (like `users-index-live:87`) — do NOT reference `admin-modal-interaction.spec.ts` |
| Focus-trap / focus-restore (7 APG gates) | **N/A** — no overlay | cite N/A |
| Desktop↔mobile content-equivalence | **YES** | `admin-design.spec.ts assertAuditResultEquivalence` (MG-6 + live `/admin/audit` + per-user) |
| Glossary-clean microcopy | **YES** | `glossary_test.exs:28-29` (both files scoped) |
| Motion-tokens / no `transition: all` | YES (manual) | grep audit HEEx + `sigra_admin.css` — no `transition: all` |
| Density / whitespace rhythm | YES (manual) | `sg-stack--6` outer section / `sg-stack--3` results / `sg-stack--1` cell stacks |
| Target-size ≥24px | YES (manual) | Apply filters / Clear / Export / quick-toggle chips / applied-chip remove / pagination links / disclosure `<summary>` all ≥24×24 (documented-as-manual) |

**Ledger cell template** (copy the EXACT format of `users-index-live` at `:87`, swapping in the
audit checkpoint slug `audit-explorer` / `user-audit`, the audit equivalence helper, and
`glossary_test.exs:28`/`:29`). Both cells flip column-4 from `1` to a bare `2`.

## Common Pitfalls

### Pitfall 1: Equivalence-weakening (the 201 D-06 failure mode) — HIGHEST RISK
**What goes wrong:** Codes move into a disclosure rendered as `data-*` attrs, a copy button, or
outside `[data-testid="admin-audit-desktop-results"]`. `firstTexts(desktop, 'code.sg-code', 2)`
returns 0–1 tokens, `expectTokensInBothContainers` passes vacuously, and content-equivalence becomes
a rubber stamp that no longer proves anything.
**Why it happens:** The helper extracts a *bounded* token list (`limit=2`); fewer tokens silently
weakens the assertion rather than failing it.
**How to avoid:** Keep both codes as real `<code class="sg-code">` text nodes INSIDE the desktop
results container (even if visually inside a `<details>`). After the change, run
`assertAuditResultEquivalence` and confirm it still extracts 2 codes. Consider asserting
`firstTexts(...).length === 2` in the helper itself to make under-extraction FAIL loudly (a strict
upgrade the planner may add). `[VERIFIED: admin-design.spec.ts:142-178]`
**Warning signs:** Equivalence test passes after codes "disappear" from desktop — investigate, that's
the vacuous-pass symptom.

### Pitfall 2: One helper, three call sites
**What goes wrong:** `assertAuditResultEquivalence` is invoked at gallery MG-6 (`:334`), live
`/admin/audit` (`:358`), and live per-user audit (`:385`). Editing the selector for one site silently
changes the contract for all three.
**How to avoid:** Treat the helper edit as a single lockstep change; re-run all three sites (gallery +
both live audit checks). `[VERIFIED: admin-design.spec.ts:334,358,385]`

### Pitfall 3: CSS triple-copy → unstyled generated host (the 184→185 regression class)
**What goes wrong:** A new `sg-*` class (e.g. a disclosure chevron) is added to the example copy but
not all three byte-identically → install golden-diff fails OR generated hosts ship an unstyled page.
**How to avoid:** Prefer ZERO new CSS (browser-default `<details>` + existing `sg-filter-panel`
chrome). If CSS is unavoidable, write it byte-identically into all three:
`priv/templates/sigra.install/admin/sigra_admin.css`,
`test/example/priv/static/assets/sigra_admin.css`,
`test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (current md5
`9b281962ee8fe33254829c877af00382`). Never reintroduce `sg-chevron` (0 rules everywhere).
`[VERIFIED: md5 of 3 copies + grep sg-chevron=0]`

### Pitfall 4: Breaking the GET-form / URL contract (D-03)
**What goes wrong:** Collapsing the per-user 3 forms into 1, an errant named input lands outside the
form (or a toggle becomes `phx-click`), breaking real GET submission, deep-linking, the
`?action_prefix=admin.impersonation` checkpoint entry, the `:checked`-state assertion, or the
`return_to` round-trip.
**How to avoid:** Keep `<form method="get" action={index_path(...)}>` with every named input inside;
toggles stay GET checkboxes; chips stay navigation-only `<a>`; `return_to` hidden input survives
exactly once. The checkpoint spec (`admin-checkpoints.spec.ts:349-367`) navigates via pre-built URL
and asserts `:checked` — a broken form would be caught there. Consider a form-submit Playwright test
(the 201 D-02 precedent at `admin-design.spec.ts:395`). `[VERIFIED: spec + both LiveViews]`

### Pitfall 5: Decorating the ledger tier integer (D-11)
**What goes wrong:** Writing `2 ✓`, `2*`, or `**2**` in ledger column-4 breaks the
`awk -F'|' {tier ~ /^[012]$/}` positional parse → the monotonic guard silently skips the cell →
false-pass CI.
**How to avoid:** Bare `2`, nothing else, in column-4. Put all proxy evidence in the Evidence column
(column 5). `[VERIFIED: admin-quality-ledger.md:14-27,32-39]`

### Pitfall 6: Assuming `<details>` is already styled
**What goes wrong:** Planner assumes existing CSS handles `<details>`; it does not (the 3 `details`
grep hits are `sg-summary-facts`). A disclosure that *needs* chrome would silently render browser-
default — which is acceptable, but a chevron/panel would need new (triple-copied) CSS.
**How to avoid:** Decide up front: browser-default `<details>` (zero CSS, recommended) vs styled
(triple-copy gate). `[VERIFIED: grep details in sigra_admin.css → only sg-summary-facts]`

### Pitfall 7: Capturing pagination under-populated
**What goes wrong:** Recapturing `audit-explorer`/`user-audit` against a non-seeded DB → the `<nav>`
isn't present (≤25 events) → the elevation is baked under-proven (the same class as 201 D-08 / the
long-standing `mg5-6-content-equivalence-data-dependent` todo).
**How to avoid:** Boot a dev DB with seeds run before capture; the ExUnit pagination test (D-10) is
the deterministic backstop so the proof doesn't depend solely on the seeded screenshot.
`[VERIFIED: admin-design.spec.ts:368-392 + seeds.ex:12-13]`

## Shared-Component Extraction Shape (D-08 recommendation)

> Research priority 4: recommend concrete function-component boundaries + which module.

**Recommended boundaries (3 new PUBLIC function components in `lib/sigra/admin/components.ex`):**

1. `audit_table_row/1` — the desktop `<tr>` body (4 cells: Occurred / Event+codes-disclosure / Actor
   / Outcome). Args: `row` (required). Renders `<tr data-tone={audit_tone(@row)}>` with the 4 `<td>`s.
   Replaces the hand-duplicated `audit_index_live.ex:164-191` ≡ `audit_user_live.ex:193-220`.
   **Keep the `<thead>` in each page's shell** (it's static and lets the page own column labels), or
   add `audit_table/1` wrapping thead+tbody — either works; prefer keeping `<thead>` shared too for
   true byte-coherence.

2. `audit_pagination_nav/1` — the `<nav :if={@meta && multi_page?(@meta)}>`. Args: `meta` (required),
   `prev_href`/`next_href` OR a `path_fn`. The per-page divergence is only the href builder
   (`page_path/3` index vs `page_path/4` per-user with `user_id`) — pass the built hrefs in, keep the
   nav markup shared. Replaces `audit_index_live.ex:216-236` ≡ `audit_user_live.ex:246-266`.

3. `audit_empty_state/1` — wraps `<.empty_state>` with the audit-specific copy. The per-page copy
   differs slightly (index "No audit events match this view" + filter-aware body vs per-user "No audit
   events for this user"), so either parametrize the title/body via slots or keep empty-state in each
   shell (it's the smallest duplication). **Recommendation:** parametrize via `title` attr + inner
   block slot, OR leave empty-state per-page (lowest-value DRY; D-09 lets legitimate copy differences
   stand). Lean toward parametrized-with-slot for coherence.

**Shared helper module:** move the byte-identical helpers to ONE module. Two options:
- (a) Add them as private helpers next to the new components in `components.ex` (where `audit_tone/1`
  and `format_date/1` already live publicly/privately). Cleanest — the components and their helpers
  co-locate.
- (b) A new `Sigra.Admin.Audit.View` (or `Sigra.Admin.AuditHelpers`) module imported by both LiveViews.
**Recommendation:** (a) for the helpers the new components need (`audit_tone/1` already public there;
`format_timestamp/1` can join `format_date/1`); keep page-specific path/query helpers
(`append_query/2`, `index_path`, `sort_path`, `page_path`, `remove_chip_path`, chip helpers) in each
LiveView since they encode per-page routing (index vs per-user `user_id`/`return_to`) — that's the
legitimate D-09 divergence. `format_timestamp/1` (with-seconds) vs `format_date/1` (no-seconds) differ
today; reconcile or keep both intentionally. `[VERIFIED: components.ex:723,732 + both LiveViews]`

**Legitimate per-page divergence that MUST stay OUT of the shared component (D-09):**
- Per-user: breadcrumbs (`audit_breadcrumbs/3`), page header with `display_name`/email/`sg-code`,
  `return_to` plumbing, `clear_path`/`export_params`, 5-key `@chip_keys`.
- Index: scope header `<header class="sg-page-header">` with kicker/title, 6-key `@chip_keys`
  (incl. `actor`/`effective_user`), Effective-user filter field.
- Routing helpers (`index_path` arity, `page_path` arity, sort/remove-chip paths) — page-specific.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-LiveView private row components (201) | Public shared components in `components.ex` for cross-page reuse | Phase 202 | Two LiveViews can share byte-identical markup; private-to-one won't do |
| Codes as primary desktop columns | Codes in in-row disclosure, human label/badge primary | Phase 202 (D-05) | Reduced density; codes still DOM-extractable for equivalence + CSV |
| Pagination proven by screenshot only | Deterministic ExUnit test + seeded capture | Phase 202 (D-10) | Proof no longer depends on dev-seed availability |
| Tier 1 audit cells | Tier 2 with N/A overlay/APG proxies | Phase 202 (D-11) | Mirrors `users-index-live` Phase-201 template |

**Deprecated/outdated:**
- Two private `audit_tone/1` copies in the LiveViews — superseded by public `Components.audit_tone/1`
  (`components.ex:723`); delete on DRY.
- `sg-chevron` class — 0 rules in all three CSS copies; do not use (D-02/D-13).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Native `<details>` in-cell is the best inline-code-disclosure mechanism (vs expandable `<tr>` or copy-icon) | Pattern 2 | Low — it's Claude's Discretion (D-05); any mechanism keeping `code.sg-code` in the desktop container satisfies D-06. Planner/discuss may pick differently. |
| A2 | Browser-default `<details>` styling is acceptable (zero new CSS) | Pattern 3 / Pitfall 6 | Low — if design wants a styled disclosure, triple-copy CSS is required (D-13); raises golden-diff surface but is a known, gated path. |
| A3 | Shared components belong in `components.ex` (public) rather than a new module | Extraction Shape | Low — both satisfy cross-page sharing; `components.ex` already hosts `audit_row/1`. A new module is equally valid. |
| A4 | The deterministic ExUnit pagination test can insert 26 self-tied events to force `next_page` non-nil | Validation / D-10 | Low — verified the insert seam + `multi_page?/1` logic; cursor `next_page` is set when rows exceed page_size. Worst case the test drives `page_size` smaller (as the existing test does with `page_size=1`). |

**No `[ASSUMED]` claims about packages, compliance, retention, or security standards** — this phase
adds none. All package/dep claims are N/A (no installs).

## Open Questions

1. **Align `from`/`to` input type across the two pages?**
   - What we know: index uses `type="date"`, per-user uses `type="text"` (`audit_index_live.ex:119`
     vs `audit_user_live.ex:143`).
   - What's unclear: whether converging to `type="date"` (better DX) is in-scope for "byte-coherent
     shared markup" or a deliberate per-page difference.
   - Recommendation: converge to `type="date"` when both feed the shared advanced-disclosure fieldset
     — it's a coherence win and removes one divergence. Flag for the planner; trivial either way.

2. **Shared `<thead>` or per-page `<thead>`?**
   - What we know: column labels are identical today (Occurred/Event/Actor/Outcome).
   - Recommendation: share the whole `<table>` (thead+tbody) for maximal byte-coherence; the sort link
     href is the only per-page difference and can be passed in.

3. **Does `mg-6` markup actually change?**
   - What we know: D-12 says recapture `mg-6` IFF its markup changes; `mg-6` mirrors the live audit
     feed (`design_gallery_live.ex` board-mg-6, asserted at `admin-design.spec.ts:301` = 3 list rows).
   - Recommendation: if the desktop row component is restructured (codes into disclosure), `mg-6`'s
     audit-feed board likely changes → recapture. Confirm during execution by running the gallery
     equivalence check; route only if the snapshot drifts.

## Sources

### Primary (HIGH confidence — verified against live code this session)
- `lib/sigra/admin/live/audit_index_live.ex` (full read) — single panel, table, helpers, `multi_page?/1`
- `lib/sigra/admin/live/audit_user_live.ex` (full read) — 3 forms, `return_to`, breadcrumbs, chip-keys
- `lib/sigra/admin/components.ex:650-740` — `audit_row/1`, `audit_tone/1`, `format_date/1`
- `lib/sigra/admin/live/users_index_live.ex:360-410` — 201 private field-slice precedent
- `lib/sigra/admin/audit/csv_export.ex` — `event_id` independence from LiveView render
- `test/example/priv/playwright/tests/admin-design.spec.ts:140-393` — `assertAuditResultEquivalence` + 3 call sites
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts:330-380` — audit-explorer/user-audit slugs + entry path
- `test/example/test/example_web/live/admin_audit_index_live_test.exs` (full read) — ExUnit insert seam
- `guides/reference/admin-quality-ledger.md:1-118` — parse rules, cells `:90/:91`, template `:87`
- `guides/reference/admin-fractal-scorecard.md:130-167` — Tier-2 proxy defs
- `guides/reference/admin-design-contract.md:168-300` — archetype format (List/Detail) to mirror
- `test/example/lib/example/demo/seeds.ex:1-40` — FIXT-01, MIX_ENV=dev/test guard
- `test/sigra/admin/glossary_test.exs:20-39` — both audit files scoped
- `.planning/phases/201-users-index-elevation/201-PATTERNS.md` — DRY/lockstep/ratchet/recapture precedent
- `scripts/ci/snapshot-recapture-gate.sh:1-45` — recapture routing + usage
- `.github/workflows/ci.yml:101-112` — canary-guard + monotonic-guard wiring

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` accumulated decisions — 200/201 ratchet + recapture history
- md5 / grep verifications (CSS triple-copy parity `9b281962…`; `sg-chevron`=0; `<details>` CSS absent)

### Tertiary (LOW confidence)
- None — no external/web sources needed for an in-repo refactor phase.

## Metadata

**Confidence breakdown:**
- CONTEXT line citations: HIGH — every cited range read and confirmed against live files.
- Validation architecture: HIGH — existing ExUnit + Playwright seams verified; new pagination test seam proven to exist.
- Shared-component shape: HIGH — 201 precedent read directly; cross-page public-vs-private distinction verified.
- Pitfalls: HIGH — equivalence-weakening mechanism traced through the actual helper code; CSS/ledger gates verified by grep/md5.
- Disclosure mechanism (Pattern 2): MEDIUM — recommendation is sound and D-06-safe, but it is Claude's Discretion; discuss/planner may choose another D-06-safe affordance.

**Research date:** 2026-06-26
**Valid until:** 2026-07-26 (stable in-repo refactor; only invalidated if the audit LiveViews,
the equivalence helper, or the ledger format change before planning)
