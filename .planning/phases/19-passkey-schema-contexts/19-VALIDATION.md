---
phase: 19
slug: passkey-schema-contexts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18 / OTP 27) |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --stale` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~30–60 seconds (quick); ~2–3 minutes (full suite) |

Postgres must be live at `localhost:5432` with `postgres`/`postgres` credentials per CLAUDE.md. No `:postgres` tag exclusion.

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale` (or a focused `mix test test/sigra/passkeys_test.exs` when iterating on one module)
- **After every plan wave:** Run the full suite (`mix test`)
- **Before `/gsd-verify-work`:** Full suite must be green AND `mix credo --strict` and `mix dialyzer` must pass
- **Max feedback latency:** 60 seconds (quick); 180 seconds (full)

---

## Per-Task Verification Map

Tasks below will be filled in by the planner with exact task IDs. Plans expected: `19-01-*` schema + migration, `19-02-*` registration wrap, `19-03-*` authentication wrap (credential-confusion defense + sign-count handling), `19-04-*` management API (list/rename/delete) + Cloak vault extension.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | PK-01 | — | `{:wax_, "~> 0.7"}` compiles cleanly on OTP 27 | compile | `mix deps.compile wax_` | ❌ W0 | ⬜ pending |
| 19-01-02 | 01 | 1 | PK-01 | — | `UserPasskey` schema round-trips encrypted `public_key` via existing `Sigra.Vault` | unit | `mix test test/sigra/passkeys/user_passkey_test.exs` | ❌ W0 | ⬜ pending |
| 19-01-03 | 01 | 1 | PK-01 | — | Migration creates `credential_id` unique index (binary/bytea) and encrypted `public_key` column | integration | `mix test test/sigra/passkeys/migration_test.exs` | ❌ W0 | ⬜ pending |
| 19-02-01 | 02 | 2 | PK-03 | P-3 | `register/3` persists `rp_id` at registration time on `UserPasskey` row | unit | `mix test test/sigra/passkeys_test.exs:register` | ❌ W0 | ⬜ pending |
| 19-02-02 | 02 | 2 | PK-03 | — | COSE public key serializes/deserializes without data loss (ETF round-trip) | unit | `mix test test/sigra/passkeys/cose_serialization_test.exs` | ❌ W0 | ⬜ pending |
| 19-03-01 | 03 | 2 | PK-04 | P-6 (StrongKey CVE-2025-26788) | `authenticate/3` looks up `{user_id, credential_id}` BEFORE calling `Wax.authenticate/6`; mismatch returns `{:error, :credential_not_owned}` with no `wax_` call made | unit | `mix test test/sigra/passkeys_test.exs:credential_confusion_defense` | ❌ W0 | ⬜ pending |
| 19-03-02 | 03 | 2 | PK-05 | P-4 | Sign-count regression in `:warn` mode emits audit event `:passkey_sign_count_regression` + returns `{:ok, _}` | unit | `mix test test/sigra/passkeys_test.exs:sign_count_warn` | ❌ W0 | ⬜ pending |
| 19-03-03 | 03 | 2 | PK-05 | P-4 | Sign-count regression in `:require_reauth` mode returns `{:ok, :reauth_required}` | unit | `mix test test/sigra/passkeys_test.exs:sign_count_require_reauth` | ❌ W0 | ⬜ pending |
| 19-03-04 | 03 | 2 | PK-05 | P-4 | Sign-count regression in `:revoke` mode marks credential revoked + returns `{:error, :credential_revoked}` | unit | `mix test test/sigra/passkeys_test.exs:sign_count_revoke` | ❌ W0 | ⬜ pending |
| 19-03-05 | 03 | 2 | PK-05 | P-4 | Zero-to-zero sign count (resident-key / synced passkey) is NOT treated as regression | unit | `mix test test/sigra/passkeys_test.exs:sign_count_zero_allowed` | ❌ W0 | ⬜ pending |
| 19-04-01 | 04 | 3 | PK-07 | — | `list_for_user/1` returns all non-revoked credentials for user, ordered by `inserted_at` | unit | `mix test test/sigra/passkeys_test.exs:list_for_user` | ❌ W0 | ⬜ pending |
| 19-04-02 | 04 | 3 | PK-07 | — | `rename/3` happy path + `{:error, :not_found}` for missing credential | unit | `mix test test/sigra/passkeys_test.exs:rename` | ❌ W0 | ⬜ pending |
| 19-04-03 | 04 | 3 | PK-08 | — | `delete/2` happy path + `{:error, :not_found}` for missing credential | unit | `mix test test/sigra/passkeys_test.exs:delete` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/passkeys_test.exs` — context-level test module with shared fixtures for `UserPasskey` creation
- [ ] `test/sigra/passkeys/user_passkey_test.exs` — schema-level tests for changeset validation + encrypted round-trip
- [ ] `test/sigra/passkeys/cose_serialization_test.exs` — ETF round-trip tests for COSE key maps with integer keys
- [ ] `test/sigra/passkeys/migration_test.exs` — integration test that runs the generated migration and asserts column types + unique index
- [ ] `test/support/passkey_fixtures.ex` — fixture helpers (`valid_cose_key/0`, `passkey_fixture/1`, `regressed_sign_count_fixture/0`)

*wax_ test vectors should be sourced from SimpleWebAuthn fixtures per RESEARCH.md §WaxJson Bridge.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real authenticator round-trip (YubiKey 5, iCloud Keychain, Android passkey) | PK-03, PK-04 | Real hardware ceremonies cannot be automated inside `mix test` | Deferred to later LiveView phase — Phase 19 validates the data layer only; end-to-end browser ceremony lives in the UI phase |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
