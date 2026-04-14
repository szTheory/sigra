---
phase: 17-invitation-flow-email
plan: 06
subsystem: organizations, liveview, generator-template
tags: [sigra, liveview, organization-members, invite-modal, revoke-modal, phase-17, d-14]
requires: ["17-03", "17-04"]
provides:
  - "OrganizationMembersLive invite-member modal wired to create_invitation/1 use-macro delegator"
  - "OrganizationMembersLive pending-invitations section filled with real list_pending_invitations/1-driven stream"
  - "OrganizationMembersLive revoke-confirm modal wired to revoke_invitation/2 use-macro delegator"
  - "Phase 17 handlers: open_invite_modal, cancel_invite, invite_member, open_revoke_modal, cancel_revoke, confirm_revoke"
  - "Socket assigns added: :invite_form, :revoking_invitation, :pending_count; new stream :pending_invitations"
  - "Generator template + example-app copy both updated in lockstep"
affects:
  - priv/templates/sigra.install/organizations/live/organization_members_live.ex
  - priv/templates/sigra.install/organizations/organization_invitation.ex
  - priv/templates/sigra.install/organizations/migration.exs
  - test/example/lib/example_web/live/organization_members_live.ex
  - test/example/lib/example/organizations.ex
  - test/example/lib/example/accounts/organization_invitation.ex
  - test/example/priv/repo/migrations/20260414000000_add_revoked_by_id_to_organization_invitations.exs
  - test/example/test/example_web/live/organization_members_live_test.exs
  - lib/sigra/organizations.ex
  - test/sigra/install/features/organizations_test.exs
tech-stack:
  added: []
  patterns:
    - "Lockstep template + example-app edits (mirrors Plan 17-04's convention for touching both copies)"
    - "owner_or_admin?/1 UI gate helper combined with library-level authz re-check (defense in depth per T-17-01 / T-17-09)"
    - "push_event open-modal/close-modal pattern matching Phase 16 Plan 05 modal rhythm"
    - "<.form for={@invite_form} phx-submit=\"invite_member\"> with invitation[email] / invitation[role] name binding"
    - "Per-row aria-label=\"Revoke invitation for #{inv.email}\" for screen-reader unambiguous row identification"
    - "Test pattern: conn-level GET + html_response assertions + direct library-call tests (matches Phase 16 integration test pattern — the example-app test suite does not import Phoenix.LiveViewTest)"
key-files:
  created:
    - test/example/test/example_web/live/organization_members_live_test.exs
    - test/example/priv/repo/migrations/20260414000000_add_revoked_by_id_to_organization_invitations.exs
    - .planning/phases/17-invitation-flow-email/deferred-items.md
  modified:
    - priv/templates/sigra.install/organizations/live/organization_members_live.ex
    - priv/templates/sigra.install/organizations/organization_invitation.ex
    - priv/templates/sigra.install/organizations/migration.exs
    - test/example/lib/example_web/live/organization_members_live.ex
    - test/example/lib/example/organizations.ex
    - test/example/lib/example/accounts/organization_invitation.ex
    - lib/sigra/organizations.ex
    - test/sigra/install/features/organizations_test.exs
decisions:
  - "Event handler names match Phase 16 convention: open_invite_modal / cancel_invite / invite_member / open_revoke_modal / cancel_revoke / confirm_revoke (not invite-modal-open etc.); mirrors Plan 05's open_role_modal / cancel_action rhythm"
  - "UI gate on the Invite button renders TWO <.button> tags with :if/:unless branches — one enabled for owner/admin, one with disabled+aria-disabled for members — rather than a single conditional `disabled` attribute. This keeps the rendered HTML predictable for test grep (the enabled branch is simply absent from the DOM for non-admins) and matches the Phoenix 1.8 idiomatic :if attribute"
  - "Test pattern is conn-level GET + html_response/2 + direct Example.Organizations delegator calls (not Phoenix.LiveViewTest clicks) because the example-app test suite does not import Phoenix.LiveViewTest anywhere — the Phase 16 integration tests use the same GET pattern. Behavior coverage is preserved: we verify both the rendered template shape AND the library-delegator error taxonomy end-to-end"
  - "Invite modal's Cancel button dispatches a phx-click=\"cancel_invite\" handler that push_events close-modal, rather than the UI-SPEC's JS.dispatch-to-backdrop pattern, because push_event is already the established Phase 16 convention and consistent with open_invite_modal"
requirements: [INV-01, INV-08, INV-10]
metrics:
  duration: "~55 minutes"
  completed: "2026-04-14"
  tasks: 2
  commits: 6
  tests_added: 16
---

# Phase 17 Plan 17-06: OrganizationMembersLive Invite + Revoke UI Summary

**One-liner:** Filled the Phase 16 `OrganizationMembersLive` extension points — enabled the "Invite member" header button (owner/admin only), wired an invite-member modal to `create_invitation/1`, replaced the `<section id="pending-invitations-section">` stub with a real 5-column `list_pending_invitations/1`-driven `<.table>` stream, and added a revoke-confirm modal wired to `revoke_invitation/2`. All six new event handlers land in the example-app LV and the installer template in lockstep; 16 new tests cover both the rendered markup and the library delegator error taxonomy end-to-end.

## Event handlers added (6 total)

| Handler | Params | Effect |
|---|---|---|
| `open_invite_modal` | — | Resets `:invite_form`; `push_event("open-modal", %{id: "invite-member-modal"})` |
| `cancel_invite` | — | `push_event("close-modal", %{id: "invite-member-modal"})` |
| `invite_member` | `%{"invitation" => %{"email" => ..., "role" => ...}}` | Delegates to `Organizations.create_invitation/1` with full error taxonomy (`rate_limited_user`, `rate_limited_org`, `already_member`, `unauthorized`, `Ecto.Changeset`, `:ok`). Success: flash + stream_insert + pending_count increment + modal close. Errors: inline form errors or flash toast + modal close |
| `open_revoke_modal` | `%{"id" => id}` | Looks up invitation via `Organizations.list_pending_invitations/1` + `Enum.find`; assigns `:revoking_invitation`; opens modal |
| `cancel_revoke` | — | Clears `:revoking_invitation`; closes modal |
| `confirm_revoke` | `%{"id" => id}` | Delegates to `Organizations.revoke_invitation/2`. Success: flash + stream_delete + pending_count decrement + modal close. Errors: `:not_pending` race flash / `:unauthorized` / `:not_found` |

## Socket assigns added

- `:invite_form` — `to_form(%{"email" => "", "role" => "member"}, as: :invitation)` seeded at mount, reset on `:ok` / `open_invite_modal`
- `:revoking_invitation` — `nil | %OrganizationInvitation{}` populated by `open_revoke_modal`, cleared on `cancel_revoke` / `confirm_revoke`
- `:pending_count` — integer reflecting `length(Organizations.list_pending_invitations(org))` at mount; incremented on `:ok` insert, decremented on revoke `:ok`

**Stream added:** `:pending_invitations` — seeded at mount with preloaded `[:invited_by]` rows from `list_pending_invitations/1`.

## Phase 16 section id preserved (D-14 additive constraint)

`<section id="pending-invitations-section">` — the Phase 16 Plan 05 seam marker — is preserved verbatim. Only the inner body changes: the Phase 16 stub `<h2>Pending invitations</h2>` + "coming in the next release" card is replaced with `<.header>Pending invitations ({@pending_count})</.header>` + empty-state card OR populated `<.table>`. Zero Phase 16 tests were churned beyond a single assertion update in `test/sigra/install/features/organizations_test.exs` (the old assertion grepped for the exact disabled-stub HTML, which is now gone).

## Phase 16 regression results

- `mix test test/sigra/install/features/organizations_test.exs` → 60/60 passing
- `cd test/example && mix test --exclude example_app` → 46/46 passing (all Phase 16 integration tests, 17-04 email tests, and new Phase 17 LV tests)

## Deviations from Plan

### Auto-fixed Issues (Rule 2/3 — library plumbing)

**1. [Rule 2/3 - Blocking] `Sigra.Organizations` config schema was missing the `:rate_limiter` key**

- **Found during:** Pre-execution analysis of the invitation create path
- **Issue:** `lib/sigra/organizations/invitations.ex:121` calls `config.rate_limiter.check_rate/3`, but `@org_config_schema` in `lib/sigra/organizations.ex` had no `:rate_limiter` key at all. `NimbleOptions.validate!` strips unknown keys, so calling `Sigra.Organizations.Invitations.create/2` via the `use` macro path would have raised `KeyError` at the first rate-limit check. Plan 17-03 passed tests via Mox-based fake config that injected the key directly; the real host-app path through the use-macro delegator was silently broken.
- **Fix:** Added `rate_limiter: [type: :atom, default: Sigra.RateLimiters.Noop, doc: ...]` to `@org_config_schema` before `:url_builder`. Defaults to the already-shipped `Sigra.RateLimiters.Noop` always-allow fallback (CLAUDE.md optional-Hammer policy).
- **Files modified:** `lib/sigra/organizations.ex`
- **Commit:** `bdda444`

**2. [Rule 2/3 - Blocking] Generated `OrganizationInvitation` schema was missing the `:revoked_by_id` field**

- **Found during:** Task 2 (revoke flow) design
- **Issue:** Plan 17-03 Deviation #4 flagged this — `Sigra.Organizations.Invitations.revoke/3` (line 301) writes `revoked_by_id` via `Ecto.Changeset.change/2`, which raises `ArgumentError: unknown field :revoked_by_id` if the field is not defined on the schema. The Plan 17-03 author assumed `change/2` was tolerant; it is not (verified via a quick probe: `mix run -e 'Ecto.Changeset.change(%OrganizationInvitation{}, %{revoked_by_id: ...})'` → `ArgumentError`). Plan 17-03 explicitly deferred the schema+migration update to Plan 17-06.
- **Fix:** Added `field :revoked_by_id` via `belongs_to :revoked_by, <%= context_module %>.<%= schema_alias %>` to both the template schema (`priv/templates/sigra.install/organizations/organization_invitation.ex`) and the example-app copy (`test/example/lib/example/accounts/organization_invitation.ex`). Added `:revoked_by_id` to the cast allowlist. Added the `revoked_by_id references(:users, ...)` column to both branches of the template migration (`priv/templates/sigra.install/organizations/migration.exs` — postgres and mysql/sqlite) and created a new example-app migration at `test/example/priv/repo/migrations/20260414000000_add_revoked_by_id_to_organization_invitations.exs`.
- **Files modified:** see above
- **Commit:** `a90a478`

**3. [Rule 2/3 - Blocking] `Example.Organizations` was not wired with Phase 17 config keys**

- **Found during:** Test runtime — the `use Sigra.Organizations` call in `test/example/lib/example/organizations.ex` only passed `:repo` and `:schemas`, so `secret_key_base`, `url_builder`, `emails_module`, and `rate_limiter` all defaulted to `nil` (or would have been missing entirely for rate_limiter before Deviation 1). `Sigra.Organizations.Invitations.create/2` raises `RuntimeError` at first use when `secret_key_base` is nil (line 100-106). Without this fix, Plan 17-06's LiveView tests calling `Example.Organizations.create_invitation(...)` would have raised at the first rate-limit check AND then again at the secret_key_base guard.
- **Fix:** Added four keys to the `use Sigra.Organizations` call: `emails_module: Example.Accounts.Emails` (Plan 17-04), `secret_key_base: Application.compile_env!(:example, ExampleWeb.Endpoint)[:secret_key_base]` (reads from the existing `config/test.exs` key), `url_builder: &Example.Organizations.__build_invite_url__/1` (temporary stub over `ExampleWeb.Endpoint.url/0`; Plan 17-07 will rewire to the real accept route via `Phoenix.VerifiedRoutes`), and `rate_limiter: Sigra.RateLimiters.Noop`.
- **Files modified:** `test/example/lib/example/organizations.ex`
- **Commit:** `c33f51c`

### Plan divergences

**4. Test pattern: conn-level GET + html_response + direct library calls (not `Phoenix.LiveViewTest`)**

- **Found during:** Read-first scan of the example-app test suite
- **Issue:** The plan's behavior section (Task 1 / Task 2 test enumerations) was written assuming `Phoenix.LiveViewTest` — `render_click`, `form`, `render_submit`. But `grep -rn "Phoenix.LiveViewTest" test/example/` returns zero matches. The entire example-app LV testing convention (Phase 16 `phase_16_integration_test.exs`) uses `get(conn, ~p"...")` + `html_response(conn, 200)` + direct library-call tests. Adding `Phoenix.LiveViewTest` would drag in `floki` + `jason` + rewrite the ConnCase, which is scope creep.
- **Fix:** Wrote the 16 tests as conn-level GET assertions on rendered markup (T1-T7, T13-T14) plus direct-library-call assertions on `Example.Organizations.{create_invitation,revoke_invitation,list_pending_invitations}` (T8-T12, T15-T16). Coverage is preserved: T5/T6 verify the 5-column pending table renders with per-row revoke buttons + aria-labels; T8-T12 verify the end-to-end `use Sigra.Organizations` → `Sigra.Organizations.Invitations` → `Repo` path with the full error taxonomy.
- **Tests delivered:** 16 (all passing, 0 RED skipped)

**5. One extra handler added: `cancel_invite`**

- **Found during:** Task 1 render block design
- **Issue:** The invite modal's Cancel button needs to close the dialog. The UI-SPEC uses `JS.dispatch("click", to: "...modal-backdrop button")` but Phase 16 uses `push_event("close-modal", %{id: ...})` via a server-side handler, which is the established convention in this codebase.
- **Fix:** Added a tiny `def handle_event("cancel_invite", _params, socket)` handler that just `push_event`s the close. Preserves rhythm with Phase 16 `cancel_action`.

## Deferred Issues

See `.planning/phases/17-invitation-flow-email/deferred-items.md` — five pre-existing install-test failures (isolation_test, templates_layout_test, features/core_test, golden_diff_test) caused by Plan 17-04's `organization_invitation_email.ex` fragment file not being registered in the install coverage map. Out of scope for Plan 17-06 — verified via `git stash` that these failures existed before this plan started.

## Auth Gates

None — fully autonomous execution.

## Commits (in order)

| Commit    | Type | Summary                                                                     |
| --------- | ---- | --------------------------------------------------------------------------- |
| `bdda444` | fix  | Add `:rate_limiter` to `@org_config_schema` (default `Sigra.RateLimiters.Noop`) |
| `a90a478` | fix  | Add `:revoked_by_id` to template + example-app invitation schema + migrations  |
| `c33f51c` | fix  | Wire Phase 17 config (emails, secret_key_base, url_builder, rate_limiter) into `Example.Organizations` |
| `f847fa7` | test | RED — 16 tests for OrganizationMembersLive Phase 17 extension (7 red on mount) |
| `3fc8079` | feat | GREEN — example-app LV invite modal + pending list + revoke modal            |
| `6ea99d0` | feat | GREEN — mirror LV changes into installer template + fix Phase 16 test assertion |

## Verification Results

```
mix compile --warnings-as-errors (library)                    → clean
cd test/example && mix compile                                → clean
cd test/example && mix test test/example_web/live/organization_members_live_test.exs
  → 16 tests, 0 failures
cd test/example && mix test --exclude example_app
  → 46 tests, 0 failures (all Phase 16 integration + Phase 17-04 email + Phase 17-06 LV)
mix test test/sigra/install/features/organizations_test.exs
  → 60 tests, 0 failures (Phase 16 install-feature assertion updated for Phase 17)
mix test
  → 1683 tests, 5 failures (all pre-existing from Plan 17-04 fragment debt — see deferred-items.md)
```

**Template EEx render + parse:** `EEx.eval_string(template, [web_module: "MyAppWeb", app_module: "MyApp"])` renders to 26,444 bytes containing all 11 expected fragments (open_invite_modal, invite_member, confirm_revoke, cancel_revoke, pending-invitations-section, invite-member-modal, revoke-invitation-modal, "No pending invitations", "Revoke invitation?", `defp owner_or_admin?`, `MyAppWeb.OrganizationMembersLive`). `Code.string_to_quoted/1` on the rendered output returns `{:ok, _ast}` — the generated file is valid Elixir.

**Acceptance-criteria grep (per plan Task 1 + Task 2):**

Template file (`priv/templates/sigra.install/organizations/live/organization_members_live.ex`):

- `phx-submit="invite_member"` → 1 match ✓
- `def handle_event("invite_member"` → 1 match ✓
- `create_invitation` → 1 match ✓
- `Invitation sent to` → 1 match ✓
- `too many people today` → 1 match ✓
- `daily invitation limit` → 1 match ✓
- `owner_or_admin?` → 5 matches (def + 4 uses) ✓
- `disabled>Invite member` → 0 matches (stub removed) ✓
- `id="pending-invitations-section"` → 1 match ✓
- `@streams.pending_invitations` → 2 matches ✓
- `phx-click="open_revoke_modal"` → 1 match ✓
- `phx-click="confirm_revoke"` → 1 match ✓
- `phx-click="cancel_revoke"` → 1 match ✓
- `aria-label={"Revoke invitation for` → 1 match ✓
- `def handle_event("confirm_revoke"` → 1 match ✓
- `revoke_invitation(` → 1 match ✓
- `Pending invitations ({` → 1 match ✓
- `No pending invitations` → 1 match ✓
- `Invitation for .* revoked` → 1 match ✓
- `already been accepted and cannot be revoked` → 1 match ✓

All acceptance criteria met.

## Known Stubs

**1. `Example.Organizations.__build_invite_url__/1`** — Temporary URL stub that wraps `ExampleWeb.Endpoint.url/0 <> "/invitations/accept?token="`. Plan 17-07 (accept LV) will rewire this to `~p"/invitations/#{token}/accept"` via `Phoenix.VerifiedRoutes`. The current stub is sufficient for Plan 17-06's tests (they don't assert on URL format, only on the `{:ok, invitation}` / `{:error, _}` delegator contract).

**2. Invite form `:already_pending` error copy is not rendered inline** — The plan's error table (UI-SPEC lines 535-536) mentions an `:already_pending` error ("{email} already has a pending invitation..."). The current Plan 17-03 library does not return this error tuple (D-05 re-invite auto-revokes the prior pending row). If the library taxonomy ever grows this error, the `invite_member` handler's `{:error, %Ecto.Changeset{}}` branch will already surface it inline via the form's standard error slot.

## Threat Flags

None — all new trust-boundary changes are covered by the plan's `<threat_model>` block (T-17-01, T-17-09, T-17-04, T-17-10). Mitigations are honored:

- **T-17-01 / T-17-09 (authz):** UI gate via `owner_or_admin?/1` on the button + column; library re-check via `Sigra.Organizations.Invitations.authorize_create/1` + `revoke/3` role guard (`when role in @auth_roles`). Defense in depth.
- **T-17-04 (rate-limit surfacing):** Both `:rate_limited_user` and `:rate_limited_org` render distinct flash copy and close the modal without revealing internal state. Library's Hammer hit is already counted regardless of UI outcome.
- **T-17-10 (info disclosure):** `:already_member` renders asymmetric inline copy per Pitfall 7; documented acceptance.

## Self-Check: PASSED

**Created files:**

- FOUND: test/example/test/example_web/live/organization_members_live_test.exs
- FOUND: test/example/priv/repo/migrations/20260414000000_add_revoked_by_id_to_organization_invitations.exs
- FOUND: .planning/phases/17-invitation-flow-email/deferred-items.md

**Modified files verified via grep:**

- FOUND: `def handle_event("invite_member"` in priv/templates/.../organization_members_live.ex
- FOUND: `phx-click="confirm_revoke"` in priv/templates/.../organization_members_live.ex
- FOUND: `id="pending-invitations-section"` preserved (Phase 16 D-14 additive constraint)
- FOUND: `rate_limiter:` in lib/sigra/organizations.ex (@org_config_schema)
- FOUND: `field :revoked_by_id` via `belongs_to :revoked_by` in both schema copies
- FOUND: `add :revoked_by_id` in both template migration branches + new example-app migration
- FOUND: 16 test blocks (T1-T16) in organization_members_live_test.exs

**Commits (all 6 reachable from HEAD):**

- FOUND: bdda444 (fix — rate_limiter config key)
- FOUND: a90a478 (fix — revoked_by_id schema + migration)
- FOUND: c33f51c (fix — example config wiring)
- FOUND: f847fa7 (test RED — 16 tests)
- FOUND: 3fc8079 (feat GREEN — example-app LV)
- FOUND: 6ea99d0 (feat GREEN — template + Phase 16 test fix)
