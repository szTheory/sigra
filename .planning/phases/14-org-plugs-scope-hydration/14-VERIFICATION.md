---
phase: 14-org-plugs-scope-hydration
verified: 2026-04-12T17:10:00Z
status: passed
score: 4/4 ROADMAP success criteria + 28/28 plan must-haves verified
overrides_applied: 0
deferred:
  - truth: "LoadActiveOrganization plug auto-injected into the host router pipeline by the installer"
    addressed_in: "Phase 18"
    evidence: "Phase 18 goal: '--organizations Generator Wiring … Developer upgrading a v1.0 app to v1.1 can run the upgrade … --no-organizations produces a zero-org install that compiles clean.' Plan 03 Deviation 3 explicitly defers the router-injection expansion to Phase 18."
  - truth: "Sigra.Install.Features.Organizations registered in lib/mix/tasks/sigra.install.ex @features list so generated organizations.ex template lands in host apps"
    addressed_in: "Phase 18"
    evidence: "Phase 18 generator wiring scope; Plan 03 Deviation 4 documents that Features.Organizations.files/1 returns the right template list but installer-level walker registration is left for Phase 18."
---

# Phase 14: Org Plugs + Scope Hydration — Verification Report

**Phase Goal:** Every authenticated request — Plug pipeline or LiveView — lands at its handler with `current_scope.active_organization` correctly populated, stale session pointers gracefully reset, and org-required routes blocked for non-members with a clear error.

**Verified:** 2026-04-12T17:10:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### ROADMAP Success Criteria

| #   | Success Criterion                                                                                                                                                                                                                | Status     | Evidence                                                                                                                                                                                                                             |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| SC-1 | Stale session `active_organization_id` (revoked membership / deleted org) silently resets to "no active org" instead of 500.                                                                                                    | VERIFIED   | `lib/sigra/scope/hydration.ex` returns `{:error, :not_a_member \| :org_not_found}` (never raises). `lib/sigra/plug/load_active_organization.ex` `recover_from_stale_pointer/5` clears column + reruns selector + audit. Tests in `test/sigra/scope/hydration_test.exs` (7) and `test/sigra/plug/load_active_organization_test.exs` (10). |
| SC-2 | Routes guarded by `RequireMembership` redirect to picker on missing org and to 403 on insufficient role.                                                                                                                         | VERIFIED   | `lib/sigra/plug/require_membership.ex` halts via `error_handler.auth_error(:no_active_org \| :insufficient_role)`. Generated `priv/templates/sigra.install/core/error_handler.ex` redirects `:no_active_org` to `~p"/organizations"` and renders 403 for `:insufficient_role`. 12 tests in `test/sigra/plug/require_membership_test.exs`. |
| SC-3 | LiveView `on_mount` and Plug path produce byte-identical `current_scope` for same session — parity covers login, switch, stale-pointer cases.                                                                                  | VERIFIED   | Both paths call `Sigra.Scope.Hydration.hydrate/3` (single source of truth). `test/sigra/scope/plug_liveview_parity_test.exs` (3 tests) drives identical session state through `Hydration.hydrate/3` (LV path) and `LoadActiveOrganization.call/2` (Plug path) and asserts structurally equal scopes on happy/nil/stale cases. |
| SC-4 | Login: 0 orgs → no active org (picker landing), 1 org → auto-select, 2+ → resume previous or show picker.                                                                                                                       | VERIFIED   | `lib/sigra/auth.ex` `maybe_assign_active_organization/6` calls `Sigra.Organizations.select_active_organization/3` once inside `create_session/4`, threading `:previous_active_organization_id` from opts. Selector returns `{:ok, org}` (1 or matching resume), `{:none, :zero_orgs}`, or `{:multiple, orgs}`. 9 tests in `test/sigra/auth_org_selection_test.exs` cover every branch including the fail-open T-14-13 path. |

**Score:** 4/4 success criteria verified.

### Plan must-haves rollup

| Plan | Truths verified | Notes |
| ---- | --------------- | ----- |
| 14-01 pure primitives | 10/10 | Hydration, selector, SessionStore callback + ecto impl, ErrorHandler types — all confirmed via grep + tests (50 tests in plan-scoped run). |
| 14-02 library plugs   | 10/10 | LoadActiveOrganization (never halts, stale recovery), RequireMembership (init validation, role filter, 0 DB re-queries), PutActiveOrganization (membership-before-write, no cookie write) — all confirmed (27 tests). |
| 14-03 integration & templates | 11/11 | create_session selector wiring, generated Scope/user_auth/error_handler templates, organizations.ex defdelegate, parity test, scope_module config field — all confirmed (18 tests). |

### Required Artifacts

| Artifact | Status | Wired | Evidence |
| -------- | ------ | ----- | -------- |
| `lib/sigra/scope/hydration.ex` | VERIFIED | WIRED | 2 clauses, no Repo calls, never raises (PITFALLS O-6 guard). Imported by LoadActiveOrganization + parity test + user_auth.ex template. |
| `lib/sigra/organizations.ex` (`select_active_organization/3` + `fetch_organization/2` + `__sigra_org_config__/0`) | VERIFIED | WIRED | Lines 147 / 456 / 493. Called by hydration, plugs, auth. |
| `lib/sigra/session_store.ex` (`@callback update_active_organization/3`) | VERIFIED | WIRED | Line 80 callback; Ecto impl at session_stores/ecto.ex:148/156. |
| `lib/sigra/session_stores/ecto.ex` | VERIFIED | WIRED | Two clauses (no-op short-circuit + real update), called by PutActiveOrganization + Auth + LoadActiveOrganization. |
| `lib/sigra/plug/error_handler.ex` | VERIFIED | WIRED | `:no_active_org` and `:insufficient_role` present in `@type error_type` (lines 61-62) and moduledoc (18, 22). |
| `lib/sigra/plug/load_active_organization.ex` | VERIFIED | WIRED | Calls `Sigra.Scope.Hydration.hydrate/3` + `Organizations.select_active_organization/3`; never halts (no `Plug.Conn.halt` in body); stale recovery clears + reselects + audits. |
| `lib/sigra/plug/require_membership.ex` | VERIFIED | WIRED | Halts via `error_handler.auth_error(:no_active_org)` and `(:insufficient_role)`; reads `scope.membership.role` directly (no Repo calls). |
| `lib/sigra/plug/put_active_organization.ex` | VERIFIED | WIRED | Verifies membership via `Organizations.get_membership/3` BEFORE calling `SessionStore.update_active_organization/3`; no `put_session`/`configure_session`/`renew_session`/`Repo.` calls in body. |
| `lib/sigra/auth.ex` (`create_session/4` selector wiring) | VERIFIED | WIRED | `maybe_assign_active_organization/6` (line 1037) inside `create_session` (line 1027). Fail-open via `try/rescue`/`catch`. |
| `lib/sigra/config.ex` (`scope_module` + `organizations_module`) | VERIFIED | WIRED | Schema (lines 569, 575), `@type t` (1255-1256), `defstruct` (1288-1289). |
| `priv/templates/sigra.install/core/scope.ex` (`put_active_organization/3`) | VERIFIED | WIRED | Two clauses at lines 67 + 75, joint docstring. |
| `priv/templates/sigra.install/core/user_auth.ex` (`mount_current_scope` calls hydrate/3) | VERIFIED | WIRED | Line 237 — `Sigra.Scope.Hydration.hydrate(scope, org_config, sigra_session)`. |
| `priv/templates/sigra.install/core/error_handler.ex` | VERIFIED | WIRED | `:no_active_org` clause (line 42, redirects to `~p"/organizations"` with non-blaming flash); `:insufficient_role` clause (line 49, 403 render); zero "This page requires the" leak. |
| `priv/templates/sigra.install/organizations/organizations.ex` | VERIFIED | WIRED (template emitted by `Features.Organizations.files/1`; installer-walker registration deferred to Phase 18) | `use Sigra.Organizations` + `defdelegate set_active_organization(conn, org), to: Sigra.Plug.PutActiveOrganization, as: :call`. |
| `lib/sigra/install/features/organizations.ex` | VERIFIED | PARTIAL (file exists, template registered; not yet in installer `@features` list — explicitly deferred to Phase 18 per Plan 03 Deviation 4) | files/1 populated. |
| `test/sigra/scope/hydration_test.exs` | VERIFIED | n/a | 7 tests covering all hydration branches. |
| `test/sigra/plug/load_active_organization_test.exs` | VERIFIED | n/a | 10 tests including never-halts + no-cookie-write invariants. |
| `test/sigra/plug/require_membership_test.exs` | VERIFIED | n/a | 12 tests including admin-does-not-imply-owner regression + no-DB-re-query invariant. |
| `test/sigra/plug/put_active_organization_test.exs` | VERIFIED | n/a | 5 tests including not_a_member-no-write invariant. |
| `test/sigra/auth_org_selection_test.exs` | VERIFIED | n/a | 9 tests covering 0/1/2+ + resume pointer + fail-open. |
| `test/sigra/scope/plug_liveview_parity_test.exs` | VERIFIED | n/a | 3 tests proving SC-3 parity. |

### Key Link Verification

| From | To | Via | Status |
| ---- | -- | --- | ------ |
| `lib/sigra/scope/hydration.ex` | `Sigra.Organizations.fetch_organization/2` + `get_membership/3` | direct module call | WIRED |
| `lib/sigra/plug/load_active_organization.ex` | `Sigra.Scope.Hydration.hydrate/3` | direct call (line 17, 73) | WIRED |
| `lib/sigra/plug/load_active_organization.ex` | `Sigra.Organizations.select_active_organization/3` | stale recovery (line 100) | WIRED |
| `lib/sigra/plug/load_active_organization.ex` | `SessionStore.update_active_organization/3` | clear + write (lines 96, 128) | WIRED |
| `lib/sigra/plug/put_active_organization.ex` | `Organizations.get_membership/3` | authz choke point (line 88) | WIRED |
| `lib/sigra/plug/put_active_organization.ex` | `SessionStore.update_active_organization/3` | post-authz write (lines 69, 94) | WIRED |
| `lib/sigra/plug/require_membership.ex` | `error_handler.auth_error/3` | host-injected handler (lines 92, 99) | WIRED |
| `lib/sigra/auth.ex` `create_session/4` | `Sigra.Organizations.select_active_organization/3` | inside `maybe_assign_active_organization/6` (line 1052) | WIRED |
| `priv/templates/sigra.install/core/user_auth.ex` `mount_current_scope` | `Sigra.Scope.Hydration.hydrate/3` | LiveView on_mount path (line 237) | WIRED |
| `priv/templates/sigra.install/organizations/organizations.ex` | `Sigra.Plug.PutActiveOrganization.call/2` | `defdelegate set_active_organization` | WIRED |
| `priv/templates/sigra.install/core/error_handler.ex :no_active_org` | `~p"/organizations"` | verified-route redirect | WIRED |

### Requirements Coverage

| Requirement   | Source plans | Status    | Evidence |
| ------------- | ------------ | --------- | -------- |
| ORG-SCOPE-03  | 14-01, 14-02, 14-03 | SATISFIED | `Sigra.Plug.LoadActiveOrganization` exposed; runs after fetch_current_scope; hydrates `scope.active_organization` + `scope.membership`; resets stale pointer (proven by hydration_test.exs + load_active_organization_test.exs stale-recovery tests). Pitfall O-6 mitigated. |
| ORG-SCOPE-04  | 14-02, 14-03 | SATISFIED | `Sigra.Plug.RequireMembership` exposed with `:roles` filter validated against `[:owner, :admin, :member]` universe; init raises on unknown atoms; call halts via error_handler. 12 tests. Router pipelines `:require_org` / `:require_org_owner` registered in Core feature injection. |
| ORG-SCOPE-05  | 14-03 | SATISFIED | Generated `user_auth.ex` `mount_current_scope` calls `Sigra.Scope.Hydration.hydrate/3` with the host's `__sigra_org_config__/0`. Parity test enforces byte-identical scope output vs Plug path. |
| ORG-SCOPE-06  | 14-01, 14-03 | SATISFIED | `Sigra.Organizations.select_active_organization/3` returns triadic `{:ok | :none | :multiple}`, sorted by inserted_at desc, with resume pointer matched only against user's own membership list. Wired into `create_session/4` with fail-open and `:previous_active_organization_id` opt. 9 integration tests. |

No orphaned requirements: REQUIREMENTS.md maps ORG-SCOPE-03..06 to Phase 14, and every ID appears in at least one plan's `requirements:` field.

### Anti-Patterns Found

| File | Pattern | Severity | Notes |
| ---- | ------- | -------- | ----- |
| (none in Phase 14 changes) | — | — | Pre-existing `_var` warnings in `test/sigra/rate_limiters/hammer_test.exs` are out of phase scope and pre-existed. Compile is clean (`mix compile --warnings-as-errors` passes). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Full test suite | `mix test` | `33 doctests, 3 properties, 1494 tests, 0 failures` (68.4s) | PASS |
| Compile clean | `mix compile --warnings-as-errors` | exit 0, no warnings | PASS |
| Hydrator never raises (Pitfall 2 guard) | `grep -c "get_organization!" lib/sigra/scope/hydration.ex` | 0 | PASS |
| LoadActiveOrganization never halts | `grep -c "Plug.Conn.halt" lib/sigra/plug/load_active_organization.ex` | 0 | PASS |
| PutActiveOrganization no cookie write | `grep -c "put_session\|configure_session\|renew_session" lib/sigra/plug/put_active_organization.ex` | 0 | PASS |
| PutActiveOrganization no direct Repo | `grep -c "Repo\." lib/sigra/plug/put_active_organization.ex` | 0 | PASS |
| RequireMembership no DB re-query | `grep -c "Repo\.\|Organizations\.get_membership" lib/sigra/plug/require_membership.ex` | 0 | PASS |
| ErrorHandler no role-name leak | `grep -c "This page requires the" priv/templates/sigra.install/core/error_handler.ex` | 0 | PASS |
| Hydration single source of truth | `grep -rn "Sigra.Scope.Hydration.hydrate" lib priv/templates` | 3 call sites: load_active_organization.ex, scope/plug_liveview_parity_test.exs (test), user_auth.ex template | PASS |

### Deferred Items

Items not actionable in Phase 14 because they belong to a later phase's roadmap scope.

| # | Item | Addressed in | Evidence |
| - | ---- | ------------ | -------- |
| 1 | LoadActiveOrganization plug auto-injected into the host router pipeline by the installer (currently the `:require_org` / `:require_org_owner` pipelines are registered but the `LoadActiveOrganization` plug is not yet wired into a `:browser_authenticated` block) | Phase 18 | Phase 18 goal explicitly chartered for "`--organizations` Generator Wiring … upgrade with or without backfill … `--no-organizations` produces a zero-org install that compiles clean." Plan 03 Deviation 3 documents the architectural reason (no router.ex template; `Features.Organizations` not yet in `@features`). |
| 2 | `Sigra.Install.Features.Organizations` added to `lib/mix/tasks/sigra.install.ex @features` list so the new `organizations.ex` template lands in installed host apps | Phase 18 | Phase 18 generator-wiring scope; Plan 03 Deviation 4 documents that the per-file template list and feature-module-level tests are in place but installer-walker registration is Phase 18's contract. |

These deferrals do NOT block Phase 14's goal because:
- The library-side primitives, plugs, generated templates, and parity test all ship and are green.
- The picker UI lives in Phase 16, and the router auto-wiring in Phase 18 — both are downstream phases that sit on top of Phase 14's library surface.
- Host apps that wire `LoadActiveOrganization` into their router manually (or that get the router auto-injection in Phase 18) get the full Phase 14 behavior without library-side changes.

### Human Verification Required

None. Every Phase 14 success criterion is automatically tested:

- SC-1 stale-pointer reset: covered by `hydration_test.exs` + `load_active_organization_test.exs` stale-recovery tests.
- SC-2 redirect / 403 behavior: covered by `require_membership_test.exs` + `install/features/organizations_test.exs` (asserts exact UI-SPEC copy).
- SC-3 plug ↔ LV parity: covered by `plug_liveview_parity_test.exs` (3 tests).
- SC-4 0/1/2+ login: covered by `auth_org_selection_test.exs` (9 tests).

Visual / UX verification of the picker landing page is correctly scoped to Phase 16 (Org LiveViews + Switcher).

### Gaps Summary

**No gaps.** All four ROADMAP success criteria are verified, every plan must-have is satisfied with tests + code, every key link is wired, and the four ORG-SCOPE-03..06 requirements are SATISFIED. The two deferred items (router auto-injection of `LoadActiveOrganization` and installer registration of `Features.Organizations`) are explicitly chartered for Phase 18 and are documented as such in Plan 03's deviations.

`mix test` reports **1494 tests passing, 0 failures** — confirming the wave 3 subagent's claim. `mix compile --warnings-as-errors` is clean.

---

_Verified: 2026-04-12T17:10:00Z_
_Verifier: Claude (gsd-verifier)_
