---
phase: 92-rbac-seams-b2b-02
plan: 03
subsystem: auth
tags: [rbac, scope, hydration, parity, b2b-02, role-propagation]

# Dependency graph
requires:
  - phase: 92-rbac-seams-b2b-02 (Plan 92-01)
    provides: "Sigra.Authz behaviour, role-agnostic explicit-only Organizations seam"
  - phase: 92-rbac-seams-b2b-02 (Plan 92-02)
    provides: "Reserved :role and :actor_type fields on the generated Scope struct, nullable host-owned :role storage on OrganizationMembership"
provides:
  - "Sigra.Scope.{build/3, from_opts/2, from_config/2} additive carry-through for :role and :actor_type"
  - "Sigra.Scope.Hydration.hydrate/3 derives scope.role from membership.role on successful org-active enrichment (and only there)"
  - "Sigra.Plug.PutActiveOrganization writes scope.role from membership.role on set, nil on clear, never on :not_a_member"
  - "Sigra.Plug.LoadActiveOrganization clears scope.role on all stale-pointer recovery branches; writes role from new membership on auto-reassign"
  - "Plug ↔ on_mount parity preserved end-to-end: both paths produce structurally-equal :role values"
affects: [92-04, 93-m2m-tokens]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared-seam role write: scope.role is touched at exactly two library seams (Sigra.Scope.Hydration and Sigra.Plug.PutActiveOrganization), keeping FetchSession/FetchBearer role-agnostic per Phase 92 tension #3."
    - "Role-clearing parity across stale-pointer recovery branches: every code path that synthesizes a no-org/replacement scope clears :role alongside :membership."
    - "Defensive Map.get on membership.role: tolerates pre-Plan-92-02 host membership schemas without :role and nullable role columns (Plan 92-02 made the column nullable)."
    - "Reserve-now-populate-later for :actor_type: Phase 92 carries the field through struct/2 so Phase 93 stays additive — no library code branches on it."

key-files:
  created: []
  modified:
    - "lib/sigra/scope.ex"
    - "lib/sigra/scope/hydration.ex"
    - "lib/sigra/plug/put_active_organization.ex"
    - "lib/sigra/plug/load_active_organization.ex"
    - "test/sigra/scope/build_test.exs"
    - "test/sigra/scope/hydration_test.exs"
    - "test/sigra/scope/plug_liveview_parity_test.exs"
    - "test/sigra/plug/put_active_organization_test.exs"
    - "test/sigra/plug/load_active_organization_test.exs"
    - "test/sigra/scope/hydration_impersonation_test.exs"

key-decisions:
  - "Library plug owns the :role write, host scope module remains role-agnostic. Sigra.Plug.PutActiveOrganization wraps the host's scope_module.put_active_organization/3 and applies the role write afterwards. This keeps the host scope module simple (no role wiring required), preserves the single authoritative library seam contract (T-92-08), and lets hosts customize their put_active_organization/3 freely."
  - "user_auth.ex template was NOT structurally modified. Role propagation in the LiveView mount path happens transparently via the existing hydrate_scope/2 call to Sigra.Scope.Hydration.hydrate/3. Adding a documentation-only comment would have forced a golden fixture regeneration (Phase 11 regression barrier) for zero behavioral benefit. The plug ↔ on_mount parity test gives the live regression coverage."
  - "Map.get/3 over membership.role (not %{m | role: ...}). Tolerates a membership struct without a :role key (defense-in-depth — host OrganizationMembership schemas may have :role added at any point) and a nil role value (Plan 92-02 made the column nullable + plain :string with no opinionated default). Hydration must NEVER raise."
  - "Sigra.Plug.LoadActiveOrganization role-clearing on recovery branches is a Rule 2 critical-correctness add-on, not in the plan's <files>. Without it, scope.role can leak across stale-pointer boundaries — directly violating the must-have contract that role is nil on stale-pointer branches. The 4 recovery branches (row-vanished WR-05, single-org reassign success, single-org reassign failure, zero-orgs, multi-org picker) all now clear :role; the single-org reassign success additionally writes role from the new membership."
  - "actor_type stays nil on EVERY path under Phase 92. No library code branches on it. Phase 92 tests pin this contract (3 tests in put_active_organization + 1 in hydration_test + 1 in parity_test). Phase 93 will populate it for service accounts; until then it is reserve-only."

patterns-established:
  - "Two-seam role write: scope.role is mutated at exactly two seams (Sigra.Scope.Hydration on the read path, Sigra.Plug.PutActiveOrganization on the active-org transition path). FetchSession and FetchBearer are explicitly forbidden from touching role."
  - "Role-clearing parity across stale-pointer recovery: every branch that synthesizes a no-org or replacement scope must clear :role alongside :membership. Pin in lib/sigra/plug/load_active_organization.ex and via plug ↔ on_mount parity tests."
  - "Library plug + role-agnostic host scope module: the library plug applies role updates after the host scope_module call returns, so hosts that customize put_active_organization/3 retain their customization without losing role propagation."

requirements-completed: [B2B-02]

# Metrics
duration: 28 min
completed: 2026-04-29
---

# Phase 92 Plan 03: Runtime Role Propagation Summary

**`current_scope.role` is now derived from `membership.role` only at the two shared org-enrichment seams (`Sigra.Scope.Hydration.hydrate/3` and `Sigra.Plug.PutActiveOrganization`); plug ↔ on_mount parity preserved; nil-safe on every error / zero-org / stale-pointer / userless branch; `:actor_type` reserved Phase 93 prep.**

## Performance

- **Duration:** 28 min (worktree-agent execution)
- **Started:** 2026-04-29T20:05:53Z
- **Completed:** 2026-04-29T20:34:13Z
- **Tasks:** 2 (both TDD: RED → GREEN; no REFACTOR pass needed)
- **Files modified:** 10 (4 lib + 6 test)

## Accomplishments

- `Sigra.Scope.{build/3, from_opts/2, from_config/2}` accept `:role` and `:actor_type` as additive opts, default to nil when omitted, and pass through to `struct/2`. Worker/audit scopes can carry these fields for transport without turning them into authoritative authz state.
- `Sigra.Scope.Hydration.hydrate/3` derives `scope.role` from `membership.role` on successful org-active enrichment using `Map.get/3`. Nil-org-id, nil-user, `:not_a_member`, and `:org_not_found` branches do NOT propagate a role atom.
- `Sigra.Plug.PutActiveOrganization` is the SINGLE authoritative library seam for role updates on active-org transitions: writes `scope.role` from `membership.role` on set, nil on clear, never writes on `:not_a_member`. The host scope module remains role-agnostic — the plug applies role updates AFTER calling `scope_module.put_active_organization/3`.
- `Sigra.Plug.LoadActiveOrganization` (Rule 2 add-on) now clears `:role` alongside `:membership` on every stale-pointer recovery branch. The single-org auto-reassign branch additionally writes role from the new membership — making it the recovery-path analog of the Hydration seam.
- Plug ↔ on_mount parity preserved: both paths flow through `Sigra.Scope.Hydration.hydrate/3`, so they produce structurally-equal `:role` values for the same session inputs. The dedicated parity test pins this with a host-themed role atom (`:tenant_lead`) plus full coverage of nil / stale-pointer branches.
- `:actor_type` is reserved on every path — no library code branches on it. 5 tests across the suite assert `actor_type` stays nil under Phase 92.
- 39/39 plan verification tests green. 200/200 across `test/sigra/scope/` + `test/sigra/plug/`. 193/193 organizations tests still pass. 579/579 install tests green. 2/2 install_golden_diff integration tests still pass (no template change → no golden regen required).

## Task Commits

Each task was committed atomically (TDD: RED → GREEN):

1. **Task 1 RED — failing tests for `:role` and `:actor_type` carry-through on Sigra.Scope** — `91e0c70` (test)
2. **Task 1 GREEN — extend Sigra.Scope contract with `:role` and reserved `:actor_type`** — `d1630c9` (feat)
3. **Task 2 RED — failing tests for `:role` propagation at shared org-enrichment seams** — `9950bf4` (test)
4. **Task 2 GREEN — wire `:role` propagation through shared org-enrichment seams** — `c1658d7` (feat)

The plan-completion docs commit will follow after this SUMMARY is written.

## Files Created/Modified

**Modified (lib):**

- `lib/sigra/scope.ex` — `build/3`, `from_opts/2`, `from_config/2` now read `:role` and `:actor_type` from opts/config and pass them to `struct/2`. Both fields default to nil when omitted. Updated moduledoc with the Phase 92 contract: `:role` is populated authoritatively only at the shared seams; `:actor_type` is Phase 93 reserve-only.
- `lib/sigra/scope/hydration.ex` — `do_hydrate/3` happy-path now sets `scope.role` from `membership.role` via `Map.get/3` (defensive against missing `:role` key and nil role value). Updated moduledoc to document Phase 92 role-write contract and explicitly forbid role writes from FetchSession / FetchBearer.
- `lib/sigra/plug/put_active_organization.ex` — Set path writes `scope.role` from `membership.role` after the host scope_module call returns. Clear path writes `scope.role: nil`. `:not_a_member` error path does NOT write role. Updated moduledoc to document T-92-08: this plug is the SINGLE authoritative library seam for role updates on active-org transitions.
- `lib/sigra/plug/load_active_organization.ex` (Rule 2) — All 4 stale-pointer recovery branches now clear `:role` alongside `:membership`: row-vanished WR-05 fallback, single-org reassign failure, zero-orgs, multi-org picker. Single-org auto-reassign success additionally writes role from the new membership. Updated moduledoc to document the Phase 92 role-clearing contract.

**Modified (tests):**

- `test/sigra/scope/build_test.exs` — Inline TestScope expanded to include `:role`/`:actor_type`. New describe block "Phase 92 / B2B-02 — :role and :actor_type carry-through" with 8 tests covering: defaults nil; carries `:role` from opts; carries `:actor_type` from opts; defaults to nil when other fields are supplied; both fields together; `from_opts/2` carries; `from_opts/2` defaults; `from_config/2` carries; `from_config/2` defaults.
- `test/sigra/scope/hydration_test.exs` — Inline TestScope + `build_scope/1` helper updated to include `:role`/`:actor_type`. Existing happy-path test now asserts `scope.role == :admin`. New describe block "Phase 92 / B2B-02 — :role propagation (Plan 92-03 Task 2)" with 6 tests covering: host-themed role atom (`:tenant_lead`) propagates; nil membership.role passes through; nil-org-id branch leaves role nil even with stale scope.role; nil-user branch leaves role nil; `:not_a_member` error path does not mutate scope; `:org_not_found` error path does not mutate scope; `actor_type` stays nil on happy path.
- `test/sigra/scope/plug_liveview_parity_test.exs` — Inline TestScope + `build_scope/1` helper updated. Happy-path parity test now asserts `plug_scope.role == lv_scope.role == :admin` AND actor_type stays nil on both. Nil-org-id parity test asserts role nil on both. Stale-pointer test asserts role nil on plug recovery. New host-themed role atom parity test (`:tenant_lead` propagates on both paths).
- `test/sigra/plug/put_active_organization_test.exs` — Inline TestScope updated; the test scope module's `put_active_organization/3` deliberately does NOT update `:role` itself (proves the library plug owns the role write). `build_scope/3` populates role from membership.role for clear-path pre-condition assertions. Existing happy-path test asserts `scope.role == membership.role`. Existing clear-path test asserts pre-condition + post-condition role nil. New "Phase 92 / B2B-02 — :role propagation" describe block with 4 tests: host-themed role atom write on set; nil membership.role propagation; `:not_a_member` does not write role onto scope; actor_type stays nil on set + clear paths.
- `test/sigra/plug/load_active_organization_test.exs` (Rule 3 cascade) — Inline TestScope updated to include `:role`/`:actor_type` so the library plug's role write doesn't raise KeyError on the struct update.
- `test/sigra/scope/hydration_impersonation_test.exs` (Rule 3 cascade) — Same TestScope cascade fix.

## Decisions Made

- **Library plug owns the role write; host scope module stays role-agnostic.** `Sigra.Plug.PutActiveOrganization` calls `scope_module.put_active_organization/3` first and then applies `Map.put(:role, ...)` to the returned scope. This means hosts who have customized their generated `put_active_organization/3` (e.g. to add audit metadata or invariant checks) keep their customization unchanged. The single authoritative library seam contract (T-92-08) is preserved by the plug, not by the host module.
- **`user_auth.ex` template was NOT modified.** Role propagation in the LiveView mount path happens transparently via the existing `hydrate_scope/2` call to `Sigra.Scope.Hydration.hydrate/3`. I drafted a documentation-only comment for the Phase 92 contract but reverted it: the comment would have forced a golden fixture regeneration (the install_golden_diff test is the Phase 11 regression barrier) for zero behavioral benefit. The plug ↔ on_mount parity test gives live regression coverage, so the documentation lives in the Hydration moduledoc instead.
- **`Map.get/3` (not `%{m | role: ...}`).** Membership reads use `Map.get/3` to tolerate a membership struct without a `:role` key (defense-in-depth — host OrganizationMembership schemas may have `:role` added at any point) and a nil role value (Plan 92-02 made the column nullable + plain `:string` with no opinionated default). The Hydration contract says it NEVER raises (PITFALLS O-6) and `Map.get/3` upholds that.
- **Stale-pointer role-clearing in `LoadActiveOrganization` is a Rule 2 add-on.** The plan's `<files>` doesn't list `lib/sigra/plug/load_active_organization.ex`, but the must-haves explicitly require role to be nil on stale-pointer branches. Without the role-clearing fix, `scope.role` leaks across stale-pointer recovery — defeating the contract. The 4 recovery branches (row-vanished WR-05 fallback, single-org reassign success, single-org reassign failure, zero-orgs, multi-org picker) all clear `:role`; the single-org reassign success additionally writes role from the new membership.
- **`actor_type` is reserved-only on every path.** No library code branches on `actor_type` under Phase 92. 5 tests across the suite assert it stays nil. Phase 93 will populate it for service accounts; the additive struct field reservation in Plan 92-02 makes that change non-breaking.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Critical correctness] Stale-pointer role-clearing in `Sigra.Plug.LoadActiveOrganization`**
- **Found during:** Task 2 GREEN verification.
- **Issue:** The plan's `<files>` for Task 2 lists `Sigra.Scope.Hydration` and `Sigra.Plug.PutActiveOrganization` but NOT `Sigra.Plug.LoadActiveOrganization`. The must-haves explicitly require: "current_scope.role is populated only when org-active membership enrichment succeeds, and is nil on zero-org, clear, stale-pointer, and userless branches." `LoadActiveOrganization` has 4 recovery branches that synthesize a no-org/replacement scope: row-vanished WR-05 fallback, single-org reassign failure, zero-orgs, multi-org picker, plus the single-org auto-reassign success path. None of them touched `:role`. Without role-clearing on these branches, a previously-populated `scope.role` leaks across stale-pointer recovery — directly violating the must-have contract.
- **Fix:** All 4 recovery branches now clear `:role` alongside `:membership`. The single-org auto-reassign success path additionally writes role from the new membership (this is the recovery analog of the Hydration seam — a successful selector write reaches the same end state as a successful hydrate). Updated the moduledoc to document the Phase 92 role-clearing contract.
- **Files modified:** `lib/sigra/plug/load_active_organization.ex`.
- **Verification:** All 10 `Sigra.Plug.LoadActiveOrganizationTest` tests pass.
- **Committed in:** `c1658d7` (Task 2 GREEN).

**2. [Rule 3 — Blocking] `test/sigra/plug/load_active_organization_test.exs` TestScope cascade**
- **Found during:** Task 2 GREEN broader verification.
- **Issue:** The library plug now does `%{scope | role: ...}` updates on the recovery branches. The pre-existing TestScope in `load_active_organization_test.exs` was defined as `defstruct [:user, :active_organization, :membership, :impersonating_from]` — without `:role` declared on the struct. Elixir raises `KeyError` on the struct update.
- **Fix:** Updated TestScope to include `:role` and `:actor_type` fields, mirroring the generated scope struct after Plan 92-02. The test file was not in the plan's `files_modified` list, but the breakage is a direct consequence of the contract change in `lib/sigra/plug/load_active_organization.ex` (Rule 2 fix above).
- **Files modified:** `test/sigra/plug/load_active_organization_test.exs`.
- **Verification:** All 10 `Sigra.Plug.LoadActiveOrganizationTest` tests pass.
- **Committed in:** `c1658d7` (Task 2 GREEN).

**3. [Rule 3 — Blocking] `test/sigra/scope/hydration_impersonation_test.exs` TestScope cascade**
- **Found during:** Task 2 GREEN broader verification.
- **Issue:** Same cascade — `Sigra.Scope.Hydration.do_hydrate/3` now does `%{scope | ..., role: ...}` and the inline TestScope in `hydration_impersonation_test.exs` lacks `:role`/`:actor_type` declarations.
- **Fix:** Updated TestScope to include `:role`/`:actor_type` fields.
- **Files modified:** `test/sigra/scope/hydration_impersonation_test.exs`.
- **Verification:** The single test in `Sigra.Scope.HydrationImpersonationTest` now passes.
- **Committed in:** `c1658d7` (Task 2 GREEN).

---

**Total deviations:** 3 (1 Rule 2 critical-correctness add-on, 2 Rule 3 cascade test fixes).
**Impact on plan:** All deviations are tightly scoped. The Rule 2 add-on (LoadActiveOrganization role-clearing) is required by the plan's must-haves — without it the contract is silently violated on every stale-pointer recovery. The two Rule 3 cascades are mechanical TestScope field additions; both test files were not in the plan's `<files>` list but their breakage is a direct consequence of the contract change. No scope creep into unrelated phases.

## Issues Encountered

- **None.** No DB schema changes required (Plan 92-02 made `:role` nullable on the membership table; we only read it). No new dependencies. No flaky tests. No threat-model surprises. The pre-existing `:audit` Multi step collision (DEF-92-02-01 from Plan 92-02) is unaffected by this plan.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries were introduced. Mitigation status against the Phase 92-03 threat register (T-92-07, T-92-08, T-92-09):

- **T-92-07 (T, `Sigra.Scope.Hydration`)** — Mitigated. `do_hydrate/3` populates `scope.role` only from a validated active membership. Stale/missing-org paths fail closed (return `{:error, :not_a_member | :org_not_found}`) WITHOUT touching role; nil-org-id and nil-user paths return the scope unchanged. 6 dedicated tests + 1 happy-path role assertion pin the contract.
- **T-92-08 (E, `Sigra.Plug.PutActiveOrganization`)** — Mitigated. The plug clears role when clearing membership and reuses the authoritative `Sigra.Organizations.get_membership/3` membership check before writes. The `:not_a_member` branch returns BEFORE the SessionStore + scope_module calls — verified by the existing membership-verification test, plus a new test that asserts no role write happens on this branch with a stale scope.role pre-condition.
- **T-92-09 (R, plug/live parity)** — Mitigated. Both paths flow through `Sigra.Scope.Hydration.hydrate/3`. The dedicated parity test (`Sigra.Scope.PlugLiveViewParityTest`) covers happy path, nil-org-id, stale-pointer, and host-themed role atom (`:tenant_lead`) — all 4 scenarios assert plug ↔ on_mount role parity.

No threat flags found.

## User Setup Required

None — no external service configuration required. Generated host applications get role propagation automatically: `Sigra.Plug.PutActiveOrganization` writes `scope.role` from `membership.role` on every active-org transition, and `Sigra.Scope.Hydration.hydrate/3` writes it on every authenticated request that resolves an active org. Hosts who customize their generated `put_active_organization/3` retain that customization — the library plug applies the role write afterwards.

## Next Phase Readiness

- **Plan 92-04 (RBAC recipe + golden/docs/authz verification gates)** is unblocked. The host's `Sigra.Authz.can?/3` implementation can now read `scope.role` confidently — the field is populated authoritatively at the two shared seams and is nil everywhere else. The deny-by-default recipe walks the host from `can?(_scope, _action, _resource), do: true` to per-role allow rules + a deny fall-through; `scope.role` is the host-defined atom they pattern-match on.
- **Phase 93 (M2M tokens / service accounts)** is unblocked. `:actor_type` is reserved on every path — populating it for service accounts in Phase 93 is purely additive (no breaking scope-struct change, no library code branches on it under Phase 92). `Sigra.Scope.{build,from_opts,from_config}` already pass `:actor_type` through, so login-time service-account scope synthesis lands without further library changes.
- **Phase 14 D-23 plug ↔ on_mount parity** stays intact. The shared seam contract is now stronger: both paths produce structurally-equal scopes including `:role`. The parity test gives the live regression coverage.

## Self-Check: PASSED

- [x] `lib/sigra/scope.ex` exists and contains `Keyword.get(opts, :role)` — verified via `rg`.
- [x] `lib/sigra/scope/hydration.ex` exists and contains `membership.role` — verified via `rg`.
- [x] `lib/sigra/plug/put_active_organization.ex` exists and contains `scope_module.put_active_organization` — verified via `rg`.
- [x] `priv/templates/sigra.install/core/user_auth.ex` exists and contains `Sigra.Scope.Hydration.hydrate` — verified via `rg`.
- [x] All in-scope tests pass:
  - Plan verification: `MIX_ENV=test mix test test/sigra/scope/build_test.exs test/sigra/scope/hydration_test.exs test/sigra/scope/plug_liveview_parity_test.exs test/sigra/plug/put_active_organization_test.exs` → 39/39 pass.
  - Wider scope+plug+organizations sweep: 393/393 pass.
  - Auth + api_token + account + mfa smoke: 78/78 pass.
  - Install suite (excluding integration/golden): 579/579 pass.
  - Install golden_diff (integration): 2/2 pass — user_auth.ex template was NOT modified, golden fixture untouched.
- [x] Plan verification regex: `rg -n "membership\\.role|role: nil|actor_type: nil" lib/sigra/scope.ex lib/sigra/scope/hydration.ex lib/sigra/plug/put_active_organization.ex priv/templates/sigra.install/core/user_auth.ex` returns the expected 6 matches across the 3 lib files (moduledocs + inline comments + the actual `Map.get(membership, :role)` write seams). user_auth.ex has zero matches because role propagation there is transitive via `Sigra.Scope.Hydration.hydrate/3` (documented as a key decision above).
- [x] Commits exist:
  - `91e0c70` (Task 1 RED) — verified via `git log`.
  - `d1630c9` (Task 1 GREEN) — verified via `git log`.
  - `9950bf4` (Task 2 RED) — verified via `git log`.
  - `c1658d7` (Task 2 GREEN) — verified via `git log`.

## TDD Gate Compliance

Both tasks followed RED → GREEN. Plan-level frontmatter is `type: execute` (not `type: tdd`), so the gate sequence is per-task; both per-task TDD cycles are intact in the commit log:

```
91e0c70 test(92-03): add failing tests for :role and :actor_type carry-through on Sigra.Scope            # Task 1 RED
d1630c9 feat(92-03): extend Sigra.Scope contract with :role and reserved :actor_type                     # Task 1 GREEN
9950bf4 test(92-03): add failing tests for :role propagation at shared org-enrichment seams              # Task 2 RED
c1658d7 feat(92-03): wire :role propagation through shared org-enrichment seams                         # Task 2 GREEN
```

No REFACTOR pass needed — both tasks landed clean implementations on the first GREEN.

---
*Phase: 92-rbac-seams-b2b-02*
*Completed: 2026-04-29*
