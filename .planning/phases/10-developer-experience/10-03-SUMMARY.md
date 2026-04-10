---
phase: 10
plan: 03
subsystem: config
tags: [dx, security, cookies, config, session]
requirements: [DX-04]
dependency_graph:
  requires:
    - Sigra.Config NimbleOptions schema (phase 01)
    - Sigra.MFA.Trust.cookie_opts/0 (phase 06)
    - Sigra.Application boot hooks (phase 09)
    - Auth.sigra_config() generated accessor (phase 01)
  provides:
    - "Sigra.Config{}.cookie_domain runtime config key"
    - Sigra.MFA.Trust.cookie_opts/1 (config-aware)
    - Sigra.Application.maybe_warn_missing_cookie_domain/0,2
    - Runtime remember_me_options/0 in generated UserAuth template
  affects:
    - lib/sigra/config.ex
    - lib/sigra/mfa/trust.ex
    - lib/sigra/application.ex
    - lib/sigra/testing.ex (trust_browser helper)
    - priv/templates/sigra.install/user_auth.ex
    - priv/templates/sigra.install/mfa_challenge_controller.ex
tech-stack:
  added: []
  patterns:
    - "Runtime-resolved cookie options (defp reading Auth.sigra_config() per call) replacing compile-time module attribute — prevents stale domain values frozen into host-app bytecode"
    - "Boot-time Logger.warning for soft-failable prod misconfiguration (alongside maybe_warn_audit_cleanup_fallback precedent)"
    - "Soft + hard deprecation combo on shim fn (@doc deprecated + @deprecated) to flag callers while preserving API"
key-files:
  created:
    - test/sigra/cookie_domain_test.exs
    - test/sigra/application_cookie_warning_test.exs
  modified:
    - lib/sigra/config.ex
    - lib/sigra/mfa/trust.ex
    - lib/sigra/application.ex
    - lib/sigra/testing.ex
    - priv/templates/sigra.install/user_auth.ex
    - priv/templates/sigra.install/mfa_challenge_controller.ex
    - test/sigra/templates/session_templates_test.exs
decisions:
  - "D-08: Top-level :cookie_domain option in Sigra.Config struct (single source of truth, not per-cookie)"
  - "D-09: Per-env defaults — nil in dev/test, nil + Logger.warning in :prod"
  - "D-10: Explicit {:or, [:string, nil]} — no :parent / :auto atom sugar"
  - "D-11: Two cookie write sites honor the config (generated UserAuth remember_me + generated mfa_challenge_controller via Trust.cookie_opts/1); FetchSession confirmed read-only via grep"
metrics:
  completed: "2026-04-09"
  tasks: 2
  files_changed: 7
  tests_added: 16
---

# Phase 10 Plan 03: Cookie Domain Config Summary

One-liner: Added `:cookie_domain` to `Sigra.Config`, threaded through both cookie write sites (generated UserAuth remember-me, generated MFA trust cookie) via a new `Sigra.MFA.Trust.cookie_opts/1` clause and a runtime-resolved `remember_me_options/0` function, plus a `:prod` boot-time `Logger.warning` when unset — satisfying DX-04 (cookie domain configurable with sensible defaults and loud prod failure).

## What was built

### Task 1 — Config key + Trust.cookie_opts/1 (commit `de7beae` → `080fd4f`)
- Added `cookie_domain` key to the `@schema` NimbleOptions keyword list in `lib/sigra/config.ex` with `type: {:or, [:string, nil]}, default: nil` and a doc block pointing to `guides/recipes/subdomain-auth.md`.
- Added the matching struct field `cookie_domain: nil` and extended the `@type t` typespec to include `cookie_domain: String.t() | nil`.
- Added `Sigra.MFA.Trust.cookie_opts/1` with two clauses:
  - `%Sigra.Config{cookie_domain: nil}` → returns base `@cookie_opts` (host-only, no `:domain`)
  - `%Sigra.Config{cookie_domain: domain} when is_binary(domain)` → `Keyword.put(@cookie_opts, :domain, domain)`
- Marked `Sigra.MFA.Trust.cookie_opts/0` with both `@doc deprecated:` (doc annotation) and `@deprecated` (hard compile warning) so downstream callers get a visible deprecation message.
- Updated `Sigra.Testing.trust_browser/3` to build/accept a `%Sigra.Config{}` and call `cookie_opts/1` so the library compiles cleanly with `warnings-as-errors`.
- Authored `test/sigra/cookie_domain_test.exs` (9 tests covering: default nil, nil acceptance, string acceptance, atom rejection (`:parent`, `:auto`), integer rejection, `cookie_opts/1` with/without `:domain`, deprecated `cookie_opts/0` shim still returning base opts).

### Task 2 — Runtime remember_me_options, MFA controller wiring, boot warning (commit `3994ce1` → `4aa7030`)
- **`priv/templates/sigra.install/user_auth.ex`:** Replaced the compile-time `@remember_me_options` module attribute with a runtime `defp remember_me_options/0`:
  - Kept `@remember_me_static_options` holding the immutable keys (`sign`, `max_age`, `same_site`, `http_only`).
  - `remember_me_options/0` reads `<%= context_module %>.sigra_config()` each call, injects `:secure` via `Keyword.put` keyed on `Mix.env() == :prod`, and appends `:domain` iff `config.cookie_domain` is a binary.
  - `maybe_write_remember_me_cookie/3` now calls `remember_me_options()` instead of `@remember_me_options`.
- **`priv/templates/sigra.install/mfa_challenge_controller.ex`:** `maybe_set_trust_cookie/3` already computed `config = Auth.sigra_config()`; changed the cookie-opts call to `Sigra.MFA.Trust.cookie_opts(config) ++ [max_age: trust_ttl]`.
- **`lib/sigra/application.ex`:** Added `maybe_warn_missing_cookie_domain/0` (reads `Application.get_env(:sigra, :otp_app)` → `Application.get_env(otp_app, :sigra_config)` → looks up `:cookie_domain`) and a testable `maybe_warn_missing_cookie_domain/2` that takes `(env, cookie_domain)` directly. Only `:prod` + `nil` emits the `Logger.warning("... cookie_domain is not set ...")`; all other combinations return `:ok`. Wired into `start/2` alongside the existing `maybe_warn_audit_cleanup_fallback/0` precedent.
- **`test/sigra/templates/session_templates_test.exs`:** Updated the "remember-me has secure flag" assertion from `secure: Mix.env() == :prod` (compile-time literal) to `:secure, Mix.env() == :prod` (runtime `Keyword.put` form) to match the new pattern — the semantics are preserved.
- Authored `test/sigra/application_cookie_warning_test.exs` (7 tests: `:prod` + nil warns, `:prod` + string does not warn, `:dev` never warns (both nil and set), `:test` never warns, user_auth template references `sigra_config()` + `config.cookie_domain` at runtime, user_auth no longer uses the raw `@remember_me_options` attribute in `put_resp_cookie`, mfa_challenge_controller calls `Trust.cookie_opts(config)`).

## Tests added

- `test/sigra/cookie_domain_test.exs` — 9 tests
- `test/sigra/application_cookie_warning_test.exs` — 7 tests

**Total:** 16 new tests. All pass (`mix test test/sigra/cookie_domain_test.exs test/sigra/application_cookie_warning_test.exs` → 16/16).

## Verification results

- `mix test test/sigra/cookie_domain_test.exs` → 9 tests, 0 failures
- `mix test test/sigra/application_cookie_warning_test.exs` → 7 tests, 0 failures
- `mix compile --warnings-as-errors` → clean compile (0 warnings, 0 errors)
- `mix test` (full suite) → 1206 tests, 3 pre-existing failures (unrelated; see Deferred Issues below)
- Grep acceptance criteria (all match):
  - `rg 'cookie_domain' lib/sigra/config.ex` → 4 matches (schema + doc + struct + typespec)
  - `rg 'def cookie_opts\(%Sigra.Config' lib/sigra/mfa/trust.ex` → 2 matches (nil clause + binary clause)
  - `rg '@deprecated' lib/sigra/mfa/trust.ex` → 1 match on `cookie_opts/0`
  - `rg 'put_resp_cookie' lib/sigra/plug/fetch_session.ex` → 0 matches (Open Q2 path (b) still holds; FetchSession is read-only for cookies)
  - `rg 'defp remember_me_options' priv/templates/sigra.install/user_auth.ex` → 1 match
  - `rg '@remember_me_options' priv/templates/sigra.install/user_auth.ex` → 0 matches (only the renamed `@remember_me_static_options` remains)
  - `rg 'Sigra.MFA.Trust.cookie_opts\(config\)' priv/templates/sigra.install/mfa_challenge_controller.ex` → 1 match
  - `rg 'maybe_warn_missing_cookie_domain' lib/sigra/application.ex` → 5 matches (definition, arity-2 match clause, fall-through clause, arity-0 entry, caller in `start/2`)
  - `rg 'cookie_domain is not set' lib/sigra/application.ex` → 1 match (Logger.warning body)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `@deprecated` on `Trust.cookie_opts/0` broke `warnings-as-errors` in pre-existing `Sigra.Testing.trust_browser/3`**
- **Found during:** Task 1 verification (`mix compile --warnings-as-errors`)
- **Issue:** The plan required both `@deprecated` and grep-pinned acceptance of its presence, but `Sigra.Testing.trust_browser/3` was calling the deprecated `/0` form, tripping `warnings-as-errors`.
- **Fix:** Updated `Sigra.Testing.trust_browser/3` to read an optional `:config` from `opts` (defaulting to `%Sigra.Config{}` so the existing callers keep working with a zero-value struct whose `cookie_domain` is nil), and call `Sigra.MFA.Trust.cookie_opts(config)`. Kept `@deprecated` on `/0` to satisfy the acceptance grep.
- **Files modified:** `lib/sigra/testing.ex`
- **Commit:** `080fd4f`

**2. [Rule 3 - Blocking] Pre-existing `Sigra.Templates.SessionTemplatesTest` "remember-me has secure flag" asserted compile-time literal**
- **Found during:** Task 2 full-suite run
- **Issue:** The test asserted `content =~ "secure: Mix.env() == :prod"` against the template source. My Task 2 refactor moved `:secure` injection from a literal keyword list entry into `Keyword.put(@remember_me_static_options, :secure, Mix.env() == :prod)`. The behavior is identical but the literal source substring changed.
- **Fix:** Updated the assertion to `:secure, Mix.env() == :prod` (the comma form produced by `Keyword.put/3`), with a comment explaining the Phase 10 D-09 runtime-resolution rationale.
- **Files modified:** `test/sigra/templates/session_templates_test.exs`
- **Commit:** `4aa7030`

**3. [Scope clarification] Plan referenced `Sigra.Config.new/1`; the actual public API is `Sigra.Config.new!/1`**
- **Found during:** Task 1 test authoring
- **Issue:** The plan's behavior table wrote `Sigra.Config.new(cookie_domain: nil)` but the module only exposes `new!/1` (bang variant). No corresponding `/1` non-bang exists.
- **Fix:** Tests use `Config.new!/1`. Pattern matches the existing `test/sigra/config_test.exs`. No plan objective changes; this is a wording fix.
- **Commit:** `de7beae` (tests) / `080fd4f` (implementation)

### Deferred Issues

These pre-existing failures were out of scope per Rule 4 / deferred-items tracking (verified pre-existing via `git stash` before starting Task 1):

- `Sigra.Audit.CursorPortabilityTest` "paginates deterministically across cursor boundary on this adapter" — phase 9 cursor stability regression, unrelated to cookie_domain.
- `Mix.Tasks.Sigra.InstallTest` "renders fixtures template" and "renders fixtures template with Phase 4 session fixtures" — template rendering compile error unrelated to 10-03 (EEx → Erlang quote bug on phase 10-02's AuthFixtures template).

Logged to `.planning/phases/10-developer-experience/deferred-items.md` on 2026-04-09.

## Commits

| Commit   | Type | Scope | Message |
|----------|------|-------|---------|
| `de7beae` | test | 10-03 | add failing tests for cookie_domain config and Trust.cookie_opts/1 |
| `080fd4f` | feat | 10-03 | add :cookie_domain config + Sigra.MFA.Trust.cookie_opts/1 |
| `3994ce1` | test | 10-03 | add failing tests for boot warning and runtime cookie_domain in templates |
| `4aa7030` | feat | 10-03 | runtime remember_me_options in UserAuth + MFA trust cookie + boot warning |

## Threat Model Status

All four mitigate-dispositioned threats from the plan's threat register are now addressed:

- **T-10-01** (overly-broad cookie_domain leak): Schema accepts any string — plan 10-05 `subdomain-auth.md` carries the documentation mitigation (out of scope for 10-03).
- **T-10-02** (silent nil cookie_domain in :prod): Mitigated via `maybe_warn_missing_cookie_domain/2` Logger.warning.
- **T-10-11** (compile-time @remember_me_options frozen value): Mitigated — attribute replaced with runtime `defp remember_me_options/0` reading `Auth.sigra_config()` each call.
- **T-10-12** (cookie_domain accepted as atom): Mitigated — `{:or, [:string, nil]}` rejects atoms with a NimbleOptions.ValidationError; Task 1 tests 4-5 assert both `:parent` and `:auto` are rejected.
- **T-10-13** (FetchSession cookie write site Open Q2): Accepted — grep-confirmed read-only; acceptance criterion pins `rg put_resp_cookie lib/sigra/plug/fetch_session.ex` = 0 matches so regression is caught if a write path is ever added.

No new threat surface introduced.

## Known Stubs

None. All wiring is complete — `cookie_domain` flows from user config → `Sigra.Config` struct → both cookie write sites → the actual `put_resp_cookie` call. No placeholder values, no `TODO`/`FIXME`, no empty `[]`/`nil` data paths.

## Self-Check: PASSED

- `lib/sigra/config.ex` — FOUND (cookie_domain schema key + struct field + typespec verified via grep)
- `lib/sigra/mfa/trust.ex` — FOUND (`cookie_opts/1` with 2 clauses + `@deprecated` on `/0` verified via grep)
- `lib/sigra/application.ex` — FOUND (`maybe_warn_missing_cookie_domain/0` and `/2` definitions verified via grep)
- `lib/sigra/testing.ex` — FOUND (`trust_browser/3` updated to use `cookie_opts/1`)
- `priv/templates/sigra.install/user_auth.ex` — FOUND (`defp remember_me_options` + `@remember_me_static_options` verified via grep; no raw `@remember_me_options`)
- `priv/templates/sigra.install/mfa_challenge_controller.ex` — FOUND (`Sigra.MFA.Trust.cookie_opts(config)` call site verified via grep)
- `test/sigra/cookie_domain_test.exs` — FOUND (9 tests passing)
- `test/sigra/application_cookie_warning_test.exs` — FOUND (7 tests passing)
- `test/sigra/templates/session_templates_test.exs` — FOUND (updated assertion)
- Commit `de7beae` — FOUND in `git log`
- Commit `080fd4f` — FOUND in `git log`
- Commit `3994ce1` — FOUND in `git log`
- Commit `4aa7030` — FOUND in `git log`
