---
phase: 138-mix-sigra-doctor-operator-diagnostic
fixed_at: 2026-05-29T00:00:00Z
review_path: .planning/phases/138-mix-sigra-doctor-operator-diagnostic/138-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 138: Code Review Fix Report

**Fixed at:** 2026-05-29
**Source review:** `.planning/phases/138-mix-sigra-doctor-operator-diagnostic/138-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (CR-01, WR-01 through WR-06)
- Fixed: 7
- Skipped: 0

All seven critical and warning findings were addressed in a single atomic commit, as
they form a coherent single-source-of-truth (D-06) realignment of `Sigra.Doctor` to
the canonical semantics in `Sigra.Application` and `Sigra.Config`. The test suite
expanded from 13 tests to 30 tests; all pass green.

## Fixed Issues

### CR-01: `encryption_hard_fail?` diverges from `verify_vault!` and rests on a phantom config key

**Files modified:** `lib/sigra/doctor.ex`, `test/sigra/doctor_test.exs`
**Commit:** 6c936a9
**Applied fix:**
- Replaced `encryption_configured?` (which called the phantom `oauth_token_storage_enabled?`
  reading nonexistent `:store_tokens` key) with a direct mirror of `verify_vault!/1`.
- Added `user_schema` guard: `encryption_configured?` now returns `true` only when
  `passkeys_enabled? AND user_schema != nil`. This matches `verify_vault!`'s behavior
  of short-circuiting to `:ok` when `encrypted_binary_module/1` returns nil (no user_schema).
- Deleted the entire `oauth_token_storage_enabled?` private function (phantom key gone).
- Updated `hint_available`, `hint_active`, `hint_broken` for the `:encryption` feature
  to remove the "or OAuth token storage" wording that described dead behavior.
- Added regression tests: "absent passkeys key + user_schema configured → hard-fail"
  and "absent passkeys key + no user_schema → :ok (dep-off safe)".

### WR-01: `passkeys_enabled?` default disagrees with `Sigra.Application` (false negative)

**Files modified:** `lib/sigra/doctor.ex`, `test/sigra/doctor_test.exs`
**Commit:** 6c936a9
**Applied fix:**
- Changed `passkeys_enabled?/1` from a `case` with `nil -> false` to a simple
  two-hop `Keyword.get` with default `[]` then `Keyword.get(:enabled, true)`, exactly
  matching `Sigra.Application.passkeys_enabled?/1` (application.ex:212-216).
- Updated Test 7 (passkeys enabled + encryption_active false → hard-fail) to include
  `user_schema` in the host_sigra, since `encryption_configured?` now requires it
  (matching the behavior of `verify_vault!` which also needs a user_schema to check).
- Added new regression tests locking both the WR-01 corrected default and the
  user_schema guard interaction.

### WR-02: `oauth_configured?` ignores the `enabled: false` master switch (false positive)

**Files modified:** `lib/sigra/doctor.ex`, `test/sigra/doctor_test.exs`
**Commit:** 6c936a9
**Applied fix:**
- Rewrote `oauth_configured?` to check `Keyword.get(oauth, :enabled, true) and providers != []`,
  mirroring `Sigra.Config.oauth_enabled?/1` (config.ex:1037) exactly.
- Uses the new `sub/2` helper for safe unvalidated reads.
- Added regression test: `oauth: [enabled: false, providers: [google: [...]]]` →
  state `:available` (not `:loaded_active`), verdict `:ok`.

### WR-03: `totp_configured?` ignores `mfa[:enabled]` (false positive)

**Files modified:** `lib/sigra/doctor.ex`, `test/sigra/doctor_test.exs`
**Commit:** 6c936a9
**Applied fix:**
- Changed `totp_configured?` to check `Keyword.get(mfa, :enabled, true)` in addition
  to `mfa != []`. Previously any non-empty `:mfa` list was reported as configured even
  when `enabled: false`.
- Uses the new `sub/2` helper.
- Added regression test: `mfa: [enabled: false, totp_drift_steps: 2]` →
  state `:available` (not `:loaded_active`), verdict `:ok`.

### WR-04: Malformed forwarder entry crashes doctor instead of reporting misconfig

**Files modified:** `lib/sigra/doctor.ex`, `test/sigra/doctor_test.exs`
**Commit:** 6c936a9
**Applied fix:**
- Changed `Enum.any?/2` lambda in `audit_forwarding_hard_fail?` from a single clause
  to a multi-clause function with `forwarder_opts when is_list(forwarder_opts)` as the
  guarded happy path, and `_` -> `true` as the malformed-entry fallback (flags as
  misconfiguration, does not crash).
- Also switched to `sub/2` for the audit sub-config read.
- Added regression test: `forwarders: [:bad_entry]` → state `:configured_but_missing`,
  verdict `:fail`, no crash.

### WR-05: `jwt_configured?` / `async_email_configured?` assume well-typed sub-config

**Files modified:** `lib/sigra/doctor.ex`
**Commit:** 6c936a9
**Applied fix:**
- Added `defp sub(host_sigra, key)` helper that returns `[]` when the value for a key
  is absent OR is not a keyword list (e.g. `jwt: "true"` → `[]`).
- Routed ALL `configured?` predicates through `sub/2`:
  `totp_configured?`, `oauth_configured?`, `rate_limiting_configured?`, `jwt_configured?`,
  `async_email_configured?`, `audit_forwarding_configured?`, `enterprise_connections_configured?`.
- This eliminates the `FunctionClauseError` that would have been raised by
  `Keyword.get/2` on a non-list value from unvalidated `Application.get_env` config.

### WR-06: Test 8 asserts hard-fail on a module name that may become loadable

**Files modified:** `lib/sigra/doctor.ex`, `test/sigra/doctor_test.exs`
**Commit:** 6c936a9
**Applied fix:**
- Added `:module_loaded?` injection key to `diagnose/1` opts (parallel to `:oban_running`),
  accepting a `(module :: atom() -> boolean())` function override for `Code.ensure_loaded?/1`.
- Threaded `module_loaded?` through `diagnose/1` → `resolve_module_loaded/1` →
  `build_matrix/4` → `evaluate_feature/5` → `audit_forwarding_hard_fail?/4`.
- Updated all `hard_fail?` lambdas in `feature_definitions/0` from 3-arity to 4-arity
  (`fn _preds, _host, _oban, _module_loaded? -> false end`).
- Updated `async_email_hard_fail?/4` and `encryption_hard_fail?/4` signatures accordingly.
- Added two new deterministic injection tests:
  - `always_not_loaded` fn injected → forwarder hard-fail fires for `Sigra.Doctor` itself
    (a module that IS actually loaded), proving the check is driven by the injected fn.
  - `always_loaded` fn injected → forwarder does NOT hard-fail, state `:loaded_active`.
- Original Test 8 (using `VeryDefinitelyNotALoadedModule12345`) is retained as a
  belt-and-suspenders integration check alongside the new injection tests.

## Skipped Issues

None — all seven in-scope findings were fixed.

---

_Fixed: 2026-05-29_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
