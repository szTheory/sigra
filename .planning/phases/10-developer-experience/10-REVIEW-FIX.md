---
phase: 10-developer-experience
fixed_at: 2026-04-09T00:00:00Z
review_path: .planning/phases/10-developer-experience/10-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 5
skipped: 6
status: partial
---

# Phase 10: Code Review Fix Report

**Fixed at:** 2026-04-09
**Source review:** `.planning/phases/10-developer-experience/10-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (2 critical + 4 warning + 5 info)
- Fixed: 5 (CR-01, WR-01, WR-02, WR-03, WR-04)
- Deferred: 6 (CR-02 + IN-01..IN-05)
- Sanity: `mix compile --warnings-as-errors` clean; `mix test test/sigra/` = 1205 tests, 1 failure (pre-existing phase-09 `cursor_portability_test`, unrelated to this pass).

## Fixed Issues

### CR-01: `Mix.env()` called at runtime in generated `UserAuth` (release crash)

**Files modified:** `priv/templates/sigra.install/user_auth.ex`, `test/example/lib/example_web/user_auth.ex`, `test/sigra/templates/session_templates_test.exs`
**Commits:** `7a922e7`, `0437427`
**Applied fix:** Replaced the unguarded `Mix.env() == :prod` call inside `remember_me_options/0` with the same release-safe pattern already used by `lib/sigra/application.ex:30`:

```elixir
env = if function_exported?(Mix, :env, 0), do: Mix.env(), else: :prod
base = Keyword.put(@remember_me_static_options, :secure, env == :prod)
```

Applied to BOTH the installer template and the generated `test/example/` copy so the example app stays in lockstep with the template. Added an explanatory comment describing why the guard is needed (`:mix` is not loaded in production releases). Updated `session_templates_test.exs` "remember-me has secure flag" assertion to look for `function_exported?(Mix, :env, 0)` + `:secure, env == :prod` instead of the old unguarded string. Verified under `mix test test/sigra/templates/session_templates_test.exs` → 50 tests, 0 failures.

### WR-01: `guides/flows/mfa.md` references non-existent MFA functions

**Files modified:** `guides/flows/mfa.md`, `test/sigra/guides_dx02_test.exs`
**Commit:** `fc43f52`
**Applied fix:** Replaced `Sigra.MFA.verify_backup_code(config(), user, input)` with the real `Sigra.MFA.verify_backup(config(), user, input)` (arity 3 is valid because `verify_backup/4` has a default `opts \\ []`). Replaced `Sigra.MFA.enrolled?(user)` with the real `Sigra.MFA.enabled?(config(), user)`. Updated the "Related" list at line 148 to list `verify_backup` and `enabled?`. Removed both entries from `@known_library_drift` in `test/sigra/guides_dx02_test.exs` since they are no longer drift — the guide now references real functions. `mix test test/sigra/guides_dx02_test.exs` → 8 tests, 0 failures (including the "Sigra.* references match shipped code" sweep that would have flagged new drift).

### WR-02: `assert_audit_event` metadata lookup collapses `false`/`nil`

**File modified:** `lib/sigra/testing.ex`
**Commit:** `138777c`
**Applied fix:** Replaced the short-circuiting `Map.get(...) || Map.get(...)` chain with an explicit `Map.has_key?/2`-based `cond`:

```elixir
metadata = event.metadata || %{}
string_key = to_string(k)

actual =
  cond do
    Map.has_key?(metadata, string_key) -> Map.get(metadata, string_key)
    Map.has_key?(metadata, k) -> Map.get(metadata, k)
    true -> nil
  end
```

This preserves `false`/`nil` metadata values correctly: string-keyed lookups win if present, otherwise we fall through to the atom key, otherwise `nil`. Note: this fix changes no call-site behavior for truthy metadata values but correctly exposes `false`/`nil` values to the equality check below.

**Logic verification status:** fixed — Tier 1 re-read confirms the branching shape matches the REVIEW fix sketch, and Tier 2 `mix compile --warnings-as-errors` is clean. No dedicated regression test was added in this pass (the REVIEW suggestion calls for one but adding it touches audit fixtures; recommend adding under plan 10.1 follow-up).

### WR-03: `Sigra.MFA.Trust.cookie_opts/0` deprecated shim silently drops `:cookie_domain`

**Files modified:** `lib/sigra/mfa/trust.ex`, `test/sigra/mfa/trust_test.exs`, `test/sigra/cookie_domain_test.exs`
**Commit:** `009d424`
**Applied fix:** Converted the arity-0 `cookie_opts/0` from a silent shim returning domain-unaware options to a `raise`-ing stub that directs callers to `cookie_opts/1`:

```elixir
def cookie_opts do
  raise """
  Sigra.MFA.Trust.cookie_opts/0 was removed to guarantee :cookie_domain is honored.

  Call Sigra.MFA.Trust.cookie_opts/1 with your %Sigra.Config{} instead:

      config = MyApp.Auth.sigra_config()
      Sigra.MFA.Trust.cookie_opts(config)

  See CHANGELOG and guides/recipes/subdomain-auth.md for migration notes.
  """
end
```

Kept `@deprecated` and `@doc deprecated:` annotations so any upgrader who still calls the arity-0 form gets both a compile-time deprecation warning AND a runtime error pointing at the correct migration path. Updated `@spec` to `no_return()`.

**Caller sweep confirmed no internal callers of the arity-0 form:**
- `lib/sigra/testing.ex:515` already uses `cookie_opts(config)` (Phase 10-03 update).
- `priv/templates/sigra.install/mfa_challenge_controller.ex:113` already uses `cookie_opts(config)`.
- `test/example/lib/example_web/controllers/mfa_challenge_controller.ex:113` already uses `cookie_opts(config)`.

Two test files exercised the arity-0 shim and were updated:
- `test/sigra/mfa/trust_test.exs`: replaced `describe "cookie_opts/0"` with two describes — `cookie_opts/1` exercises the nil-domain case, and `cookie_opts/0 (removed)` asserts `assert_raise RuntimeError, ~r/cookie_opts\/0 was removed/`.
- `test/sigra/cookie_domain_test.exs`: updated `describe "Sigra.MFA.Trust.cookie_opts/0 (deprecated shim)"` to `(removed)` with the same `assert_raise` shape. Kept the `apply(Trust, :cookie_opts, [])` indirection so `--warnings-as-errors` isn't tripped by the compile-time deprecation.

`mix test test/sigra/mfa/trust_test.exs test/sigra/cookie_domain_test.exs` → 19 tests, 0 failures.

### WR-04: `oauth_enabled?/1` returns `true` with zero configured providers

**Files modified:** `lib/sigra/config.ex`, `test/sigra/oauth/config_test.exs`
**Commit:** `1aae029`
**Applied fix:** Investigated the default config — `oauth: []` (empty providers list) is indeed the default, and there are no production callers inside `lib/` or `priv/` that rely on the old semantics. Redefined `oauth_enabled?/1`:

```elixir
def oauth_enabled?(%__MODULE__{oauth: oauth}) do
  Keyword.get(oauth, :enabled, true) and Keyword.get(oauth, :providers, []) != []
end
```

Updated the doctest to assert `false` on the default config and added a third doctest covering the `enabled: false` path. Updated `test/sigra/oauth/config_test.exs` `oauth_enabled?/1` describe block:
- The "enabled" test now configures a google provider (otherwise the fix would cause it to return false).
- The "disabled" test similarly includes a provider so the test unambiguously isolates the `enabled: false` flag.
- Added "returns false on the default config (no providers configured)" and "returns false when enabled but providers list is empty" regression tests.

Verified via `mix test test/sigra/oauth/config_test.exs --include doctest` → 16 tests, 0 failures, and `mix test test/sigra/doctest_test.exs` → 30 doctests, 0 failures.

## Deferred Issues

### CR-02: `Sigra.Auth.request_password_reset/3` inserts a plain map

**File:** `lib/sigra/auth.ex:828-835`
**Status:** DEFERRED to fix phase 10.1
**Reason:** This is a pre-existing library bug (flagged in the review config as `scope_notes` "known deferred issue"). The fix requires building a proper `%UserToken{}` struct via the schema module resolved from `config.token_schema`, then adding a smoke test that drives `request_password_reset/3` through a live repo. The scope is broader than a targeted line-level fix and warrants its own planning step — the REVIEW itself notes that no current smoke test exercises this path, so a regression test needs to be designed. Tracked for fix phase 10.1.

### IN-01: Extract `Sigra.Env.current/0` helper for Mix.env guard pattern

**File:** new `lib/sigra/env.ex`
**Status:** DEFERRED to fix phase 10.1
**Reason:** Not a one-line change — this creates a new module with its own tests and updates `lib/sigra/application.ex:30` plus the installer template to consume it. CR-01 was already addressed with an inline guard that mirrors the application.ex pattern, so the runtime bug is fixed. The helper extraction is a pure refactor and belongs in a follow-up cleanup.

### IN-02: `test_load_filters` regex comment

**File:** `mix.exs:15`
**Status:** DEFERRED to fix phase 10.1
**Reason:** Documentation-only comment enhancement; the REVIEW itself notes the existing comment is already "good." No runtime impact. Batching with other IN fixes.

### IN-03: CI workflow pins actions loosely

**File:** `.github/workflows/ci.yml`
**Status:** DEFERRED to fix phase 10.1
**Reason:** Requires resolving specific commit SHAs for every action, enabling Dependabot `github-actions` updates, and testing the pinned workflow — multi-step supply-chain hardening, not a one-liner. Fits better as its own focused task.

### IN-04: `scenario/2` generic `FunctionClauseError` on unknown atoms

**File:** `priv/templates/sigra.install/auth_fixtures.ex:270-275`
**Status:** DEFERRED to fix phase 10.1
**Reason:** Requires both a catch-all clause in the template AND an update to `test/sigra/auth_fixtures_scenario_test.exs` to assert against `ArgumentError` with a matching message. Not a one-line change.

### IN-05: `normalize_email/1` does not strip interior whitespace

**File:** `lib/sigra/auth.ex:49-52`
**Status:** DEFERRED to fix phase 10.1
**Reason:** The REVIEW recommends a documentation-only fix (clarifying the narrower "normalize" contract). Moduledoc updates can be batched with other IN-level doc tweaks in 10.1.

## Sanity Results

**Compile:** `mix compile --warnings-as-errors` → clean (no warnings, no errors).

**Test (test/sigra/):** `mix test test/sigra/` → **30 doctests, 3 properties, 1205 tests, 1 failure**.

The single failure is pre-existing and unrelated to this fix pass:

- `Sigra.Audit.CursorPortabilityTest` — `test paginates deterministically across cursor boundary on this adapter` at `test/sigra/audit/cursor_portability_test.exs:52`. Asserts `length(page1.entries) == 2` but gets `0`. Introduced by phase 09 commit `43e4a11` (`test(09-05): add Wave 0 integration + observability + security scaffolds`), not touched by any file modified in this review-fix pass. Recommend capturing as a deferred follow-up under the phase-09 fix bucket.

Per-finding verification:
- CR-01: `mix test test/sigra/templates/session_templates_test.exs` → 50/50 pass.
- WR-01: `mix test test/sigra/guides_dx02_test.exs` → 8/8 pass.
- WR-02: Tier 2 compile clean; no dedicated test added (deferred to 10.1 regression sweep).
- WR-03: `mix test test/sigra/mfa/trust_test.exs test/sigra/cookie_domain_test.exs` → 19/19 pass.
- WR-04: `mix test test/sigra/oauth/config_test.exs --include doctest` → 16/16 pass; `mix test test/sigra/doctest_test.exs` → 30/30 doctests pass.

## Commit Log

| Hash      | Finding | Type | Description                                                                    |
|-----------|---------|------|--------------------------------------------------------------------------------|
| `7a922e7` | CR-01   | fix  | guard Mix.env() in generated UserAuth remember_me_options                      |
| `fc43f52` | WR-01   | fix  | correct MFA guide function references                                          |
| `138777c` | WR-02   | fix  | preserve false/nil in assert_audit_event metadata lookup                       |
| `009d424` | WR-03   | fix  | make Sigra.MFA.Trust.cookie_opts/0 raise to prevent silent cookie_domain drop  |
| `1aae029` | WR-04   | fix  | oauth_enabled? requires at least one configured provider                       |
| `0437427` | CR-01   | test | update session_templates_test assertion for release-safe Mix.env guard         |

---

_Fixed: 2026-04-09_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
