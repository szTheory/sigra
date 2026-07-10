---
created: 2026-07-10T00:00:00.000Z
status: pending
resolves_phase: 223
title: Port impersonation defense-in-depth to all sensitive ops in the installer context template
area: security
files:
  - priv/templates/sigra.install/core/auth.ex
  - test/example/lib/example/accounts.ex
---

## What

The installer-generated context (`priv/templates/sigra.install/core/auth.ex`) only guards
**one** sensitive operation against admin-impersonation: `rename_passkey/4` (added in Phase 221
to complete SHIP-01, commit `f94277c0`). The example twin
(`test/example/lib/example/accounts.ex`, the established source of truth) guards **nine**
sensitive operations with `forbid_sensitive_operation/3` (+ `forbid_api_token_operation` for
API tokens):

- `account.password_change`
- `mfa.disable`
- `mfa.regenerate_backup_codes`
- `passkey.register`
- `passkey.rename`  ← the only one wired in the template today
- `passkey.delete`
- `account.deletion_schedule`
- `account.deletion_cancel`
- `account.data_export`

So a generated host's admin-impersonation session can still perform the other 8 sensitive
operations on behalf of an impersonated user without the app-level deny-guard (Sigra enforces
at the library layer; this is the missing **defense-in-depth** layer). This is pre-existing
template drift behind the example — the template's `auth.ex` was last substantively touched
2026-06-08 and never received the impersonation layer that the example twin has.

## Why deferred

Phase 221 (SHIP-01) scoped only the passkey-rename path (`save_passkey_name`) — that's what the
requirement named, and it was the item that broke `ci-gate`. The broader port is a larger,
separate change (8 more call sites + their callers' error-clause handling + golden re-bless +
verification) and was not in the phase's scope. Discovered while fixing the incomplete SHIP-01
half-fix at ship time.

## How

Mirror the example twin op-by-op into the template `auth.ex`:
1. For each guarded op above, add `opts \\ []` (or `details`) + a leading
   `with :ok <- forbid_sensitive_operation(opts, user, "<op>")` clause, matching the example.
2. Ensure each generated LiveView/controller caller passes `scope: ...` and handles
   `{:error, :impersonation_forbidden}` (rename already does; audit the others).
3. Consider `forbid_api_token_operation` + `@impersonation_api_token_denial_message` for the
   API-token path (example has it).
4. Re-bless the golden context fixture and add generator assertions per op.
5. Verify with the example's `impersonation_blocked_ops_test.exs` as the behavioral contract
   (`test/example/test/example_web/impersonation_blocked_ops_test.exs`).

## Done when

The installer-generated context guards the same set of sensitive operations against
impersonation as the example twin, verified by a generated-host equivalent of
`impersonation_blocked_ops_test.exs`.
