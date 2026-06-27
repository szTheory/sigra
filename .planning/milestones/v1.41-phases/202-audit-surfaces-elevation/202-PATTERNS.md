# Phase 202: Audit Surfaces Elevation - Pattern Map

**Mapped:** 2026-06-26
**Files analyzed:** 11 (2 LiveViews, 3 new shared components, 1 ExUnit test, 1 Playwright helper, 1 ledger, 1 design contract, 3 CSS copies)
**Analogs found:** 11 / 11 (this is an in-repo refactor — every target has a same-repo analog; zero external patterns needed)

> **Posture note for the planner:** This phase is *deletion of duplication + promotion to shared components + ratchet*, not greenfield. Almost every "new" file is `components.ex` gaining public function components whose body is copied verbatim from the existing hand-duplicated LiveView markup. The strongest analogs are in THIS repo (the two audit LiveViews are ~90% identical to each other; the 201 `user_name_stack/1` field-slice is the DRY precedent; the existing public `audit_row/1` is the shape to mirror). RESEARCH.md patterns are confirmations of these in-repo analogs, not substitutes for them.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/admin/components.ex` (+ `audit_table_row/1`, `audit_pagination_nav/1`, `audit_empty_state/1`) | component (function components) | transform (row data → HEEx) | `lib/sigra/admin/components.ex:699` `audit_row/1` (existing public audit component) + `users_index_live.ex:369` `user_name_stack/1` (DRY field-slice precedent) | exact |
| `lib/sigra/admin/live/audit_index_live.ex` (modify: add `<details>`, call shared components, delete dup helpers) | controller (LiveView) | request-response (URL-driven via `handle_params/3`) | itself + `audit_user_live.ex` (mutual ~90% dup) | exact |
| `lib/sigra/admin/live/audit_user_live.ex` (modify: collapse 3 forms→1, add `<details>`, call shared components) | controller (LiveView) | request-response (URL-driven via `handle_params/3`) | `audit_index_live.ex` (already single-form; the target shape) | exact |
| `test/example/test/example_web/live/admin_audit_index_live_test.exs` (add pagination test) | test (ExUnit LiveView) | request-response | itself `:145-161` `insert_audit_event/1` seam | exact |
| `test/example/priv/playwright/tests/admin-design.spec.ts` (modify `assertAuditResultEquivalence`) | test (Playwright equivalence) | transform (DOM token extraction) | `assertUserResultEquivalence` `:153-164` (201 sibling helper) | exact |
| `guides/reference/admin-quality-ledger.md:90,91` (ratchet 1→2) | config (ledger doc) | n/a | `:87` `users-index-live` Tier-2 cell template | exact |
| `guides/reference/admin-design-contract.md` (ADD Audit Explorer archetype) | config (design doc) | n/a | `:211` List Archetype block | exact |
| 3× `sigra_admin.css` copies | config (CSS) | n/a | existing `sg-filter-panel`/`sg-table-panel` rules | role-match (target: zero new CSS) |

---

## Pattern Assignments

### `lib/sigra/admin/components.ex` — NEW `audit_table_row/1` (component, transform)

**Analog A (shape to mirror — existing public audit component):** `components.ex:685-714` `audit_row/1`
**Analog B (body to copy verbatim):** `audit_index_live.ex:164-191` `<tbody>` ≡ `audit_user_live.ex:193-220` (byte-identical today)

**Attr + def shape** (copy from `audit_row/1`, `components.ex:685-699`):
```elixir
attr :row, :map, required: true, doc: "the presenter row map for the audit event"

def audit_table_row(assigns) do
  ~H"""
  <tr data-tone={audit_tone(@row)}>
    ...
  </tr>
  """
end
```

**Cell body to lift verbatim** (`audit_index_live.ex:164-191` — the hand-duplicated `<tr>`):
```elixir
<tr :for={row <- @rows} data-tone={audit_tone(row)}>
  <td class="sg-nowrap">
    <div class="sg-stack sg-stack--1">
      <span class="sg-text-sm">{format_timestamp(row.inserted_at)}</span>
      <code class="sg-code">{row.id}</code>          <%!-- D-05: move into <details> in the Event cell --%>
    </div>
  </td>
  <td>
    <div class="sg-stack sg-stack--1">
      <div class="sg-cluster sg-cluster--2">
        <span class="sg-status-pill" data-tone={audit_tone(row)}>{row.action_label}</span>
        <span :if={row.action_badge} class="sg-status-pill" data-tone="info">{row.action_badge}</span>
      </div>
      <code class="sg-code">{row.action}</code>        <%!-- D-05: move into <details> in the Event cell --%>
    </div>
  </td>
  <td>
    <div class="sg-stack sg-stack--1 sg-text-sm">
      <span>{row.actor_summary}</span>                 <%!-- D-06: td:nth-child(3) span — Actor column, FROZEN at position 3 --%>
      <span :if={row.action_badge} class="sg-muted">Actor: {row.actor_label}</span>
      <span :if={row.action_badge} class="sg-muted">Effective user: {row.effective_user_label}</span>
    </div>
  </td>
  <td class="sg-show-desktop sg-text-sm">
    <span :if={audit_tone(row) == "risk"} class="sg-status-pill" data-tone="risk">{row.outcome}</span>
    <span :if={audit_tone(row) != "risk"} class="sg-muted">{row.outcome}</span>
  </td>
</tr>
```

**D-05 inline-code disclosure (Claude's Discretion — RESEARCH Pattern 2 recommendation):** wrap the two `<code class="sg-code">` nodes (id `:168`, action `:177`) in a native CSS-only `<details>` **inside the Event `<td>`** (NOT a sibling `<tr>` — keeps the 4-column `td:nth-child` contract frozen). The codes MUST remain real `<code class="sg-code">` text nodes inside the `[data-testid="admin-audit-desktop-results"]` container so `firstTexts(desktop,'code.sg-code',2)` still returns 2 (D-06, Pitfall 1).

**`audit_tone/1` source of truth:** the new component calls the existing public `Components.audit_tone/1` (`components.ex:723-725`). DELETE both private re-declarations: `audit_index_live.ex:244-246` and `audit_user_live.ex:273-275` (comments already flag them "identical to Components.audit_tone/1").

---

### `lib/sigra/admin/components.ex` — NEW `audit_pagination_nav/1` (component, transform)

**Analog (body to lift verbatim):** `audit_index_live.ex:216-236` ≡ `audit_user_live.ex:246-266` (byte-identical except the href builder arity)

**Pattern — per-page divergence is ONLY the built href; pass hrefs in** (RESEARCH Extraction Shape #2):
```elixir
attr :meta, :map, required: true
attr :prev_href, :string, required: true
attr :next_href, :string, required: true

def audit_pagination_nav(assigns) do
  ~H"""
  <nav :if={@meta && multi_page?(@meta)} class="sg-cluster sg-cluster--between">
    <a
      class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.previous_page, do: "", else: "is-disabled")]}
      href={@prev_href}
      aria-disabled={to_string(is_nil(@meta.previous_page))}
      aria-label="Previous page"
    >
      <span aria-hidden="true">&larr;</span>
      <span class="sr-only">Previous page</span>
    </a>
    <span class="sg-muted sg-text-sm">Page {@meta.current_page || 1}</span>
    <a
      class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.next_page, do: "", else: "is-disabled")]}
      href={@next_href}
      aria-disabled={to_string(is_nil(@meta.next_page))}
      aria-label="Next page"
    >
      <span aria-hidden="true">&rarr;</span>
      <span class="sr-only">Next page</span>
    </a>
  </nav>
  """
end
```

**Why pass hrefs in:** the only difference between the two pages is `page_path/3` (index, `audit_index_live.ex:336-342`) vs `page_path/4` with `user_id`/`return_to` (per-user, `audit_user_live.ex:403-409`). The nav markup is shared; the href builders stay per-page (D-09 legitimate divergence). The `multi_page?/1` guard (`:309-313` ≡ `:475-479`, byte-identical, honest-cursor) moves into the shared component or a shared helper.

---

### `lib/sigra/admin/components.ex` — NEW `audit_empty_state/1` (component, transform)

**Analog (existing wrapper):** `components.ex:407` `empty_state/1` (the generic zero-state already called at `audit_index_live.ex:205` and `audit_user_live.ex:234`)

**Pattern — parametrize title via attr + inner block slot** (RESEARCH Extraction Shape #3; the per-page copy legitimately differs per D-09):
- Index copy: title `"No audit events match this view"` + filter-aware body w/ "Clear all filters" link (`audit_index_live.ex:205-214`)
- Per-user copy: title `"No audit events for this user"` + "No scoped events…" body (`audit_user_live.ex:234-244`)

Either parametrize (`title` attr + slot) or — since this is the lowest-value DRY and the copy legitimately differs — leave `<.empty_state>` inline in each shell. RESEARCH leans toward parametrized-with-slot for coherence; this is Claude's Discretion.

---

### `lib/sigra/admin/live/audit_user_live.ex` (controller, request-response) — THE PRIMARY SURGERY

**Analog:** `audit_index_live.ex` — already a single `sg-filter-panel` form; it IS the target shape.

**Problem — THREE forms today** (`audit_user_live.ex:81-108` = two standalone quick-toggle forms above the main `:110-164` form):
```elixir
<div class="sg-cluster sg-cluster--2">
  <form method="get" action={index_path(@admin_scope, @detail.user.id)}>      <%!-- form 1 — DELETE, fold into main --%>
    <input type="hidden" name="return_to" value={@return_to} />
    <label class="sg-filter-chip"> ... Failures ... </label>
  </form>
  <form method="get" action={index_path(@admin_scope, @detail.user.id)}>      <%!-- form 2 — DELETE, fold into main --%>
    <input type="hidden" name="return_to" value={@return_to} />
    <label class="sg-filter-chip"> ... Impersonation ... </label>
  </form>
</div>
```

**Target — fold the toggles into the main form as GET checkboxes** (copy the quick-chip cluster pattern verbatim from `audit_index_live.ex:59-80`):
```elixir
<form method="get" action={index_path(@admin_scope, @detail.user.id)} class="sg-filter-panel sg-stack">
  <div class="sg-cluster">                                          <%!-- folded-in quick toggles (was 2 forms) --%>
    <label class="sg-filter-chip">
      <input type="checkbox" name="outcome" value="failure"
             checked={param_value(@current_params, "outcome") == "failure"}
             class="checkbox checkbox-sm" />
      <span>Failures</span>
    </label>
    <label class="sg-filter-chip">
      <input type="checkbox" name="action_prefix" value="admin.impersonation"
             checked={param_value(@current_params, "action_prefix") == "admin.impersonation"}
             class="checkbox checkbox-sm" />
      <span>Impersonation</span>
    </label>
  </div>
  <details>                                                        <%!-- D-02: advanced text/date fields fold in here --%>
    <summary>More filters</summary>
    <div class="sg-form-grid sg-form-grid--cols"> ... </div>
  </details>
  <div class="sg-cluster"> ... Apply filters / Clear / Export CSV ... </div>  <%!-- D-04: Export stays here --%>
  <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />   <%!-- D-03: return_to survives EXACTLY ONCE --%>
  <input type="hidden" name="page_size" value={...} /> ...
</form>
```

**Critical constraints carried by analog:**
- **`return_to` plumbing (D-03, RESEARCH finding #2):** it appears 3× today (`:83`, `:96` in the dead toggle forms, `:160` conditional in main). After collapse it must survive **exactly once** (`:160` `<input :if={@return_to} ...>`), and `clear_path`/`export_path`/`page_path`/`remove_chip_path` must keep round-tripping it.
- **GET-form contract (D-03, Pitfall 4):** keep `method="get"`, every named input inside the form, toggles as checkboxes (NOT `phx-click`). The checkpoint `admin-checkpoints.spec.ts` navigates via pre-built URL and asserts `:checked` — a broken form fails there.
- **Input-type divergence (RESEARCH finding #1, Open Question 1):** per-user `from`/`to` are `type="text"` (`:143,148`); index is `type="date"` (`:119,124`). RESEARCH recommends converging to `type="date"`. Planner decision.

---

### `lib/sigra/admin/live/audit_index_live.ex` (controller, request-response)

**Analog:** itself (already the canonical single-form shape) + the new shared components.

**Changes (lighter — index is already close):**
1. Add the `<details>` advanced-disclosure wrapping the `sg-form-grid` (`:82-126`) — same `<details>` shape as the per-user page (D-02, byte-coherent).
2. Replace the hand-written `<tbody>` `<tr>` loop (`:164-191`) with `<.audit_table_row :for={row <- @rows} row={row} />`.
3. Replace the `<nav>` (`:216-236`) with `<.audit_pagination_nav meta={@meta} prev_href={...} next_href={...} />`.
4. DELETE private `audit_tone/1` (`:244-246`), `multi_page?/1` (`:309-313`, if moved to shared), and `format_timestamp/1` (`:315-318`) once the shared component owns them.
5. **Keep page-specific** (D-09): `<header class="sg-page-header">` (`:52-55`), `@chip_keys` 6-key (`:274` — incl. `actor`/`effective_user`), the Effective-user field (`:88-91`), and all routing helpers (`index_path/1`, `sort_path/3`, `page_path/3`, `remove_chip_path/3`).

**Applied-chip pattern (keep, both pages share via existing `applied_chip/1`):** `audit_index_live.ex:139-146`:
```elixir
<div :if={any_filter_active?(@current_params)} class="sg-cluster sg-cluster--start">
  <.applied_chip :for={chip <- applied_chips(@current_params)}
    label={chip.label}
    remove_href={remove_chip_path(@admin_scope, @current_params, chip.key)} />
  <a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
</div>
```

---

### `test/example/test/example_web/live/admin_audit_index_live_test.exs` (test, request-response) — NEW pagination test (D-10)

**Analog (insert seam to reuse verbatim):** `:145-161` `insert_audit_event/1` (inserts directly via example `Repo`, no dev seeds — test-env-independent):
```elixir
defp insert_audit_event(attrs) do
  now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
  defaults = %{action: "session.create", actor_type: "user", target_type: "user",
               outcome: "success", occurred_at: now, inserted_at: now, metadata: %{}}
  %AuditEvent{}
  |> Ecto.Changeset.change(Map.merge(defaults, attrs))
  |> Repo.insert!()
end
```

**New test (RESEARCH-sketched, D-10):** insert ≥26 self-tied events → assert `<nav aria-label="Next page">` present (`multi_page?/1` true at `page_size=25`); insert ≤25 (or filter) → refute the nav. Default `page_size=25` is the hidden input at `audit_index_live.ex:134`. This is the deterministic backstop so pagination proof does NOT depend on the `MIX_ENV=dev`-only seeded screenshot (seeds hard-blocked in test).

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (test, transform) — `assertAuditResultEquivalence` LOCKSTEP (D-06, HIGHEST RISK)

**Analog (sibling helper, same shape):** `assertUserResultEquivalence` `:153-164`
**Helper to update:** `assertAuditResultEquivalence` `:166-178`:
```typescript
async function assertAuditResultEquivalence(desktop: Locator, mobile: Locator, label: string) {
  const tokens = [
    ...(await firstTexts(desktop, 'code.sg-code', 2)),     // ← the 2 raw codes; MUST still return 2 after D-05 move
    ...(await firstTexts(desktop, '.sg-status-pill', 2)),
    ...(await firstTexts(desktop, 'td:nth-child(3) span', 3)),  // ← Actor column, FROZEN at td position 3
  ];
  await expectTokensInBothContainers(desktop, mobile, tokens, label);
  const desktopTone = await desktop.locator('tbody tr, article.sg-list-row').first().getAttribute('data-tone');
  const mobileTone = await mobile.locator('article.sg-list-row').first().getAttribute('data-tone');
  expect(mobileTone, `${label}: mobile tone should match desktop outcome tone`).toBe(desktopTone);
}
```

**Lockstep requirement (D-06 / Pitfall 1 / Pitfall 2):**
- `firstTexts(desktop, 'code.sg-code', 2)` must still extract **exactly 2** after codes move into the `<details>`. If codes leave the desktop container or become `data-*`/JS-only, this silently returns <2 and the equivalence assertion degrades to a vacuous rubber stamp — the exact 201 D-06 failure mode.
- **One helper, THREE call sites:** gallery MG-6 (`:334`), live `/admin/audit` (`:354-361`), live per-user (`:383-388`). One selector edit ripples to all three — re-run all three.
- **Recommended strict upgrade (Pitfall 1):** assert `firstTexts(...).length === 2` so under-extraction FAILS loudly instead of weakening silently.

---

### `guides/reference/admin-quality-ledger.md:90,91` (config) — Tier ratchet 1→2 (D-11)

**Analog (EXACT template to copy):** `:87` `users-index-live` Tier-2 cell. Copy its format, swapping: checkpoint slug → `audit-explorer` (`:90`) / `user-audit` (`:91`); equivalence helper → `assertAuditResultEquivalence`; glossary scope → `glossary_test.exs:28` (index) / `:29` (per-user).

**Hard constraint (Pitfall 5):** column-4 is a **bare single `[012]` integer** — write `2`, nothing else (no `2 ✓`, `2*`, `**2**`). The `awk -F'|'` monotonic-guard parse depends on it. Put ALL proxy evidence in column-5.

**Proxies to cite (RESEARCH Tier-2 Proxy Applicability table):** content-equivalence (`assertAuditResultEquivalence` MG-6 + live), glossary-clean (`glossary_test.exs:28`/`:29`), motion-tokens (no `transition: all`), density-rhythm (`sg-stack--6`/`--3`/`--1`), target-size ≥24px (documented-as-manual). **Overlay-axe + 7-APG-dialog = N/A** (neither page owns a modal) — cite N/A exactly like `:87`; do NOT fabricate (false Tier-2 claim fails Phase-204 review).

---

### `guides/reference/admin-design-contract.md` (config) — ADD Audit Explorer archetype (D-14)

**Analog (block format to mirror):** `:211-282` List Archetype (`**Source:**` + composition pseudo-tree `[1]…[N]` + `**Notes:**` with D-refs). There is NO existing Audit block — ADD a new one after Detail (`:284`). Document: unified `sg-filter-panel` form + `<details>` advanced-disclosure + folded-in quick toggles + inline-code disclosure + byte-coherent shared `audit_table_row`/`audit_pagination_nav` + honest pagination. Update the stale `audit_user_live.ex:77` applied-chip line ref the contract already cites so it doesn't drift when markup moves.

---

### 3× `sigra_admin.css` copies (config) — triple-copy lockstep (D-13)

**Target: ZERO new CSS** (RESEARCH Pattern 3 / Pitfall 6). The audit pages reuse existing `sg-filter-panel`, `sg-form-grid`, `sg-filter-chip`, `sg-table-panel`, `sg-applied-chip`. Browser-default `<details>`/`<summary>` needs no CSS. **Do NOT reintroduce `sg-chevron`** (0 rules in all three copies). IF any new `sg-*` class is unavoidable, it MUST be byte-identical across all three (shared md5 `9b281962ee8fe33254829c877af00382`) or install golden-diff fails / generated hosts ship unstyled (184→185 regression class):
- `priv/templates/sigra.install/admin/sigra_admin.css`
- `test/example/priv/static/assets/sigra_admin.css`
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`

---

## Shared Patterns

### Cross-page DRY: PUBLIC function components (not private-to-one)
**Source:** `components.ex:699` `audit_row/1` (public, already shared across 3 surfaces) — the shape to mirror.
**Contrast with:** `users_index_live.ex:369` `user_name_stack/1` is **private** because only ONE LiveView (201) uses it. Phase 202 has TWO LiveViews that must emit byte-identical markup → the new row/nav/empty-state components MUST be **public in `components.ex`**. Private-to-one does not satisfy cross-page byte-coherence.
**Apply to:** all three new shared components.

### `audit_tone/1` single source of truth
**Source:** `components.ex:723-725` (public, authoritative).
**Apply to:** delete both private copies (`audit_index_live.ex:244-246`, `audit_user_live.ex:273-275`); shared `audit_table_row/1` calls the components one.

### Honest cursor pagination guard (do NOT rebuild — D-10)
**Source:** `multi_page?/1` `audit_index_live.ex:309-313` ≡ `audit_user_live.ex:475-479` (byte-identical; cursor meta has no `total_pages`).
**Apply to:** move into the shared `audit_pagination_nav/1` (or a shared helper); both pages already render `<nav :if={@meta && multi_page?(@meta)}>`.

### GET-form / URL-driven state (D-03 — never break)
**Source:** `handle_params/3` is the ONLY state path (`audit_index_live.ex:25`, `audit_user_live.ex:29`). Every filter/sort/page/chip link is a built query string (`append_query/2`, `sort_path`, `page_path`).
**Apply to:** all toggles stay GET checkboxes; chips stay navigation-only `<a>`; no `phx-click`. The checkpoint asserts `:checked` after URL entry.

### Applied-chip row (existing shared component)
**Source:** `components.ex:369` `applied_chip/1`, called identically at `audit_index_live.ex:139-146` and `audit_user_live.ex:166-175` (only the `remove_href` builder arity differs — D-09 per-page).
**Apply to:** keep as-is on both pages; align the `@chip_keys`-fed labels feeding it, not the chip component.

### Legitimate per-page divergence (KEEP — D-09)
**Apply to (stays OUT of shared components):**
- Per-user: breadcrumbs (`audit_breadcrumbs/3`), page header w/ email+`sg-code` (`:69-79`), `return_to` plumbing, `clear_path`/`export_params`, 5-key `@chip_keys` (`:435` `~w(actor action_prefix outcome from to)`).
- Index: scope `<header class="sg-page-header">` (`:52-55`), 6-key `@chip_keys` (`:274` `~w(actor effective_user action_prefix outcome from to)`), Effective-user field (`:88-91`).
- All routing helpers (`index_path`/`sort_path`/`page_path`/`remove_chip_path` arities differ — index vs per-user `user_id`/`return_to`).

---

## No Analog Found

None. Every target file has a same-repo analog (this is an in-repo refactor with zero new deps, routes, or external patterns). The one "new construct" — a native `<details>` advanced/code disclosure — has no in-repo CSS analog but needs none (browser-default rendering; RESEARCH Pattern 3 / Pitfall 6).

---

## Metadata

**Analog search scope:** `lib/sigra/admin/live/` (both audit LiveViews + 201 users-index precedent), `lib/sigra/admin/components.ex` (existing public audit components), `test/example/priv/playwright/tests/admin-design.spec.ts` (equivalence helpers), `test/example/test/example_web/live/admin_audit_index_live_test.exs` (ExUnit seam), `guides/reference/` (ledger + design contract), 3× `sigra_admin.css`.
**Files scanned:** 11 (all read directly; line citations verified against live code this session, consistent with RESEARCH.md drift audit).
**Pattern extraction date:** 2026-06-26
