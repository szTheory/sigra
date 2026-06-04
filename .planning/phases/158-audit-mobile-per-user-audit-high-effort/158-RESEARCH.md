# Phase 158: Audit Mobile + Per-User Audit (High Effort) - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView admin UI coherence — function-component extraction, dual-layout (mobile card fallback), value-setting filter chips, Playwright visual checkpoints + axe gate. Elixir/Phoenix 1.8+, build-free `sg-*` CSS token layer.
**Confidence:** HIGH (entire phase verified against live codebase via Read/grep; this is a coherence pass on a mature tree, not greenfield)

## Summary

This is a coherence pass on an existing, very mature codebase. CONTEXT.md and UI-SPEC.md already lock the technical approach in deep detail (exact files + line numbers, D-01..D-10). My job was to verify the cited code is exactly as CONTEXT describes, surface drift and landmines, and produce a Validation Architecture for the Nyquist VALIDATION.md.

**The decisions hold up against the live code** — the Presenter produces every field the unified `audit_row/1` needs, the three divergent renderings exist as described, the route exists, the dual-layout idiom and the Playwright two-call pattern are real, and `@allowed_params` contains `action_prefix`/`outcome` with no boolean `impersonation`/`failure` param. **However, three landmines and several line-number drifts must reach the planner.**

**Primary recommendation:** Plan the work in this order — (1) add unified `audit_row/1` + single `audit_tone/1` to `Sigra.Admin.Components` with a byte-golden test FIRST; (2) wire it into the three sites and delete the three divergent tone helpers; (3) resolve the **chip-as-link vs `sg-filter-chip:has(input:checked)`** tension explicitly; (4) reconcile the **`format_date/1` vs `format_timestamp/1` naming/behavior drift**; (5) re-record all three `audit-explorer` baselines and add three `user-audit` baselines as a deliberate, HTML-report-reviewed step.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Unified audit-row presentation | Library — `Sigra.Admin.Components` (`audit_row/1`) | — | Lib-owned component, propagates to host apps via `mix deps.update` (D-05/156 D-09). Flat/stateless function component. |
| Audit-row tone derivation (`audit_tone/1`) | Library LiveView-private helper | — | Single source of truth retiring the 3 divergent helpers; lives next to the component or in each LiveView per house style — see Open Question. |
| Mobile/desktop dual-layout switch | CSS (`sg-show-desktop`/`sg-show-mobile`) + LiveView markup | — | Pure CSS breakpoint at 1024px; LiveView emits both branches, CSS hides one. No JS. |
| Quick-filter chips → query params | Library LiveView (`AuditIndexLive`/`AuditUserLive`) | `QueryParams` (existing) | Chips set existing string params; no query-layer change. |
| Filter param normalization | Library — `Sigra.Admin.Audit.QueryParams` | — | Unchanged; `action_prefix`/`outcome` already whitelisted. |
| Row data shaping | Library — `Sigra.Admin.Audit.Presenter` | `Detail.recent_audit_preview/3` | Unchanged; already produces the full field set for all three sites. |
| Visual regression + a11y gate | Test tier — Playwright `admin-checkpoints.spec.ts` + axe | — | Lib-owned modules exercised through the example host; baselines committed PNGs. |

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add an **11th shared function component `audit_row/1`** to `Sigra.Admin.Components`, emitting the **card form** (`sg-list-row <article>` shape). Use it for AuditIndex mobile cards, AuditUser mobile cards, AND the `UserShowLive` "Recent Audit" block. Desktop `<table>` rows in both explorers stay inline `<tr>`. Contract: single `attr :row, :map` + an internal unified `audit_tone/1` derived from `outcome`/`action_badge` (single source of truth retiring `row_tone`/`audit_tone` divergence). Optional attrs toggle `row.id`/`row.action` code lines and `Actor:`/`Effective user:` detail lines. **Hard-fail boundary:** Do NOT build a polymorphic `audit_row/1` with `variant={:table|:card}`.
- **D-02:** Mirror `UsersIndexLive` exactly for `AuditIndexLive`. Wrap desktop table in `<div class="sg-table-panel sg-show-desktop" data-testid="admin-audit-desktop-results">`; add sibling `<div class="sg-stack sg-stack--3 sg-show-mobile" data-testid="admin-audit-mobile-results">` iterating `<.audit_row>` cards. **Hard-fail boundary:** Do NOT solve mobile via horizontal-scroll on the table.
- **D-03:** Apply the same dual-layout to `AuditUserLive`, reusing `<.audit_row>` cards. testids `admin-audit-user-desktop-results` / `admin-audit-user-mobile-results`.
- **D-04 [user-confirmed]:** Add quick-filter chips reusing `sg-filter-chip` styling, backed by the audit query's **existing string params** as **value-setting links/setters** (NOT boolean checkboxes): a "Failures" chip → `outcome=failure`, an "Impersonation" chip → `action_prefix=admin.impersonation`. Detailed filter form stays; chips populate the same params and surface through the existing `<.applied_chip>` row. **Hard-fail boundary:** Impersonation is NOT a boolean column — chips MUST set the real param values; an `impersonation=true` chip would be silently dropped by `QueryParams`.
- **D-05 [user-confirmed]:** Chips render on **all viewports** (desktop + mobile) — one filter idiom everywhere.
- **D-06:** Add one new slug `user-audit` to the single authenticated journey in `admin-checkpoints.spec.ts` via `captureAndVerify(...)` + `assertCheckpointScreenshot(...)`, navigating to `/admin/users/:id/audit` for the journey's existing `targetEmail` user **after** the impersonation start/stop sequence (zero new seed). Produces 3 new committed PNGs (chromium/mobile/dark) with the axe gate. **Hard-fail boundary:** screenshot wait MUST assert a **visible loaded audit row**, not just `.phx-connected`. Placing the slug before impersonation would freeze an empty-state baseline.
- **D-07:** Deliberately re-record **all three** `audit-explorer` projects (chromium/mobile/dark) as intended deltas after HTML-report review. **Hard-fail boundary:** Do NOT assume desktop is byte-frozen — the all-viewport chip row shifts desktop+dark under `fullPage:false` capture.
- **D-08:** `admin-generated` installer-parity lane (GATE-02) stays green — lib-owned `Sigra.Admin.Live.*` modules routed directly (no generated-host LiveView copies, 156 D-09). Any admin HEEx mirrored to `test/example/` must stay in lockstep.
- **D-09 [folded]:** Fix the date helper to handle `%NaiveDateTime{}` explicitly: `%DateTime{}` and `%NaiveDateTime{}` → format; `nil` → `"—"`; unexpected → raise `ArgumentError` (no silent catch-all absorbing a populated-but-wrong-typed value). **See CRITICAL DRIFT #1 — the cited `format_date/1` does not exist in the audit views.**
- **D-10 [folded]:** The Elixir tone-derivation single-source-of-truth: D-01's `audit_row` `audit_tone/1` becomes the one tone helper, retiring `row_tone/1` (×2) and the old `audit_tone/1`. Optionally add a `render_component` golden asserting tone→`data-tone` mapping.

### Claude's Discretion
- Exact `audit_row/1` attr names and which detail lines are gated by optional attrs (one component must serve all three sites; compact recent-audit variant stays compact).
- Quick-filter chip microcopy and exact placement above the detailed filter form.
- Whether AuditUser reuses AuditIndex's chip markup verbatim or a trimmed subset.
- Exact Playwright wait selector that proves "loaded row, not empty/transient."
- Per-screen commit ordering; whether audit-row extraction and the two screen migrations land in one or several commits.
- Whether to add a tone-mapping golden guard (D-10) or rely on the single-helper consolidation.

### Deferred Ideas (OUT OF SCOPE)
- Net-new admin surfaces, IA restructure, host-overridable component hooks (ADMN-F1/F2/F3).
- FIXT-04 richer audit seed variety — **Phase 159** (Seed Enrichment), NOT 158. 158's checkpoint uses existing impersonation events on `targetEmail`.
- GATE-03 motion-usage audit — Phase 159 scope.
- New design tokens, new CSS classes, new runtime deps, Tailwind, horizontal-scroll responsive pattern.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUDX-01 | `AuditIndexLive` mobile card layout mirroring users-index dual-layout | `sg-show-desktop`/`sg-show-mobile` exist (`app.css:247-255`, flip at 1024px); `UsersIndexLive` dual-layout idiom verified (`users_index_live.ex:179-280`); `audit_row/1` card reuses `sg-list-row` (`app.css:945-967`). No new CSS. |
| AUDX-02 | Quick-filter chips for common cases consistent with users-index idiom | `sg-filter-chip` CSS exists (`app.css:858-882`); `@allowed_params` has `action_prefix`+`outcome` (`query_params.ex:9-21,53-61`). **LANDMINE:** existing chip CSS active state is `:has(input:checked)` (checkbox), but D-04 mandates value-setting links — see Common Pitfalls #1. |
| AUDX-03 | Per-user audit reconciled — shared components, shared filter idiom, mobile layout, shared audit-row also used by user-detail recent-audit | `AuditUserLive` currently hand-rolls `<.applied_chip>`/`<.empty_state>`/`<.page_back>`/`<.scope_ribbon>` inline (verified) — all four exist in `Sigra.Admin.Components` and must be wired in. Presenter produces identical fields for all three sites (`presenter.ex:20-35`, `detail.ex:61-102`). |
</phase_requirements>

---

## Standard Stack

No new dependencies. This phase composes existing primitives only. Confirmed in-tree:

### Core (existing, verified present)
| Library / Primitive | Location | Purpose | Status |
|---------------------|----------|---------|--------|
| `Sigra.Admin.Components` | `lib/sigra/admin/components.ex` | 10 flat/stateless function components; `audit_row/1` is the 11th | `[VERIFIED: codebase]` — 10 components present (`stat_link`, `stat`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`, `notice`, `skeleton`) |
| `Sigra.Admin.Audit.Presenter` | `lib/sigra/admin/audit/presenter.ex` | Produces row maps: `id`, `inserted_at`, `action`, `action_label`, `action_badge`, `actor_label`, `effective_user_label`, `actor_summary`, `outcome` | `[VERIFIED: codebase]` (`presenter.ex:20-35`) |
| `Sigra.Admin.Audit.QueryParams` | `lib/sigra/admin/audit/query_params.ex` | Whitelist param normalizer; `@allowed_params` includes `action_prefix`, `outcome` | `[VERIFIED: codebase]` (`:9-21`); no `impersonation`/`failure` boolean param `[VERIFIED]` |
| `@axe-core/playwright` ^4.10.0, `@playwright/test` ^1.48.0 | `test/example/priv/playwright/package.json` | Visual checkpoint + WCAG A/AA gate | `[VERIFIED: codebase]` |

### Supporting (existing CSS, verified present, zero new classes)
| Class | Location | Purpose |
|-------|----------|---------|
| `sg-show-desktop` / `sg-show-mobile` | `app.css:247-255` | Dual-layout breakpoint (1024px) |
| `sg-list-row` + `[data-tone="ok|warn|risk|info"]` | `app.css:945-967` | Audit-row card surface + tone treatment (merged selector with `sg-notice`, 156 D-08) |
| `sg-filter-chip` + `:has(input:checked)` | `app.css:858-882` | Quick-filter chip; **active state is keyed on a checked input** (landmine for link-based chips) |
| `sg-applied-chip` / `sg-applied-chip__remove` | `app.css:884+` | Active-filter remove pill (already used) |
| `sg-table-panel`, `sg-stack`, `sg-stack--3`, `sg-cluster`, `sg-status-pill`, `sg-code`, `sg-muted` | `app.css` | Existing layout/text primitives |

**Installation:** None. `mix deps.get` already satisfied. No `mix.exs` change.

**Version verification:** N/A — no new packages. (Package Legitimacy Audit omitted: this phase installs zero external packages.)

---

## Architecture Patterns

### System data flow (audit surfaces)

```
HTTP GET /admin/audit?action_prefix=admin.impersonation&outcome=failure
        │  (or /admin/users/:id/audit, or /admin/organizations/:org/...)
        ▼
Router live_session  ── on_mount AdminScope ──►  assigns.admin_scope (:global | :organization)
        ▼
LiveView.handle_params(params)              ◄── AuditIndexLive / AuditUserLive (SYNC load, not connected?-deferred)
        ▼
QueryParams.normalize(params, scope)        ── whitelist Map.take(@allowed_params); UUID/datetime cast
        ▼
Explorer.list_events/3  (or list_subject_events/4)
        ▼
Presenter.present(events, users_by_id)      ── row map: id, inserted_at, action, action_label,
        │                                       action_badge, actor_label, effective_user_label,
        │                                       actor_summary, outcome
        ▼
assign(:rows, …) ; assign(:current_params, …) ; assign(:meta, …)
        ▼
render/1 ─┬─ desktop  <div sg-table-panel sg-show-desktop>  <table> inline <tr> (tone via audit_tone/1)
          ├─ mobile   <div sg-stack sg-show-mobile>  <.audit_row :for={row} show_detail show_codes/>  ◄── NEW
          └─ chips    <.audit chip links> set outcome=failure / action_prefix=admin.impersonation  ◄── NEW

UserShowLive "Recent Audit": Detail.recent_audit_preview/3 → Presenter.present/2
          └─ <.audit_row :for={row} />  (compact: show_detail=false, show_codes=false)  ◄── NEW
```

The desktop `<tr>` and the card `<article>` cannot share markup (a `<tr>` is not an `<article>`) — exactly why `UsersIndexLive` keeps its `<tr>` inline and shares nothing with its mobile `<article>` (`users_index_live.ex:194-280`). `audit_row/1` is the CARD shape only.

### Pattern 1: Dual-layout (the idiom to mirror)
**What:** Two sibling result containers, CSS hides one per breakpoint.
**Source:** `users_index_live.ex:179-280`
```heex
<div id="admin-users-desktop-results" data-testid="admin-users-desktop-results"
     class="sg-table-panel sg-show-desktop">
  <table class="sg-table"> … inline <tr> rows … </table>
</div>
<div id="admin-users-mobile-results" data-testid="admin-users-mobile-results"
     class="sg-stack sg-stack--3 sg-show-mobile">
  <article :for={row <- @rows} class="sg-card sg-stack sg-stack--3"> … </article>
</div>
```
For audit, the mobile `<article>` becomes `<.audit_row row={row} show_detail show_codes />` (card uses `sg-list-row`, not `sg-card`, per D-01/UI-SPEC). Keep the `id=` AND `data-testid=` (both present in the users idiom).

### Pattern 2: Unified `audit_row/1` card (the new 11th component)
**What:** Flat stateless function component, card form, single `attr :row, :map` + optional booleans. Markup per UI-SPEC lines 124-159. House-style match: every existing component takes `attr … :class, default: nil` + `attr :rest, :global` and merges `class={[…, @class]} {@rest}` (`components.ex` passim). `audit_row/1` should follow the same `:class`/`:rest` convention for consistency unless the planner deliberately omits (note the golden will freeze whatever is chosen).
**Tone helper (single source of truth, D-10):**
```elixir
defp audit_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
defp audit_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
defp audit_tone(_row), do: nil
```
This is the `row_tone/1` body verbatim from `audit_index_live.ex:206-208` / `audit_user_live.ex:246-248`. It is NOT the same as `user_show_live.ex:437-440`'s `audit_tone/1`, which lacks the impersonation→`"info"` branch — see Pitfall #3.

### Pattern 3: `render_component` byte-golden discipline
**What:** Before any Playwright run, each component has a literal `==` string golden in `test/sigra/admin/components_test.exs`. No mneme/auto_assert/snapshot lib (D-13 in that file). Each assertion carries a "drifted — see admin-design-contract.md; do not re-record Playwright baselines" message.
**Source:** `test/sigra/admin/components_test.exs:1-90` (10 tests today; `audit_row` golden(s) become the 11th+).
```elixir
@audit_row_golden "<article class=\"sg-list-row sg-stack sg-stack--2\" data-tone=\"info\"> … </article>"
test "audit_row renders the unified card bytes faithfully" do
  html = render_component(&Components.audit_row/1, row: %{…fixed assigns…})
  assert html == @audit_row_golden, "audit_row drifted — see admin-design-contract.md; do not re-record Playwright baselines"
end
```
Plan AT LEAST: one golden for the compact variant (UserShow: `show_detail=false`, `show_codes=false`) and one for the full variant (explorer: `show_detail=true`, `show_codes=true`), plus optionally a tone-mapping golden (D-10). The compact golden must reproduce the exact bytes `user_show_live.ex:265-272` produces today for characterization fidelity — including the timestamp format (`%Y-%m-%d %H:%M`, see Pitfall #2).

### Pattern 4: Playwright two-call checkpoint + axe
**Source:** `admin-checkpoints.spec.ts:94-145, 270-276`
```ts
await captureAndVerify(page, testInfo, 'user-audit');           // attaches artifact + asserts non-empty PNG
await assertCheckpointScreenshot(page, testInfo, 'user-audit'); // axe gate THEN toHaveScreenshot('user-audit.png')
```
`assertCheckpointScreenshot` runs `assertNoAxeViolations` (WCAG 2a/2aa) first, then `toHaveScreenshot` with `fullPage: false` and per-project `maxDiffPixels` tolerances (`:140-144`).

### Anti-Patterns to Avoid
- **Polymorphic `audit_row/1` (`variant={:table|:card}`):** explicit D-01 hard-fail boundary. Card only.
- **Horizontal-scroll responsive table:** explicit D-02 hard-fail boundary.
- **`impersonation=true` / `failure=true` boolean chip params:** silently dropped by `QueryParams.normalize` (`Map.take(@allowed_params)` excludes them). D-04 hard-fail boundary.
- **Re-recording baselines "to be safe":** 156/157 discipline — every non-named-delta stays byte-green; each re-record is reasoned after HTML-report review.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audit-row tone | A 4th tone helper | The single `audit_tone/1` in/near `audit_row` | D-10 explicitly retires the 3 divergent helpers; a 4th re-creates the drift. |
| Filter param plumbing | New `impersonation`/`failure` params through `QueryParams` | Existing `action_prefix`/`outcome` string params | They already work end-to-end (checkpoint journey proves `?action_prefix=admin.impersonation`). |
| Back-nav / scope ribbon / empty state in AuditUserLive | Inline `<a>`/`<span>`/`<div class="sg-empty-state">` (current state) | `<.page_back>`, `<.scope_ribbon>`, `<.empty_state>`, `<.applied_chip>` from `Sigra.Admin.Components` | AUDX-03 reconciliation is literally this; the components exist and are golden-tested. |
| Snapshot assertions for components | A snapshot library | Literal `==` byte goldens | Project policy (components_test.exs D-13). |

**Key insight:** Every "build" in this phase already has a canonical home. The work is consolidation + wiring, not invention.

---

## Runtime State Inventory

This is a UI-coherence phase with no rename/migration. The only stored-state-adjacent concerns:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — audit events are read-only; no schema/migration change. | None — verified: no `priv/repo` or generator change in scope. |
| Live service config | None. | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | Playwright lane reads `SIGRA_PLATFORM_ADMIN_EMAIL` etc. (`admin-generated.spec.ts:24-32`) — unchanged. | None. |
| Build artifacts | **Committed PNG baselines** under `admin-checkpoints.spec.ts-snapshots/`: 3 `audit-explorer-*` to re-record, 3 new `user-audit-*` to create. | Re-record via `--update-snapshots` then `git add` the PNGs (D-07/D-06). |

---

## Common Pitfalls

### Pitfall 1 (LANDMINE): `sg-filter-chip` active state is `:has(input:checked)` but D-04 mandates value-setting LINKS
**What goes wrong:** The existing `sg-filter-chip:has(input:checked)` rule (`app.css:878-882`) only applies the brand-soft "active" treatment when there is a checked `<input>` inside the chip. `UsersIndexLive`'s `quick_filter/1` (`users_index_live.ex:325-338`) is exactly that — a `<label class="sg-filter-chip"><input type="checkbox" name={@key} value="true" checked={…}></label>`. But D-04 forbids that pattern for audit because impersonation/failure are string param *values*, not boolean params. A link-based chip (`<a href="?outcome=failure">`) has no `<input>`, so the existing CSS will never show it as active.
**Why it happens:** The mature CSS was written for the boolean-checkbox users-index idiom; the audit decision deliberately diverges on the value semantics.
**How to avoid:** This is a Claude's-discretion design point the planner MUST resolve explicitly. Options: (a) keep the `<label class="sg-filter-chip"><input>` shell but make submission set the real string value (e.g. a checkbox whose checked state maps to the param value via the surrounding GET form, or a radio/hidden-input scheme), preserving the `:has(input:checked)` active CSS with zero new CSS; or (b) use plain `<a>` links and accept that "active" is signalled only via the existing `<.applied_chip>` row (UI-SPEC line 192 leaves this open: "Clear via the `<.applied_chip>` remove link" OR "clicking an active chip deactivates"). Option (a) keeps the visual active state with no new CSS and is the closest match to the users idiom while still setting real param values — recommend (a) unless the planner finds the form-submission semantics awkward. **Do not ship a chip whose active state never renders.**
**Warning signs:** A chip that looks identical whether or not its filter is applied; an `impersonation=true` querystring that returns unfiltered results.

### Pitfall 2 (CRITICAL DRIFT): `format_date/1` does not exist in the audit views — they use `format_timestamp/1`
**What goes wrong:** CONTEXT D-09 and UI-SPEC (lines 138-139, 260-266) instruct the implementer to "fix `format_date/1`" in `lib/sigra/admin/live/`. **There is no `format_date/1` in `audit_index_live.ex`, `audit_user_live.ex`, or `user_show_live.ex`.** What actually exists:
- `audit_index_live.ex:265-268` and `audit_user_live.ex:384-387`: `defp format_timestamp(%DateTime{}) -> "%Y-%m-%d %H:%M:%S"`; **catch-all `format_timestamp(_) -> ""`** (empty string, not `"—"`).
- `user_show_live.ex:271`: inline `Calendar.strftime(row.inserted_at, "%Y-%m-%d %H:%M")` — **no helper at all**, and a DIFFERENT format (no seconds).
- `organization_live.ex:190-191`: the ONLY `format_date/1`: `%DateTime{} -> "%Y-%m-%d"`; catch-all `-> "—"` — different format, different file, different surface (org invites, not audit).
**Why it happens:** The folded todo (`2026-06-04-admin-format-date-naivedatetime.md`) named the helper generically; the audit surfaces use a differently-named helper with a *worse* catch-all (`""` silently swallows wrong-typed values — exactly the bug the todo targets, but at a different name).
**How to avoid:** The planner must decide WHICH helper the unified `audit_row/1` calls and apply the D-09 head set to it. Because `audit_row/1` is the single rendering site post-consolidation, the cleanest move is: give `audit_row/1` its own private `format_date/1` (or keep the name `format_timestamp/1` but apply the D-09 contract) with heads `%DateTime{}`+`%NaiveDateTime{}` → format, `nil` → `"—"`, else → raise `ArgumentError`. **Decide one format string** — the explorer table currently shows seconds (`%Y-%m-%d %H:%M:%S`) while the compact card shows no seconds (`%Y-%m-%d %H:%M`); the byte-golden for the compact variant will freeze whichever is chosen, and changing the explorer-table seconds will shift the `audit-explorer` baseline (acceptable under D-07, but reason it explicitly). Note `organization_live.ex`'s `format_date/1` is OUT of scope (org surface, Phase 157 territory) — leave it unless the planner deliberately unifies.
**Warning signs:** A `format_date(naive_datetime)` call rendering `""` or `"—"` instead of raising; a baseline diff on `audit-explorer` that is actually a timestamp-format change nobody intended.

### Pitfall 3: The three tone helpers genuinely disagree — consolidation changes UserShowLive output
**What goes wrong:** `user_show_live.ex:437-440` `audit_tone/1` returns `nil` for impersonation rows (it only does success→nil / non-success→risk, no `action_badge` branch). The explorer `row_tone/1` (×2) returns `"info"` for impersonation. Adopting the unified helper (which has the `action_badge → "info"` branch) means **impersonation rows in the UserShowLive "Recent Audit" block will gain `data-tone="info"`** where today they have none — a real visual change on the `user-detail` checkpoint.
**Why it happens:** D-10 is exactly this drift; the consolidation is intended, but its side effect on UserShow is easy to miss.
**How to avoid:** Expect the `user-detail` baseline to potentially shift if the seeded recent-audit contains impersonation rows. Verify whether `targetEmail`'s recent-audit preview includes impersonation events; if so, plan `user-detail` as a possible additional intended re-record (CONTEXT only names `audit-explorer` ×3 and `user-audit` ×3 — flag this to the planner so a surprise red on `user-detail` is anticipated, not read as regression). The compact-variant byte golden must be authored from the NEW unified behavior, not the old `audit_tone/1`.
**Warning signs:** `user-detail-*` baseline red after the tone consolidation.

### Pitfall 4: Line-number drift between CONTEXT/UI-SPEC and live code
**What goes wrong:** CONTEXT cites line numbers from before Phase 157 landed `global-overview`/`org-overview` checkpoints and other edits. Several have drifted (see Drift table). Implementers who navigate by line number will land in the wrong place.
**How to avoid:** Navigate by symbol/structure, not line number. The Drift table below gives current locations.

---

## CRITICAL DRIFT TABLE (CONTEXT/UI-SPEC cited lines vs live code)

| Cited (CONTEXT/UI-SPEC) | Live reality | Impact |
|--------------------------|--------------|--------|
| `format_date/1` in `lib/sigra/admin/live/` audit views (D-09, UI-SPEC 138-139,260-266) | **No `format_date/1` in any audit view.** Audit views use `format_timestamp/1` (catch-all `""`). UserShow uses inline `Calendar.strftime`. Only `format_date/1` is in `organization_live.ex:190-191` (different surface/format). | **HIGH** — planner must reconcile name + behavior + format string. See Pitfall #2. |
| `sg-filter-chip` active state copyable from users-index for value-links | Active CSS is `:has(input:checked)` (`app.css:878-882`); users `quick_filter/1` is a checkbox (`users_index_live.ex:325-338`). Link-chips have no checked input. | **HIGH** — see Pitfall #1. |
| `user_show_live.ex:265-272` compact card; `audit_tone/1:437-440` | Card at `265-272` ✓. `audit_tone/1` at `437-440` ✓ — but it LACKS the impersonation branch (Pitfall #3). | MEDIUM — consolidation changes UserShow output. |
| `audit_index_live.ex` table `:125-162`, `row_tone/1:206-208` | Table `<tr>` at `136-163`; `row_tone/1` at `206-208` ✓; applied_chip row `116-123` ✓. | LOW — minor offset. |
| `audit_user_live.ex` `<tr>` `:165-192`, `row_tone/1:246-248`, sync load `:26-56` | `<tr>` at `165-192` ✓; `row_tone/1` at `246-248` ✓; sync `handle_params` at `26-56` ✓. **Confirmed: AuditUser hand-rolls applied_chip (`138-148`), empty_state (`197-217`), back-nav (`63-66`), scope ribbon (`66`) inline — none use the shared components yet.** | LOW (lines ok) / informs AUDX-03 scope. |
| `users_index_live.ex` dual-layout `:179-238`, `quick_filter:322-338` | Dual-layout `179-280` (desktop `179-232`, mobile `234-280`); `quick_filter/1` `325-338`; `@quick_filter_keys` `14`; rendered `108`. | LOW — slightly wider than cited. |
| `query_params.ex` `@allowed_params:9-15,56-60` | `@allowed_params` `9-21`; per-key reduce clauses `action_prefix` `56-57`, `outcome` `59-60`. No `impersonation`/`failure`. ✓ | LOW. |
| `admin-checkpoints.spec.ts` capture `:140-144`, journey `:171-277`, `audit-explorer` `:270-273` | capture `94-145`; `toHaveScreenshot` `140-144` ✓; journey `147-278` (now includes `global-overview` `171-181` + `org-overview` `183-192` added by 157); impersonation start `233-241`, stop `259-265`; `audit-explorer` slug `267-276`. | MEDIUM — journey now has 7 checkpoints, not 5 (header comment stale). Insert `user-audit` AFTER `audit-explorer` (`276`) or between stop (`265`) and `audit-explorer` (`267`) — both satisfy "after impersonation stop." |
| `router.ex` audit routes `:257-293`, `AuditUserLive` `:260,293` | `live "/admin/users/:id/audit" → AuditUserLive` at `260` (global) and `293` (org) ✓. | NONE — exact. |
| `app.css` `sg-show` `:247-255`, `sg-list-row[data-tone]` `:945-967` | `sg-show` `247-255` ✓; `sg-list-row[data-tone]` `952-967` (block starts `945`) ✓; `sg-filter-chip` `858-882` ✓. | NONE/LOW. |

---

## Code Examples (verified from live tree)

### Presenter row map (the `:row` struct `audit_row/1` consumes)
```elixir
# Source: lib/sigra/admin/audit/presenter.ex:20-35
%{
  id: event.id,
  inserted_at: event.inserted_at,                      # DateTime.t() from Ecto
  action: event.action,                                # e.g. "admin.impersonation.start"
  action_label: action_label(event.action),           # "Impersonation started"
  action_badge: if(impersonation?, do: "Impersonation", else: nil),
  actor_label: user_label(actor, event.actor_id),
  effective_user_label: user_label(effective_user, event.effective_user_id),
  actor_summary: if(impersonation?, do: "<a> acting as <b>", else: user_label(actor, ...)),
  outcome: event.outcome || "success"                  # NB: defaults to "success", never nil from explorer
}
```
`Detail.recent_audit_preview/3` (`detail.ex:82-102`) calls the SAME `Presenter.present/2` and documents the identical key set (`detail.ex:66-80`) with a "MUST NOT introduce fields outside this set" contract — so all three sites are field-compatible by construction.

### Existing inline applied-chip in AuditUser to REPLACE with `<.applied_chip>`
```heex
<!-- Source: audit_user_live.ex:138-148 — currently hand-rolled, AUDX-03 replaces with <.applied_chip> -->
<span :for={chip <- applied_chips(@current_params)} class="sg-applied-chip">
  <span>{chip.label}</span>
  <a class="sg-applied-chip__remove" href={remove_chip_path(...)} aria-label={"Remove filter " <> chip.label}>
    <span aria-hidden="true">&times;</span><span class="sr-only">remove</span>
  </a>
</span>
```
This is byte-identical to the `<.applied_chip>` golden (`components_test.exs:40`), so swapping to the component is behavior-preserving for the desktop/dark `audit-explorer`/`user-audit` baselines (the chip markup itself does not change — only the source).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 3 divergent audit renderings + 3 tone helpers | 1 `audit_row/1` card + 1 `audit_tone/1` | This phase (D-01/D-10) | Retires `row_tone/1` ×2 + `audit_tone/1`. |
| Audit explorer table-only (overflows mobile) | Dual-layout card fallback | This phase (D-02/D-03) | Mirrors users-index. |
| AuditUser hand-rolled chrome | Shared `Sigra.Admin.Components` | This phase (AUDX-03) | Coherence. |
| 5-checkpoint journey | 7-checkpoint (global/org overview added 157), → 8 with `user-audit` | 157 then this phase | Header comment in spec is stale ("five required pages"); planner may update it. |

---

## Validation Architecture

> `workflow.nyquist_validation: true` (`.planning/config.json`) — section required.

### Test Framework
| Property | Value |
|----------|-------|
| Component goldens | ExUnit `Sigra.Admin.ComponentsTest` (`test/sigra/admin/components_test.exs`); `Phoenix.LiveViewTest.render_component/2`; literal `==` byte assertions; **no snapshot lib** |
| LiveView/integration | ExUnit (`test/sigra/admin/**`, `test/example/test/**`); requires live Postgres at `localhost:5432` (`postgres`/`postgres`) per CLAUDE.md |
| Visual checkpoint + a11y | Playwright `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`; `@axe-core/playwright` WCAG 2a/2aa; committed PNG baselines |
| Parity smoke | Playwright `admin-generated.spec.ts` (project `admin-generated`) — shell/scope/nav/access only, NO screenshot baseline |
| Quick run command | `mix test test/sigra/admin/components_test.exs` |
| Full suite command | `mix test` (Elixir) + Playwright (below) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | Exists? |
|-----|----------|-----------|-------------------|---------|
| AUDX-03 | `audit_row/1` compact variant byte-equals old UserShow card | golden | `mix test test/sigra/admin/components_test.exs` | ❌ Wave 0 (add `audit_row` golden) |
| AUDX-03 | `audit_row/1` full variant (explorer) bytes frozen | golden | same | ❌ Wave 0 |
| AUDX-03 / D-10 | tone→`data-tone` mapping (risk/info/nil) | golden (optional) | same | ❌ Wave 0 (optional per D-10) |
| D-09 | `format_date`/`format_timestamp` raises on wrong type, `"—"` on nil | unit | `mix test test/sigra/admin/live/` (add test) | ❌ Wave 0 |
| AUDX-01 | AuditIndex desktop hidden / mobile cards shown at <1024px; `data-testid` present | Playwright (mobile project) | see commands below | ❌ Wave 0 (new `user-audit` + re-recorded `audit-explorer`) |
| AUDX-02 | Chip sets real param (`outcome=failure` / `action_prefix=admin.impersonation`); active chip renders active state | LiveView test + Playwright | `mix test` + checkpoint | ❌ Wave 0 |
| AUDX-03 | AuditUser uses shared `<.page_back>`/`<.scope_ribbon>`/`<.notice>`/`<.empty_state>` | LiveView render assert | `mix test test/sigra/admin/` | ❌ Wave 0 |
| GATE-01 | `user-audit` ×3 (chromium/mobile/dark) green + axe; loaded row visible | Playwright | see commands | ❌ Wave 0 (new baselines) |
| GATE-01 | `audit-explorer` ×3 deliberately re-recorded as intended deltas | Playwright | see commands | re-record |
| GATE-02 | `admin-generated` parity lane green | Playwright | see commands | ✓ exists (must stay green) |

### Observable signals (for VALIDATION.md)
- **AUDX-01:** at iPhone-13 viewport, `[data-testid="admin-audit-desktop-results"]` is `display:none` and `[data-testid="admin-audit-mobile-results"]` contains ≥1 `<article class="sg-list-row">`; at ≥1024px the inverse. Captured in `audit-explorer-*-mobile.png` + `user-audit-*-mobile.png`.
- **AUDX-02:** navigating a chip yields a URL with the real param and a filtered result set; the active chip renders the brand-soft state; the `<.applied_chip>` row shows the active filter.
- **AUDX-03:** AuditUser DOM contains the shared-component output (e.g. `<.page_back>` ghost button with `&larr;`, `sg-empty-state__title`); the same `audit_row` card markup appears in AuditUser mobile, AuditIndex mobile, AND UserShow recent-audit (byte-golden proves single source).
- **GATE-01:** three new `user-audit-admin-checkpoints-{chromium,mobile,dark}.png` exist + committed; axe 0 violations on each; screenshot wait asserts a visible loaded row (recommended selector: `[data-testid="admin-audit-user-mobile-results"] article` OR `[data-testid="admin-audit-user-desktop-results"] tbody tr` — pick per project, or a stable action-label pill text like "Impersonation"). `AuditUserLive` loads synchronously in `handle_params` (`audit_user_live.ex:26-56`), so `.phx-connected` likely suffices today, but row-visible wait is the safe baseline-stabilizer (157 D-06 lesson).
- **GATE-02:** `admin-generated` project passes (shell renders, Global+org scope labels visible, nav present, 403/404 copy intact). Because admin LiveViews are lib-owned and routed directly (`router.ex:256-294`), there is **no generated-host HeEx to mirror** — the parity lane exercises the same `Sigra.Admin.Live.*` modules. It stays green as long as the admin HEEx renders without error.

### Sampling Rate
- **Per task commit:** `mix test test/sigra/admin/components_test.exs` (goldens — fast, no DB needed for component goldens; `@endpoint nil`).
- **Per wave merge:** `mix test` (full Elixir; needs Postgres) + targeted Playwright project.
- **Phase gate:** full `mix test` green + all Playwright projects green with reviewed baselines, before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/sigra/admin/components_test.exs` — add `audit_row` golden(s): compact + full variant (+ optional tone-mapping golden, D-10).
- [ ] Date-helper unit test — `%DateTime{}`/`%NaiveDateTime{}` format, `nil → "—"`, wrong-type → `ArgumentError` (D-09).
- [ ] New committed baselines: `user-audit-admin-checkpoints-{chromium,mobile,dark}.png`.
- [ ] Re-recorded baselines: `audit-explorer-admin-checkpoints-{chromium,mobile,dark}.png` (D-07).
- [ ] Possible additional re-record: `user-detail-*` if recent-audit gains impersonation `data-tone="info"` (Pitfall #3) — verify and flag.

### Playwright run mechanics (local)
`package.json` exposes only `test` (`playwright test`) and `install-browsers`. Project names (from `playwright.config.ts:108-144`): `admin-checkpoints-chromium`, `admin-checkpoints-mobile`, `admin-checkpoints-dark`, `admin-generated`. Per MEMORY (admin-checkpoint Playwright procedure):
- Boot the example dev server on an ALT `PORT` (port 4000 is taken by Rulestead Docker locally; use e.g. 4011).
- **Pre-compile** the example app before recording to avoid a code-reload crash mid-capture.
- Re-record with `--update-snapshots` then **restore any canary/unchanged-slug PNGs** so only the intended deltas change. Review the HTML report before committing.
- Run a single project at a time, e.g. (verify exact invocation against the project's playwright config/justfile before running):
  ```
  npx playwright test admin-checkpoints.spec.ts --project=admin-checkpoints-mobile --update-snapshots
  ```
- `notice/1` wraps slot content in `<p>` (`components.ex:303-306`) — relevant if asserting notice text.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL @ localhost:5432 (postgres/postgres) | `mix test` (LiveView/integration; NOT component goldens) | assume per CLAUDE.md | 16 (disposable container documented) | Component goldens run without DB (`@endpoint nil`); CLAUDE.md gives a one-liner docker container |
| Node + Playwright + chromium | Visual checkpoints | assume per existing lane | `@playwright/test` ^1.48.0 | `npm run install-browsers` |
| Elixir ~> 1.18 / OTP 27 / Phoenix 1.8 | Everything | assume per CLAUDE.md stack | — | — |

**Note:** Component byte-goldens (the first/cheapest gate) need no Postgres — they use `render_component` with `@endpoint nil`. Sequence them first.

---

## Project Constraints (from CLAUDE.md)

- **GSD workflow enforcement:** No direct edits outside a GSD workflow. (This research is within `/gsd:plan-phase`.)
- **Framework:** Phoenix 1.8+ / Ecto 3.x; PostgreSQL primary; minimal transitive deps; OWASP throughout. (None challenged this phase — read-only audit UI, no security surface change.)
- **Testing:** comprehensive, AAA, flat, self-contained; `mix test` needs live Postgres at localhost:5432. No `:postgres` tag exclusion.
- **Milestone law:** "same job → same component" (this phase IS that law applied to audit rows + filter chips + AuditUser chrome).
- **CSS posture:** build-free `sg-*` token layer; example app is `--no-tailwind`; admin LiveViews lib-owned, shell generated. No new tokens/classes this phase.
- **Byte-golden discipline:** literal `==` goldens, "do not re-record Playwright baselines" on drift; deliberate HTML-report-reviewed baseline re-records only.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Recommend chip-active-state Option (a) — keep `<label>`+checked-input shell setting real string values — to preserve `:has(input:checked)` CSS with zero new CSS | Pitfall #1 | If form-submission semantics for value-setting via a checked input prove awkward, planner may choose plain `<a>` links + applied_chip-only active signal (UI-SPEC permits). Discretion point. `[ASSUMED]` |
| A2 | `user-detail` baseline may need re-record if `targetEmail` recent-audit contains impersonation rows (new `info` tone) | Pitfall #3 | If recent-audit preview excludes impersonation for that user, no extra re-record needed. Planner should verify against seed/journey. `[ASSUMED]` |
| A3 | `admin-generated` lane needs no HEEx mirroring because admin is lib-owned routed directly | Validation / GATE-02 | Confirmed via `router.ex` + `admin-generated.spec.ts` (smoke only, no baseline) — low risk. `[VERIFIED: codebase]` but the "stays green automatically" claim is `[ASSUMED]` pending a run. |
| A4 | Playwright invocation `npx playwright test … --project=… --update-snapshots` | Validation run mechanics | Exact runner/justfile wrapper not confirmed (no README; package.json has only `test`). Planner/executor must verify the project's actual invocation + dev-server boot. `[ASSUMED]` |
| A5 | Local dev server alt PORT 4011 (4000 = Rulestead Docker) | Validation run mechanics | Per MEMORY note; environment-specific. `[ASSUMED]` |

---

## Open Questions (RESOLVED)

1. **Where does `audit_tone/1` live?**
   - Known: it must be a single source of truth (D-10). House style is flat function components; the helper is currently a `defp` in each LiveView.
   - Unclear: whether the unified helper lives as a private fn inside `Sigra.Admin.Components` (callable from `audit_row/1` only) or remains a `defp` duplicated-but-identical in the views, or becomes a public helper.
   - RESOLVED in Plans 01/02/03/04: a private `audit_tone/1` lives in `components.ex` (authored in Plan 01, called by `audit_row/1`); each consuming LiveView's divergent `row_tone/1` is retired/consolidated to the identical body (the explorer desktop `<tr>` rows reference the same unified mapping in Plans 02/03), and the D-10 golden pins the mapping in `components_test.exs`.

2. **Which date format + helper name does `audit_row/1` use?** (Pitfall #2)
   - Known: explorer table = `%Y-%m-%d %H:%M:%S`; compact card = `%Y-%m-%d %H:%M`; no `format_date/1` exists in audit views.
   - RESOLVED in Plan 01: a private `format_date/1` (with the D-09 head set for %DateTime/%NaiveDateTime/nil/raise) using the format `%Y-%m-%d %H:%M` (no seconds, to match the compact card and minimize that golden's diff); the desktop explorer `<tr>` keeps its own inline seconds form (`%Y-%m-%d %H:%M:%S`), so there is no explorer-table format shift to re-record.

3. **Chip placement + microcopy** (Claude's discretion) — above the detailed filter form, below `<.applied_chip>` row, per UI-SPEC. Labels "Failures" / "Impersonation".
   - RESOLVED in Plans 02/03: quick-filter chips placed above the detailed filter form, labels "Failures" / "Impersonation".

---

## Sources

### Primary (HIGH confidence — live codebase, this session)
- `lib/sigra/admin/components.ex` — 10 components, house style, sg-* only rule, `:class`/`:rest` convention
- `lib/sigra/admin/audit/presenter.ex:20-55` — row field set
- `lib/sigra/admin/audit/query_params.ex:9-21,53-61` — `@allowed_params`, no boolean impersonation/failure
- `lib/sigra/admin/live/audit_index_live.ex` — table `136-163`, `row_tone/1` `206-208`, `format_timestamp/1` `265-268`
- `lib/sigra/admin/live/audit_user_live.ex` — sync load `26-56`, `<tr>` `165-192`, hand-rolled chrome `63-66,138-148,197-217`, `row_tone/1` `246-248`, `format_timestamp/1` `384-387`
- `lib/sigra/admin/live/user_show_live.ex` — recent-audit card `250-275`, inline strftime `271`, `audit_tone/1` `437-440` (no impersonation branch)
- `lib/sigra/admin/live/users_index_live.ex` — dual-layout `179-280`, `quick_filter/1` (checkbox) `325-338`, `@quick_filter_keys` `14`
- `lib/sigra/admin/live/organization_live.ex:190-191` — the only `format_date/1`
- `lib/sigra/admin/users/detail.ex:61-118` — `recent_audit_preview/3` shares Presenter
- `test/sigra/admin/components_test.exs:1-90` — byte-golden discipline (literal `==`, no snapshot lib)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — capture pattern `94-145`, journey `147-278`, `audit-explorer` `267-276`, impersonation `233-265`
- `test/example/priv/playwright/tests/admin-generated.spec.ts:1-60` — parity lane (smoke, no baseline)
- `test/example/priv/playwright/playwright.config.ts:108-144` — project names
- `test/example/lib/example_web/router.ex:256-294` — audit routes, AuditUserLive `260,293`
- `test/example/priv/static/assets/css/app.css` — `sg-show` `247-255`, `sg-filter-chip` `858-882`, `sg-list-row[data-tone]` `945-967`
- `.../admin-checkpoints.spec.ts-snapshots/` — `audit-explorer-*` (3, to re-record), no `user-audit-*` yet
- `.planning/config.json` — `nyquist_validation: true`, `commit_docs: true`

### Secondary
- MEMORY: admin-checkpoint Playwright re-record procedure (alt PORT, pre-compile, `--update-snapshots`, restore canaries, notice `<p>` wrap)

---

## Metadata

**Confidence breakdown:**
- Standard stack / reuse map: HIGH — every primitive read directly in tree.
- Architecture / patterns: HIGH — idioms verified against live source.
- Pitfalls: HIGH — drifts #1 (chip CSS) and #2 (missing `format_date`) confirmed by grep across all four LiveViews.
- Playwright run mechanics: MEDIUM — no README; invocation inferred from config + MEMORY (A4/A5).

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 (stable internal codebase; re-verify line numbers if other phases touch these files first)
