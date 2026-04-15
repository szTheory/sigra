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

Per-task rows below reflect the plans as written (revised 2026-04-15). Plan shape: `19-01-*` schema + COSE + D-16 smoke + migration; `19-02-*` config slot + registration primitive + `Sigra.Passkeys.register/4` + list/count + `known_transport?/1`; `19-03-*` StrongKey guard + sign-count policy + `authenticate/4`; `19-04-*` rename/delete + vault promotion + upgrade step + boot-check.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | PK-01 | — | `{:wax_, "~> 0.7"}` compiles cleanly on OTP 27; `Sigra.Passkeys.CoseKey.serialize/1` + `deserialize/1` round-trip a real `wax_`-returned COSE key (ETF + `:safe`, D-17); D-16 smoke test executes `Wax.register/3` → `Wax.authenticate/6` end-to-end against SimpleWebAuthn fixture vectors | compile + unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/passkeys/cose_serialization_test.exs test/sigra/passkeys/wax_roundtrip_test.exs --trace` | ❌ W0 | ⬜ pending |
| 19-01-02 | 01 | 1 | PK-01 | — | Generated `UserPasskey` schema round-trips encrypted `public_key` via `<app_module>.Encrypted.Binary`; migration creates unique `credential_id` index and `:uuid` `aaguid` column (D-01) on Postgres | integration | `mix test test/sigra/passkeys/user_passkey_test.exs test/sigra/passkeys/migration_test.exs` | ❌ W0 | ⬜ pending |
| 19-02-01 | 02 | 2 | PK-03 | P-3 | `config.passkeys` NimbleOptions sub-schema accepts `sign_count_policy`, `max_per_user`, `rp_id`, `origin`, `attestation`, `user_verification`, `timeout_ms` with documented defaults (D-05/D-06); `Sigra.Passkeys.Registration.new_challenge/2` + `verify/4` are Plug.Conn-free (D-09); `passkey.` audit prefix reserved | unit | `mix test test/sigra/passkeys/registration_test.exs` | ❌ W0 | ⬜ pending |
| 19-02-02 | 02 | 2 | PK-03, PK-04, PK-05 | P-3 | `Sigra.Passkeys.register/4` persists `rp_id` from `config.passkeys[:rp_id]` only (never from params), enforces `max_per_user` cap atomically inside `Repo.transact/2` (D-06), emits `passkey.register.success` audit via `log_multi_safe/3` with rollback on audit failure (D-12); `list_for_user/2` + `count_for_user/2` expose read helpers; `known_transport?/1` exists and returns `true` for `~w(usb nfc ble internal hybrid)a` and `false` otherwise (CONTEXT.md D-02 telemetry helper) | unit | `mix test test/sigra/passkeys_test.exs --trace` | ❌ W0 | ⬜ pending |
| 19-03-01 | 03 | 3 | PK-04, PK-07 | P-6 (StrongKey CVE-2025-26788) | `authenticate/4` performs `{user_id, credential_id}` pre-lookup BEFORE calling `Wax.authenticate/6`; mismatch returns `{:error, :credential_not_owned}` with no `wax_` call made; `userHandle` mismatch also returns `:credential_not_owned` (D-07) | unit | `mix test test/sigra/passkeys/authentication_test.exs:credential_confusion_defense` | ❌ W0 | ⬜ pending |
| 19-03-02 | 03 | 3 | PK-05 | P-4 | Sign-count regression in `:warn` mode emits `passkey.sign_count_regression` audit event (D-10 payload shape: `credential_id`, `previous_count`, `presented_count`, `policy_applied`, `delta`, `rp_id`) and returns `{:ok, %Credential{}}` — auth continues | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs:warn` | ❌ W0 | ⬜ pending |
| 19-03-03 | 03 | 3 | PK-05 | P-4 | Sign-count regression in `:require_reauth` mode emits audit event and returns `{:error, :sign_count_regression}` (D-08) | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs:require_reauth` | ❌ W0 | ⬜ pending |
| 19-03-04 | 03 | 3 | PK-05 | P-4 | Sign-count regression in `:revoke` mode emits audit event, deletes the credential in the same `Ecto.Multi`, and returns `{:error, :sign_count_regression}` (D-08) | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs:revoke` | ❌ W0 | ⬜ pending |
| 19-03-05 | 03 | 3 | PK-05 | P-4 | Zero-to-zero sign count (resident-key / synced passkey carve-out) is NOT treated as regression in any mode | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs:zero_allowed` | ❌ W0 | ⬜ pending |
| 19-04-01 | 04 | 4 | PK-07, PK-08 | PK-07 (class defense) | `Sigra.Passkeys.rename/5` and `delete/4` reject cross-user access (`{:error, :not_found}` when the `{user_id, credential_id}` tuple does not exist) and emit `passkey.rename` / `passkey.delete` audit events via `log_multi_safe/3`. Supersedes CONTEXT.md D-08's 3-arity `rename` signature via addendum D-08a | unit | `mix test test/sigra/passkeys_test.exs:management` | ❌ W0 | ⬜ pending |
| 19-04-02 | 04 | 4 | PK-01 | T-19-04-04, T-19-04-05 | `Sigra.Install.Features.Core` feature-gates vault emission: any of `--passkeys`/`--mfa`/`--oauth` triggers real `vault.ex` + `encrypted_binary.ex` under `<app_module>` namespace; otherwise passthrough stub (D-13). `Sigra.Install.Features.Passkeys` emits `user_passkey.ex` + `create_user_passkeys.exs` when enabled | integration | `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/vault_promotion_test.exs --trace` | ❌ W0 | ⬜ pending |
| 19-04-03 | 04 | 4 | PK-01 | T-19-04-04, T-19-04-07 | `mix sigra.upgrade promote_vault/1` writes vault template, rewrites `encrypted.ex` to `Cloak.Ecto.Binary`, injects `{MyApp.Vault, []}` child via existing `Sigra.Install.Injector.inject_vault_child/2`, prints `CLOAK_KEY` banner (D-14); **pre-existing stub-written MFA rows survive promotion**: raw `encrypted_secret` column is plaintext before and ciphertext after, verified via `Ecto.Adapters.SQL.query!/3` (closes RESEARCH.md Q3, T-19-04-07 mitigated); `Sigra.Application.verify_vault_or_raise!/0` raises at `start/2` when `config.passkeys[:enabled?]` is true AND `<app_module>.Encrypted.Binary` resolves to the stub (D-15) | integration | `mix test test/sigra/install/vault_promotion_test.exs --trace` | ❌ W0 | ⬜ pending |

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
