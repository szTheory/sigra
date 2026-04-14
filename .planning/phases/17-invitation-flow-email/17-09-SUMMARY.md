---
phase: 17-invitation-flow-email
plan: 09
subsystem: organizations
tags: [security, idor, cross-tenant, invitations, gap-closure]
type: gap_closure
requirements: [INV-08]
dependency_graph:
  requires:
    - "Sigra.Organizations.Invitations.revoke/3 (17-03)"
    - "Sigra.MockRepo.Behaviour one/1 callback (pre-existing)"
  provides:
    - "Cross-tenant IDOR protection on revoke/3 (closes CR-01 / INV-08)"
  affects:
    - "lib/sigra/organizations/invitations.ex"
    - "test/sigra/organizations/invitations_test.exs"
tech_stack:
  patterns:
    - "Ecto.Query.from/2 + config.repo.one/1 (scoped lookup)"
    - "Pattern-match destructure in function head (active_organization: %{id: org_id})"
    - "Enumeration-resistant error collapsing (wrong-org → :not_found)"
key_files:
  modified:
    - "lib/sigra/organizations/invitations.ex"
    - "test/sigra/organizations/invitations_test.exs"
decisions:
  - "Collapse cross-tenant hits onto {:error, :not_found} (identical to missing id) to prevent enumeration"
  - "No audit row on the :not_found branch — cross-tenant probe telemetry deferred to a future WR-04-class enhancement"
  - "Function head destructures active_organization: %{id: org_id}; scopes without an active org cleanly fall through to :unauthorized"
metrics:
  tasks_completed: 3
  files_modified: 2
  tests_added: 1
  tests_retrofitted: 5
  completed: 2026-04-14
---

# Phase 17 Plan 09: Close INV-08 Cross-Tenant IDOR in revoke/3 — Summary

**One-liner:** Scoped `Sigra.Organizations.Invitations.revoke/3` to `actor_scope.active_organization.id` via an Ecto `from` query, structurally blocking the cross-tenant IDOR surfaced by CR-01 / INV-08.

## Objective

Close the single remaining gap from `17-VERIFICATION.md`: an admin of Organization A could revoke a pending invitation belonging to Organization B because `revoke/3` looked up the row by primary key alone and enforced only the role gate (`role in [:owner, :admin]`), never asserting `inv.organization_id == actor_scope.active_organization.id`.

## What Changed

### `lib/sigra/organizations/invitations.ex` — `revoke/3`

**Before:** Unscoped lookup by primary key only.
```elixir
def revoke(config, invitation_id, %{membership: %{role: role}} = actor_scope)
    when role in @auth_roles do
  schema = config.schemas.invitation

  case config.repo.get(schema, invitation_id) do
    nil -> {:error, :not_found}
    %{accepted_at: nil, revoked_at: nil} = inv -> do_revoke(config, inv, actor_scope)
    _inv -> {:error, :not_pending}
  end
end
```

**After:** Scoped Ecto query with dual-column filter.
```elixir
def revoke(
      config,
      invitation_id,
      %{membership: %{role: role}, active_organization: %{id: org_id}} = actor_scope
    )
    when role in @auth_roles do
  schema = config.schemas.invitation

  query =
    from i in schema,
      where: i.id == ^invitation_id and i.organization_id == ^org_id

  case config.repo.one(query) do
    nil ->
      # Collapses two cases onto one response to prevent cross-tenant
      # enumeration: (a) id truly does not exist, (b) id exists in
      # another org. Per CR-01 / INV-08 gap closure.
      # No audit emission on the :not_found branch — cross-tenant
      # probes are observable via future telemetry, tracked separately.
      {:error, :not_found}

    %{accepted_at: nil, revoked_at: nil} = inv ->
      do_revoke(config, inv, actor_scope)

    _inv ->
      {:error, :not_pending}
  end
end
```

Key properties of the fix:

1. **Structural impossibility.** The `where` clause runs inside the SQL query itself. Cross-tenant ids cannot resolve — no amount of client-side tampering with the `invitation_id` parameter can bypass the org scope.
2. **Enumeration resistance.** Found-but-wrong-org collapses to the same `{:error, :not_found}` shape as a truly missing id. An attacker cannot distinguish "this id exists in another org" from "this id does not exist anywhere."
3. **Fail-safe destructure.** The function head now pattern-matches `active_organization: %{id: org_id}`. A role-authorized actor whose scope has no active organization cleanly falls through to the existing `def revoke(_config, _id, _scope), do: {:error, :unauthorized}` clause — a safe default.
4. **`do_revoke/3` untouched.** The audit emission path (`organization.invitation.revoked`) is unchanged and still records the actor's `user_id` + `invitation_id`.

### `test/sigra/organizations/invitations_test.exs`

- **Added** one regression test: *"cross-tenant: Org A admin cannot revoke Org B's pending invitation → {:error, :not_found}, Org B row untouched."* The test stubs `config.repo.one/1` to return `nil` (simulating the scoped query filtering out the Org B row) and deliberately sets no `:transact` expectation — Mox `verify_on_exit!` fails the test if the lib attempts a DB mutation, which is how we assert the Org B row remains structurally untouched.
- **Retrofitted** 5 existing revoke/3 tests (`happy path`, `admin can revoke`, `already-accepted`, `already-revoked`, `missing invitation`) from `expect(:get, fn TestInvitation, ^inv_id -> ... end)` to `expect(:one, fn %Ecto.Query{} -> ... end)`.
- **Left unchanged** the `member actor returns {:error, :unauthorized}, no DB call` test — still sets no repo expectation because the role guard rejects before any query runs.

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED | `1a17dde` test(17-09): RED — cross-tenant revoke regression + :one retrofits | Verified: 6 failures in revoke/3 describe block (lib still calls `:get`) |
| GREEN | `15cacca` fix(17-09): GREEN — scope revoke/3 lookup to actor's active org (INV-08) | Verified: 46/46 tests pass in `invitations_test.exs` |
| REFACTOR | n/a — no additional refactor needed; swept library for parallel IDOR patterns (none found) | N/A |

## Regression Sweep (Task 3)

- `rg 'config.repo.get\(schema, invitation_id\)' lib/sigra/organizations/invitations.ex` → **0 hits** (old unscoped lookup is gone).
- `rg 'config.repo.get\(' lib/sigra/organizations/invitations.ex` → 5 remaining hits, all at lines 453/454/466/467/546. Each lookup derives its id from the invitation row itself (`invitation.organization_id`, `invitation.invited_by_id`) — these are NOT client-supplied ids, so no IDOR surface. Verified by inspection of `classify_pending/3` and `fetch_org/2` paths.
- `rg 'organization.invitation.revoked' lib/sigra/organizations/invitations.ex` → 1 hit (line 706, inside `do_revoke/3`). Unchanged.
- `mix compile --warnings-as-errors` → clean (the added pattern-match destructure introduces no unused-variable warnings).
- `mix test test/sigra/organizations/invitations_test.exs` → 46/46 tests pass.
- `mix test test/sigra/` → 1685 tests, 5 failures. **All 5 failures are the pre-existing install-layout failures documented in `deferred-items.md`** (TemplatesLayoutTest, IsolationTest ×2, Features.CoreTest, GoldenDiffTest) — tracked debt from Plan 17-04 fragment file not yet registered in the install coverage map. Not regressions from this change. Re-verified by running `mix test test/sigra/organizations/invitations_test.exs` in isolation.

## Deviations from Plan

None. Plan executed exactly as written.

## Decisions Made

1. **Enumeration collapse onto `:not_found`.** Rather than returning a distinct error atom for cross-tenant hits (e.g. `:wrong_org`), we chose the stronger security property: identical error shape for "missing id" and "id in another org." Attackers cannot probe which invitation ids exist in other orgs. Trade-off: slightly worse DX for a hypothetical legitimate caller who typos the active-org switch — acceptable because such a caller would retry with a valid scope.
2. **No audit row on the `:not_found` branch.** Emitting an audit row on read-path `:not_found` would leak the same existence signal we just closed (a cross-tenant probe would now produce audit noise uniquely distinguishable from a truly-missing id). Cross-tenant probe telemetry is better delivered as a dedicated `[:sigra, :security, :cross_tenant_probe]` telemetry event on a separate code path, and that is deliberately deferred (WR-04 class work, not part of INV-08 closure). Documented inline in `revoke/3`.
3. **Pattern-match destructure over explicit assertion.** Rather than adding `if inv.organization_id != actor_scope.active_organization.id, do: {:error, :not_found}` after the query, we moved the check into the query itself (`where: i.organization_id == ^org_id`). This is structurally superior: the DB cannot return a wrong-org row even in the face of future refactors. The function-head destructure also cleanly handles scopes with no active org by falling through to `:unauthorized`.

## Threat Model Coverage

| Threat ID | Category | Mitigation Status |
|-----------|----------|-------------------|
| T-17-09-01 | Elevation of Privilege / IDOR | **MITIGATED** — scoped Ecto query with `where: i.organization_id == ^org_id` makes cross-tenant resolution structurally impossible |
| T-17-09-02 | Information Disclosure (enumeration) | **MITIGATED** — found-but-wrong-org collapses to `{:error, :not_found}`, identical to missing-id response |
| T-17-09-03 | Repudiation (audit trail) | **ACCEPTED** — `do_revoke/3` audit row unchanged for successful revokes; cross-tenant probe audit deferred to future telemetry |
| T-17-09-04 | Tampering (test mock drift) | **ACCEPTED** — `Sigra.MockRepo.Behaviour` already declared `one/1`; no behaviour change needed |

## Out of Scope / Deferred

- **Cross-tenant probe telemetry (WR-04 class).** A dedicated `[:sigra, :security, :cross_tenant_probe]` telemetry event for security teams to observe cross-tenant enumeration attempts. Not delivered here because it would partially reverse the enumeration-resistance property unless carefully designed (e.g. sampled, rate-limited, not written to the main audit table). Tracked as a follow-up enhancement.
- **Install-layout test failures.** 5 pre-existing failures in `isolation_test.exs`, `templates_layout_test.exs`, `features/core_test.exs`, `golden_diff_test.exs` are documented in `deferred-items.md` and predate this plan. Not touched here.

## Commits

| Hash | Type | Message |
|------|------|---------|
| `1a17dde` | test | RED — cross-tenant revoke regression + :one retrofits |
| `15cacca` | fix | GREEN — scope revoke/3 lookup to actor's active org (INV-08) |

## Self-Check

**Files:**
- FOUND: `lib/sigra/organizations/invitations.ex` (modified)
- FOUND: `test/sigra/organizations/invitations_test.exs` (modified)
- FOUND: `.planning/phases/17-invitation-flow-email/17-09-SUMMARY.md` (this file)

**Commits:**
- FOUND: `1a17dde` (RED)
- FOUND: `15cacca` (GREEN)

**Acceptance criteria:**
- [x] `revoke/3` function head destructures `active_organization: %{id: org_id}`
- [x] `revoke/3` body uses `from i in schema, where: i.id == ^invitation_id and i.organization_id == ^org_id` via `config.repo.one/1`
- [x] `config.repo.get(schema, invitation_id)` no longer present in `invitations.ex`
- [x] New cross-tenant regression test exists and passes
- [x] All 6 existing revoke/3 tests pass (5 retrofitted + 1 unchanged member-unauthorized test)
- [x] Full `mix test test/sigra/organizations/invitations_test.exs` green (46/46)
- [x] `mix compile --warnings-as-errors` clean
- [x] Inline comment documents enumeration-resistance rationale and audit-omission decision

## Self-Check: PASSED
