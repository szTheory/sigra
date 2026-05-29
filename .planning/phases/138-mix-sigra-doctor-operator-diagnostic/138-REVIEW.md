---
phase: 138-mix-sigra-doctor-operator-diagnostic
reviewed: 2026-05-29T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/sigra/doctor.ex
  - lib/mix/tasks/sigra.doctor.ex
  - test/sigra/doctor_test.exs
  - test/sigra/mix/tasks/doctor_task_test.exs
findings:
  critical: 1
  warning: 6
  info: 3
  total: 10
status: issues_found
---

# Phase 138: Code Review Report

**Reviewed:** 2026-05-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Phase 138 adds `Sigra.Doctor` (pure diagnostic, builds a nine-feature optional-dependency
matrix + D-09 hard-fail wiring checks) and `Mix.Tasks.Sigra.Doctor` (thin formatter/exit
shell). The exit-code contract is correct: `exit({:shutdown, 1})` fires only on `:fail`,
the full matrix prints before the exit, and clean/dep-off installs exit 0 — verified against
tests 6/7 and the `format_and_exit/2` control flow. The optional-dep detection correctly
delegates to `Sigra.OptionalDeps` rather than re-implementing `Code.ensure_loaded?`, honoring
the D-06 single-source-of-truth.

The defects cluster around **`configured?` predicate divergence from Sigra's canonical config
semantics**. Doctor re-implements config interpretation from scratch instead of reusing the
predicates already living in `Sigra.Config` / `Sigra.Application`. Several of these
re-implementations disagree with the authoritative versions, producing false verdicts. The
most serious is `oauth_token_storage_enabled?`, which reads a config key (`:store_tokens`)
that does not exist anywhere in Sigra's config schema — making half of the encryption
hard-fail logic permanently dead, and creating a hard-fail divergence from
`Sigra.Application.verify_vault!/1` (the very function this module claims to mirror).

## Critical Issues

### CR-01: `encryption_hard_fail?` diverges from `verify_vault!` and rests on a phantom config key

**File:** `lib/sigra/doctor.ex:455-461, 498-506, 522-529`
**Issue:** The module's moduledoc (lines 56-58) states doctor uses the *non-raising mirror* of
`Sigra.Application.verify_vault!/1`. But the two no longer agree on *when* encryption is
required:

- `Sigra.Application.verify_vault!/1` (application.ex:185-210) raises **only** when
  `passkeys_enabled?/1` is true.
- `Sigra.Doctor.encryption_hard_fail?/3` fails when `passkeys_enabled?` **OR**
  `oauth_token_storage_enabled?` is true (via `encryption_configured?/1`, line 460).

The OAuth-token-storage branch reads `oauth: [store_tokens: ...]` (line 525-529), but
`:store_tokens` is **not a key in Sigra's OAuth config schema** — `grep store_tokens
lib/sigra/config.ex` returns nothing. Two consequences:

1. **Dead branch (always false).** No host ever sets `:store_tokens`, so the default `false`
   always applies. The entire OAuth-token-storage path of the encryption check is unreachable
   — it can never trigger a hard-fail, never set the row to `:available`/`:active`, and the
   docstring/hint promising "OAuth token storage" detection (lines 321, 325, 456-459) is
   describing behavior that does not exist.
2. **Latent false-positive if the key is ever honored.** If a future phase wires
   `:store_tokens` without also updating `verify_vault!`, doctor would emit a `:fail` verdict
   (exit 1, CI gate trips) for a configuration that boots cleanly — a false alarm that blocks
   deploys. Doctor must not be stricter than the boot path it claims to mirror.

The doctor is the operator's source of truth for "will this boot?" A diagnostic whose
hard-fail set diverges from the actual boot-time raise set is a correctness defect.

**Fix:** Mirror `verify_vault!` exactly — gate encryption-required on passkeys only, matching
the boot path, and drop the phantom key:
```elixir
defp encryption_configured?(host_sigra) do
  # Mirror Sigra.Application.verify_vault!/1: encryption is required only when
  # passkeys are enabled. Do not introduce divergent triggers.
  passkeys_enabled?(host_sigra)
end
```
If OAuth-token-storage encryption is a genuine future requirement, add the real config key to
`Sigra.Config` and to `verify_vault!` first, then have doctor consume that — never invent a
detection key that exists only in the diagnostic.

## Warnings

### WR-01: `passkeys_enabled?` default disagrees with `Sigra.Application` (false negative)

**File:** `lib/sigra/doctor.ex:512-520` vs `lib/sigra/application.ex:212-216`
**Issue:** The two implementations treat an absent `:passkeys` key oppositely:
- `Sigra.Application.passkeys_enabled?/1`: `Keyword.get(host_sigra, :passkeys, [])` →
  `Keyword.get([], :enabled, true)` → **`true`** when `:passkeys` is absent.
- `Sigra.Doctor.passkeys_enabled?/1`: `case Keyword.get(:passkeys, nil) do nil -> false` →
  **`false`** when `:passkeys` is absent.

The install generator defaults `passkeys?: true` (sigra.install.ex:65,136) and the config
schema defaults `passkeys[:enabled]: true` (config.ex:39). So a host that enabled passkeys via
the generator (which may not emit an explicit `passkeys:` block, relying on the schema
default) will boot with `verify_vault!` treating passkeys as enabled — yet doctor reports
encryption as `:missing`/not-required and gives verdict `:ok`. That is exactly the silent
at-rest-encryption regression D-07 was written to prevent, surfaced through the diagnostic
that is supposed to catch it.
**Fix:** Use the same default as the boot path so doctor never under-reports:
```elixir
defp passkeys_enabled?(host_sigra) do
  host_sigra
  |> Keyword.get(:passkeys, [])
  |> Keyword.get(:enabled, true)
end
```
(Note: confirm the intended semantics — if absent-means-disabled is deliberate for doctor,
then `Sigra.Application` has the bug instead and they still must be reconciled. They cannot
both be correct.)

### WR-02: `oauth_configured?` ignores the `enabled: false` master switch (false positive)

**File:** `lib/sigra/doctor.ex:416-423`
**Issue:** Canonical `Sigra.Config.oauth_enabled?/1` (config.ex:1037) is
`Keyword.get(oauth, :enabled, true) and providers != []`. Doctor's `oauth_configured?` checks
only `providers != []`, ignoring `enabled`. A host with
`oauth: [enabled: false, providers: [google: [...]]]` (OAuth intentionally turned off) is
reported by doctor as `:loaded_active`/`:configured_but_missing`, contradicting the canonical
predicate. The operator is told OAuth is live when the master switch has disabled it.
**Fix:** Honor the master switch:
```elixir
defp oauth_configured?(host_sigra) do
  oauth = Keyword.get(host_sigra, :oauth, [])
  Keyword.get(oauth, :enabled, true) and Keyword.get(oauth, :providers, []) != []
end
```

### WR-03: `totp_configured?` ignores `mfa[:enabled]` (false positive)

**File:** `lib/sigra/doctor.ex:405-408`
**Issue:** `totp_configured?` returns true for any non-empty `:mfa` keyword list. But
`mfa: [enabled: false, totp_drift_steps: 2]` is a non-empty list with MFA explicitly disabled.
Doctor would report TOTP/MFA as configured/active. The config schema has `mfa[:enabled]`
default `true` (config.ex:38), so the disabled case is real and reachable.
**Fix:** Check the `:enabled` sub-key, consistent with how other features gate on a switch:
```elixir
defp totp_configured?(host_sigra) do
  mfa = Keyword.get(host_sigra, :mfa, [])
  is_list(mfa) and mfa != [] and Keyword.get(mfa, :enabled, true)
end
```

### WR-04: Malformed forwarder entry crashes doctor instead of reporting misconfig

**File:** `lib/sigra/doctor.ex:484-495`
**Issue:** `audit_forwarding_hard_fail?` does `Keyword.get(forwarder_opts, :module)` over each
entry in `:forwarders`. If a host writes a malformed entry (e.g. `forwarders: [:bad]` or a bare
map), `Keyword.get/2` raises `FunctionClauseError` (verified), aborting the whole report with
an opaque stacktrace rather than the actionable diagnostic the tool exists to produce. A
diagnostic tool should be the most robust thing in the codebase against bad config, not the
least. (`Sigra.Application.attach_forwarders/0` has the same fragility with `Keyword.fetch!`,
but doctor's whole job is to report misconfig gracefully.)
**Fix:** Guard the shape before reading:
```elixir
Enum.any?(forwarders, fn
  forwarder_opts when is_list(forwarder_opts) ->
    module = Keyword.get(forwarder_opts, :module)
    dispatch = Keyword.get(forwarder_opts, :dispatch, :auto)
    (not is_nil(module) and not Code.ensure_loaded?(module)) or
      (dispatch == :async and not oban_running)
  _ ->
    # Malformed entry is itself a misconfiguration — flag, don't crash.
    true
end)
```

### WR-05: `jwt_configured?` / `async_email_configured?` assume well-typed sub-config

**File:** `lib/sigra/doctor.ex:434-444`
**Issue:** `jwt_configured?` does `Keyword.get(host_sigra, :jwt, []) |> Keyword.get(:enabled,
false)`. If a host passes `jwt: "true"` (a string, not a keyword list) the inner `Keyword.get`
raises. Same shape risk in `async_email_configured?` (`email: ...`), `rate_limiting_configured?`,
`oauth_configured?`, and `audit_forwarding_configured?`. The raw `host_sigra` here is
*unvalidated* host input read straight from `Application.get_env` (resolve_host_sigra:147-152)
— it has NOT been through `Sigra.Config.new!/NimbleOptions`, so the type guarantees those
schemas would provide do not hold. A diagnostic over raw config must defend against
ill-typed values.
**Fix:** Wrap sub-config reads in an `is_list/1` guard helper, e.g.
`defp sub(host, key), do: case Keyword.get(host, key, []) do l when is_list(l) -> l; _ -> [] end`,
and route all `configured?` predicates through it.

### WR-06: Test 8 asserts hard-fail on a module name that may become loadable

**File:** `test/sigra/doctor_test.exs:165-185`
**Issue:** Test 8 relies on `VeryDefinitelyNotALoadedModule12345` never being a loaded module
to exercise the D-09 #4 "forwarder module not loaded" path. This is a correct test today, but
the assertion is coupled to a global runtime fact (no module by that name exists). It is also
the *only* coverage for the module-not-loaded hard-fail in isolation — and `Code.ensure_loaded?`
is a real, non-injected call inside `audit_forwarding_hard_fail?` (line 489), so this branch
cannot be unit-tested via the injection seam. That is an unguarded gap in the otherwise
fully-injectable design: the D-04 injection seam covers predicates, host_sigra, and
oban_running, but **not** the dynamic `Code.ensure_loaded?(module)` forwarder check, so its
correctness rests entirely on this one brittle integration-style assertion.
**Fix:** Either accept a `:module_loaded?` injection function in
`audit_forwarding_hard_fail?` (parallel to `:oban_running`) so the branch is unit-testable
deterministically, or add a second test using a module that is loaded-then-purged to make the
not-loaded condition explicit rather than relying on a never-defined name.

## Info

### IN-01: `run/1` docstring claims `:quiet` strips hints from returned rows — it does not

**File:** `lib/sigra/doctor.ex:125-134`
**Issue:** The `run/1` doc says `:quiet` "omits hints from the returned rows." But `run/1`
delegates to `diagnose/1`, which never reads `:quiet` (lines 99-117) — every row always
carries its full `:hint`. The actual hint suppression happens only in the Mix task's
`print_row/2`. The docstring describes behavior the function does not implement.
**Fix:** Remove the `:quiet` paragraph from `run/1`'s doc, or move quiet-handling into the
library if returned-row stripping is genuinely intended.

### IN-02: `bcrypt_configured?/1` always returns false, making `:password_migration` rows degenerate

**File:** `lib/sigra/doctor.ex:412-414`
**Issue:** `bcrypt_configured?` is hardcoded `false`. The comment (410-411) explains bcrypt's
presence is the configured signal, but the result is that `:password_migration` can only ever
be `:missing` (bcrypt absent) or `:available` (bcrypt loaded) — never `:loaded_active`, since
`configured and all_deps_available` is unreachable. The `hint_active` / `hint_broken` strings
for this feature (lines 232-235) are dead. This is intentional per the comment, but the dead
hint strings and the impossibility of the active state are worth flagging as a maintainability
smell — a reader cannot tell the unreachable states are deliberate without the inline comment.
**Fix:** Either drop the unreachable `hint_active`/`hint_broken` for this feature, or add a
brief note in `feature_definitions` that `:password_migration` is intentionally a two-state
feature.

### IN-03: Test file reads source via relative path, coupling test to CWD

**File:** `test/sigra/mix/tasks/doctor_task_test.exs:160`
**Issue:** Test 8 does `File.read!("lib/mix/tasks/sigra.doctor.ex")` with a relative path. This
passes only when the test runner's CWD is the project root. It is conventional for `mix test`,
but a source-grep assertion is a brittle way to enforce "no `System.halt`" — it would also
match the string inside a comment or docstring.
**Fix:** Low priority. If kept, anchor to `__ENV__.file`-relative path resolution; better,
assert the behavior (exit is catchable, process not halted) which Test 6 already does, and drop
the grep test.

---

_Reviewed: 2026-05-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
