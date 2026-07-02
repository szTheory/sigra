# Phase 201: Users Index Elevation - Pattern Map

**Mapped:** 2026-06-26
**Files analyzed:** 11 (1 in-place LiveView recompose + 1 query host-seam + 1 example hook + 3 CSS copies + 2 Playwright specs + 2 docs + 1 design gallery)
**Analogs found:** 11 / 11 (no net-new surface — this phase recomposes a known page and DRYs its per-row presentation)

> No RESEARCH.md — all patterns below are extracted from the live Sigra codebase.
> Strongest in-repo precedent: **Phase 200** (`.planning/phases/200-user-detail-elevation/`)
> for shared-component DRY, CSS triple-copy lockstep, ledger ratchet, and checkpoint
> recapture. Strongest in-repo DRY analog: the **audit feed** (`audit_index_live.ex` +
> `Components.audit_row/1`) for separate-DOM desktop/mobile + shared-token equivalence.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/admin/live/users_index_live.ex` *(modify/recompose + add shared component)* | LiveView (list) | request-response (GET-form, URL-driven) | itself + `audit_index_live.ex` (shared row component) + `components.ex audit_row/1` | role+flow exact |
| `lib/sigra/admin/users/query.ex` *(modify — keep in sync only)* | service/query loader | CRUD/batch (aggregates + decorate) | itself (`summary_stats/3` `:171-208`, `decorate_rows/2` `:534-549`) | self |
| `test/example/lib/example/sigra_admin_users.ex` *(modify — emit non-empty seam)* | host-seam hook impl | data callback | Phase 200's `extra_detail_sections` seam-coverage change | exact precedent |
| `priv/templates/sigra.install/admin/sigra_admin.css` *(modify — conditional, D-11)* | config/CSS | n/a | the 3-copy byte-parity set (md5 `9b281962…`) | self |
| `test/example/priv/static/assets/sigra_admin.css` *(modify — conditional)* | config/CSS | n/a | the 3-copy byte-parity set | self |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` *(modify — conditional)* | config/CSS | n/a | the 3-copy byte-parity set | self |
| `test/example/priv/playwright/tests/admin-design.spec.ts` *(modify, conditional)* | test (structural/equivalence) | request-response | `assertUserResultEquivalence` (`:153-164`) + `td:nth-child(3)/(4)` (`:158-159`) | self |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` *(modify — recapture `global-user-index`)* | test (e2e/visual) | request-response | `global-user-index` block (`:210-216`) | self |
| `guides/reference/admin-quality-ledger.md` *(modify — D-09 ratchet)* | doc/ledger | n/a | `user-show-live` Tier-2 cell (`:88`) | exact |
| `guides/reference/admin-design-contract.md` *(modify — D-12 rewrite)* | doc | n/a | Phase 200's Detail Archetype rewrite (`200-PATTERNS.md` §design-contract) | exact precedent |
| `test/example/lib/example_web/live/admin/design_gallery_live.ex` *(modify — conditional, mg-1/2/5/6)* | LiveView (gallery) | n/a | `board-mg-5` Users-results board (`:611-733`) | self |

---

## Pattern Assignments

### `lib/sigra/admin/live/users_index_live.ex` (modify — LiveView, request-response)

**Analog:** itself (in-place recompose per UI-SPEC "Page Composition Contract") + the audit
feed for the DRY shared-row mechanism.

This is the heart of the phase. Five distinct edits, each with a concrete in-file or in-repo
source. **No new data logic** — all helpers already exist.

#### (A) D-05 — DRY shared per-row component `<.user_row_fields>`

**The audit feed is the in-repo DRY precedent, but with one critical nuance.** The audit feed
shares a component for the **mobile** card only (`<.audit_row :for={row <- @rows} ...>` at
`audit_index_live.ex:202`) and **hand-codes the desktop `<td>` cells** (`audit_index_live.ex:163-191`).
The `Components.audit_row/1` definition (`components.ex:699-714`) is the shape to mirror:

```elixir
attr :row, :map, required: true, doc: "the presenter row map for the audit event"
attr :show_detail, :boolean, default: false, doc: "..."
attr :show_codes, :boolean, default: false, doc: "..."
attr :class, :any, default: nil
attr :rest, :global

def audit_row(assigns) do
  ~H"""
  <article class={["sg-list-row sg-stack sg-stack--2", @class]} data-tone={audit_tone(@row)} {@rest}>
    <div class="sg-cluster sg-cluster--2">
      <span class="sg-status-pill" data-tone={audit_tone(@row)}>{@row.action_label}</span>
      ...
  """
end
```

**Decision for D-05:** the UI-SPEC (`:188-201`) calls for `<.user_row_fields>` to feed BOTH
the desktop `<td>` cells AND the mobile `sg-kv`/card — going one step further than the audit
feed (which only shares mobile). Two equally valid mirrorings of the precedent:
1. **Field-slice components** — one small private component per logical field group
   (`name/email/id` stack, `status_pills + extra_badges` cluster, `org summary`, `activity +
   registered + extra_columns`) that the desktop `<td>` and mobile `dl`/`card` both call. This
   most directly de-duplicates the currently-copied blocks (desktop `:262-289` vs mobile `:306-337`).
2. **One `<.user_row_fields layout={:desktop|:mobile}>`** component that branches the shell.

Pattern-wise, prefer (1): it keeps the desktop `<td>` boundaries (which the positional
`td:nth-child` selectors depend on, D-06) authored in the table, while the *inner* content is
shared. The duplicated blocks to collapse, side-by-side:

- **name/email/id stack:** desktop `:262-268` ≡ mobile `:306-310` (byte-identical today —
  `sg-strong` / `sg-muted sg-truncate` / `code.sg-code`).
- **status pills + extra_badges:** desktop `:269-276` ≡ mobile `:312-317` (byte-identical —
  this is the seam that MUST stay in both, D-07).
- **org summary:** desktop `:277-282` ≈ mobile `:319-326` (desktop uses `sg-stack`, mobile
  wraps in `<dt>/<dd>` — the layout-specific shell).
- **activity/registered + extra_columns:** desktop `:283-289` ≈ mobile `:328-337`.

Keep the field-emitting helpers unchanged and call them from the shared component:
`primary_name/1` (`:641-643`), `activity_label/1` (`:645-650`), `registered_label/1`
(`:652-654`), `badge_text/1` (`:656-658`), `column_text/2` (`:660-667`), `pluralize/2`
(`:669-670`).

#### (B) D-06 — frozen desktop column order (HARD lockstep)

The `<thead>` order at `:253-257` (User / Status / Organizations / Activity / Action) is a
contract because `assertUserResultEquivalence` extracts tokens by position:
`admin-design.spec.ts:158` reads `td:nth-child(3) span` (Organizations),
`admin-design.spec.ts:159` reads `td:nth-child(4) span` (Activity). **Any reorder/insert/remove
of a `<td>` MUST update those selectors in the same change.** The DRY refactor (A) must preserve
exactly five `<td>` cells in this order.

#### (C) D-04 — reduce `status_pills/1` (`:415-430`)

Current body returns `[confirmation, security]` then appends Locked/Deletion. Per UI-SPEC
"Reduced Pill Vocabulary" (`:214-229`): **drop** the always-`{"Confirmed","ok"}` branch
(`:417`), **collapse** the 4-way security `cond` (`:420-425`) to surface only `{"No MFA","warn"}`
when unsecured and **nothing** when secured, **keep** Unconfirmed/Locked/Deletion. Target shape:

```elixir
defp status_pills(row) do
  []
  |> maybe_append(is_nil(row.user.confirmed_at), {"Unconfirmed", "warn"})
  |> maybe_append(no_security?(row), {"No MFA", "warn"})   # warn, NOT risk (UI-SPEC :114)
  |> maybe_append(row.user.locked_at, {"Locked", "risk"})
  |> maybe_append(row.user.deleted_at, {"Deletion scheduled", "warn"})
end
```

> **Watch (D-04):** `assertUserResultEquivalence` reads only the first 2 pills
> (`admin-design.spec.ts:157`, `firstTexts(..., '.sg-status-pill', 2)`) — over-pilling won't fail
> CI. Don't drop `Locked`: it's the at-a-glance signal for the `needs_review` filter
> (`query.ex:353-357`). `maybe_append/3` (`:432-433`) already takes a truthy/nil first arg —
> reuse it; the existing `nil`-checks pass `row.user.locked_at` (a datetime-or-nil) directly.

#### (D) D-03 — demote + slim the metric strip

Move the `<section aria-labelledby="users-health-heading">` (`:91-149`) **below** the
`Find users` filter `<section>` (`:151-234`) in DOM + visual order (it currently renders first
at `:91`, burying search). Keep it visible (no `<details>`, no delete). Cut the six
`<.summary_chip>` calls to **Total** (`:94-100`), **Locked** (`:128-137`), **Deletion scheduled**
(`:138-147`) — the risk/warn-toned ones; drop Confirmed (`:101-109`), MFA (`:110-118`), Passkeys
(`:119-127`). The `<% ... %>` count bindings at `:85-90` for the dropped chips can be removed.
**Do not touch `Query.summary_stats/3`** (`query.ex:171-208`) — it computes all six cheaply
regardless of how many render. Keep `empty_summary_stats/0` (`:465-478`) and `summary_count/2`
(`:483-484`) shape intact so a dropped key can't mask a wiring bug.

> Precedent: Phase 200 "slimmed (not deleted) the Detail facts row" — `200-PATTERNS.md`
> §user_show_live D-01. Same "slim, don't delete" call here.

#### (E) D-01 — consolidate applied-chip block into the filter panel

The applied-chip block is a detached `<div :if={any_filter_active?(@current_params)}>` sibling
**after** `</form>` (`:236-243`). Move it up to sit directly below the search row (`:157-171`),
inside or visually contiguous with the `sg-filter-panel`. **All data already exists** —
`applied_chips/1` (`:531-550`), `any_filter_active?/1` (`:524-528`), `remove_chip_path/4`
(`:566-574`), `<.applied_chip>` (`components.ex:369`). **Interaction contract (D-02):** if the
chips move *inside* `<form>`, they must remain navigation-only `<a>` tags (no named inputs) — an
errant named input outside/inside the form silently breaks GET submission. Keep
`<form method="get" action={index_path(@admin_scope)}>` (`:156`) and checkbox-based
`quick_filter/1` (`:399-412`) exactly; only `toggle_filters` (`:66-68`) stays a LiveView event.

#### (F) D-08 — honest pagination (already implemented; prove only)

`multi_page?/1` (`:513-517`), `all_results_label/1` (`:519-522`), `showing_range/3` (`:502-511`),
and the `<p>` vs `<nav>` split (`:359-390`) already implement the honest clause. **No markup
change.** Proven at list-scale via the checkpoint capture against a seeded dev DB (see D-10).

---

### `lib/sigra/admin/users/query.ex` (modify — keep-in-sync only, no behavior change)

**Analog:** itself. Per D-03/D-07 this file does **not** change behavior. The host-seam read at
`decorate_rows/2` (`:534-549`) is the frozen contract that feeds `extra_badges` / `extra_columns`:

```elixir
Map.merge(row, %{
  display_name: display_name,
  extra_badges: safe_apply(hooks, :extra_list_badges, [user]) || [],
  extra_columns: safe_apply(hooks, :extra_list_columns, []) || []
})
```

Both keys MUST survive the DRY refactor in **both** desktop and mobile (D-07). `summary_stats/3`
(`:171-208`) stays intact (cheap aggregates). Only touch this file if a dropped metric key
requires `empty_summary_stats/0` parity — and even then, prefer keeping all keys.

---

### `test/example/lib/example/sigra_admin_users.ex` (modify — close the host-seam blind spot, D-07)

**Analog:** Phase 200's identical move for `extra_detail_sections` (`200-PATTERNS.md` §Shared
"Host-seam preservation"). The example currently returns `[]` for both list seams:

```elixir
@impl true
def extra_list_badges(_user), do: []      # :20

@impl true
def extra_list_columns, do: []            # :23
```

Because both return `[]`, CI will NOT catch a one-sided drop of the seam in the DRY refactor —
the same blind-spot class as Phase 200's `extra_detail_sections`. **Make each emit one non-empty
value** so the live `assertUserResultEquivalence` spec exercises the seam. The frozen
`badge_text/1` (`users_index_live.ex:656-658`) and `column_text/2` (`:660-667`) helpers accept
both shapes — match one:

```elixir
def extra_list_badges(_user), do: ["Example badge"]            # binary → badge_text/1 :657
def extra_list_columns, do: [%{label: "Region", value: "us-east"}]  # map → column_text/2 :660
```

> Keep copy glossary-clean (the badge/column text renders into `users_index_live` markup, which
> `glossary_test.exs:24` scopes). After this change the equivalence spec sees the badge in BOTH
> the desktop status `<td>` (`:274`) and mobile cluster (`:316`), and the column in BOTH the
> desktop activity `<td>` (`:287`) and mobile `dl` (`:335-337`).

---

### `*/sigra_admin.css` — three byte-identical copies (modify — CONDITIONAL, D-11)

**Analog:** the 3-copy byte-parity set, verified identical (md5 **`9b281962ee8fe33254829c877af00382`**, all three):
- `priv/templates/sigra.install/admin/sigra_admin.css`
- `test/example/priv/static/assets/sigra_admin.css`
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`

**Prefer zero CSS change.** All target primitives are already styled: `sg-kv` (3 rules),
`sg-list-row` (5 rules), `sg-table` / `sg-table-panel`, `sg-filter-panel`, `sg-search-row`,
`sg-cluster`, `sg-stack--N`, `sg-status-pill`, `sg-card`. If the DRY refactor reuses these (it
should), **no CSS change is needed** and the golden-diff gate stays green.

**`sg-chevron` decision (D-11):** confirmed **0 rules** in all three copies (`grep -c sg-chevron`
→ 0), yet it's used at `users_index_live.ex:185`. During consolidation either (a) add rules to
**all three** copies byte-identically, or (b) drop the `<span class="sg-chevron">▾</span>`. If
any new `sg-*` class IS introduced, it must be written byte-identically into all three or
golden-diff fails and generated hosts get an unstyled page (the 184→185 regression class).

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (modify — CONDITIONAL, D-06)

**Analog:** itself — `assertUserResultEquivalence` (`:153-164`):

```ts
async function assertUserResultEquivalence(desktop, mobile, label) {
  const tokens = [
    ...(await firstTexts(desktop, '.sg-strong', 1)),          // primary_name
    ...(await firstTexts(desktop, 'code.sg-code', 1)),        // user id
    ...(await firstTexts(desktop, '.sg-status-pill', 2)),     // first 2 pills only (D-04 watch)
    ...(await firstTexts(desktop, 'td:nth-child(3) span', 2)),// Organizations — POSITIONAL
    ...(await firstTexts(desktop, 'td:nth-child(4) span', 2)),// Activity — POSITIONAL
    'Open user',
  ];
  await expectTokensInBothContainers(desktop, mobile, tokens, label);
}
```

Driven against `[data-testid="admin-users-desktop-results"]` / `admin-users-mobile-results`
(`:349-350`). **Only touch the `td:nth-child(3)/(4)` selectors (`:158-159`) if the column order
changes** (it must not, per D-06). **Risk to add a test (D-02):** the existing equivalence test
navigates with pre-built query strings (`:210` in checkpoints uses `?q=...`) and would NOT catch
a broken GET form. The plan should add/keep a test that actually **submits** the form (types in
search, clicks Submit) to guard the D-01/D-02 reflow.

---

### `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (modify — recapture `global-user-index`, D-10)

**Analog:** the existing `global-user-index` block (`:210-216`):

```ts
await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
await waitForLiveViewReady(page);
await expect(page.locator('header').first()).toContainText('Admin');
await expect(adminUsersEmailLocator(page, targetEmail)).toBeVisible();
await captureAndVerify(page, testInfo, 'global-user-index');
await assertCheckpointScreenshot(page, testInfo, 'global-user-index');
```

Blast radius (D-10): the **`global-user-index`** slug → 3 PNGs (`-chromium`/`-dark`/`-mobile`).
Recapture **only** through `snapshot-recapture-gate.sh` (not the canary guard). The
`impersonation-banner` canary (checkpoints) MUST stay byte-stable. **Capture must run against a
dev DB with seeds run** (`MIX_ENV=dev`-only; hard-blocked in test) so the Phase-199 cohort (36
`loadtest-*` + 9 personas = 45 users → 2 pages at `page_size: 25`) renders the list-scale
pagination `<nav>` — otherwise the overflow elevation is captured under-populated and unproven
(D-08). Prove zero-drift idempotency (Phase-192/199 method) before baking baselines. Leave
allowlists empty at end-of-phase (Phase 204 owns terminal reset).

---

### `guides/reference/admin-quality-ledger.md` (modify — D-09 ratchet)

**Analog:** the `user-show-live` Tier-2 cell (`:88`) — the exact precedent for a fully-cited
Tier-2 row. The current `users-index-live` row (`:87`):

```
| users-index-live | L3 | 1 | [admin-checkpoints global-user-index — 3 projects × toHaveScreenshot + axe](...) |
```

**Ratchet column-4 `1` → bare `2`** (single undecorated `[012]` integer — the monotonic guard's
positional `awk -F'|'` parse depends on it; D-09). Expand the Evidence column to cite the
**applicable** Tier-2 proxies, mirroring `:88`'s format: content-equivalence (MG-5/6 + live
`assertUserResultEquivalence`), glossary-clean (`glossary_test.exs:24` scopes
`users_index_live`), no-`transition: all` (CSS grep), density rhythm (`sg-stack--6` outer /
`--4`/`--3` inner), target-size ≥24px. **The overlay-axe + 7-APG-gate proxies are EXEMPT** — the
index owns no modal dialog (unlike Detail `:88` / Sessions `:89`) — cite as N/A, do NOT fabricate
a modal-interaction reference.

---

### `guides/reference/admin-design-contract.md` (modify — D-12 rewrite List Archetype)

**Analog:** Phase 200's Detail Archetype rewrite (`200-PATTERNS.md` §design-contract; the actual
edit replaced the stale composition diagram with the JTBD-first one). The stale **List
Archetype** block is `:211-243`. It is stale because it shows markup the code does not render —
e.g. a `<p class="sg-page-copy">` and a `<dl class="sg-metric-grid">` **inside** the
`sg-page-header` (`:216-220`), but the live header (`users_index_live.ex:78-81`) emits only
kicker + title; the metric strip is a separate `<section>` (`:91`). It also shows the metric
strip **first** and the applied-chip row as a detached post-form sibling — both reversed by this
phase. Rewrite it to the UI-SPEC "Page Composition Contract" (`201-UI-SPEC.md:151-208`): search-
first, demoted metric strip, applied chips contiguous with the panel, `<.user_row_fields>` DRY note.

---

### `test/example/lib/example_web/live/admin/design_gallery_live.ex` (modify — CONDITIONAL, D-10)

**Analog:** itself — `board-mg-5` (Users results + pagination, `:611-733`) is the desktop↔mobile
equivalence board for the Users list; `mg-5-desktop-results` (`:616`) / `mg-5-mobile-results`
(`:665`) mirror the live `admin-users-*-results` testids. `board-mg-1` (`:455-488`) is the
metric strip, `board-mg-2` (`:489-...`) the filter/applied-chip board, `board-mg-6` (`:734-...`)
the audit feed. **Only touch these boards if the live markup they mirror changes** (pill set,
column structure, applied-chip placement) — then recapture `mg-5`/`mg-6` (and `mg-1`/`mg-2` if
metric/filter markup moved) per D-10. The `board-notice` canary (design) MUST stay byte-stable.

---

## Shared Patterns

### Shared per-row component, separate DOM, token equivalence (the DRY mechanism)
**Source:** `audit_index_live.ex:148-203` (desktop `<table>` + `<.audit_row :for=...>` mobile) +
`components.ex:685-714` (`audit_row/1` attr block + `<article>` body) + `admin-design.spec.ts:166-178`
(`assertAuditResultEquivalence` token check, incl. `data-tone` parity)
**Apply to:** `users_index_live.ex` D-05 `<.user_row_fields>` — but extend the precedent to feed
BOTH desktop `<td>` and mobile `sg-kv`, not just mobile. Equivalence is proven by
`assertUserResultEquivalence` (`admin-design.spec.ts:153-164`), not by markup identity.

### Host-seam preservation (frozen semver/generated-host contract)
**Source:** `query.ex:534-549` (`decorate_rows/2` reads `extra_list_badges`/`extra_list_columns`),
rendered desktop `users_index_live.ex:274,287` + mobile `:316,335-337`; `badge_text/1` (`:656-658`),
`column_text/2` (`:660-667`); example no-op `sigra_admin_users.ex:20,23`
**Apply to:** the DRY refactor (both seams in both layouts) AND the example hook (emit non-empty so
CI exercises the seam). Direct mirror of Phase 200's `extra_detail_sections` blind-spot close.

### CSS triple-copy byte-parity lockstep
**Source:** the 3 `sigra_admin.css` copies (md5 `9b281962…`, golden-diff gated); `sg-chevron` 0-rule
gap; reusable styled primitives `sg-kv` (×3), `sg-list-row` (×5), `sg-table`, `sg-filter-panel`,
`sg-status-pill`, `sg-card`, `sg-stack--N`
**Apply to:** any new/changed `sg-*` class → byte-identical across all three or golden-diff fails
(184→185 unstyled-admin regression class). Prefer reusing existing primitives → no CSS change.

### GET-form / URL-driven state contract (do not convert to phx-click)
**Source:** `users_index_live.ex:156` (`<form method="get">`), `quick_filter/1` (`:399-412`,
checkbox `name={@key}`), `toggle_filters` (`:66-68`, the ONLY LiveView event),
`open_user_path/3` (`:606-622`, `return_to` round-trip), `page_path/3` (`:598-604`)
**Apply to:** the D-01 applied-chip reflow — keep every named input inside `<form>`; chips that move
inside must be navigation-only `<a>`. Add a form-submit Playwright test (D-02).

### Ledger ratchet — bare undecorated integer
**Source:** `admin-quality-ledger.md:87` (cell to ratchet) vs `:88` (`user-show-live` Tier-2
exemplar); monotonic guard `scripts/ci/quality-ledger-monotonic.sh` (positional `awk -F'|'`)
**Apply to:** flip column-4 `1`→`2` as a single `[012]`, no decorators; cite applicable Tier-2
proxies, mark overlay-axe/APG as N/A (no modal).

### Snapshot recapture routing (changed slugs only, canaries stable)
**Source:** `scripts/ci/snapshot-recapture-gate.sh` (slug-arg routing) + `snapshot-canary-guard.sh`
(`impersonation-banner` checkpoints, `board-notice` design); Phase-192/199 zero-drift idempotency
method (`admin-quality-ledger.md:115-118`)
**Apply to:** recapture `global-user-index` (+ `mg-1/2/5/6` iff markup changes) through the
recapture gate, against a seeded dev DB; canaries byte-stable; allowlists empty at end-of-phase.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | None. Every file in this phase recomposes/extends an existing surface; the `<.user_row_fields>` shared component clones the audit feed's `audit_row/1` + separate-DOM pattern, so even the one net-new component has an exact in-repo analog. |

---

## Metadata

**Analog search scope:** `lib/sigra/admin/live/`, `lib/sigra/admin/users/`,
`lib/sigra/admin/components.ex`, `test/example/lib/example/`,
`test/example/lib/example_web/live/admin/`, `test/example/priv/playwright/tests/`,
the 3 `sigra_admin.css` copies, `guides/reference/`, `test/sigra/admin/glossary_test.exs`,
`.planning/phases/200-user-detail-elevation/`
**Files scanned:** ~14 read/grepped (the LiveView under elevation full-read; audit feed +
`audit_row/1` for DRY; query host-seam; example hook; Playwright equivalence + checkpoint specs;
ledger/design-contract/glossary refs; design gallery boards; 3 CSS copies md5-verified identical;
Phase-200 PATTERNS + Plan-01 SUMMARY as the precedent)
**Pattern extraction date:** 2026-06-26
