---
status: issues_found
phase: 141-seed-data-layer
depth: standard
reviewed: 2026-05-29T00:00:00Z
findings_count: 6
critical: 0
warning: 3
info: 3
---

# Phase 141: Code Review Report

**Reviewed:** 2026-05-29
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the six files comprising the Phase 141 seed data layer: `UserIdentity` schema + migration, `dev.exs` Argon2 override, `Personas` data module, `Seeds` orchestrator, and `seeds.exs` entry script. No critical (blocking) issues found. The CI safety guard, idempotency logic, and security posture are sound.

Three warnings were found: a stale misleading comment that could cause a future maintainer to misunderstand Dave's password-clearing flow, a check-then-insert key mismatch for `EnterpriseConnection` that uses a weaker lookup key than the actual unique index, and an audit count-threshold guard that is not atomic (partial-batch crash leaves the seeder in an indefinitely re-triggerable state). Three info findings cover minor matters.

---

## Warnings

### WR-01: Stale comment in `maybe_lock` catch-all implies password clearing that never happens there

**File:** `test/example/lib/example/demo/seeds.ex:138-142`

**Issue:** The `maybe_lock(user, _persona)` catch-all clause carries the comment "Dave's hashed_password is also cleared — do it here alongside the lockout check. On re-run the password is already nil so skip." The body of this clause is `user` — it does nothing. The password clearing actually happens in `maybe_schedule_deletion/2` via the `%{email: "dave@demo.sigra.dev"}` pattern at line 144. Any future maintainer reading the `maybe_lock` clause will believe the password clear is handled there and may delete the `maybe_schedule_deletion` Dave-specific clause, silently breaking Dave's seeded state.

**Fix:** Replace the misleading comment with an accurate one (or remove it entirely, since the body is a no-op):

```elixir
# Non-locked personas: nothing to do.
defp maybe_lock(user, _persona), do: user
```

---

### WR-02: `EnterpriseConnection` check-then-insert uses `display_name` alone — weaker than the actual unique index

**File:** `test/example/lib/example/demo/seeds.ex:302`

**Issue:** `Repo.get_by(EnterpriseConnection, display_name: "Acme Corp SSO")` looks up by `display_name` alone. The database unique index (`enterprise_connections_active_display_name_index`) is partial on `[:organization_id, :protocol, :display_name] WHERE status = 'active'`. The single-field lookup is weaker in two ways:

1. **False positive:** If a `draft` or `disabled` `EnterpriseConnection` named "Acme Corp SSO" already exists (e.g., from a prior abandoned setup), `get_by` returns that row and the seed skips inserting the `active` one. The Acme Corp SSO connection is never seeded, but the code silently claims it already exists.
2. **Wrong scope:** The check does not scope to `acme.id`, so in a multi-tenant dev database with two organizations both having a connection named "Acme Corp SSO", the wrong row could be returned.

For a single-tenant demo DB this is low-probability, but the pattern is incorrect relative to the index.

**Fix:** Scope the check to `organization_id` and `status`:

```elixir
existing =
  Repo.get_by(EnterpriseConnection,
    organization_id: acme.id,
    display_name: "Acme Corp SSO",
    status: :active
  )
```

---

### WR-03: Audit batch count-threshold guard is non-atomic — partial batch crash breaks idempotency

**File:** `test/example/lib/example/demo/seeds.ex:366-405`

**Issue:** `seed_audit_events/1` inserts 18 rows inside an `Enum.each/2` with no transaction wrapper. The guard fires if `admin_tied_count < 15`. If the process crashes or is killed mid-batch (e.g., after 7 rows), the next call to `run/0` sees 7 rows, determines `7 < 15`, and inserts another 18 rows, producing 25 rows. A second crash-then-retry cycle produces 43 rows. Each full batch that crosses the 15-row threshold locks in a permanently larger count, but any interrupted run accumulates unbounded duplicates.

The module docstring states "Calling `run/0` twice is safe," which is accurate only for the happy path (full batch insertion). The guarantee does not hold under partial failure.

**Fix:** Wrap the batch insertion in a transaction so it either completes fully or rolls back entirely, leaving the guard count below 15 for a clean retry:

```elixir
defp seed_audit_events(users) do
  admin = users["admin@demo.sigra.dev"]

  admin_tied_count =
    Repo.aggregate(
      from(a in AuditEvent, where: a.effective_user_id == ^admin.id),
      :count
    )

  if admin_tied_count < 15 do
    Repo.transaction(fn -> insert_audit_batch(admin) end)
  end
end
```

---

## Info

### IN-01: `demo_totp_secret/0` is used for both `admin` and `bob` but the `@doc` only mentions `admin`

**File:** `test/example/lib/example/demo/personas.ex:128`

**Issue:** The `@doc` for `demo_totp_secret/0` says "Used by both the `admin` and `bob` personas during seeding" — the `admin` mention is correct, but the code and persona spec confirm both admin and bob share this TOTP secret. This is not a bug; the shared secret is an intentional demo convenience. However, the doc is accurate. The issue is that the module-level `@doc` for `all/0` at line 30 does not mention `totp` key semantics accurately — it says "uses `demo_totp_secret/0`" only under `:totp`, which is correct. Minor doc-only matter.

**Fix:** No code change required. Optionally note in the `@moduledoc` that admin and bob share a TOTP secret intentionally to simplify the cheat-sheet display.

---

### IN-02: `maybe_schedule_deletion` for Dave matches on hard-coded email string instead of on persona field

**File:** `test/example/lib/example/demo/seeds.ex:144`

**Issue:** The clause `defp maybe_schedule_deletion(user, %{email: "dave@demo.sigra.dev"})` pattern-matches on a hard-coded string rather than on a dedicated `boolean` persona field (e.g., `%{clear_password: true}`). The dispatch behavior is inconsistent with the other `maybe_*` functions, which all match on a semantic boolean field (`confirmed: true`, `locked: true`, `scheduled_deletion: true`). If Dave's email is ever renamed (e.g., for a localization variant), this clause silently stops firing.

**Fix:** Add a `:clear_password` boolean key to the Dave persona in `Personas.all/0` and match on it:

```elixir
# In personas.ex, Dave persona:
%{..., clear_password: true, ...}

# In seeds.ex:
defp maybe_schedule_deletion(user, %{clear_password: true}) do
  ...
end
```

---

### IN-03: Migration `create_if_not_exists` for table but bare `timestamps()` default precision

**File:** `test/example/priv/repo/migrations/20260529000000_create_user_identities.exs:19`

**Issue:** The `UserIdentity` schema uses `timestamps(type: :utc_datetime)` (second precision). The migration also uses `timestamps(type: :utc_datetime)` — these match. However, compare with peer schemas in the same app (`UserMFACredential`, `UserPasskey`) that use `timestamps(type: :utc_datetime_usec)`. The `user_identities` table is the only new schema in this phase using second-precision timestamps. This is not a bug (the schema and migration are consistent with each other), but the inconsistency with peer schemas may cause unexpected behavior if future code joins or compares `user_identities.inserted_at` with `user_mfa_credentials.inserted_at` — the precision difference can cause spurious ordering differences.

**Fix:** Align with the rest of the app's schemas by using microsecond precision:

```elixir
# migration:
timestamps(type: :utc_datetime_usec)

# schema:
timestamps(type: :utc_datetime_usec)
```

---

_Reviewed: 2026-05-29_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
