---
phase: 32-generated-installer-admin-surface-parity
plan: 01
subsystem: installer
tags: [generator, installer, admin, eex, router, impersonation, audit-export, phoenix]

# Dependency graph
requires:
  - phase: 28-user-operations-surface
    provides: Sigra.Admin.Live.UsersIndexLive + UserShowLive LiveViews (library-owned)
  - phase: 29-secure-impersonation
    provides: Sigra.Impersonation.start/5 + stop/4 API, UserAuth.begin_/restore_impersonation helpers, admin impersonation controller in example app
  - phase: 30-audit-exploration-and-export
    provides: Sigra.Admin.Audit.Export.csv/3 + subject_csv/4, admin/audit_export_controller.ex template (previously orphaned)
provides:
  - Emission of priv/templates/sigra.install/admin/impersonation_controller.ex (new) and admin/audit_export_controller.ex (existing) to host lib/<app>_web/controllers/admin/ via Sigra.Install.Features.Admin.files/1
  - Router template mounts for Elixir.Sigra.Admin.Live.UsersIndexLive (/admin/users, /users) and UserShowLive (/admin/users/:id, /users/:id) in both global and organization-scoped live_session blocks
  - Generator test assertions that fail loudly on regression for all three INT fixes (INT-01/02/03)
  - 5-rule EEx substitution parameterization enforced by refute content =~ "Example" and assertion of :not_allowed -> :not_found enumeration-prevention mapping
affects: [32-02 runtime smoke probe, future host-app installs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "5-rule EEx substitution table for admin controllers (web_module, app_module, context_module, context_module.Scope, app_module.Organizations)"
    - "alias <%= context_module %> bare + post-alias Accounts.get_user! usage (D-02)"
    - "Admin-implies-organizations convention: no <%= if organizations? do %> guards on admin routes or controllers (D-03)"
    - "TDD RED -> GREEN at plan level with atomic per-task commits"

key-files:
  created:
    - priv/templates/sigra.install/admin/impersonation_controller.ex
  modified:
    - lib/sigra/install/features/admin.ex
    - priv/templates/sigra.install/admin/router_injection.ex
    - test/sigra/install/features/admin_test.exs

key-decisions:
  - "D-01: Enumeration-prevention preserved verbatim from example controller -- {:error, :not_allowed} maps to AuthErrorHandler.auth_error(:not_found, []), NOT :forbidden. Asserted by test preserves enumeration-prevention mapping."
  - "D-02: alias <%= context_module %> bare with post-alias Accounts.get_user!/sigra_config usage, matching example controller convention. Diverges from audit_export_controller.ex (which uses alias <%= app_module %>.Accounts); the Plan 01 convention for impersonation follows the example controller exactly to avoid gratuitous parameterization drift."
  - "D-03: Admin controllers and router mounts have no <%= if organizations? do %> guards -- admin implies organizations by existing template convention. Both live_session blocks and all four new live mounts unconditionally emit."
  - "D-04: coverage_test.exs @known_drift for Sigra.Install.Features.Admin stays []. audit_export_controller.ex moves OUT of orphan territory by being registered in files/1, NOT by allowlist expansion. This preserves drift-detection purpose per 32-RESEARCH.md Pitfall 2."

patterns-established:
  - "5-rule EEx substitution table: Example -> web_module, ExampleWeb -> web_module, Example.Accounts -> context_module, Example.Accounts.Scope -> context_module.Scope, Example.Organizations -> app_module.Organizations"
  - "Generator test render+grep guard: File.read! + EEx.eval_string + refute content =~ \"Example\" rejects any future parameterization regression"
  - "Paired RED+GREEN commits per task keep TDD gates auditable in git log"

requirements-completed: [USER-01, USER-02, USER-03, USER-04, IMPR-01, IMPR-03, IMPR-05, AUD-04]

# Metrics
duration: ~12 min
completed: 2026-04-17
---

# Phase 32 Plan 01: Generated Installer Admin Surface Parity Summary

**Installer now emits the 3 CRITICAL v1.2 admin surface templates (impersonation controller, audit export controller registration, and two admin user LiveView router mounts in both global and org-scoped blocks) so a fresh `mix sigra.install` host app ships a functional admin surface.**

## Performance

- **Duration:** ~12 min of active execution (plus one-time `mix deps.get` bootstrap for the worktree)
- **Started:** 2026-04-17T14:20:00Z
- **Completed:** 2026-04-17T14:32:27Z
- **Tasks:** 2 (each with paired RED and GREEN commits = 4 commits total)
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- **INT-01 closed:** `priv/templates/sigra.install/admin/router_injection.ex` now mounts `Elixir.Sigra.Admin.Live.UsersIndexLive` and `UserShowLive` in both the `:admin_global` (`/admin/users`, `/admin/users/:id`) and `:admin_organization` (`/users`, `/users/:id`) `live_session` blocks. Positioned in URL-shape alphabetical order between AuditIndexLive and AuditUserLive to keep diff surgical.
- **INT-02 closed:** New `priv/templates/sigra.install/admin/impersonation_controller.ex` (148 lines, ≥ 130 min) mirrors the example controller verbatim modulo the 5-rule EEx substitution table. Sudo-fresh gate (`@sudo_window 300`), `safe_return_to` open-redirect guard, dual-actor restore via `UserAuth.restore_impersonation`, and `:impersonator_user_token` session pivot all preserved. Zero literal `Example`/`ExampleWeb` tokens (asserted by `refute content =~ "Example"`).
- **INT-03 closed:** `admin/audit_export_controller.ex` (previously orphaned — on disk, not emitted) now ships in `Sigra.Install.Features.Admin.files/1` alongside `impersonation_controller.ex`. `test/sigra/install/features/coverage_test.exs @known_drift` for Admin stays `[]` — the file moves out of orphan territory by being registered, not allowlisted.
- **T-IMPR-ESCALATION mitigation preserved verbatim:** `{:error, :not_allowed} -> AuthErrorHandler.auth_error(:not_found, [])` mapping copied from example controller. New generator test `preserves enumeration-prevention mapping (:not_allowed -> :not_found)` greps both the match arm and the auth_error call so a future "improvement" to `:forbidden` would fail loudly.
- **Generator-side regression coverage:** 9 new assertions across 2 new describe blocks and 3 existing blocks in `admin_test.exs` (12 tests added total). Every Phase 32 emission is now mechanically verified — any future regression fails `mix test test/sigra/install/features/admin_test.exs` immediately.

## Task Commits

Each task was committed atomically with paired RED + GREEN gates per TDD:

1. **Task 1 RED: failing tests for impersonation_controller template + files/1 emissions** — `02e3f84` (test)
2. **Task 1 GREEN: emit impersonation + audit_export controllers from installer** — `d33cc4c` (feat)
3. **Task 2 RED: failing tests for UsersIndexLive/UserShowLive router mounts** — `1b046a1` (test)
4. **Task 2 GREEN: mount UsersIndexLive + UserShowLive in admin router template** — `c05c151` (feat)

**Plan metadata (SUMMARY.md):** to be committed after this file lands — per worktree protocol, the final metadata commit covers SUMMARY.md only; STATE.md and ROADMAP.md are owned by the orchestrator.

## Files Created/Modified

- `priv/templates/sigra.install/admin/impersonation_controller.ex` (**CREATED**, 148 lines) — EEx template for host `<%= web_module %>.Admin.ImpersonationController`. Mirrors `test/example/lib/example_web/controllers/admin/impersonation_controller.ex` with 5-rule EEx substitutions. Contains both `create/2` (sudo-fresh + `Sigra.Impersonation.start/5` + `UserAuth.begin_impersonation/3`) and `delete/2` (dual-actor restore via `UserAuth.restore_impersonation/1`). Preserves `@sudo_window 300`, `safe_return_to/1` open-redirect guard (`String.starts_with?(path, "/") and not String.starts_with?(path, "//")`), and enumeration-prevention `:not_allowed -> :not_found` mapping.
- `lib/sigra/install/features/admin.ex` — `files/1` now returns 4 tuples (was 2): `admin/policy.ex`, `admin/components/admin_shell.ex`, `admin/impersonation_controller.ex`, `admin/audit_export_controller.ex`. Target paths land in `lib/<app>/` (policy) and `lib/<app>_web/{components,controllers/admin}/` (shell + controllers).
- `priv/templates/sigra.install/admin/router_injection.ex` — Two 2-line insertions. Global `:admin_global` block gains `live "/admin/users"` → `UsersIndexLive` and `live "/admin/users/:id"` → `UserShowLive` between `live "/admin/audit"` and `live "/admin/users/:id/audit"`. Organization `:admin_organization` block gains `live "/users"` and `live "/users/:id"` between `live "/audit"` and `live "/users/:id/audit"`. `# Sigra admin` idempotency marker unchanged.
- `test/sigra/install/features/admin_test.exs` — Extended `describe "files/1"` with 2 new tuple-membership assertions (impersonation, audit_export). Added 2 new describe blocks: `"impersonation_controller template (Phase 32)"` (4 tests: parameterization, runtime integration points, enumeration-prevention, app_module/context_module substitution) and `"router_injection.ex template (Phase 32 route mounts)"` (5 tests: 4 new mounts + regression guard for existing mounts). Extended `describe "template ownership guards"` with 2 new `File.exists?` assertions.

## Decisions Made

- **D-01 — Enumeration-prevention preserved verbatim:** The generated `ImpersonationController` surfaces `:not_allowed` as `auth_error(:not_found, [])` (404), not `:forbidden` (403). This is the T-IMPR-ESCALATION mitigation — an attacker who can hit `POST /admin/users/:id/impersonation` must not be able to distinguish "target user exists but you can't impersonate" from "target user does not exist." The generator test greps both the match arm and the auth_error call so a future refactor cannot silently regress.
- **D-02 — `alias <%= context_module %>` bare + post-alias `Accounts.*` usage:** Diverges from `audit_export_controller.ex` (which uses `alias <%= app_module %>.Accounts`), but matches the example controller exactly. Rationale: the example controller is the reference implementation for this template, and gratuitous re-parameterization of alias shape would increase diff surface without improving correctness. When `context_module` is `"MyApp.Accounts"`, `alias MyApp.Accounts` resolves `Accounts.get_user!` and `Accounts.sigra_config` identically in every host.
- **D-03 — Admin implies organizations:** No `<%= if organizations? do %>` guards on any of the 4 new router mounts or the impersonation controller. Consistent with the existing admin feature convention (`router_injection.ex:13,59`: `organizations: <%= app_module %>.Organizations` is already unconditional) and the `Admin` feature's dependency on `Organizations` being present in the generated host. Explicitly flagged as Pitfall 3 in 32-RESEARCH.md.
- **D-04 — coverage_test.exs @known_drift unchanged:** `Sigra.Install.Features.Admin` entry stays `[]`. The audit_export_controller.ex orphan is resolved by **registration** (adding it to `files/1`), NOT by **allowlisting** (adding it to `@known_drift`). Per 32-RESEARCH.md Pitfall 2 and the coverage_test.exs doctring, adding to `@known_drift` for a template we just wired up would defeat the drift-detection purpose. Verified: `test "every file under admin/ is owned by Sigra.Install.Features.Admin"` passes with no allowlist additions.

## Deviations from Plan

None — plan executed exactly as written. The test suite ordering was adjusted marginally: the plan suggested adding all Task 1 + Task 2 tests up front; I added Task 1 tests first, committed RED, made Task 1 GREEN, then added Task 2 tests as a separate RED commit. This keeps the TDD gate order (RED → GREEN → RED → GREEN) crisp and auditable in git log, but the net test surface is identical to what the plan specified.

## Issues Encountered

- **Worktree had no installed dependencies** on first `mix test` (55+ missing Hex packages). Resolved with a single `mix deps.get` run; no code changes required. Dependencies correctly resolved against the existing `mix.lock`.

## Deferred Issues

- **Broader `test/sigra/install/` suite has 59 pre-existing failures** in `passkeys_js_test.exs`, `generator_email_test.exs`, `generator_mfa_test.exs`, and `generator_wiring_test.exs`. These are compilation errors in `priv/templates/sigra.install/core/mfa_challenge_live.ex` and related passkey templates — entirely unrelated to the Phase 32 Plan 01 admin surface changes. Verified at the base commit (07a9c00) that these failures predate this plan. Per scope-boundary rules, these are out of scope for Plan 01 and should be addressed in a dedicated repair plan. The plan's explicit verification command (`mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs`) exits 0 with all 23 tests green.

## User Setup Required

None — no external service configuration required. All changes are installer-side template and test additions.

## Next Phase Readiness

- **Plan 01 complete:** All generator-side emissions closed for INT-01/02/03.
- **Plan 02 (runtime smoke probe) ready to start:** Plan 01's templates are on disk and registered; Plan 02's Wave 2 smoke test can now run `mix sigra.install` against a fresh host and assert that `lib/<app>_web/controllers/admin/impersonation_controller.ex` + `audit_export_controller.ex` are emitted with correct substitutions and that the router contains all 4 admin user live mounts.
- **No blockers** for Plan 02 execution.

## Self-Check: PASSED

**Files verified on disk:**
- FOUND: priv/templates/sigra.install/admin/impersonation_controller.ex (created)
- FOUND: priv/templates/sigra.install/admin/audit_export_controller.ex (existed, now registered)
- FOUND: priv/templates/sigra.install/admin/router_injection.ex (modified)
- FOUND: lib/sigra/install/features/admin.ex (modified)
- FOUND: test/sigra/install/features/admin_test.exs (extended)
- FOUND: .planning/phases/32-generated-installer-admin-surface-parity/32-01-SUMMARY.md

**Commits verified in git log:**
- FOUND: 02e3f84 (Task 1 RED)
- FOUND: d33cc4c (Task 1 GREEN)
- FOUND: 1b046a1 (Task 2 RED)
- FOUND: c05c151 (Task 2 GREEN)

**Automated verification:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs` exits 0 with 23 tests, 0 failures.

**Acceptance criteria grep counts (all match plan):**
- `defmodule <%= web_module %>.Admin.ImpersonationController` in impersonation template: 1 (expected 1)
- `Example` literal in impersonation template: 0 (expected 0)
- `AuthErrorHandler.auth_error(:not_found` in impersonation template: 1 (expected 1)
- `Sigra.Impersonation.start(` in impersonation template: 1 (expected 1)
- `Sigra.Impersonation.stop(` in impersonation template: 1 (expected 1)
- `admin/impersonation_controller.ex` in admin.ex files/1: 1 (expected 1)
- `admin/audit_export_controller.ex` in admin.ex files/1: 1 (expected 1)
- `live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` in router: 1 (expected 1)
- `live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` in router: 1 (expected 1)
- `live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` in router: 1 (expected 1)
- `live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` in router: 1 (expected 1)
- Total `Elixir.Sigra.Admin.Live.UsersIndexLive` occurrences in router: 2 (expected 2)
- Total `Elixir.Sigra.Admin.Live.UserShowLive` occurrences in router: 2 (expected 2)
- `# Sigra admin` idempotency marker: 1 (preserved)
- Impersonation template line count: 148 (≥ min_lines 130)

---
*Phase: 32-generated-installer-admin-surface-parity*
*Plan: 01*
*Completed: 2026-04-17*
