---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Lockout and optional rate limits behave differently for existing and unknown accounts
area: security
severity: major
source: Phase 259 enumeration parity harness
files:
  - lib/sigra/auth.ex
  - lib/sigra/lockout.ex
  - lib/sigra/error.ex
  - priv/templates/sigra.install/core/session_controller.ex
  - priv/templates/sigra.install/core/auth.ex
  - priv/templates/sigra.install/core/reset_password_controller.ex
  - priv/templates/sigra.install/core/reset_password_live.ex
  - test/example/lib/example/accounts.ex
  - test/fixtures/brand/public-surfaces.json
  - test/example/test/example_web/enumeration_parity_test.exs
---

Registry rows tracked here in `test/fixtures/brand/public-surfaces.json`:

- `password-signin-repeat-attempts` (state `known_divergence`, compared dimension `result`, asserted at library level)
- `magic-link-rate-limit` (state `not_proven`)
- `password-reset-rate-limit` (state `not_proven`)

All three are about what a caller can learn from repeated requests, which the single-request parity rows do not cover (`password-signin`, `magic-link-request` are bounded to one request in a fresh state).

## 1. Lockout (asserted by the harness)

After the configured threshold of wrong passwords, an existing account and an unknown email get different library results.

- `lib/sigra/auth.ex:511` looks the user up, then `lib/sigra/auth.ex:515-533` checks lockout before password verification and returns `{:error, :account_locked}` (line 533) for a locked existing account.
- `lib/sigra/lockout.ex:57` is `def check(nil, _opts), do: :ok`: an unknown email is never locked, so it keeps returning `invalid_credentials` on every attempt.
- The two errors map to different library messages: `lib/sigra/error.ex:155` ("Invalid email or password.") and `lib/sigra/error.ex:160-161` (a "Too many attempts" message).
- The harness drives this through `Example.Accounts.authenticate_user/2` and asserts the `result` differs (reason and safe message) after the threshold plus one attempts.

Masked in the generated and example controllers: the catch-all clause at `priv/templates/sigra.install/core/session_controller.ex:101-105` (and its example-host equivalent) maps every other error, `:account_locked` included, to one flash, and the harness asserts the example controller's status, redirect and flash are the same after the threshold. A host that renders `Sigra.Error.safe_message/1` for the returned reason, or reads the typed result (`lib/sigra/auth.ex:345`), exposes the difference. This is bounded to what was compared: status, redirect and flash at the example controller, and the library result.

## 2. Magic-link and password-reset throttles (not proven, read in source)

The optional `:rate_limiter` is consulted only for existing accounts.

- Magic link: `lib/sigra/auth.ex:636-645`. An unknown email returns `{:ok, :sent}` (lines 639-641) before the limiter runs; an existing account reaches the limiter (lines 643-645) and can return `{:error, :rate_limited}`.
- Password reset: `lib/sigra/auth.ex:1123-1133`. The unknown-email branch runs a dummy hash and returns `{:ok, :sent}` (lines 1126-1129) before the limiter (lines 1131-1133).
- The generated wrappers do not pass a limiter, so the throttle is off until a host turns it on: `priv/templates/sigra.install/core/auth.ex:137-143` (magic link) and `:433-438` (reset); the example host is the same (`test/example/lib/example/accounts.ex:141` and `:463`). The library default is no rate limiting (`lib/sigra/auth.ex:620`).
- The generated magic-link controller swallows the result (`priv/templates/sigra.install/core/session_controller.ex:41-44`), so a default host shows one response either way.
- The generated reset controller and LiveView call the context only when the account exists (`priv/templates/sigra.install/core/reset_password_controller.ex:24-29`, `priv/templates/sigra.install/core/reset_password_live.ex:155-160`), so for an unknown email neither the limiter nor the library's dummy hash (`lib/sigra/auth.ex:1128`) runs. Timing is not compared by the harness.

The harness cannot drive any of this: the example host passes no limiter, so both rows are `not_proven` with a path:line blocker. Nothing here claims the throttles are exploitable in a default host; it records that the behaviour depends on whether an existing account is behind the address and is unproven either way.

## Why it matters

A host that enables the limiter, or that surfaces the typed result, lets a caller tell an existing account from an unknown address by repeating a request. The registry bounds what may be claimed: no document may extend the single-request parity rows to repeat attempts, lockout or throttling.

## Proposed fix direction

1. Lockout: make the externally visible result independent of account existence, for example by keeping lockout accounting keyed on the normalized email (or a limiter keyed before the account lookup) so an unknown address locks the same way, or by returning one external error and keeping `:account_locked` as audit and telemetry detail only.
2. Throttles: evaluate the limiter before the existence branch, keyed on the normalized email, so the outcome does not depend on whether an account exists; keep the wrappers returning one response.
3. Reset: have the generated controller and LiveView always call the context, so the existing work (including the dummy hash) is the same for both.

This needs bytes under `lib/` and `priv/templates/` and touches a documented return type (`lib/sigra/auth.ex:345`), so it is out of scope for Phase 259 (zero shipped bytes) and must go through the compatibility policy.

## Shrink discipline

- Fixing the lockout behaviour makes the harness test "every known_divergence row still differs on exactly the registered dimensions" fail. Remove or change the `password-signin-repeat-attempts` row in `test/fixtures/brand/public-surfaces.json`, update `@expected_divergence_dims` in `test/example/test/example_web/enumeration_parity_test.exs`, and drop its todo path.
- To make the two throttle rows provable, pass a limiter in the example host (`test/example/lib/example/accounts.ex:141`, `:463`), add a probe, then change the `magic-link-rate-limit` and `password-reset-rate-limit` rows to `parity` or `known_divergence`, or remove them. The `blocker` citations in those rows will move with the code; the harness fails on a citation that no longer resolves.
- Close this todo only when no registry row still points at it.
