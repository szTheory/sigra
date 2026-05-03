---
phase: 260502-oc7
plan: 01
subsystem: ci-build
tags: [pr-37, ci, oban-optional, assent-optional, admin-policy, group-b, group-d, gsd-quick]

requires: []
provides:
  - "Sigra.Workers.* modules stay loadable when Oban is absent (test contract restored)"
  - "Sigra.Workers.*.new/2 raises Sigra.OptionalDeps.MissingDependencyError (:lifecycle_jobs / :async_email) on first queue-backed call"
  - "OAuth strategy refresh/3 no longer leaks Assent.Strategy.OAuth2.refresh_access_token/2 at compile time"
  - "scripts/ci/admin-acceptance-smoke.sh heredoc compiles in generated host (admin_org_ids_from_memberships called with required :roles)"

affects: [pr-37, ci-groups-b-d, install-fixture, install-matrix]

tech-stack:
  added: []
  patterns:
    - "Dual-defmodule pattern for optional Oban worker boundary: outer `if Code.ensure_loaded?(Oban.Worker) do defmodule ... use Oban.Worker ... else defmodule ... stub end` — Elixir 1.19 expands `use` macros eagerly even inside `if false`, so the conditional must wrap the entire defmodule"
    - "apply/3 indirection to defer compile-time symbol resolution of optional-dep functions (Assent.Strategy.OAuth2.refresh_access_token/2)"

key-files:
  created: []
  modified:
    - "lib/sigra/workers/account_deletion.ex"
    - "lib/sigra/workers/audit_cleanup.ex"
    - "lib/sigra/workers/cleanup_expired_invitations.ex"
    - "lib/sigra/workers/email_delivery.ex"
    - "lib/sigra/workers/token_cleanup.ex"
    - "lib/sigra/oauth/strategies/apple.ex"
    - "lib/sigra/oauth/strategies/facebook.ex"
    - "lib/sigra/oauth/strategies/generic.ex"
    - "lib/sigra/oauth/strategies/github.ex"
    - "scripts/ci/admin-acceptance-smoke.sh"
    - "test/fixtures/install_golden/STDOUT.txt"

key-decisions:
  - "Dual-defmodule shape (outer if/else, both branches define the worker module) is the only pattern that works in Elixir 1.19. Inner-`if Code.ensure_loaded?(Oban.Worker) do use Oban.Worker end` (Phase 95-04 pattern) and the `@oban_available = ...; if @oban_available do` variant both fail because Elixir 1.19 fully expands the `use` macro AST regardless of the conditional. Confirmed empirically with both `if false do use Nonexistent end` and `if @attr do use Nonexistent end` reproducers."
  - "Stub `new/2` accepts `(args, opts \\\\ [])` so the CI 'oban-stripped' lane that calls `Sigra.Workers.AccountDeletion.new(%{...}, [])` (ci.yml:204) raises through the same OptionalDeps path."
  - "apply/3 chosen over Code.ensure_loaded? guard or wrapper module for the OAuth refresh fix — `ensure_assent!()` already guards at runtime; only the compile-time symbol leak needs to be addressed; apply/3 is the canonical analog to the refresh_classifier.ex map-pattern precedent."
  - "Admin policy template stays at /2 arity. The CI smoke heredoc was the drift; the lib API contract is correct as is. Rejected adding /1 alias because that would re-introduce the implicit-role default Phase 92 deliberately removed."
  - "Golden install fixture STDOUT.txt re-blessed via the sanctioned `mix sigra.fixture.rebless_golden` task. The fixture had captured the Group D2 bug (4 Assent OAuth2 undefined warnings); fixing the bug naturally invalidated the fixture."

patterns-established:
  - "When optional Oban-backed modules need to stay loadable in Oban-absent builds, wrap the entire defmodule (both real and stub) with `if Code.ensure_loaded?(Oban.Worker) do ... else ... end` — Elixir 1.19 macro-expansion semantics make inner-if patterns unworkable."
  - "Optional-dep function calls inside non-conditional code paths use `apply(M, :f, args)` to defer compile-time resolution; the runtime guard (`ensure_*!()`) handles the missing-dep case."

requirements-completed:
  - "PR-37-CI-GROUP-B (Oban-off worker contract — modules loadable + tagged error)"
  - "PR-37-CI-GROUP-D1 (admin_org_ids_from_memberships arity drift in CI smoke heredoc)"
  - "PR-37-CI-GROUP-D2 (Assent OAuth2 refresh_access_token compile-time leak in 4 strategies)"

duration: 70min
completed: 2026-05-02
---

# 260502-oc7: PR #37 CI Groups B + D Fixes Summary

Three atomic fix commits closing the residual code-side CI failures from PR #37 (groups B, D1, D2) plus one re-bless commit for the golden install fixture invalidated by the Group D2 fix. Local suite ends at 2358 tests / 1 failure (the expected deferred Group A `UpgradeIntegrationTest`).

## Performance

- **Duration:** ~70 min
- **Started:** 2026-05-02T17:30:00Z (approx)
- **Completed:** 2026-05-03T00:45:00Z
- **Tasks:** 3 fix tasks + 1 verification
- **Files modified:** 11 (10 planned + 1 deviation)
- **Commits:** 4

## Accomplishments

- **Group B (Oban-off worker contract):** Restored the `optional_deps_test.exs` and `delivery_test.exs:103,189` contract — all 5 worker modules (`AccountDeletion`, `AuditCleanup`, `TokenCleanup`, `CleanupExpiredInvitations`, `EmailDelivery`) stay loadable when Oban is absent and raise `Sigra.OptionalDeps.MissingDependencyError` tagged `:lifecycle_jobs` / `:async_email` on first queue-backed call.
- **Group D2 (OAuth strategy compile-time leak):** Converted `Assent.Strategy.OAuth2.refresh_access_token/2` direct calls to `apply/3` indirection in `apple.ex`, `facebook.ex`, `github.ex`, `generic.ex` so path-dep installs without Assent compile cleanly under `--warnings-as-errors`.
- **Group D1 (admin policy template arity drift):** Updated `scripts/ci/admin-acceptance-smoke.sh:141` heredoc to call `admin_org_ids_from_memberships(roles: [:owner, :admin])` matching the post-Phase-92 `/2` contract.
- **Golden install fixture:** Re-blessed `test/fixtures/install_golden/STDOUT.txt` after Group D2 fix removed the Assent warnings the fixture was capturing.

## Task Commits

| # | Task | Commit | Type |
|---|------|--------|------|
| 1 | Group B — restore Oban-off worker contract (5 worker files) | `611f48a` | fix(workers) |
| 2 | Group D2 — apply/3 indirection on Assent OAuth2 refresh (4 strategy files) | `267033b` | fix(oauth) |
| 3 | Group D1 — admin policy heredoc :roles option (1 CI script) | `fe6acd9` | fix(ci) |
| 4 | Re-bless golden install STDOUT fixture (1 fixture) | `83e1514` | test(install_golden) |

## Files Created/Modified

- `lib/sigra/workers/account_deletion.ex` — Dual-defmodule shape; real Oban-backed branch + Oban-absent stub
- `lib/sigra/workers/audit_cleanup.ex` — Same pattern
- `lib/sigra/workers/cleanup_expired_invitations.ex` — Same pattern
- `lib/sigra/workers/email_delivery.ex` — Same pattern, `:async_email` feature instead of `:lifecycle_jobs`
- `lib/sigra/workers/token_cleanup.ex` — Same pattern
- `lib/sigra/oauth/strategies/apple.ex` — `apply/3` indirection on `refresh_access_token/2`
- `lib/sigra/oauth/strategies/facebook.ex` — Same
- `lib/sigra/oauth/strategies/generic.ex` — Same
- `lib/sigra/oauth/strategies/github.ex` — Same
- `scripts/ci/admin-acceptance-smoke.sh` — Heredoc passes `roles: [:owner, :admin]` to match lib /2 contract
- `test/fixtures/install_golden/STDOUT.txt` — Re-blessed via `mix sigra.fixture.rebless_golden`

## Decisions Made

1. **Dual-defmodule shape (outer if/else) for the worker boundary.** The Phase 95-04 inner-`if Code.ensure_loaded?(Oban.Worker) do use Oban.Worker end` pattern fails in Elixir 1.19 — the `use` macro is fully AST-expanded regardless of the conditional. Confirmed empirically with reproducers (`/tmp/test_if.ex`, `/tmp/test_attr.ex`). The Phase 93-08 outer-`if defmodule` pattern broke the test contract (module disappears). The dual-defmodule shape (both branches define the same module — full worker when Oban present, stub when absent) satisfies both invariants.

2. **Stub `new/2` accepts `(args, opts \\ [])` rather than enforcing `(args, opts)`.** The CI "Optional dep off - oban" lane (`.github/workflows/ci.yml:204`) calls `AccountDeletion.new(%{...}, [])` with explicit empty opts but generic install paths may also call without opts; default-arg keeps both shapes raising correctly.

3. **`apply/3` over `Code.ensure_loaded?` guard for OAuth refresh.** The `refresh/3` function already calls `ensure_assent!()` at the top, which raises if Assent is absent at runtime. The only remaining compile-time concern is symbol resolution; `apply/3` is the minimal-change fix.

4. **Did not touch `authorize_url/1` or `callback/3` in OAuth strategies.** Those call provider-specific Assent strategies (e.g. `Assent.Strategy.Apple.callback/2`) and are out of scope for the Group D2 CI failure (which was specifically about `refresh_access_token/2`). The `--warnings-as-errors` failure cited only `refresh_access_token/2` as undefined.

5. **Lib API for `admin_org_ids_from_memberships/2` stays unchanged.** Adding `/1` arity would re-introduce the implicit-role default Phase 92 deliberately removed. The CI smoke script's heredoc was the drift; the contract is correct as is.

6. **Re-blessed golden fixture to capture the post-fix install output.** The fixture had captured the very bug we fixed (4 Assent OAuth2 undefined warnings). After the fix those warnings no longer fire, invalidating the fixture. Re-blessed via the sanctioned `MIX_ENV=test mix sigra.fixture.rebless_golden` mix task per the in-tree runbook. The check-mode (`--check`) reports "OK: fixture is up-to-date" post-rebless.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adopted dual-defmodule shape after inner-`if` failed under Elixir 1.19**

- **Found during:** Task 1 verification (`mix test test/sigra/install/generator_passkeys_opt_out_test.exs`)
- **Issue:** The plan's prescribed inner-`if Code.ensure_loaded?(Oban.Worker) do use Oban.Worker ... else stub end` pattern compiled in sigra's own test env (where Oban is loaded) but failed in the install fixture's path-dep host environment with "module Oban.Worker is not loaded and could not be found" at the `use Oban.Worker` line. Elixir 1.19 expands the `use` macro AST eagerly even inside `if false do ... end` (verified with isolated reproducers).
- **Fix:** Switched all 5 worker files to a dual-defmodule shape: `if Code.ensure_loaded?(Oban.Worker) do defmodule Worker do (full impl) end else defmodule Worker do (stub) end end`. The outer `if` is evaluated before any defmodule body is parsed, so the `use Oban.Worker` is never seen when Oban is absent. Both branches define the same module name, so `Code.ensure_loaded?(Sigra.Workers.AccountDeletion)` returns true in both compile environments.
- **Files modified:** All 5 worker files
- **Verification:** Both `test/sigra/workers/optional_deps_test.exs` (16/16 pass) and `test/sigra/install/generator_passkeys_opt_out_test.exs` (3/3 pass) green.
- **Committed in:** `611f48a`

**2. [Rule 1 - Bug] Re-blessed golden install fixture after Group D2 fix invalidated it**

- **Found during:** Task 4 full-suite verification
- **Issue:** `test/sigra/install/golden_diff_test.exs:66` failed with "STDOUT diverges from fixture". The fixture had captured 4 `Assent.Strategy.OAuth2.refresh_access_token/2 is undefined` warnings — the very bug Group D2 was meant to fix. After the apply/3 indirection landed, those warnings no longer fire, leaving the fixture stale.
- **Fix:** Ran `MIX_ENV=test mix sigra.fixture.rebless_golden` (the in-tree sanctioned re-bless task). Delta: 4 warnings removed (Group D2 success signal); 1 typing-violation warning added (Elixir 1.19 informational warning at `lib/sigra/delivery.ex:48` — see "Known follow-ups" below).
- **Files modified:** `test/fixtures/install_golden/STDOUT.txt` (33 inserts, 28 deletes)
- **Verification:** `mix sigra.fixture.rebless_golden --check` reports "OK: fixture is up-to-date." `mix test test/sigra/install/golden_diff_test.exs` passes (2/2).
- **Committed in:** `83e1514`

## Issues Encountered

- **Disk-full mid-suite (resolved):** During the first full-suite run, leftover `/tmp/sigra_golden_*` directories from prior test sessions (565 dirs, ~11 GiB) filled the data volume to 100%. The Postgres server entered recovery mode, the install fixture's `setup_tmp_app` failed with "no space left on device" mid-test, and the suite reported a cascade of false failures. Cleaned up via `rm -rf $TMPDIR/sigra_golden_*` and re-ran. Final clean run: 2358 tests / 1 failure (expected residual). No code changes needed; this was environmental.
- **Async log-capture flake (1 occurrence, not reproduced):** First clean run showed `Sigra.ApplicationOptionalDepsTest.maybe_warn_audit_cleanup_fallback/2 stays quiet ...` failing with a captured log line `OAuth authorize_url failed for failing: ...` from a parallel test in `test/sigra/oauth/`. The test passes in isolation and on the final run did not reproduce. This is a known async-test logger-bleed pattern unrelated to the changes in this task — the OAuth tests that emit those logs were not modified by Task 2 (the modified `refresh/3` doesn't call authorize_url). Documented but not fixed; out of scope.

## Known Follow-ups

- **Typing violation in `lib/sigra/delivery.ex:48`** (informational, not fatal). When the Oban-absent stub branch of `Sigra.Workers.EmailDelivery` is compiled in a path-dep host, the stub's `new/2` returns `no_return()` (always raises via `OptionalDeps.ensure_available!/2` plus a defensive marker). Elixir 1.19's type checker propagates `no_return` back through `Sigra.Delivery.build_job/3` to its call site at `delivery.ex:48`, emitting a "this pattern will never match" warning. The warning does NOT fail `mix compile --warnings-as-errors` (verified by hand in the install fixture's tmp app — exit 0). Behaviour is correct: `OptionalDeps.ensure_available!` raises before the unreachable marker is hit. A follow-up could refine the stub spec (e.g., return a placeholder Ecto.Changeset shape, or add `@dialyzer {:nowarn_function, ...}` on `Sigra.Delivery.build_job/3`) to silence the noise. Out of scope for this CI close-out.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- PR #37 CI Groups B, D1, D2 all closed at the code level.
- The user's next push triggers CI runs that should flip Groups B + D green.
- Group A (`UpgradeIntegrationTest`) and Group C (`CLOAK_KEY` env / Postgres role missing) remain explicitly out of scope per separate `/gsd-debug` sessions.
- The optional follow-up to silence the new typing warning at `delivery.ex:48` can be picked up as a separate quick task if the warning becomes a DX issue.

## Verification Results

```
Finished in 567.1 seconds (4.0s async, 563.0s sync)
33 doctests, 3 properties, 2358 tests, 1 failure
```

Single residual failure: `Sigra.UpgradeIntegrationTest "login after backfill-off upgrade redirects to /organizations with 302 and no 500s"` at `test/upgrade_test.exs:91` — pre-existing Group A residual, deferred to separate /gsd-debug session per plan.

Targeted verifications performed during execution:
- `mix test test/sigra/workers/optional_deps_test.exs test/sigra/delivery_test.exs` → 16/16 pass (Task 1)
- `mix test test/sigra/install/generator_passkeys_opt_out_test.exs` → 3/3 pass (Task 1 path-dep boundary)
- `mix test test/sigra/workers/` → 56/56 pass (Task 1 full worker suite)
- `mix compile --warnings-as-errors` → clean (sigra's own env, Tasks 1+2)
- `mix test test/sigra/oauth/` → 106/106 pass (Task 2)
- `grep "admin_org_ids_from_memberships(roles: \[:owner, :admin\])" scripts/ci/admin-acceptance-smoke.sh | wc -l` → 1 (Task 3)
- `mix sigra.fixture.rebless_golden --check` → "OK: fixture is up-to-date" (Task 4)
- `mix test test/sigra/install/golden_diff_test.exs` → 2/2 pass (Task 4)
- Host-level `mix compile --warnings-as-errors` in install fixture's tmp app → exit 0 (verified by hand)

## Self-Check: PASSED

- All 11 modified files exist on disk
- All 4 commits present in `git log` (`611f48a`, `267033b`, `fe6acd9`, `83e1514`)
- SUMMARY.md exists at expected path
- Final `mix test` reports 2358 tests / 1 expected residual failure
- `mix sigra.fixture.rebless_golden --check` reports "OK: fixture is up-to-date"
