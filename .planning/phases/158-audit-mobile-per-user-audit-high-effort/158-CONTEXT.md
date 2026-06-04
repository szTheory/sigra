# Phase 158: Audit Mobile + Per-User Audit (High Effort) - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Bring the **two audit surfaces** into the admin-UI-coherence milestone:

- `AuditIndexLive` (the audit explorer) gets a **mobile card fallback** mirroring the
  `UsersIndexLive` dual-layout, plus **quick-filter chips** for common cases.
- `AuditUserLive` (per-user audit) is **reconciled with the explorer** — shared
  `<.page_back>`, `<.scope_ribbon>`, `<.notice>`, `<.empty_state>`, and a **unified
  audit-row presentation** also used by the `UserShowLive` "Recent audit" block.
- New Playwright `user-audit` checkpoint ×3 projects (axe green); `audit-explorer`
  baselines re-recorded as intended deltas; `admin-generated` parity lane stays green.

**Requirements:** AUDX-01 (mobile card layout), AUDX-02 (quick-filter chips),
AUDX-03 (per-user reconciliation + shared audit-row). Verification gates GATE-01
(`user-audit` checkpoint ×3 + axe), GATE-02 (admin-generated parity).

**This is a coherence pass, NOT feature expansion.** No net-new admin surfaces, no
IA restructure, no new design tokens, no new runtime deps. The only CSS posture is
"compose existing `sg-*` classes" — the `audit_row` card form reuses `sg-list-row`.
</domain>

<decisions>
## Implementation Decisions

### Area 1 — Unified audit-row component (AUDX-03)
- **D-01 [Likely → locked]:** Add an **11th shared function component `audit_row/1`** to
  `Sigra.Admin.Components`, emitting the **card form** — the `sg-list-row` `<article>`
  shape already present at `user_show_live.ex:265-272`. Use it for: AuditIndex mobile
  cards, AuditUser mobile cards, AND the `UserShowLive` "Recent Audit" block. The desktop
  `<table>` rows in both explorers stay **inline `<tr>`** (a `<tr>` cannot share markup
  with an `<article>` — same way `UsersIndexLive` keeps its `<tr>` inline while sharing
  nothing with its mobile `<article>`).
  - **Why:** Three divergent renderings of the same audit data exist today:
    `user_show_live.ex:265-272` (compact card, tone via `audit_tone/1` :437-440),
    `audit_index_live.ex:136-162` and `audit_user_live.ex:165-192` (identical 4-col `<tr>`
    blocks, tone via `row_tone/1` :206-208 / :246-248). The two `row_tone/1` and the one
    `audit_tone/1` **already disagree** (`row_tone` returns `"info"` for impersonation;
    `audit_tone` only does risk-vs-nil) — exactly the "same job → same component" milestone
    law. `sg-list-row[data-tone]` already carries all four tones (`app.css:952-966`), so
    **zero new CSS**. Components emit only existing `sg-*` classes (`components.ex:9-10`).
  - **Contract:** single `attr :row, :map` (the Presenter row struct) + an internal
    `audit_tone/1` derived from `outcome`/`action_badge` (this becomes the single source of
    truth that retires the `row_tone`/`audit_tone` divergence). Optional attrs toggle the
    `row.id`/`row.action` code lines and the `Actor:`/`Effective user:` detail lines that the
    explorers show but the compact recent-audit block omits.
  - **Hard-fail boundary:** Do NOT build a polymorphic `audit_row/1` with
    `variant={:table|:card}` — a two-headed conditional fights the flat/stateless house style
    (`components.ex:5`) and complicates the `render_component` byte-golden discipline.

### Area 2 — Mobile dual-layout for AuditIndexLive (AUDX-01)
- **D-02 [Confident → locked]:** Mirror `UsersIndexLive` exactly. Wrap the existing desktop
  table in `<div class="sg-table-panel sg-show-desktop" data-testid="admin-audit-desktop-results">`
  and add a sibling `<div class="sg-stack sg-stack--3 sg-show-mobile" data-testid="admin-audit-mobile-results">`
  iterating `<.audit_row>` cards. The mobile card is a **separate composition** (the Area 1
  card), not the table re-flowed.
  - **Why:** Proven idiom at `users_index_live.ex:179-238`
    (`admin-users-desktop-results` / `admin-users-mobile-results`). `sg-show-desktop`/
    `sg-show-mobile` flip at 1024px (`app.css:247-255`); `sg-table-panel` has **no**
    self-hide (only `sg-bottom-nav` self-hides, `app.css:556-559`), so the always-visible
    table at `audit_index_live.ex:125` overflows the iPhone 13 profile without an explicit
    `sg-show-desktop` wrapper. The explorer already uses `sg-show-desktop` on the Outcome
    column (`audit_index_live.ex:132,159`) — utility is in scope, container not yet gated.
  - **Hard-fail boundary:** Do NOT solve mobile via horizontal-scroll on the table — that
    introduces a second bespoke responsive pattern (the milestone anti-goal). Keep the
    mobile `data-testid` naming consistent with the users convention.
- **D-03 [Likely → locked]:** Apply the same dual-layout to `AuditUserLive` (AUDX-03 says
  per-user audit also gets the mobile layout), reusing `<.audit_row>` cards.

### Area 3 — Quick-filter chips (AUDX-02) — **value-chips, all viewports**
- **D-04 [user decision — confirmed 2026-06-04]:** Add quick-filter chips reusing the
  `sg-filter-chip` styling, backed by the audit query's **existing string params** as
  **value-setting links/setters** (NOT boolean checkboxes): a **"Failures"** chip →
  `outcome=failure`, an **"Impersonation"** chip → `action_prefix=admin.impersonation`. The
  detailed filter form stays; chips are convenience shortcuts that populate the same params
  and surface through the existing `<.applied_chip>` row.
  - **Why:** `@allowed_params` already include `action_prefix` and `outcome`
    (`query_params.ex:9-15,56-60`); no query-layer change needed. The checkpoint journey
    already proves `?action_prefix=admin.impersonation` is the impersonation idiom and that
    `outcome` accepts `failure` (`audit_index_live.ex:88`, `admin-checkpoints.spec.ts:270`).
  - **Hard-fail boundary:** Impersonation is **not** a boolean column — it is an
    `action_prefix` value. A `impersonation=true` checkbox chip would be silently ignored by
    `QueryParams` and ship a dead chip. Chips MUST set the real param values. (Rejected
    alternative: literal boolean checkbox chips like users-index requiring new `impersonation`/
    `failure` params plumbed through `QueryParams` — more code, risks a second filter pattern.)
- **D-05 [user decision — confirmed 2026-06-04]:** Chips render on **all viewports**
  (desktop + mobile) — one filter idiom everywhere. (Rejected: an `sg-show-mobile`-only chip
  row that would keep desktop baselines byte-frozen but create a desktop/mobile filter
  asymmetry undercutting the "one filter idiom" goal.)

### Area 4 — `user-audit` Playwright checkpoint (AUDX-03, GATE-01)
- **D-06 [Confident → locked]:** Add one new slug `user-audit` to the single authenticated
  journey in `admin-checkpoints.spec.ts` via the established `captureAndVerify(...)` +
  `assertCheckpointScreenshot(...)` two-call pattern, navigating to `/admin/users/:id/audit`
  for the journey's existing `targetEmail` user **after** the impersonation start/stop
  sequence (so the user has real `admin.impersonation` audit rows — **zero new seed**).
  Produces 3 new committed PNGs (chromium/mobile/dark) with the axe gate.
  - **Why:** journey already impersonates and ends impersonation on `targetEmail`
    (`admin-checkpoints.spec.ts:234-264`), and the existing `audit-explorer` checkpoint
    relies on those rows via `?action_prefix=admin.impersonation` (:270-273). Route exists:
    `live "/admin/users/:id/audit" → AuditUserLive` (`router.ex:260,293`).
  - **Hard-fail boundary:** The screenshot wait MUST assert a **visible loaded audit row**
    (e.g. an `admin-audit-mobile-results`/desktop row or a known action-label pill), not just
    `.phx-connected`. `AuditUserLive` currently loads synchronously in `handle_params`
    (`audit_user_live.ex:26-56`, NOT `connected?`-deferred), so `.phx-connected` likely
    suffices today — but row-visible waiting is the safe baseline-stabilizer per the 157 D-06
    perpetual-flake lesson. Placing the slug **before** impersonation runs would freeze an
    empty-state baseline (contradicts the "meaningful rows" intent).

### Area 5 — Baseline re-record scope (GATE-01, GATE-02)
- **D-07 [Likely → locked, consequence of D-05]:** Deliberately re-record **all three**
  `audit-explorer` projects (chromium / mobile / dark), not just mobile. The mobile card
  layout (AUDX-01) is the named delta, but the all-viewport quick-filter chip row (D-05)
  sits **above the fold on every viewport** under `fullPage:false` capture
  (`admin-checkpoints.spec.ts:141`), so desktop and dark shift too. Each re-record is an
  explicitly reasoned **intended delta after HTML-report review** (156/157 discipline:
  no blanket "to be safe" resets; every non-named-delta stays byte-green).
  - **Hard-fail boundary:** Assuming desktop is byte-frozen would surface a surprise red on
    `audit-explorer-chromium`/`-dark`, read as a regression rather than the AUDX-02 delta,
    stalling the gate. Plan the re-record as intentional from the start.
- **D-08 [locked]:** `admin-generated` installer-parity lane (GATE-02) stays green — these
  are lib-owned `Sigra.Admin.Live.*` modules routed directly (no generated-host LiveView
  copies, per 156 D-09). Any admin HEEx mirrored to `test/example/` must stay in lockstep.

### Folded Todos
- **D-09 [folded — `2026-06-04-admin-format-date-naivedatetime.md`]:** Fix `format_date/1`
  to handle `%NaiveDateTime{}` (and optionally `%Date{}`) explicitly so a mis-typed host
  timestamp column degrades **visibly/correctly** rather than silently rendering `"—"` via
  the catch-all. Audit surfaces are timestamp-heavy and read host-controlled data, so this is
  in-scope while building the unified `audit_row`. Apply the head set from the todo:
  `%DateTime{}` and `%NaiveDateTime{}` format; `nil` → `"—"`; unexpected → raise
  `ArgumentError` (at minimum support `NaiveDateTime`; the catch-all must not absorb a
  populated-but-wrong-typed value). Touches `lib/sigra/admin/live/` formatting helpers.
- **D-10 [folded — `2026-06-03-sg-notice-tone-rule-duplication.md`]:** The **CSS** tone-rule
  duplication was already resolved in Phase 156 (shared `.sg-list-row[data-tone], .sg-notice[data-tone]`
  selector merge, 156 D-08). The remaining fold target here is the **Elixir tone-derivation**
  single-source-of-truth: D-01's `audit_row` `audit_tone/1` becomes the one tone helper,
  retiring the divergent `row_tone/1` (×2) and the old `audit_tone/1` so the three audit
  sites can no longer drift. If a lightweight guard is cheap (e.g. a `render_component` golden
  asserting tone→`data-tone` mapping), add it; otherwise the consolidation itself removes the
  drift surface.

### Claude's Discretion
- Exact `audit_row/1` attr names and which detail lines are gated by optional attrs (as long
  as one component serves all three sites and the compact recent-audit variant stays compact).
- Quick-filter chip microcopy and exact placement above the detailed filter form.
- Whether AuditUser reuses AuditIndex's chip markup verbatim or a trimmed subset.
- Exact Playwright wait selector that proves "loaded row, not empty/transient."
- Per-screen commit ordering; whether the audit-row extraction and the two screen migrations
  land in one or several commits.
- Whether to add a tone-mapping golden guard (D-10) or rely on the single-helper consolidation.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `guides/reference/admin-design-contract.md` — the Job→Component mapping + page archetypes;
  governs which `sg-*` classes/components are canonical (skeleton/notice/list-row tone, etc.).
- `lib/sigra/admin/components.ex` — the 10 shared components; `audit_row/1` is the 11th
  (attr/slot norms, flat/stateless house style at :5, `sg-*`-only rule at :9-10).
- `lib/sigra/admin/live/users_index_live.ex` — the dual-layout (`:179-238`) + quick-filter
  chip (`defp quick_filter` :322-338) idiom to MIRROR.
- `lib/sigra/admin/live/audit_index_live.ex` — current explorer (table `:125-162`,
  `applied_chip` row `:116-123`, `row_tone/1` `:206-208`).
- `lib/sigra/admin/live/audit_user_live.ex` — current per-user audit (sync load
  `:26-56`, `<tr>` block `:165-192`, `row_tone/1` `:246-248`).
- `lib/sigra/admin/live/user_show_live.ex` — "Recent Audit" block `:250-275`, `audit_tone/1`
  `:437-440` (the compact card to unify).
- `lib/sigra/admin/audit/query_params.ex` — `@allowed_params` `:9-15,56-60` (the real filter
  param contract — `outcome`, `action_prefix`).
- `lib/sigra/admin/audit/explorer.ex` — `list_events/3` / `list_subject_events` query layer.
- `test/example/priv/static/assets/css/app.css` — `sg-show-desktop/mobile` `:247-255`;
  `sg-list-row[data-tone]` tones `:945-967`.
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — capture pattern `:140-144`,
  journey `:171-277`, `audit-explorer` route `:270`.
- `test/example/lib/example_web/router.ex` — audit routes `:257-293`.
- Prior locks: `.planning/phases/156-.../156-CONTEXT.md` (D-08 tone-merge, D-09 lib-owned),
  `.planning/phases/157-.../157-CONTEXT.md` (D-06 skeleton-vs-data wait discipline).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- 10 shared components in `Sigra.Admin.Components` (incl. `<.page_back>`, `<.scope_ribbon>`,
  `<.notice>`, `<.empty_state>`, `<.applied_chip>`) — AUDX-03 wires these into AuditUserLive.
- `UsersIndexLive` dual-layout + `quick_filter` chip pattern — the template to copy.
- `sg-show-desktop`/`sg-show-mobile` (1024px) and `sg-list-row[data-tone]` CSS already exist;
  no new CSS needed for the audit-row card or the chips.
- The checkpoint journey already generates per-user impersonation audit rows on `targetEmail`
  — the `user-audit` baseline needs **no new seed**.

### Established Patterns
- "Same job → same component" milestone law; flat/stateless function components emitting only
  `sg-*` classes; `render_component` byte/structural goldens before Playwright.
- Deliberate, HTML-report-reviewed baseline re-records; non-delta screens stay byte-green.
- 157 D-06 wait discipline: screenshot waits assert *loaded data visible*, not `.phx-connected`.

### Integration Points
- New `audit_row/1` in `components.ex` consumed by `audit_index_live.ex`,
  `audit_user_live.ex`, and `user_show_live.ex` (the three audit sites converge here).
- Quick-filter chips drive `QueryParams` via existing `outcome`/`action_prefix` params.
- New `user-audit` slug in `admin-checkpoints.spec.ts`; `audit-explorer` baselines re-recorded.
- `format_date/1` formatting helper(s) in `lib/sigra/admin/live/` (D-09 fold).
</code_context>

<specifics>
## Specific Ideas

- Quick-filter chips are **value-setters**, not boolean checkboxes: "Failures" →
  `outcome=failure`, "Impersonation" → `action_prefix=admin.impersonation` (D-04). This is the
  one consciously-chosen affordance fork — confirmed with the user.
- Chips on **all viewports** (D-05), accepting the all-three-project `audit-explorer`
  re-record (D-07).
- `user-audit` checkpoint reuses `targetEmail` post-impersonation (D-06) — do not seed a new
  audit-rich user (FIXT-04 seed enrichment is Phase 159's concern, not 158's).
</specifics>

<deferred>
## Deferred Ideas

- Net-new admin surfaces, IA restructure, host-overridable component hooks (ADMN-F1/F2/F3) —
  explicitly out of scope this milestone.
- FIXT-04 richer audit seed variety (password change / magic link / API token / 2nd OAuth) —
  belongs to **Phase 159** (Seed Enrichment), not 158; 158's checkpoint uses existing
  impersonation events.
- GATE-03 motion-usage audit — Phase 159 scope.

### Reviewed Todos (not folded)
- `2026-06-04-admin-overview-cleanup-misc.md` — Overview (index/organization) cleanup; 157
  surface, not audit.
- `2026-06-04-admin-overview-needs-review-count-link-mismatch.md` — Overview alarm count vs
  deep-link; 157 surface.
- `2026-06-04-admin-overview-notice-role-status.md` — Overview `role="status"` semantics; 157
  surface.
- `2026-06-04-org-notice-nested-p.md` — already folded into 157 D-07 (Org overview redesign).
</deferred>
</content>
</invoke>
