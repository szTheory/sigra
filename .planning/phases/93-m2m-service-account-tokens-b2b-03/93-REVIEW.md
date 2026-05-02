---
phase: 93-m2m-service-account-tokens-b2b-03
reviewed: 2026-05-01T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/sigra/service_accounts.ex
  - lib/sigra/oauth/token.ex
  - lib/sigra/plug/require_membership.ex
  - lib/sigra/plug/require_org_mfa.ex
  - lib/sigra/scope.ex
  - lib/sigra/config.ex
  - lib/sigra/workers/account_deletion.ex
  - lib/sigra/workers/email_delivery.ex
  - lib/sigra/workers/token_cleanup.ex
  - lib/sigra/install/features/core.ex
  - lib/sigra/install/features/organizations.ex
  - priv/templates/sigra.install/core/oauth_token_controller.ex
  - priv/templates/sigra.install/organizations/service_account.ex
  - priv/templates/sigra.install/organizations/service_account_credential.ex
  - priv/templates/sigra.install/organizations/service_accounts_migration.exs
  - priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex
  - priv/templates/sigra.install/organizations/copy_to_clipboard_hook.js
  - priv/templates/sigra.install/organizations/app_js_clipboard_injection.js
  - priv/templates/sigra.install/organizations/router_injection.ex
  - priv/templates/sigra.upgrade/alter_add_service_accounts.exs
  - guides/recipes/m2m-service-accounts.md
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: issues
---

# Phase 93: Code Review Report

**Reviewed:** 2026-05-01
**Depth:** standard
**Files Reviewed:** 17+
**Status:** issues\_found

## Summary

Phase 93 delivers the M2M service-account feature: `Sigra.ServiceAccounts`, `Sigra.OAuth.Token.client_credentials/2`, SA JWT claims, `FetchBearer` SA fork, plug short-circuits, a full-parity `OrganizationServiceAccountsLive` (1086 lines), generator wiring, and gap-closure plans 06–10 that added audit atomicity tests, parity test coverage, generator gating tests, full UI-SPEC LiveView, and an E2E lifecycle test.

The implementation is largely sound. Two critical bugs were found:

1. A credential-secret bypass bug in `Sigra.OAuth.Token` where the `verify_credential/2` clause for time-limited credentials compares the submitted hash to itself rather than the stored hash, and passes a `DateTime` instead of a credential struct downstream.
2. An exception-swallowing pattern in `Sigra.ServiceAccounts` where a catch-all `rescue` converts all unexpected exceptions (not just DB constraint violations) into a silent `{:error, atom}` return, suppressing crashes that would indicate programming errors.

Four warnings cover a stale metadata artifact, a UI rendering defect in the generated LiveView, inconsistent Oban queue assignment in a worker, and an undocumented D-93-18 plan divergence that was acknowledged but never resolved.

---

## Critical Issues

### CR-01: verify\_credential bypasses secret check for time-limited credentials

**File:** `lib/sigra/oauth/token.ex:62`

**Issue:** The `verify_credential/2` clause that handles credentials with a non-nil, non-expired `expires_at` calls `verify_secret(submitted_hash, submitted_hash, expires_at)`. This passes `submitted_hash` as both the `stored_hash` (first argument) and the `submitted_hash` (second argument), making the comparison `Token.secure_compare(submitted_hash, submitted_hash)` which is always `true`. Any client knowing only the `client_id` of an unexpired credential can obtain a valid JWT by submitting *any* non-empty `client_secret` string. Additionally, the `credential` positional argument receives the `expires_at` `DateTime` value rather than the credential struct, so `verify_service_account/2` would then call `config.repo.get(schema, expires_at.service_account_id)` and crash with a `KeyError`.

In practice the crash surfaces before the bypass is exploitable (the wrong credential struct causes an immediate error), but fixing the crash exposes the bypass. Both issues originate from the same mismatched argument at line 62.

The correct call mirrors the non-expiring clause at line 67:

```elixir
# BROKEN (line 54-64)
defp verify_credential(%{expires_at: expires_at}, submitted_hash)
     when not is_nil(expires_at) do
  cond do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt ->
      Token.secure_compare(submitted_hash, @dummy_hash)
      {:error, :invalid_client}

    true ->
      verify_secret(submitted_hash, submitted_hash, expires_at)  # BUG: wrong args
  end
end

# FIXED: bind the full credential struct and use it
defp verify_credential(%{expires_at: expires_at} = credential, submitted_hash)
     when not is_nil(expires_at) do
  cond do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt ->
      Token.secure_compare(submitted_hash, @dummy_hash)
      {:error, :invalid_client}

    true ->
      verify_secret(credential.hashed_client_secret, submitted_hash, credential)
  end
end
```

**Severity:** BLOCKER — authentication bypass for all service-account credentials that have an `expires_at` value set.

---

### CR-02: Catch-all rescue swallows all exceptions in SA mutation functions

**File:** `lib/sigra/service_accounts.ex:402-411`

**Issue:** The `emit_constraint_or_reraise/3` function's catch-all clause (third clause) catches every exception that does not match `Ecto.ConstraintError` or a known `Postgrex.Error` integrity code, emits `reason: :database_error` telemetry, and returns `{:error, atom}`. The `_ = e` discard suppresses the exception entirely. This means `RuntimeError`, `ArgumentError`, `FunctionClauseError`, `UndefinedFunctionError`, and other programming errors in `config.repo.transaction/1` or in the `Multi` composition are silently converted to a user-facing "aborted" response. Bugs introduced later (e.g., a bad Multi step or a missing config key) would produce misleading error atoms rather than crash logs, significantly complicating diagnosis.

The catch-all clause is called from all four SA mutation functions (`create`, `revoke`, `create_credential`, `revoke_credential`) via the `rescue e ->` block.

The same concern applies to `issue_token/4` at lines 212-220, which has a bare `rescue e ->` that also calls `classify_error(e)` then swallows any exception type.

**Recommendation:** Re-raise non-DB exceptions using `Kernel.reraise/2`:

```elixir
# FIXED: only suppress known DB errors; re-raise everything else
defp emit_constraint_or_reraise(e, _action, _atom) do
  reraise e, __STACKTRACE__
end
```

If the intent is to also suppress unknown `Postgrex.Error` codes as generic DB errors, add a separate clause for `%Postgrex.Error{}` that re-raises only non-integrity errors (e.g. connection errors, query syntax errors). The `classify_error/1` helper already distinguishes these two cases — `emit_constraint_or_reraise` should mirror that logic:

```elixir
# Keep DB integrity violations as controlled errors;
# re-raise connection/programming errors.
defp emit_constraint_or_reraise(e, action, atom) do
  case classify_error(e) do
    :constraint_violation ->
      :telemetry.execute([:sigra, :audit, :log_safe_error], %{count: 1},
        %{action: action, reason: :constraint_violation})
      {:error, atom}

    :database_error when is_struct(e, Postgrex.Error) ->
      :telemetry.execute([:sigra, :audit, :log_safe_error], %{count: 1},
        %{action: action, reason: :database_error})
      {:error, atom}

    _ ->
      reraise e, __STACKTRACE__
  end
end
```

**Severity:** BLOCKER — programming errors in SA mutations are silently swallowed, masking bugs and making post-deploy diagnosis significantly harder.

---

## Warnings

### WR-01: Spurious `credential_id_resolver: true` in audit metadata

**File:** `lib/sigra/service_accounts.ex:122`

**Issue:** The `create_credential/4` function passes `credential_id_resolver: true` inside the `:metadata` map passed to `append_audit/5`. The `Audit.log_multi_safe/3` API recognises only top-level opts named `*_resolver` (e.g. `:target_resolver`, `:organization_id_resolver`) as function callbacks; a key inside the `:metadata` map is stored verbatim in the audit row's JSONB `metadata` column. Every `service_account.credential_create` audit event will contain `{"credential_id_resolver": true, ...}` which has no semantic value and pollutes the audit log schema. It appears to be a leftover development marker that was never removed.

**Fix:**

```elixir
# REMOVE this line from the metadata map at service_accounts.ex:122:
credential_id_resolver: true,
```

If the intent was to resolve the credential ID into the audit target, that is already handled by `:target_resolver` at line 118.

**Severity:** WARNING — spurious data in audit metadata. No functional impact but violates audit log schema cleanliness (D-20 metadata hygiene).

---

### WR-02: `expires_relative/1` returns raw HTML that HEEx escapes as text

**File:** `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex:1057`

**Issue:** `expires_relative/1` returns the string `"<span class=\"text-error\">Expired</span>"` for expired credentials. The template renders it via `{expires_relative(cred.expires_at)}` (line 864), which uses HEEx's curly-brace interpolation. In HEEx, `{expr}` HTML-escapes the result, so the output will be the literal text `&lt;span class="text-error"&gt;Expired&lt;/span&gt;` rather than a red "Expired" badge. The intended expired-state styling will not render.

**Fix:** Either return a plain string from the function and add a separate badge component in the template, or use `Phoenix.HTML.raw/1`:

```elixir
# Option A: return Phoenix.HTML.safe instead of a raw string
defp expires_relative_html(nil), do: Phoenix.HTML.raw("—")
defp expires_relative_html(%DateTime{} = dt) do
  seconds = DateTime.diff(dt, DateTime.utc_now(), :second)
  cond do
    seconds <= 0 -> Phoenix.HTML.raw("<span class=\"text-error\">Expired</span>")
    seconds < 3600 -> Phoenix.HTML.raw("in #{div(seconds, 60)} minutes")
    ...
  end
end

# In template: use raw() wrapper
{Phoenix.HTML.raw(expires_relative_html(cred.expires_at))}
```

Or restructure the template to conditionally render the badge inline in HEEx.

**Severity:** WARNING — generated template renders incorrect HTML for expired credentials; the expiry status will not display the intended error styling to users.

---

### WR-03: `TokenCleanup` worker uses `:sigra_mailer` queue instead of `:sigra_lifecycle`

**File:** `lib/sigra/workers/token_cleanup.ex:22`

**Issue:** `TokenCleanup` is configured with `queue: :sigra_mailer` but implements lifecycle cleanup (not email delivery). It calls `OptionalDeps.ensure_available!(:lifecycle_jobs, ...)` (line 31), asserting its dependency category as `:lifecycle_jobs`. The `:sigra_mailer` queue declaration is inconsistent — the queue is documented (in the module's own instructions) as used for email delivery with 10 concurrent workers, while lifecycle jobs should use `:sigra_lifecycle` (per the `AccountDeletion` worker's docs). This means token cleanup jobs run on the mailer queue, competing with email delivery for concurrency slots, and host apps that configure `sigra_lifecycle: 5` without a higher `sigra_mailer` concurrency may see token cleanup delayed during email bursts.

Compare: `AccountDeletion` uses `queue: :sigra_lifecycle` (line 51 of `account_deletion.ex`), which is the correct queue for lifecycle work.

**Fix:**

```elixir
# lib/sigra/workers/token_cleanup.ex:21-24
use Oban.Worker,
  queue: :sigra_lifecycle,   # was: :sigra_mailer
  max_attempts: 1
```

**Severity:** WARNING — token cleanup runs on the wrong Oban queue, competing with email delivery. Not data-loss, but operationally incorrect and may cause confusion for operators tuning queue concurrency.

---

### WR-04: OAuth controller `oauth_token_controller.ex` gate diverges from D-93-18 with no plan resolution

**File:** `lib/sigra/install/features/core.ex:375` and `lib/sigra/install/features/core.ex:735` (approximately)

**Issue:** Design decision D-93-18 documented that `oauth_token_controller.ex` should be gated on `--jwt` alone (not on organizations). The actual implementation gates it on BOTH `--jwt` AND `--organizations`. This was acknowledged as a plan divergence in 93-08-SUMMARY.md "Decision 2", but the summary recommends resolving it in a follow-up ("either update D-93-18 or modify core.ex") which has not yet happened. The current state is:

- `--jwt --organizations` → controller emitted (correct per implementation)
- `--jwt --no-organizations` → controller suppressed (contradicts D-93-18)

The generator test locks the actual behavior, so it won't break, but D-93-18 remains inaccurate and the design intent (JWT-only gating) is not enforced.

**Fix:** Either update D-93-18 to document that the endpoint requires both flags (accepting the current behavior as correct), or update `core.ex` to remove the `organizations?` guard from the OAuth controller/route emission. The design intent (allowing non-org apps to expose `client_credentials`) appears to be what D-93-18 describes; if that intent remains valid, the implementation should be corrected.

**Severity:** WARNING — documentation/design debt. Does not affect runtime behavior of the current locked test suite, but leaves D-93-18 inaccurate for future contributors.

---

## Info

### IN-01: Double-hashing in `create_credential/4` is redundant

**File:** `lib/sigra/service_accounts.ex:100,107`

**Issue:** `Token.generate_hashed_token()` at line 100 returns `{raw_base64, sha256_of_raw_bytes}`. The returned `_hashed_secret` is discarded (underscore-prefixed). Line 107 then calls `Token.hash_token(raw_secret)` which computes `SHA256(raw_base64_string)` — a different value from `SHA256(raw_bytes)` because the input is the base64-encoded form. The code is internally consistent (verification also calls `hash_token(submitted_string)`), but the hash from `generate_hashed_token()` is computed and thrown away, doing unnecessary work.

**Fix:** Either use the hash returned by `generate_hashed_token()` (after checking that the hash input matches what verification will present), or stop using the underscore convention and name it `_hashed_secret_unused` to make the discard intent explicit.

**Severity:** INFO — minor redundancy. No correctness impact.

---

### IN-02: `app_js_clipboard_injection.js` assumes `colocatedHooks` symbol exists

**File:** `priv/templates/sigra.install/organizations/app_js_clipboard_injection.js:3`

**Issue:** The injection fragment includes `hooks: { ...colocatedHooks, ...ClipboardHooks }`. This assumes the host's `app.js` already defines a `colocatedHooks` variable. This mirrors the passkeys injection pattern, so it is an established project convention, not a Phase 93-specific defect. However, a host app that installs organizations+JWT without passkeys will have no passkeys injection and may not have `colocatedHooks` defined. If `colocatedHooks` is undefined, the spread `...colocatedHooks` throws a `TypeError` at runtime.

**Fix (advisory):** The injection fragment (or the recipe docs) should note that `colocatedHooks` must be declared before this injection point. Alternatively, use `...(colocatedHooks || {})` or restructure the injection to a `Hooks` named merge that doesn't assume pre-existing variables.

**Severity:** INFO — risk is low (most Phoenix 1.8 apps use colocated hooks), but can surprise hosts that skip passkeys.

---

### IN-03: `handle_params/3` accesses `config.roles` without nil-guard

**File:** `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex:82-83`

**Issue:** `handle_params/3` calls `config.roles` and `config.invitation_admin_roles` directly after `Organizations.__sigra_org_config__()`. If a host's `__sigra_org_config__/0` returns a config without `:invitation_admin_roles`, the pattern match at line 84 (`invitation_admin_roles = config.invitation_admin_roles`) would crash with a `KeyError`. The generated `Organizations` module is expected to always populate these fields, but a host that customizes the config struct may omit them.

**Fix:** Use `Map.get/3` with a default:

```elixir
invitation_admin_roles = Map.get(config, :invitation_admin_roles, [])
```

**Severity:** INFO — defensive coding improvement for generated host code. Only affects hosts that customize `__sigra_org_config__/0` to omit `:invitation_admin_roles`.

---

## Cross-Cutting Notes

### Oban worker pattern restoration (Plans 93-08)

All five Oban workers (`account_deletion.ex`, `audit_cleanup.ex`, `cleanup_expired_invitations.ex`, `email_delivery.ex`, `token_cleanup.ex`) were restored to the outer-module `if Code.ensure_loaded?(Oban.Worker) do defmodule ... end` pattern during Plan 93-08's auto-fix pass. This is the correct pattern — see WR-03 above for a residual queue assignment inconsistency in `token_cleanup.ex` that was not part of that fix.

### SA short-circuit ordering in plugs

`RequireMembership.call/2` checks `is_nil(scope) or is_nil(scope.active_organization)` before the SA short-circuit at `Map.get(scope, :actor_type) == :service_account`. Because `FetchBearer` builds SA scopes with a resolved `active_organization` (the `with` chain fails to nil scope if the org cannot be loaded), a valid SA request will always have `active_organization` set and will reach the short-circuit branch. The ordering is safe for the normal request path.

---

_Reviewed: 2026-05-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
