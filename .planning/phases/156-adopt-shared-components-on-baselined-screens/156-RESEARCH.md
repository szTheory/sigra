# Phase 156: Adopt Shared Components on Baselined Screens - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView component migration — import-swap + seam reconciliation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01** The 5 baselined screens are: `UsersIndexLive` (global, `/admin/users`), `UsersIndexLive`
  (org-scoped, `/admin/organizations/:slug/users`), `UserShowLive` (`/admin/users/:id`),
  `AuditIndexLive` (`/admin/audit`), and the host `admin_shell.ex` banner
  (`/organizations/:slug/members`). These map to slugs `global-user-index`, `org-scoped-admin`,
  `user-detail`, `audit-explorer`, `impersonation-banner`. The non-baselined Overview/per-user
  audit LiveViews (`index_live.ex`, `organization_live.ex`, `audit_user_live.ex`) get **only**
  pixel-neutral duplicate-def removal (no visual reconciliation, no re-record).
- **D-02** COHR-01 is honored across **all** lib admin LiveViews in phase 156: duplicate `defp
  metric_link`/`defp task_card` in `index_live.ex:118` and `organization_live.ex:169` are
  removed via pixel-neutral import swap.
- **D-03** Deliberate re-records are expected on up to **4 slugs × 3 projects**: `user-detail`,
  `global-user-index`, `org-scoped-admin`, `audit-explorer`. `impersonation-banner` stays
  byte-green unless banner COHR work changes pixels.
- **D-04** No blanket re-records. Every non-named-delta change must stay byte-green.
- **D-05** COHR-02 — `UserShowLive`'s `sg-card`-boxed identity header (`user_show_live.ex:97`)
  converts to open `sg-page-header` archetype. Intended visual delta — deliberate re-record on
  `user-detail`.
- **D-06** COHR-03 — `<.page_back>` replaces inline back link on `UserShowLive`. COHR-05 — all
  contextual alerts render through `<.notice>`. COHR-06 — empty states via `<.empty_state>`.
- **D-07** COHR-04 — `<.scope_ribbon>` added to every list AND leaf screen; scope prose removed
  from `sg-page-copy` subtitle on list screens; discrete element in header region.
- **D-08** COHR-05 concludes the notice-migration window: merge `.sg-list-row[data-tone="X"]`
  and `.sg-notice[data-tone="X"]` to a shared-selector block at `app.css:945-993`. CSS-only
  edit, stays inside `@layer sg-components`, invents no class.
- **D-09** `admin-generated` parity lane auto-tracks (example routes to lib-owned modules
  directly). **Exception:** banner is dual-maintained — any banner change must edit both
  `priv/templates/sigra.install/admin/components/admin_shell.ex` AND
  `test/example/lib/example_web/components/admin_shell.ex` together.

### Claude's Discretion

- Exact placement of `<.scope_ribbon>` within list-screen header region.
- Whether freed `sg-page-copy` subtitle is dropped or repurposed.
- Scope microcopy: default to existing `scope_copy/1` strings.
- Per-screen migration order.
- Internal modularization of migration commits (one screen per commit recommended).

### Deferred Ideas (OUT OF SCOPE)

- Loud, color/role-coded global super-admin scope treatment (needs token work locked out this milestone).
- Scope microcopy tightening to short labels — ui-phase discretionary refinement.
- Overview needs-led redesign — Phase 157.
- Per-user audit + audit-mobile — Phase 158.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COHR-01 | All 6 admin screens render via shared components; no duplicated private stat/task/chip/empty defs remain | Import pattern + defp deletion mechanics; name-collision ordering |
| COHR-02 | User-detail identity header uses open `sg-page-header` archetype, consistent with other screens | `user_show_live.ex:97` sg-card removal; COHR-02 is the sole intended structural delta on user-detail |
| COHR-03 | Single back-nav component on detail/leaf screens consuming `return_to` | `page_back/1` component call-site swap at `user_show_live.ex:91-93` |
| COHR-04 | Persistent in-body scope ribbon on every list and leaf screen | `scope_ribbon/1` added to `users_index_live.ex`, `audit_index_live.ex`; scope prose removed from `sg-page-copy` |
| COHR-05 | Contextual alerts render through shared `notice` component with consistent tone | `user_show_live.ex:131` and `organization_live.ex:71` call-site swap; tone atom/string clarification |
| COHR-06 | Empty-state structure and spacing consistent across all screens | `empty_state/1` swap on all 6 inline empty-state blocks across 3 LiveViews |
</phase_requirements>

---

## Summary

Phase 156 is a migration phase. The shared components (`Sigra.Admin.Components`) exist and
are proven byte-faithful by Phase 155 goldens. This phase wires them into the admin LiveViews
by adding `import Sigra.Admin.Components`, deleting the private `defp` duplicates, and
repointing call sites. Visual coherence seams are reconciled across the 5 baselined screens.

The primary execution risk is the Playwright baseline contract: 4 of the 5 slugs will
re-record (COHR-02 and COHR-04 produce intentional visual deltas), while 1 slug must stay
byte-green. All non-baselined screens (Overview, organization overview, per-user audit) must
also stay byte-green for their own pending baselines even though they have no committed
Playwright snapshots yet. The `admin-generated` parity lane auto-tracks via the shared module.

**Primary recommendation:** Migrate one screen per commit, assert ExUnit green + run
checkpoint spec after each screen, re-record intended-delta slugs only after HTML report
confirms the delta is the named one.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Component rendering | Library (lib-owned LiveViews) | — | `Sigra.Admin.Live.*` owns markup; components.ex is lib-owned |
| CSS tone rules | Static asset (example CSS) | — | `app.css` is host-side; D-08 edit is CSS-only in `@layer sg-components` |
| Snapshot baselines | Test infrastructure | CI gating | `admin-checkpoints.spec.ts-snapshots/` committed; Playwright asserts them |
| Banner dual-maintenance | Template (installer) + Example | — | Both files must stay in sync; no auto-sync mechanism exists |
| Parity lane | CI script + Playwright spec | — | `admin-acceptance-smoke.sh` + `admin-generated.spec.ts`; auto-tracks lib module changes |

---

## Standard Stack

This phase introduces **no new packages**. All work is in existing Elixir/Phoenix/Playwright
code. No package installation required.

---

## Package Legitimacy Audit

Not applicable. Phase 156 installs no external packages.

---

## Migration Mechanics

### Import Idiom

Phoenix 1.8 function components are imported via `import ModuleName` in the calling module.
The migration pattern is:

1. Add `import Sigra.Admin.Components` immediately after the existing `use Phoenix.LiveView`
   (or after the last `alias` block) in the LiveView module.
2. Delete the `defp` that is now shadowed (see name-collision note below).
3. Replace inline HEEx markup with the component call using `<.component_name attr={...}>`.

**Verified pattern** from `core_components.ex` and Phoenix LiveView conventions [ASSUMED: import
order convention; no official doc mandating position, but after `use` is idiomatic]:

```elixir
defmodule Sigra.Admin.Live.UsersIndexLive do
  use Phoenix.LiveView
  import Sigra.Admin.Components   # <-- add here

  alias Sigra.Admin.Scope
  # ...
end
```

### Name-Collision Hazard — CRITICAL

**None of the lib admin LiveViews currently import `Sigra.Admin.Components`** (verified by
grepping `lib/sigra/admin/live/`). The following private defs share names with exported
components and MUST be deleted before or atomically with the import:

| File | Local `defp` | Imported Component | Risk If Not Deleted |
|------|-------------|-------------------|---------------------|
| `users_index_live.ex:336` | `defp summary_chip/1` | `summary_chip/1` | Local defp shadows import; `<.summary_chip>` keeps calling the private def — COHR-01 not achieved |
| `index_live.ex:118,132` | `defp metric_link/1`, `defp task_card/1` | `stat_link/1`, `task_card/1` | Same; plus `metric_link` name differs from `stat_link` so it requires both delete + call-site rename |
| `organization_live.ex:169,183` | same duplicate defs | same | Same as above |

**Note on `stat_link` vs `metric_link`:** The shared component is named `stat_link/1` (not
`metric_link`). Call sites in `index_live.ex` and `organization_live.ex` use `<.metric_link>`.
After deleting the local `defp metric_link`, those call sites must be renamed to `<.stat_link>`
with the matching `href`/`label`/`value` attrs.

**Safe order:** Delete local `defp` first, then add `import`, then update call sites — or do
all three in one atomic commit. Never add the import before deleting the conflicting defp.

### Applied Chip: Loop Pattern

The applied_chip inline blocks use a `:for` loop pattern. After migration:

```heex
<%!-- Before --%>
<span :for={chip <- applied_chips(@current_params)} class="sg-applied-chip">
  <span>{chip.label}</span>
  <a class="sg-applied-chip__remove" href={...} aria-label={"Remove filter " <> chip.label}>
    <span aria-hidden="true">&times;</span>
    <span class="sr-only">remove</span>
  </a>
</span>

<%!-- After --%>
<.applied_chip
  :for={chip <- applied_chips(@current_params)}
  label={chip.label}
  remove_href={remove_chip_path(@admin_scope, @current_params, chip.key)}
/>
```

The `:for` attr moves to the component call. The `remove_chip_path/3` helper maps to the
`remove_href` attr.

### Empty State: Slot Pattern

The `empty_state/1` component uses an optional `inner_block` slot for variable body content:

```heex
<.empty_state title="No users match this view">
  <%= if any_filter_active?(@current_params) do %>
    <p class="sg-muted sg-text-sm">No users match the active filters. Clear them to widen the result set.</p>
    <div class="sg-cluster sg-cluster--center">
      <a href={index_path(@admin_scope)} class="sg-btn sg-btn--secondary sg-btn--sm">Clear all filters</a>
    </div>
  <% else %>
    <p class="sg-muted sg-text-sm">Users appear here as people register and sign in. …</p>
  <% end %>
</.empty_state>
```

Conditional `<%= if %>` expressions inside HEEx slots are fully supported.

---

## Tone Atom-vs-String Resolution (Carried from 155-specifics)

**RESOLVED — verified from source:**

`summary_alert/1` (`user_show_live.ex:488-504`) returns **string** tuples: `{"risk", msg}`,
`{"warn", msg}`. The `notice/1` component accepts `:atom` (attr type `:atom`). The current
call site at `user_show_live.ex:131` passes `data-tone={elem(summary_alert(@detail), 0)}`
where `elem/2` extracts the string.

**Migration path:** Replace with `<.notice tone={:warn}>` or `<.notice tone={:risk}>` using
atom literals determined by the same logic as `summary_alert/1`. Either:

1. Change `summary_alert/1` to return atom tuples: `{:risk, msg}`, `{:warn, msg}`.
2. Or pass the atom directly at the call site: `<.notice tone={notice_tone(@detail)}>` where
   a helper returns the atom.

**Why it works in both cases:** In HEEx attribute position, Phoenix renders the atom `:risk`
as the string `"risk"` in the HTML attribute. The `components_test.exs` golden confirms this:

```elixir
# From components_test.exs:57-61 (Phase 155 golden comment):
# "In HEEx attribute position, atom :risk renders as 'risk', so data-tone='risk' matches."
@notice_golden = "<div class=\"sg-notice \" data-tone=\"risk\">…"
# Called with tone: :risk — atom renders as string in the HTML output
```

The `organization_live.ex:71` call site currently uses inline string tones:
`data-tone={if(..., do: "risk", else: nil)}`. Migration maps to `<.notice tone={:risk}>` or
`<.notice tone={nil}>` based on the same condition.

**Decision for planner:** Option 1 (change `summary_alert/1` to return atoms) is cleaner
because it aligns the internal representation with the component contract. Option 2 (local
helper at call site) avoids touching a shared function. Either is valid; the planner should
pick one and apply it consistently.

---

## COHR-02: UserShowLive Header Archetype Change

**Current code** (`user_show_live.ex:89-134`, verified):

```heex
<section :if={@detail} class="sg-stack sg-stack--6">
  <div class="sg-cluster sg-cluster--between">
    <a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>
      <span aria-hidden="true">&larr;</span> Back to users
    </a>
    <span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>   <%!-- line 94 --%>
  </div>

  <section class="sg-card sg-stack sg-stack--3">   <%!-- line 97: THIS is removed --%>
    <div class="sg-cluster sg-cluster--between sg-cluster--start sg-cluster--3">
      <div class="sg-stack sg-stack--1">
        <p class="sg-page-kicker">Identity &amp; Status</p>
        <h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>
        <span class="sg-muted sg-text-sm">{@detail.user.email}</span>
        <code class="sg-code">{@detail.user.id}</code>
      </div>
      <div class="sg-cluster sg-cluster--2">
        <span :for={{label, tone} <- status_pills(@detail)} class="sg-status-pill" data-tone={tone}>
          {label}
        </span>
      </div>
    </div>
    <dl class="sg-summary-facts">…</dl>
    <div :if={summary_alert(@detail)} class="sg-list-row" data-tone={…}>  <%!-- line 131 --%>
    …
  </section>
```

**Target:** Replace `<div class="sg-cluster sg-cluster--between">` back/ribbon pair with
`<.page_back>` + `<.scope_ribbon>`, and replace `<section class="sg-card sg-stack sg-stack--3">`
with `<header class="sg-page-header">`. The `<dl class="sg-summary-facts">` and `<.notice>`
stay inside the header section but are no longer in a card surface.

---

## COHR-04: scope_ribbon Placement on List Screens

**Current code** in `users_index_live.ex:71-85` (verified):

```heex
<header class="sg-page-header">
  <p class="sg-page-kicker">User operations</p>
  <h1 class="sg-page-title">{page_heading(@admin_scope)}</h1>
  <p class="sg-page-copy">{scope_copy(@admin_scope)}</p>   <%!-- line 75: REMOVE this --%>
  <dl class="sg-metric-grid">
    …
  </dl>
</header>
```

**Target** (per UI-SPEC L148-150):

```heex
<header class="sg-page-header">
  <p class="sg-page-kicker">User operations</p>
  <h1 class="sg-page-title">{page_heading(@admin_scope)}</h1>
  <dl class="sg-metric-grid">…</dl>
</header>
<.scope_ribbon copy={scope_copy(@admin_scope)} />   <%!-- discrete element AFTER the header --%>
```

The scope ribbon goes **outside and after** the `sg-page-header` block on list screens (no
`page_back` sibling, so no `sg-cluster--between` wrapper). The freed `sg-page-copy` subtitle
is dropped (not repurposed) unless the planner decides otherwise — this is a discretion area.

Same pattern applies to `audit_index_live.ex:50-54`.

---

## D-08: Notice Tone CSS Merge

**Verified CSS locations** (`test/example/priv/static/assets/css/app.css`):

| Block | Lines (verified) | Description |
|-------|-----------------|-------------|
| `.sg-list-row` base | 945–951 | Base styles (border-radius, background, box-shadow, padding, transition) |
| `.sg-list-row[data-tone="ok"]` | 952–955 | ok tone — color-mix background + inset box-shadow |
| `.sg-list-row[data-tone="warn"]` | 956–959 | warn tone |
| `.sg-list-row[data-tone="risk"]` | 960–963 | risk tone |
| `.sg-list-row[data-tone="info"]` | 964–967 | info tone |
| `.sg-notice` base | 971–977 | Byte-clone of `.sg-list-row` base |
| `.sg-notice[data-tone="ok"]` | 978–981 | Byte-clone of `.sg-list-row[data-tone="ok"]` |
| `.sg-notice[data-tone="warn"]` | 982–985 | Byte-clone |
| `.sg-notice[data-tone="risk"]` | 986–989 | Byte-clone |
| `.sg-notice[data-tone="info"]` | 990–993 | Byte-clone |

The two blocks are exact byte-clones as designed. The merge target:

```css
.sg-list-row[data-tone="ok"], .sg-notice[data-tone="ok"] { … }   /* one block replaces both */
.sg-list-row[data-tone="warn"], .sg-notice[data-tone="warn"] { … }
.sg-list-row[data-tone="risk"], .sg-notice[data-tone="risk"] { … }
.sg-list-row[data-tone="info"], .sg-notice[data-tone="info"] { … }
```

`.sg-list-row` base styles survive unchanged (audit/invitation rows use it as a non-alert
layout primitive). Only the `[data-tone]` blocks are merged. The merge changes zero rendered
bytes — both selectors were byte-identical before. This edit must stay inside
`@layer sg-components { }`.

---

## D-09: Banner Dual-Maintenance Trap

**Both files exist and are verified in sync** (diff shows only the `<%= web_module %>` template
substitution differs):

- `priv/templates/sigra.install/admin/components/admin_shell.ex` (installer template)
- `test/example/lib/example_web/components/admin_shell.ex` (example host)

**The trap:** If the impersonation banner COHR work (or any banner component change) edits
only one file, the `admin-generated` parity lane goes red because the smoke scaffolds a fresh
app from the installer template, which would diverge from the example app.

**Current banner state:** The banner component (`impersonation_banner`) is defined inside
`admin_shell.ex` as a local `defp`. Phase 156 COHR work does NOT change the banner's visual
output (D-03: `impersonation-banner` slug stays byte-green). So banner dual-maintenance is a
**no-op for this phase** unless the planner decides to also import `Sigra.Admin.Components`
into the banner file (which has no shared components currently). Monitor: if any edit touches
`admin_shell.ex`, edit both files.

---

## Known Byte-Delta Inventory

The following byte-deltas have been analyzed against the current source:

| Screen | Delta Source | Slug Effect |
|--------|-------------|-------------|
| `user_show_live.ex` | COHR-02 header archetype change | `user-detail`: intended re-record |
| `user_show_live.ex` | `<.page_back>` replaces inline `<a>` | `user-detail`: absorbed into re-record |
| `user_show_live.ex` | `<.scope_ribbon>` replaces inline `<span>` | `user-detail`: absorbed (scope_ribbon golden is byte-identical) |
| `user_show_live.ex` | `<.notice>` replaces `sg-list-row` alert | `user-detail`: absorbed (sg-notice is byte-clone of sg-list-row per app.css) |
| `user_show_live.ex` | `<.empty_state>` adds `sg-stack sg-stack--3` to bare `sg-empty-state` blocks | `user-detail`: absorbed into re-record (4 instances gain the stack classes) |
| `users_index_live.ex` | `<.scope_ribbon>` added outside header, `sg-page-copy` removed | `global-user-index`, `org-scoped-admin`: intended re-record (COHR-04) |
| `users_index_live.ex` | `<.applied_chip>` replaces inline — trailing space in class attribute | `global-user-index`, `org-scoped-admin`: absorbed into COHR-04 re-record |
| `users_index_live.ex` | `<.empty_state>` replaces inline (already has `sg-stack sg-stack--3`) | Byte-neutral — `global-user-index` stays green on empty state |
| `audit_index_live.ex` | `<.scope_ribbon>` added, `sg-page-copy` removed | `audit-explorer`: intended re-record (COHR-04) |
| `audit_index_live.ex` | `<.applied_chip>` replaces inline | `audit-explorer`: absorbed into re-record |
| `audit_index_live.ex` | `<.empty_state>` replaces inline (already has `sg-stack sg-stack--3`) | Byte-neutral |
| `index_live.ex` + `organization_live.ex` | `defp metric_link`/`defp task_card` deleted; import + call-site rename | No committed baselines; pixel-neutral |
| `organization_live.ex:71` | `<.notice>` replaces `sg-list-row` alert | No committed baseline; pixel-neutral |

---

## Scope Copy String Discrepancy (Flag for Planner)

**DISCREPANCY BETWEEN UI-SPEC AND CONTEXT.MD:**

The UI-SPEC Copywriting Contract (lines 228-229) lists shortened copy:
- `{org.name} users` (for org-scoped UsersIndexLive ribbon)
- `{org.name} audit` (for org-scoped AuditIndexLive ribbon)
- `{org.name} user` (for org-scoped UserShowLive ribbon — singular)

But the **actual current `scope_copy/1` functions** return:
- `users_index_live.ex:409`: `"Organization-scoped user operations for #{name}"`
- `audit_index_live.ex:242`: `"Organization-scoped audit explorer for #{name}"`
- `user_show_live.ex:413-414`: `"Organization-scoped user operations for #{name}"`

And **CONTEXT.md (line 120)** explicitly locks: "Scope microcopy: default to keeping the
existing `scope_copy/1` strings (byte-faithful, least-surprising). Tightening to a short scope
label is a **ui-phase discretionary refinement, not required here**."

**Resolution for planner:** CONTEXT.md wins over UI-SPEC on scope copy strings. Use the
existing `scope_copy/1` output verbatim. The UI-SPEC short-form strings are a documentation
artifact of a future refinement, not a Phase 156 requirement. The `admin-checkpoints.spec.ts`
only asserts `'Global user operations'` by text (line 188 of the spec) — no assertion on the
org-scoped copy strings. Using the existing strings keeps all text assertions green.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Snapshot baseline diff review | Manual pixel-compare | Playwright HTML report | `playwright show-report` shows side-by-side diff with highlighting |
| Accessibility checking | Custom DOM traversal | `AxeBuilder` in checkpoint spec | Already wired with WCAG A/AA tags; `assertNoAxeViolations` called per checkpoint |
| Component byte-equality proof | Visual inspection | `components_test.exs` ExUnit goldens | Phase 155 goldens prove the component produces the same bytes as original markup |

---

## Common Pitfalls

### Pitfall 1: Import Before Deleting the Shadowing defp

**What goes wrong:** Adding `import Sigra.Admin.Components` to a LiveView that still has a
`defp summary_chip/1` — the import succeeds but the local defp takes precedence in HEEx
`<.summary_chip>` resolution. COHR-01 is not achieved; the private def silently wins.

**Why it happens:** Elixir resolves `<.component>` calls to the local scope before imported
modules. Phoenix component name resolution in HEEx templates follows the same rule.

**How to avoid:** Delete the conflicting `defp` in the same commit as the import.

**Warning signs:** `mix compile` emits an "ambiguous import" or "unused import" warning. The
visual output is unchanged (the private def still renders). Byte-green doesn't prove the right
component is running.

### Pitfall 2: Blanket Re-record of Non-Intended Deltas

**What goes wrong:** A pixel-neutral change (e.g., component class attr trailing space from nil
default) causes a trivial baseline failure. Developer runs `--update-snapshots` broadly without
reviewing the HTML report.

**Why it happens:** The trailing-space issue in `["sg-applied-chip", @class]` with `@class =
nil` emits `class="sg-applied-chip "` (trailing space) vs the original `class="sg-applied-chip"`.
For the list screens this is absorbed into the COHR-04 re-record. For `impersonation-banner`
and pixel-neutral screens it must NOT re-record.

**How to avoid:** Review the HTML diff report before accepting. Use `--update-snapshots` only
after confirming the delta matches the named intended change (D-04 / SC-7).

**Re-record command (local):**

```bash
cd test/example/priv/playwright
# First: run all three checkpoint projects to see which slugs fail
SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-checkpoints.spec.ts \
  --project=admin-checkpoints-chromium \
  --project=admin-checkpoints-mobile \
  --project=admin-checkpoints-dark

# Review the HTML report
npx playwright show-report

# Only after HTML diff confirms delta is the intended one:
SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-checkpoints.spec.ts \
  --project=admin-checkpoints-chromium \
  --project=admin-checkpoints-mobile \
  --project=admin-checkpoints-dark \
  --update-snapshots
```

### Pitfall 3: Empty State `sg-stack sg-stack--3` Added to user_show_live

**What goes wrong:** The 4 bare `sg-empty-state` blocks in `user_show_live.ex` (lines 188,
222, 252, 282) do NOT currently have `sg-stack sg-stack--3`. The `empty_state/1` component
always emits `<div class="sg-empty-state sg-stack sg-stack--3 ...">`. Migrating these to
`<.empty_state>` will add the stack classes.

**Why it matters:** This is a visual byte-delta (spacing will change for the 4 detail-page
empty states). However, `user-detail` is already flagged for intentional re-record (COHR-02),
so this secondary delta is absorbed. Not a problem if the COHR-02 re-record is done first.

**How to avoid:** No special action needed — the re-record window for `user-detail` covers it.
Just be aware this is one of the contributing deltas, not a bug.

### Pitfall 4: Installer Template Drift

**What goes wrong:** A change to `test/example/lib/example_web/components/admin_shell.ex`
is not mirrored to `priv/templates/sigra.install/admin/components/admin_shell.ex` (or vice
versa). The `admin-acceptance-smoke.sh` scaffolds a fresh Phoenix app from the installer
templates and runs `admin-generated.spec.ts`. If only one file is edited, the parity lane
goes red.

**Why it happens:** Two separate files, one is the installed template, one is the example app.
No automated sync mechanism.

**How to avoid:** For this phase, the banner files are byte-equivalent (verified by diff —
only template substitution tags differ). The phase does NOT touch the banner. If any edit
touches `admin_shell.ex`, update both files in the same commit.

---

## Validation Architecture

> `nyquist_validation: true` — this section is mandatory.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (mix test) + Playwright (npx playwright test) |
| Config file | `test/example/priv/playwright/playwright.config.ts` |
| Quick run (ExUnit) | `mix test test/sigra/admin/components_test.exs` |
| Quick run (Playwright checkpoints only) | See commands below |
| Full ExUnit suite | `mix test` |
| Full Playwright suite | `cd test/example/priv/playwright && npx playwright test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COHR-01 | No duplicated private defs remain | ExUnit (compile-level) | `mix test test/sigra/admin/components_test.exs` | Yes |
| COHR-01 | Components resolve to shared module (not private shadow) | ExUnit + Playwright render | `mix test test/sigra/admin/` | Yes |
| COHR-02 | user-detail uses open `sg-page-header` archetype | Playwright snapshot + axe | Checkpoint spec (user-detail project × 3) | Yes (re-record required) |
| COHR-03 | `<.page_back>` used on UserShowLive | Playwright snapshot | Checkpoint spec (user-detail) | Yes |
| COHR-04 | `<.scope_ribbon>` present on all list/leaf screens | Playwright snapshot | Checkpoint spec × 3 slugs × 3 projects | Yes (re-record on 3 slugs) |
| COHR-05 | `notice` component renders at `user_show_live.ex:131` | ExUnit component golden | `mix test test/sigra/admin/components_test.exs` | Yes |
| COHR-06 | `<.empty_state>` used; structure consistent | Playwright snapshot | Checkpoint spec | Yes |
| D-08 CSS merge | Tone rules consolidated; no rendered difference | Playwright snapshot (byte-green) | Checkpoint spec (all 5 slugs byte-green for tone rendering) | Yes |
| D-09 parity | admin-generated parity lane stays green | Smoke script | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh` | Yes |

### Gate 1: Phase 155 Component Goldens (must stay green)

These ExUnit tests prove the shared components produce the same bytes as the original inline
markup. They must never re-record. If they go red, a component was modified — stop and fix.

```bash
mix test test/sigra/admin/components_test.exs
```

8 tests: 7 strict byte-equal goldens (`stat_link`, `task_card`, `summary_chip`, `applied_chip`,
`empty_state`, `page_back`, `scope_ribbon`) + 1 target golden (`notice`) + 2 structural
assertions (`stat`, `skeleton`). All 10 must stay green throughout Phase 156.

### Gate 2: Playwright Admin Checkpoint Baselines

**Local command (run against a booted example app on port 4000):**

```bash
cd test/example/priv/playwright
SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-checkpoints.spec.ts \
  --project=admin-checkpoints-chromium \
  --project=admin-checkpoints-mobile \
  --project=admin-checkpoints-dark
```

**Report review:**

```bash
npx playwright show-report
```

**Snapshot directory:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/`

Current snapshots (15 files, verified):

```
audit-explorer-admin-checkpoints-chromium.png
audit-explorer-admin-checkpoints-dark.png
audit-explorer-admin-checkpoints-mobile.png
global-user-index-admin-checkpoints-chromium.png
global-user-index-admin-checkpoints-dark.png
global-user-index-admin-checkpoints-mobile.png
impersonation-banner-admin-checkpoints-chromium.png
impersonation-banner-admin-checkpoints-dark.png
impersonation-banner-admin-checkpoints-mobile.png
org-scoped-admin-admin-checkpoints-chromium.png
org-scoped-admin-admin-checkpoints-dark.png
org-scoped-admin-admin-checkpoints-mobile.png
user-detail-admin-checkpoints-chromium.png
user-detail-admin-checkpoints-dark.png
user-detail-admin-checkpoints-mobile.png
```

### Gate 3: Intended Re-record Contract (SC-7)

Per D-03 and the UI-SPEC Baseline Re-record Contract, **exactly 4 slugs × 3 projects** are
expected to re-record:

| Slug | Projects | Cause | Byte-green required? |
|------|----------|-------|----------------------|
| `user-detail` | chromium, mobile, dark | COHR-02 header archetype change | No — deliberate re-record |
| `global-user-index` | chromium, mobile, dark | COHR-04 scope ribbon added | No — deliberate re-record |
| `org-scoped-admin` | chromium, mobile, dark | COHR-04 scope ribbon added | No — deliberate re-record |
| `audit-explorer` | chromium, mobile, dark | COHR-04 scope ribbon added | No — deliberate re-record |
| `impersonation-banner` | chromium, mobile, dark | No COHR work on banner | **YES — must stay byte-green** |

**Re-record procedure:**
1. Run checkpoint spec — 12 failures expected (4 slugs × 3 projects), 3 passes expected.
2. Run `npx playwright show-report` and inspect the HTML diff for each failing slug.
3. Confirm each diff shows ONLY the named intended delta (ribbon addition or header archetype).
4. If the diff shows any unexpected change, investigate before accepting.
5. Once confirmed: `npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark --update-snapshots`
6. Commit the 12 updated `.png` files alongside the code changes.

### Gate 4: axe WCAG A/AA

The `assertCheckpointScreenshot` function calls `assertNoAxeViolations` before each snapshot
assertion. This is wired into the existing checkpoint spec with `withTags(['wcag2a', 'wcag2aa'])`.
**No additional setup needed.** axe runs automatically on every checkpoint page capture.

The accessibility contract from UI-SPEC:
- `scope_ribbon`: no ARIA role (decorative span)
- `notice` (load-present): no live-region role
- `page_back`: native `<a>` semantics, arrow `aria-hidden="true"`
- `empty_state`: no ARIA, `<p class="sg-empty-state__title">` for semantic heading
- `applied_chip` remove link: `aria-label={"Remove filter " <> chip.label}`

### Gate 5: admin-generated Parity Lane

**Parity lane (auto-tracks lib module changes):**

```bash
GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh
```

This scaffolds a fresh Phoenix app, installs Sigra from the local repo path, seeds fixtures,
and runs `test/example/priv/playwright/tests/admin-generated.spec.ts` against the generated
host on port 4017.

The parity lane auto-tracks because the example host routes admin URLs directly to
`Sigra.Admin.Live.*` modules — there are no generated host LiveView copies. Edits to the
lib LiveViews are automatically reflected when the generated host starts.

**The one manual exception:** if any edit touches `admin_shell.ex`, both copies must be
updated (D-09). For Phase 156 the banner is not touched, so no manual action required.

### Gate 6: Full ExUnit Suite

```bash
mix test
```

Requires live Postgres at localhost:5432 (credentials `postgres`/`postgres`). Covers all
lib unit + integration tests including the Phase 155 component goldens and LiveView tests.

### Sampling Rate

| Trigger | Command |
|---------|---------|
| Per screen commit | `mix test test/sigra/admin/` |
| After COHR-04 scope ribbon work | Checkpoint spec (Gates 2+3) for affected slugs |
| After each intended re-record | `npx playwright show-report` then `--update-snapshots` |
| Phase gate | Full ExUnit + full Playwright checkpoint spec + admin-generated smoke |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/mix | Full suite | Must be present | n/a | None — required |
| PostgreSQL | mix test | Must be present locally (see CLAUDE.md) | n/a | None |
| Node.js / npx | Playwright gates | Required | n/a | None |
| Playwright browsers (Chromium) | Checkpoint + parity gates | `npm ci` + `playwright install` in playwright dir | n/a | Run `npm ci && npx playwright install --with-deps chromium` |
| Example app booted on port 4000 | Playwright checkpoint spec | Must be running separately | n/a | Boot with `cd test/example && mix phx.server` |

**Note:** The checkpoint spec and admin-generated smoke script require a running server. The
component golden tests (`components_test.exs`) and the full ExUnit suite run without a server.

---

## Security Domain

This phase is a migration-only pass; no new security-relevant code paths are introduced.
All security-sensitive logic (auth, sessions, tokens) remains untouched. No ASVS category
applies to this phase.

---

## Sources

### Primary (HIGH confidence)
- `lib/sigra/admin/components.ex` — verified component signatures, attr types, class output
- `lib/sigra/admin/live/users_index_live.ex` — verified current inline markup, scope_copy returns, line references
- `lib/sigra/admin/live/user_show_live.ex` — verified lines 91-97 (header), 131 (notice call), 488-504 (summary_alert return type)
- `lib/sigra/admin/live/audit_index_live.ex` — verified lines 50-54, 115, 172
- `lib/sigra/admin/live/index_live.ex` — verified defp metric_link at :118, defp task_card at :132
- `lib/sigra/admin/live/organization_live.ex` — verified defp metric_link at :169, defp task_card at :183, inline notice at :71
- `test/sigra/admin/components_test.exs` — Phase 155 goldens; confirmed atom-vs-string resolution note at line 57
- `test/example/priv/static/assets/css/app.css:945-993` — verified tone rule byte-clone
- `test/example/priv/playwright/playwright.config.ts` — project partitioning, snapshot path template
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — axe wiring, assertCheckpointScreenshot, snapshot update procedure
- `scripts/ci/admin-acceptance-smoke.sh` — parity lane local command
- `priv/templates/sigra.install/admin/components/admin_shell.ex` and `test/example/lib/example_web/components/admin_shell.ex` — verified in-sync (only template substitution differs)
- `.planning/phases/156-adopt-shared-components-on-baselined-screens/156-CONTEXT.md` — locked decisions D-01..D-09
- `.planning/phases/156-adopt-shared-components-on-baselined-screens/156-UI-SPEC.md` — component interaction contracts, baseline re-record contract

### Secondary (MEDIUM confidence)
- Phoenix.Component import/defp shadowing behavior: [ASSUMED] based on Elixir module resolution rules and Phoenix HEEx component resolution (local defp precedes imported function)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Local `defp` takes precedence over imported function for `<.component_name>` calls in HEEx templates | Migration Mechanics (Name-Collision Hazard) | If wrong, import-before-delete would work without ambiguity; the ordering hazard is lower risk than stated. Actual behavior: still a compile warning, still cleaner to delete atomically. |
| A2 | `import Sigra.Admin.Components` placement immediately after `use Phoenix.LiveView` is idiomatic | Migration Mechanics | If wrong, placement elsewhere in the module is equally valid; no functional impact. |

---

## Open Questions

1. **Empty state body text: preserve or drop on `user_show_live.ex` migration?**
   - What we know: The 3 user_show_live empty states (sessions, identities, organizations) have
     body text in the current code (`<p class="sg-muted sg-text-sm">...`), but the UI-SPEC marks
     them `(no body)` in the Copywriting Contract table.
   - What's unclear: Is the "(no body)" annotation intentional (drop the body text on migration
     to `<.empty_state>`) or a documentation shorthand?
   - Recommendation: Preserve the existing body text as `inner_block` slot content in
     `<.empty_state>` — byte-faithful migration is the stated goal; body text removal would
     be a content change. The `user-detail` re-record absorbs any visual delta.

2. **`summary_alert/1` atom vs string: change the function or the call site?**
   - Resolved by investigation: both approaches work. Recommendation: change `summary_alert/1`
     to return atom tuples (`{:risk, msg}`, `{:warn, msg}`) — aligns with the component's
     `:atom` contract. Call site then becomes `<.notice tone={elem(summary_alert(@detail), 0)}>`.

---

## RESEARCH COMPLETE

**Phase:** 156 - Adopt Shared Components on Baselined Screens
**Confidence:** HIGH

### Key Findings

1. **Name-collision hazard confirmed:** All lib admin LiveViews currently have zero imports of
   `Sigra.Admin.Components`. `users_index_live.ex:336` has `defp summary_chip/1` that shadows
   the import. Must delete defp atomically with import. `index_live.ex` and `organization_live.ex`
   have `defp metric_link/1` + `defp task_card/1`; note `metric_link` → `stat_link` rename required
   at call sites.

2. **tone atom/string resolved:** `summary_alert/1` returns string tuples (`"risk"`, `"warn"`).
   `notice/1` accepts `:atom`. Phoenix renders atom `:risk` as `"risk"` in HTML attributes, so
   both atom call sites and string call sites produce identical HTML. Migration recommendation:
   change `summary_alert/1` to return atom tuples for contract alignment.

3. **CSS byte-clone confirmed:** `app.css:945-967` (`.sg-list-row[data-tone]`) and `:971-993`
   (`.sg-notice[data-tone]`) are exact byte-clones. D-08 merge changes zero rendered bytes.

4. **Scope copy discrepancy flagged:** UI-SPEC short-form org strings (`"{org.name} users"`)
   conflict with CONTEXT.md lock ("keep existing `scope_copy/1` strings"). CONTEXT.md wins.
   Use existing long-form strings.

5. **Validation gates fully specified:** ExUnit component goldens (Gate 1), Playwright checkpoint
   spec × 3 projects (Gate 2), re-record contract for 4 slugs × 3 projects (Gate 3), axe WCAG
   A/AA (Gate 4, already wired), admin-generated parity smoke (Gate 5).

6. **impersonation-banner files are in sync** (diff verified). Phase 156 does not touch the
   banner, so dual-maintenance is a no-op for this phase.

### File Created

`.planning/phases/156-adopt-shared-components-on-baselined-screens/156-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Migration mechanics | HIGH | All source files verified against CONTEXT.md line references |
| Validation architecture | HIGH | Scripts, spec files, snapshot dirs all verified in repo |
| CSS tone merge | HIGH | Lines 945-993 verified byte-by-byte |
| Tone atom/string | HIGH | `summary_alert/1` source + `components_test.exs` golden comment both read |
| Name-collision hazard | HIGH | Grep confirmed no existing import; defp locations confirmed |

### Open Questions

- Empty state body text disposition on `user_show_live.ex` migration (see Open Questions §1).
- `summary_alert/1` refactor scope (atom return vs call-site conversion).

### Ready for Planning

Research complete. Planner can create PLAN.md files.
