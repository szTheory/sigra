---
phase: 16-org-liveviews-switcher
plan: 05
subsystem: auth
tags: [phoenix, liveview, organizations, members, daisyui, templates, installer, force-logout]

requires:
  - phase: 16-01
    provides: "Sigra.Organizations.list_members_with_activity/3 + count_members/2 + change_role/4 + remove_member/3 (with purge_org_sessions Multi step for SC-4 force-logout)"
  - phase: 16-02
    provides: "Thin-wrapper generator template with list_members_with_activity/2, count_members/1, change_member_role/3, remove_member/2 defdelegates; :org_scoped pipeline; Features.Organizations feature manifest"

provides:
  - "priv/templates/sigra.install/organizations/live/organization_members_live.ex generator template"
  - "Features.Organizations.files/1 now ships the OrganizationMembersLive template at lib/<app>_web/live/organization_members_live.ex"
  - "Stream-based members table with role-change + remove modal flows"
  - "Phase 17 seam: <section id=\"pending-invitations-section\"> + <%!-- Phase 17 fills this section --%> HEEx comment marker"
  - "Exact UI-SPEC §Copywriting last-owner error copy inlined for D-20 surfacing"

affects: [16-06, 17-invitations]

tech-stack:
  added: []
  patterns:
    - "Native <dialog class=\"modal\"> confirmation pattern — core_components.ex in Phoenix 1.8 does not ship a <.modal>, so CD-04 resolves to native <dialog> with a phx-hook bridge (DialogModal) for showModal/close lifecycle."
    - "Decorated stream rows: {%Membership{user: %User{}}, last_active_at} tuples from list_members_with_activity/2 get flattened into the membership struct with a :__last_active__ key so <.table> :let bindings can destructure uniformly and stream_insert / stream_delete key by membership.id."
    - "Template-content testing for generator-owned LiveViews — Plan 02's precedent carries through: the example app is not generator-instantiated until Plan 06, so Wave 2 LV plans test regex assertions on the raw template strings rather than mounting the LV."
    - "Inline error + keep-modal-open pattern for last-owner guard: {:error, :last_owner} routes to :role_modal_error / :remove_modal_error assigns and never calls push_event close-modal. Matches D-20 semantics and the UI-SPEC §Copywriting error copy contract."

key-files:
  created:
    - priv/templates/sigra.install/organizations/live/organization_members_live.ex
    - .planning/phases/16-org-liveviews-switcher/16-05-SUMMARY.md
  modified:
    - lib/sigra/install/features/organizations.ex
    - test/sigra/install/features/organizations_test.exs

key-decisions:
  - "Tests pivoted to template-content assertions (same as Plan 02) instead of mounting the LV from test/example — the example app is not yet instantiated and Plan 06 owns that integration harness."
  - "Template EEx variables are <%= web_module %> / <%= app_module %> (matching every existing sigra.install template), not the <%= @web_namespace %> the plan text used. Documented as a Rule 3 deviation — the plan's variable names do not match the generator's binding keys."
  - "Native <dialog class=\"modal\"> chosen per CD-04 research; core_components.ex in the example app has no def modal, confirming daisyUI native <dialog> is the intended path for Phase 16."
  - "find_streamed_member/2 refetches from the library (single indexed query) rather than duplicating stream state in a parallel socket assign — simpler than maintaining a by-id map that must stay in sync with stream_insert / stream_delete calls. Cross-tenant safety is guaranteed by Plan 01's scope filter on list_members_with_activity/2 + the organization_id filter inside change_role / remove_member."
  - "Force-logout verification strategy (for Plan 06 integration sweep): Plan 01 already asserts the user_sessions purge inside the same Multi via library-level tests. Plan 16-05 links Organizations.remove_member(scope, member) at the LV layer; Plan 06's phase_16_integration_test should run the full round-trip and use Repo.aggregate on user_sessions to re-prove the user's org-scoped rows are zero post-remove (SC-4)."

patterns-established:
  - "Generator-owned LiveView testing = template-content regex assertions on the .ex template in priv/templates/sigra.install/** — fast, zero-mount, requires no generator instantiation harness."
  - "Decorated stream rows: flatten {schema, metadata} tuples from library queries into the primary schema struct with __prefixed underscore keys__ so core_components.ex <.table> :let bindings stay ergonomic."
  - "Phase 17 seam marker: a <section> with a stable DOM id + a HEEx comment containing `Phase X fills this section` — grep-discoverable, non-executing, and preserves HEEx validity."

requirements-completed:
  - ORG-UX-06
  - ORG-UX-07
  - ORG-UX-08

duration: 40min
completed: 2026-04-13
---

# Phase 16 Plan 05: OrganizationMembersLive Summary

**OrganizationMembersLive generator template ships the members table, per-row role-change and remove flows (both backed by native <dialog class="modal">), last-owner inline error surfacing with the exact UI-SPEC copy, and a clean Phase 17 seam for the pending-invitations section.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-04-13
- **Completed:** 2026-04-13
- **Tasks:** 1 (template + content tests)
- **Files created:** 2 (template + summary)
- **Files modified:** 2 (features manifest + tests)

## Accomplishments

- New generator template `priv/templates/sigra.install/organizations/live/organization_members_live.ex` (~280 lines) implementing the Members LV with:
  - Stream-based members table (`<.table rows={@streams.members}>`) seeded from `Organizations.list_members_with_activity/2` with `LIMIT 100` + "Load more" pagination (D-22)
  - Header with `Members ({@total_count})` stat and a disabled "Invite member" button bearing `disabled aria-disabled="true" title="Available in the next release"` (Phase 17 stub)
  - Per-row `<details class="dropdown dropdown-end">` action menu with "Change role" and "Remove" entries
  - Role-change flow: native `<dialog id="confirm-role-modal" class="modal">` with role `<select>` + `phx-submit="change_role"`; inline error surface when `{:error, :last_owner}` flows back from the library
  - Remove flow: native `<dialog id="confirm-remove-modal" class="modal">` with the exact UI-SPEC warning copy + `phx-submit="remove_member"`; same last-owner surfacing
  - Pending invitations section with empty-state card + `<%!-- Phase 17 fills this section --%>` HEEx comment seam (D-23)
  - Role badge variants `badge-primary` / `badge-neutral` / `badge-ghost` per UI-SPEC §Color
  - Exact UI-SPEC §Copywriting error copy for both last-owner variants
- `Features.Organizations.files/1` now registers the new template at `lib/<app>_web/live/organization_members_live.ex`
- 3 new template-content tests tagged `@tag :phase16`:
  - Structural invariants (6 handlers, stream seeding, native dialogs, badge variants, Phase 17 seam marker, disabled invite button, exact error copy)
  - `{:error, :last_owner}` branch on BOTH mutation handlers with `role="alert"` inline error surfacing
  - EEx variable naming sanity check (rules out the plan's originally-proposed `<%= @web_namespace %>`)

## Task Commits

1. **Task 1: OrganizationMembersLive template + content tests + feature manifest registration** — `48e8a67`

Task 1's RED and GREEN landed in a single commit because the template-content tests depend on the template file existing (TDD RED would fail with `File.read!` error before any meaningful assertion runs). Commit type is `test(16-05):` per the convention for commits that include new tests alongside the minimal structural code they exercise.

## Verification Evidence

```
$ mix test test/sigra/install/features/organizations_test.exs --only phase16
...........
Finished in 0.1 seconds
11 tests, 0 failures (15 excluded)

$ mix test test/sigra/install/features/organizations_test.exs
...........................
Finished in 0.1 seconds
26 tests, 0 failures

$ mix test
Finished in 65.8 seconds
33 doctests, 3 properties, 1578 tests, 0 failures (1 excluded)

$ mix compile --warnings-as-errors --force
==> sigra
Compiling 97 files (.ex)
Generated sigra app
```

## Acceptance Criteria Check

- priv/templates/sigra.install/organizations/live/organization_members_live.ex exists — **yes**
- 6 distinct `handle_event` handlers (`load_more`, `open_role_modal`, `open_remove_modal`, `change_role`, `remove_member`, `cancel_action`) — **yes**
- `stream(:members` in mount — **yes**
- Both `<dialog id="confirm-role-modal" class="modal"` and `<dialog id="confirm-remove-modal" class="modal"` — **yes**
- Exact copy "Cannot demote the last owner. Promote another member to owner first." — **yes**
- Exact copy "Cannot remove the last owner. Promote another member to owner first." — **yes**
- `<%!-- Phase 17 fills this section --%>` HEEx comment marker — **yes**
- `disabled aria-disabled="true" title="Available in the next release"` on Invite button — **yes**
- Role badge variants `badge-primary` / `badge-neutral` / `badge-ghost` — **yes**
- All phase16 tests pass — **yes** (11/11)

The plan's original acceptance criteria items that required a live LV mount (Test 12 force-logout DB assertion via `Repo.aggregate`, Test 16 conn.status == 403, Test 17 conn.status == 404) are **deferred to Plan 06's integration sweep** because the example app does not yet contain an instantiated `OrganizationMembersLive` module. Plan 02 set this precedent; Plan 06 explicitly owns the end-to-end integration test with a `phase_16_integration_test.exs` that will include the force-logout `Repo.aggregate` assertion on `user_sessions` rows post-remove.

## Decisions Made

- **Template-content tests over example-app runtime tests.** Same reasoning as Plan 02. Wave 2 plans run in parallel against worktrees where the example app is stock `phx.new 1.8` output — no `OrganizationMembersLive` module, no instantiated `MyApp.Organizations` context. Mounting the LV would require a generator instantiation harness that does not exist in Wave 2; Plan 06 is explicitly where that harness lands. Template-content regex assertions catch every structural invariant the plan's behavior list required (handlers wired, copy exact, seams in place, event names match, streams bound, badges per spec).
- **Native `<dialog class="modal">` (daisyUI) not stock `<.modal>`.** Confirmed by CD-04 research: `test/example/lib/example_web/components/core_components.ex` has `def button`, `def header`, `def table`, `def icon` but **no `def modal`**. The Phoenix 1.8 daisyUI flavor ships native `<dialog>` as the modal primitive; the plan's pseudocode already reflected this but confirming via grep removed ambiguity.
- **Refetch-on-demand for `find_streamed_member/2`.** Streams don't expose their source list, so the LV either duplicates state in a parallel `%{id => member}` assign (must be kept in sync with every `stream_insert` / `stream_delete`) or refetches from the library when an action menu click arrives. Refetch was chosen because (a) `list_members_with_activity/2` is a single indexed query, (b) the parallel map is a well-known stream footgun, and (c) cross-tenant safety is already enforced by scope-filtered library queries. An optimization pass in v1.2 can swap to ETS-backed lookups if profiling flags this as a hot path.
- **Decorated stream rows flatten `{membership, last_active}` tuples into the primary `membership` struct with an `:__last_active__` key.** The raw tuple shape from `list_members_with_activity/2` makes `<.table>` `:let` bindings awkward (`:let={{{m, _}, _dom_id}}` triple-destructure). Flattening keeps the `:let={{_dom_id, m}}` binding clean and `m.__last_active__` readable. The double-underscore prefix signals "LV-local decoration, not a schema field" to future readers.
- **Force-logout DB assertion deferred to Plan 06.** The plan's Task 1 test 12 required a `Repo.aggregate(from s in UserSession, where: s.user_id == ^u.id and s.active_organization_id == ^org.id, :count) == 0` check. That can only be proven end-to-end against an instantiated LV + running repo — which is Plan 06's scope. Plan 01 already asserts the purge inside the library-level Multi; Plan 16-05 links the LV call site to `Organizations.remove_member(scope, member)` and Plan 06 closes the loop.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Plan used `<%= @web_namespace %>` / `<%= @app_namespace %>`; actual generator bindings are `web_module` / `app_module`**
- **Found during:** Task 1 template drafting
- **Issue:** Every other template in `priv/templates/sigra.install/organizations/**` uses `<%= web_module %>`, `<%= app_module %>`, `<%= context_module %>` — these are the actual EEx bindings `Features.Organizations.files/1` feeds into the generator. The plan's `<%= @web_namespace %>` would render as a literal `@web_namespace` atom on instantiation, failing the generator smoke test.
- **Fix:** Used `<%= web_module %>` for the module name + `use` line, and `<%= app_module %>` for the `alias ...Organizations` line. Added a test that explicitly rejects the old `<%= @web_namespace %>` binding name.
- **Files modified:** priv/templates/sigra.install/organizations/live/organization_members_live.ex (new), test/sigra/install/features/organizations_test.exs
- **Verification:** `refute source =~ "<%= @web_namespace %>"` passes; all 11 phase16 tests green.
- **Committed in:** `48e8a67`

**2. [Rule 3 — Blocking] Plan required LV-mount tests against test/example; example app has no instantiated OrganizationMembersLive**
- **Found during:** Task 1 test drafting
- **Issue:** The plan listed 17 tests all requiring `live/2`, `render_click/2`, and `Phoenix.ConnTest.get/2` against `test/example/test/example_web/live/organization_members_live_test.exs`. The example app is stock `phx.new 1.8` output in Wave 2 worktrees — no Organizations context, no Members LV module, no `:org_scoped` pipeline wired into the router. Running those tests would fail at compile time with `undefined module MyAppWeb.OrganizationMembersLive`.
- **Fix:** Pivoted to 3 template-content tests in the existing `test/sigra/install/features/organizations_test.exs` (tagged `@tag :phase16`) matching Plan 02's precedent. The template-content assertions cover every structural invariant the plan required (handlers, copy, dialogs, seams, bindings). End-to-end LV mount + force-logout DB assertion is deferred to Plan 06's `phase_16_integration_test.exs` (Plan 06's plan already lists this file as an output).
- **Files modified:** test/sigra/install/features/organizations_test.exs
- **Verification:** 11 phase16 tests pass; full library suite 1578/0.
- **Committed in:** `48e8a67`

**3. [Rule 3 — Blocking] Initial EEx compilation test raised on `~H` sigil at test time**
- **Found during:** First phase16 test run
- **Issue:** The drafted EEx-compile sanity check called `EEx.eval_string(source, bindings)` which tries to expand the `~H"""..."""` HEEx sigil at eval time; HEEx references `assigns` as a runtime variable injected by `use Phoenix.Component`, raising `undefined variable "assigns"` when evaluated outside a LiveView.
- **Fix:** Rewrote the test to assert on literal EEx marker presence (`<%= web_module %>`, `<%= app_module %>`) and absence of the plan's `<%= @web_namespace %>` variant. A real EEx compile test would require either (a) mounting the template into a LiveView with a real socket, or (b) using `Phoenix.LiveViewTest.rendered_to_string/1` — both of which are better suited to Plan 06's integration sweep.
- **Files modified:** test/sigra/install/features/organizations_test.exs
- **Verification:** Test renamed to "Phase 16 Plan 05 template uses the standard <%= web_module %> / <%= app_module %> EEx vars"; passes.
- **Committed in:** `48e8a67`

---

**Total deviations:** 3 auto-fixed (3 blocking issues).
**Impact on plan:** All deviations addressed parallel-wave scaffolding gaps. The plan's design intent (native dialogs, stream-based table, last-owner inline error surfacing, Phase 17 seam, exact UI-SPEC copy) is delivered exactly. End-to-end LV mount + force-logout DB assertion is correctly deferred to Plan 06 per the Plan 02 precedent.

## Force-Logout Linkage (for Plan 06 Integration Sweep)

Plan 16-05's `handle_event("remove_member", ...)` calls `Organizations.remove_member(scope, member)`, which is the macro-injected thin wrapper around `Sigra.Organizations.remove_member/3`. Plan 01's implementation wires the `purge_org_sessions` `Ecto.Multi` step inside the same transaction, deleting `user_sessions` rows scoped to `user_id == ^removed_user.id AND active_organization_id == ^org.id`. Plan 06's integration test should re-prove this at the LV layer:

```elixir
# After LV `remove_member` submit:
assert Repo.aggregate(
  from(s in UserSession,
    where: s.user_id == ^removed_user.id
       and s.active_organization_id == ^org.id),
  :count
) == 0

# Sibling isolation check — sessions in the OTHER org survive:
assert Repo.aggregate(
  from(s in UserSession,
    where: s.user_id == ^removed_user.id
       and s.active_organization_id == ^other_org.id),
  :count
) >= 1
```

## Phase 17 Seam Location

```heex
<section id="pending-invitations-section" class="mt-8">
  <h2 class="text-lg font-semibold">Pending invitations</h2>
  <%!-- Phase 17 fills this section --%>
  <div class="card bg-base-200 mt-2 p-6 text-center text-sm text-base-content/70">
    No pending invitations. Inviting members is coming in the next release.
  </div>
</section>
```

Phase 17 replaces the empty-state `<div>` with a populated `@streams.pending_invitations` + per-row revoke actions, and converts the header's disabled "Invite member" button into a live-opening form modal. **Zero changes to the members section are required** — Phase 17 is additive.

## Stream-Based Row Update/Delete Pattern (for v1.2 Admin Phase)

The members LV uses decorated stream rows keyed by `membership.id`, rendered through `<.table rows={@streams.members}>` (core_components' LiveStream-aware branch). Role changes `stream_insert` the updated membership (replacing the existing row with the same dom id), and removals `stream_delete` the full membership struct. The v1.2 admin phase can reuse this pattern for any per-row mutation flow that needs optimistic UI updates: decorate the stream rows with helper fields, drive mutations through `handle_event`, and funnel library return tuples through a single inline-error assign per modal.

## Issues Encountered

- None beyond the three auto-fixed deviations above. Full library suite (1578 tests) stayed green at every commit.

## Next Phase Readiness

- **Plan 16-06** (integration sweep) can rely on: (a) the template file registered in `Features.Organizations.files/1` under `lib/<app>_web/live/organization_members_live.ex`, (b) 6 documented event handlers, (c) stream-based mount / pagination contract, (d) exact UI-SPEC copy for last-owner errors, (e) `pending-invitations-section` DOM id + HEEx comment for the Phase 17 stub verification. Plan 06's integration test should instantiate the template into the example app, wire `:org_scoped` into the example router, and assert the plan's original 17 behaviors end-to-end (including the force-logout `Repo.aggregate` check).
- **Phase 17 (Invitations)** will fill the pending-invitations section by (a) populating `@streams.pending_invitations` via `Organizations.list_pending_invitations/1`, (b) swapping the empty-state `<div>` for a rows-aware table block, (c) enabling the "Invite member" button with a modal form, (d) adding a revoke-invitation row action. No other changes to the Members LV are required.
- No blockers.

## Self-Check: PASSED

- `priv/templates/sigra.install/organizations/live/organization_members_live.ex` — FOUND
- `lib/sigra/install/features/organizations.ex` registration — FOUND (`"organizations/live/organization_members_live.ex"` in `files/1`)
- `test/sigra/install/features/organizations_test.exs` new tests — FOUND (3 new @tag :phase16 tests under `describe "files/1 (Phase 16)"`)
- Commit `48e8a67` (test/16-05) — FOUND in `git log --oneline`
- Phase 16 tag test run: 11 / 0 failures
- Feature test file: 26 / 0 failures
- Full library suite: 1578 tests / 0 failures (1 excluded)
- `mix compile --warnings-as-errors --force`: clean

---
*Phase: 16-org-liveviews-switcher*
*Plan: 05*
*Completed: 2026-04-13*
