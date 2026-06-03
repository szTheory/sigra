# Phase 33: Admin Shell Navigation and Audit Preview Polish - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 6 (3 production-code, 1 test addition, 1 test update, 1 optional test)
**Analogs found:** 6 / 6 (all Phase 33 work has an existing in-repo analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/templates/sigra.install/admin/components/admin_shell.ex` (modify, INT-04) | component (host-owned generator template) | request-response | `test/example/lib/example_web/components/admin_shell.ex` (verbatim port source) | **exact — same file, side A of generator/example pair** |
| `lib/sigra/admin/users/detail.ex` (modify, INT-05) | service (admin query module, library-owned) | CRUD + transform | `lib/sigra/admin/audit/explorer.ex` lines 115-158 (load+present owner) | **exact — same role, same flow, same Presenter seam** |
| `lib/sigra/admin/live/user_show_live.ex` (modify, INT-05) | LiveView render | request-response | `lib/sigra/admin/live/audit_user_live.ex` lines 115-148 (Presenter-row rendering) | **exact — same Presenter rows, subset fields per D-05/D-06** |
| `test/sigra/templates/installer_drift_test.exs` (append fixture, INT-04 guard) | test (drift fixture) | batch / declarative | existing `@fixtures` entries lines 29-266 | **exact — append one entry to the same list** |
| `test/sigra/admin/users_actions_test.exs` (modify lines 253-257 only if D-02 flip chosen) | test | assertion update | existing assertions at lines 253-257 using struct-field access | **exact — in-place contract swap** |
| `test/example/test/example_web/admin_shell_test.exs` (optional one-line extension per "Claude's Discretion") | test | assertion extension | existing assertions at lines 29-34 using `assert html =~ "Users"` | **exact — same shape** |

## Pattern Assignments

---

### `priv/templates/sigra.install/admin/components/admin_shell.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/components/admin_shell.ex`

This is the side-A/side-B pair the library's "hybrid lib+generator architecture" is built around (PROJECT.md) and that Phase 10.1-02 + Phase 32's "fix + guard" discipline has extended. The port must be **verbatim** except for the two EEx substitution points already present in the template header (`<%= web_module %>` → `ExampleWeb`). Per D-13, no new EEx bindings are introduced.

**Top-bar Users scope-switch entry — port verbatim** (example lines 23-26, insert **before** the existing Global scope-switch link that currently begins on line 24 of the template):
```elixir
<.scope_switch_link href={users_link(@admin_scope)} active={users_active?(@admin_scope)}>
  Users
</.scope_switch_link>
```
The existing `:if={show_global_link?(@admin_scope)}` guard on Global and `:if={organization_link(@admin_scope)}` guard on Organization stay untouched. The Users link is unguarded in the example, so it is unguarded in the port.

**Desktop sidebar Users link — replace dead `<span>`** (example lines 52-60, template's current dead anchor at line 67 is `<li><span class="text-base-content/60">Users</span></li>`):
```elixir
<li>
  <a
    class={nav_item_class(users_active?(@admin_scope))}
    href={users_link(@admin_scope)}
  >
    Users
  </a>
</li>
```

**Sidebar section ordering — Operations-before-Overview per D-11**
The template currently emits Overview (lines 47-61) then Operations (lines 64-74). The example emits Operations (lines 50-67) then Overview (lines 69-84). Swap the template's two `<div class="rounded-lg bg-base-200 p-3">` blocks so Operations renders first. **Do not** rewrite any other classes, structure, or `audit_link/1` details inside those blocks — the only structural change is ordering + the dead-text replacement above.

**Mobile bottom-nav Users entry — port verbatim** (example lines 96-102, insert as the **first** `<a>` in the existing `.btm-nav` block at template lines 83-100):
```elixir
<a
  href={users_link(@admin_scope)}
  class={bottom_nav_class(users_active?(@admin_scope))}
>
  <span class="btm-nav-label">Users</span>
</a>
```

**`users_link/1` helper — port verbatim** (example lines 191-194, place adjacent to the existing `audit_link/1` helper at template lines 165-168, matching example helper ordering):
```elixir
defp users_link(%{mode: :organization, organization_slug: slug}) when is_binary(slug),
  do: ~p"/admin/organizations/#{slug}/users"

defp users_link(_admin_scope), do: ~p"/admin/users"
```

**`users_active?/1` helper — port verbatim** (example line 201, place near other `*_active?/1` clauses at template lines 170-174):
```elixir
defp users_active?(_admin_scope), do: true
```
Per D-10 last bullet, this always-true stub is intentional — path-aware active state is deferred.

**Per D-12:** the `~p` / literal-string inconsistency in the existing `audit_link/1` helper (example line 197 uses `"/admin/organizations/..."` while other helpers use `~p`) is **not** touched in Phase 33.

---

### `lib/sigra/admin/users/detail.ex` (service, CRUD + transform)

**Analog:** `lib/sigra/admin/audit/explorer.ex` lines 115-158 (`list/4` — the canonical "build query → `repo.all` → `load_users/2` → `Presenter.present/2`" pipeline that D-01 instructs Detail to mirror).

**Pre-flip grep gate (D-02) — MUST run before flipping the return contract.** The planner / executor runs:
```
grep -rn "recent_audit_preview" lib/ test/ priv/templates/ test/example/
```
Expected callers today (verified during pattern mapping):
1. `lib/sigra/admin/users/detail.ex:25` — self-call from `load!/3` (internal, acceptable).
2. `test/sigra/admin/users_actions_test.exs:253-257` — asserts `&1.action == "session.delete"`, `&1.action == "session.revoke_all"`, and `&1.target_id == user.id` on `preview` entries, i.e. **raw struct fields**. This test must flip alongside the contract, OR D-02's fallback path (paired `_presented/3` helper) applies.

**Preferred path (D-01 + D-02):** flip `recent_audit_preview/3` in place to return `[map()]` (Presenter rows). Update the one external caller assertion.

**Fallback path (D-02):** keep `recent_audit_preview/3` returning `[struct()]` and add `recent_audit_preview_presented/3` returning `[map()]`. `load!/3` uses the new `_presented/3` helper.

**Load + Presenter pattern to mirror** (excerpt from `lib/sigra/admin/audit/explorer.ex:115-158`):
```elixir
defp list(config, %Scope{} = admin_scope, params, extra_filters) do
  # ... filter normalization ...
  audit_schema = audit_schema!(config)

  query =
    audit_schema
    |> Query.build(filters)
    |> paginate(order_by, order_direction, cursor, limit)

  events = config.repo.all(query)
  {page_events, next_cursor} = split_page(events, limit)
  users_by_id = load_users(config, page_events)
  rows = Presenter.present(page_events, users_by_id)
  # ...
end
```

**`load_users/2` pattern to mirror** (D-04, excerpt from `lib/sigra/admin/audit/explorer.ex:71-85`):
```elixir
defp load_users(config, events) do
  ids =
    events
    |> Enum.flat_map(fn event -> [event.actor_id, event.effective_user_id, event.target_id] end)
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()

  if ids == [] do
    %{}
  else
    from(user in config.user_schema, where: user.id in ^ids)
    |> config.repo.all()
    |> Map.new(&{&1.id, &1})
  end
end
```
Detail should either delegate to this helper (if promoted to public) or mirror the pattern locally. Keep the `Enum.filter(&is_binary/1)` and empty-ids short-circuit — both are load-bearing.

**Current function to flip** (existing `lib/sigra/admin/users/detail.ex:58-75`):
```elixir
@spec recent_audit_preview(map(), Scope.t(), binary()) :: [struct()]
def recent_audit_preview(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
  case audit_schema(config) do
    nil ->
      []

    audit_schema ->
      filters =
        [subject_user_id: user_id]
        |> maybe_put_audit_scope(admin_scope)

      audit_schema
      |> Sigra.Admin.Audit.Query.build(filters)
      |> order_by([event], desc: event.inserted_at, desc: event.id)
      |> limit(^@audit_preview_limit)
      |> config.repo.all()
  end
end
```

**Target shape after flip** — inserts one `load_users/2` call and one `Presenter.present/2` call between `repo.all` and the return, matching Explorer:
```elixir
@spec recent_audit_preview(map(), Scope.t(), binary()) :: [map()]
@doc """
Returns up to `@audit_preview_limit` most-recent audit events for `user_id`,
already shaped by `Sigra.Admin.Audit.Presenter.present/2`. Each row is a map
with the guaranteed keys `:id`, `:inserted_at`, `:action_label`,
`:action_badge`, and `:actor_summary` (D-03). Preview renderers MUST NOT
introduce fields outside that set (D-07).
"""
def recent_audit_preview(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
  case audit_schema(config) do
    nil ->
      []

    audit_schema ->
      filters = [subject_user_id: user_id] |> maybe_put_audit_scope(admin_scope)

      events =
        audit_schema
        |> Sigra.Admin.Audit.Query.build(filters)
        |> order_by([event], desc: event.inserted_at, desc: event.id)
        |> limit(^@audit_preview_limit)
        |> config.repo.all()

      users_by_id = load_audit_users(config, events)
      Sigra.Admin.Audit.Presenter.present(events, users_by_id)
  end
end
```
(Planner chooses whether `load_audit_users/2` is a private clone of Explorer's `load_users/2` or whether Explorer's helper is promoted to public — CONTEXT.md § Reusable Assets explicitly permits either.)

**`@spec` / `@doc` requirement from D-03.** The doc must name the row keys the preview promises (`:action_label`, `:action_badge`, `:actor_summary`, `:inserted_at`, `:id`). The planner's exact phrasing is Claude's Discretion.

---

### `lib/sigra/admin/live/user_show_live.ex` (LiveView render)

**Analog:** `lib/sigra/admin/live/audit_user_live.ex:115-148` (reference rendering of Presenter rows in the per-user explorer; coherence target per D-06/D-07).

**Current dead rendering** (existing `lib/sigra/admin/live/user_show_live.ex:207-213`, which consumes the raw struct's `event.action` — this is the INT-05 defect):
```elixir
<div class="mt-4 space-y-2 text-sm">
  <div :for={event <- @detail.recent_audit} class="rounded-md border border-base-300 bg-base-200 p-3">
    <p class="font-semibold">{event.action}</p>
    <p>{Calendar.strftime(event.inserted_at, "%Y-%m-%d %H:%M")}</p>
  </div>
  <p :if={@detail.recent_audit == []}>No recent audit activity.</p>
</div>
```

**Explorer's canonical Presenter-row render (to align with, subset form)** — from `lib/sigra/admin/live/audit_user_live.ex:128-143`:
```elixir
<td class="align-top">
  <div class="space-y-1">
    <span :if={row.action_badge} class="badge badge-warning badge-sm">{row.action_badge}</span>
    <p class="font-semibold">{row.action_label}</p>
    <p class="text-sm text-base-content/70">{row.action}</p>
  </div>
</td>
<td class="align-top">
  <div class="space-y-1">
    <p>{row.actor_summary}</p>
    <p :if={row.action_badge} class="text-sm text-base-content/70">Actor: {row.actor_label}</p>
    <p :if={row.action_badge} class="text-sm text-base-content/70">
      Effective user: {row.effective_user_label}
    </p>
  </div>
</td>
<td class="hidden align-top md:table-cell">{row.outcome}</td>
```

**Preview target — strict subset per D-05/D-06.** The preview shows `action_badge` (only when present), `action_label`, `actor_summary`, and a formatted timestamp. It does **NOT** render `action`, `actor_label`, `effective_user_label`, or `outcome`:
```elixir
<div class="mt-4 space-y-2 text-sm">
  <div :for={row <- @detail.recent_audit} class="rounded-md border border-base-300 bg-base-200 p-3">
    <div class="space-y-1">
      <span :if={row.action_badge} class="badge badge-warning badge-sm">{row.action_badge}</span>
      <p class="font-semibold">{row.action_label}</p>
      <p class="text-sm text-base-content/70">{row.actor_summary}</p>
      <p class="text-xs text-base-content/60">{Calendar.strftime(row.inserted_at, "%Y-%m-%d %H:%M")}</p>
    </div>
  </div>
  <p :if={@detail.recent_audit == []}>No recent audit activity.</p>
</div>
```
Variable rename from `event` → `row` tracks the shape change (raw struct → Presenter map) and is the smallest signal that the information model changed. `@detail.recent_audit == []` and the surrounding section at `user_show_live.ex:193-205` (header, copy, "View full audit" CTA, `full_audit_path/3` call) stay **untouched** per D-09.

**Audit-preview limit** stays at `@audit_preview_limit 5` in `Detail` (D-09) — no change to `user_show_live.ex` there.

---

### `test/sigra/templates/installer_drift_test.exs` (test, batch / declarative — fixture append)

**Analog:** the 17 existing `@fixtures` entries at lines 29-266.

The harness is purpose-built for side-A/side-B fix parity. Fixtures are declarative maps with `:id`, `:template`, `:example`, optional `:must_have`, and optional `:must_not` — identical regexes for template and example sides because neither side varies in the patterns being checked here (no EEx binding appears inside any matched text). Per D-14/D-15/D-16 and the "subset rendering" comment style established in existing fixtures, append:

```elixir
%{
  # Phase 33 — INT-04 fix + guard: the generator's admin shell template must
  # expose a live Users link (desktop + mobile) matching the example-app
  # shell. Catches the "dead <span>Users</span>" class of navigation drift.
  id: "fix #18 — admin_shell users nav + mobile bottom-nav",
  template: "priv/templates/sigra.install/admin/components/admin_shell.ex",
  example: "test/example/lib/example_web/components/admin_shell.ex",
  must_have: [
    {"users_link/1 helper defined",
     ~r/defp users_link\(/,
     ~r/defp users_link\(/},
    {"at least one href={users_link(@admin_scope)} usage",
     ~r/href=\{users_link\(@admin_scope\)\}/,
     ~r/href=\{users_link\(@admin_scope\)\}/},
    {"mobile bottom-nav Users label present",
     ~r/btm-nav-label">Users</,
     ~r/btm-nav-label">Users</}
  ],
  must_not: [
    {"dead <span>Users</span> navigation item absent",
     ~r/<li>\s*<span[^>]*>Users<\/span>\s*<\/li>/,
     ~r/<li>\s*<span[^>]*>Users<\/span>\s*<\/li>/}
  ]
}
```
Match the existing comment-on-top style, the `~r/.../` verbosity of the other fixtures, and the `must_have` / `must_not` rhythm. The exact `:id` string is Claude's Discretion — the suggestion above follows the `"fix #N — <area>"` convention already used 17 times in the file. Per D-17, do **not** add template-rendering infrastructure; regex-over-source is the right level for this phase.

---

### `test/sigra/admin/users_actions_test.exs` (test, assertion update — only if D-01 "flip in place" path chosen)

**Analog:** existing assertions at lines 253-257 using struct-field access.

**Current assertions that break on contract flip:**
```elixir
preview = Detail.recent_audit_preview(config, global_scope, user.id)

assert Enum.any?(preview, &(&1.action == "session.delete"))
assert Enum.any?(preview, &(&1.action == "session.revoke_all"))
assert Enum.all?(preview, &(&1.target_id == user.id))
```

Under Presenter rows:
- `&1.action` — still present (Presenter.present_event/2 copies `event.action` verbatim at `lib/sigra/admin/audit/presenter.ex:23`), so the first two assertions continue to pass unchanged. **Verified** by reading Presenter.
- `&1.target_id` — **not** in Presenter output (see Presenter keys list: `:id, :inserted_at, :action, :action_label, :action_badge, :actor_label, :effective_user_label, :actor_summary, :outcome`). This assertion must be rephrased as `Enum.all?(preview, &(&1.action in ["session.delete", "session.revoke_all"]))` (or equivalent), OR Phase 33 takes the D-02 fallback path and keeps the existing function + adds a new `_presented/3` helper that `load!/3` uses while the legacy function (and this test) keep the struct contract.

Planner decides based on the grep results gathered during D-02's gate — no other caller exists in `lib/`, `priv/templates/`, or `test/example/` (verified during pattern mapping), so the "flip in place" path has a one-test blast radius and is the recommended path.

---

### `test/example/test/example_web/admin_shell_test.exs` (optional one-line assertion extension — Claude's Discretion)

**Analog:** existing "renders Admin and Global" test at lines 13-34 (assertion style: `assert html =~ "<string>"`).

The existing test already asserts `html =~ "Users"` (line 31), which passed before Phase 33 because the dead `<span>Users</span>` contained the literal string "Users". To make the assertion sensitive to the Users link's **liveness** (not just the word's presence), the planner may add:
```elixir
assert html =~ "href=\"/admin/users\""
```
This mirrors the existing `assert html =~ "href=\"/admin/audit\""` assertion on line 33 of the same file. Trivial; Claude's Discretion per the CONTEXT.md "Claude's Discretion" list.

---

## Shared Patterns

### "Library owns long-lived runtime, host owns narrow seams"
**Source:** `.planning/PROJECT.md` + Phase 33 CONTEXT.md § Established Patterns.
**Apply to:** every Phase 33 file.
- `admin_shell.ex` template is **host-owned (generator-emitted)** — so the port lives under `priv/templates/sigra.install/` and its drift-guard is a regex-over-source fixture.
- `detail.ex` + `user_show_live.ex` + `presenter.ex` are **library-owned** — so the Presenter seam stays in the library and both admin surfaces (explorer, preview) call into it.

### Load + present ownership co-located in the admin query module
**Source:** `lib/sigra/admin/audit/explorer.ex:115-158`.
**Apply to:** `lib/sigra/admin/users/detail.ex` `recent_audit_preview/3`.
- Single function owns: query build, `repo.all`, `load_users`, `Presenter.present`. No LiveView ever sees a raw audit struct.

### Phase 32 "fix + guard" discipline
**Source:** `.planning/phases/32-generated-installer-admin-surface-parity/32-01-PLAN.md`, `32-02-PLAN.md`.
**Apply to:** INT-04 port.
- Every template fix ships alongside a generator test that regresses if the fix erodes. Phase 33 continues the pattern via the new `@fixtures` entry (not via a new test harness).

### Subset rendering in previews, full rendering in explorers
**Source:** CONTEXT.md § Established Patterns; decisions D-05 through D-07.
**Apply to:** `user_show_live.ex` preview section.
- Preview rows may render **fewer** Presenter fields than the explorer, but never more and never different — keeps the information scent `preview → full log` intact. If a new field is ever needed in the preview, it lands in the Presenter first.

### Fixture comment + regex rhythm
**Source:** `test/sigra/templates/installer_drift_test.exs` lines 29-266.
**Apply to:** the new `@fixtures` entry.
- Leading comment explains *why* the fixture exists (the class of regression). Regexes are specific enough to catch the fix class without being brittle. `must_have` and `must_not` coexist in the same fixture when appropriate.

## No Analog Found

None. Every Phase 33 change maps to an in-repo precedent. Per the CONTEXT.md "Specific Ideas" bullet ("every decision reuses something already shipped in v1.2"), this is the expected outcome for a "discipline test" phase.

## Metadata

**Analog search scope:**
- `priv/templates/sigra.install/admin/**`
- `test/example/lib/example_web/components/**`
- `test/example/test/example_web/**`
- `lib/sigra/admin/**`
- `test/sigra/admin/**`
- `test/sigra/templates/**`

**Files scanned / read in full:**
- `test/example/lib/example_web/components/admin_shell.ex` (208 lines)
- `priv/templates/sigra.install/admin/components/admin_shell.ex` (182 lines)
- `lib/sigra/admin/audit/explorer.ex` (184 lines)
- `lib/sigra/admin/users/detail.ex` (258 lines)
- `lib/sigra/admin/audit/presenter.ex` (56 lines — verifies D-05's `action_badge`/`action_label`/`actor_summary` key guarantees and D-07's no-other-keys constraint)
- `lib/sigra/admin/live/user_show_live.ex` (383 lines)
- `lib/sigra/admin/live/audit_user_live.ex` (261 lines — confirmed Presenter row render pattern at 115-148)
- `test/sigra/templates/installer_drift_test.exs` (323 lines — confirmed fixture shape)
- `test/sigra/admin/users_actions_test.exs` lines 220-280 (confirmed the single external caller of `recent_audit_preview/3` that D-02 cares about)
- `test/example/test/example_web/admin_shell_test.exs` (149 lines)
- `lib/sigra/admin/audit/query.ex` (38 lines — context for `subject_user_id` filter used by Detail)

**Pattern extraction date:** 2026-04-17
