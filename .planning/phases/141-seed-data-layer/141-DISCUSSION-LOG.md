# Phase 141: Seed Data Layer - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 141-seed-data-layer
**Mode:** assumptions
**Areas analyzed:** Research flags (user_identities, EnterpriseConnection, TOTP-in-dev,
passkey/Wax), user-creation API + lifecycle fields, audit log, API token, Argon2 override,
seeds wiring, library admin surface capability-gating

## Assumptions Presented

### Research Flag 1 — Carol's OAuth/UserIdentity row
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No `UserIdentity` schema exists in the example app; the row cannot be inserted as planned | Confident | No `Example.Accounts.UserIdentity` file; no `user_identities` table in any migration; `create_sigra_auth_tables` creates only users/user_tokens/user_sessions/user_mfa_credentials/user_backup_codes |
| Library admin DOES render linked identities, gated on the app providing the schema | Confident | `lib/sigra/admin/users/detail.ex:194-197` `identities_with_flag`; `user_show_live.ex:163` "Linked identities are not available for this app" |

### Research Flag 2 — EnterpriseConnection (Acme Corp SSO)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Schema exists; requires nested `oidc_settings` embed (`cast_embed required: true`); status enum is `[:draft, :validation_failed, :active, :disabled]` — use `:active` | Confident | `enterprise_connection.ex` + `enterprise_connection_oidc_settings.ex` read in full; SUMMARY.md's `configured`/`pending` strings are wrong |

### Research Flag 3 — TOTP enrollment in MIX_ENV=dev
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Sigra.Testing.setup_totp/2` IS available in dev but mints a random secret; use direct insert on `UserMFACredential` with deterministic secret | Confident | `lib/sigra/testing.ex:254-309` hardcodes `NimbleTOTP.secret()`; module under `lib/` (no env guard); `:sigra` path dep in all envs; `user_mfa_credential.ex` requires `[:user_id,:type,:encrypted_secret]`, unique `[user_id,type]` |

### Research Flag 4 — Admin passkey (display-only)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `UserPasskey.create_changeset/2` has NO Wax validation; fabricated COSE key inserts cleanly | Confident | `user_passkey.ex` `create_changeset/2` is pure cast/validate_required/validate_number/unique/fk; Wax lives in `accounts.ex register_passkey/3`, not the changeset |

### Secondary confirmations
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `register_user/1` creates unconfirmed; lifecycle fields patched via `Repo.update!` | Confident | `accounts.ex:98`; `user.ex` confirms all lifecycle fields + changesets |
| `dev.exs` has no Argon2 override today — must add `t_cost: 2, m_cost: 12` | Confident | full read of `test/example/config/dev.exs` |
| Audit table `audit_events`, event-type field `action`; 9 real action values found | Confident | `audit_event.ex`; grep of example `lib/`+`test/` |
| No API-token persistence: `create_api_token/3` is a non-persisting stub; no `api_tokens` table; no admin surface | Confident | `accounts.ex:719-731` returns in-memory map; no migration; `user_show_live.ex` render has no token surface |
| `seeds.exs` empty; `mix setup`→`ecto.setup` already calls it; `test` alias does not | Confident | `seeds.exs` (12 comment lines); `mix.exs:82-85` |

## Corrections Made

Two assumptions were "defer because schema missing." Both were escalated to the user because
they contradict roadmap Success Criterion #3 and affect what the demo can honestly claim
(above the methodology escalation threshold). User decided:

### Carol's OAuth identity
- **Original assumption:** Defer the row (no `UserIdentity` schema exists).
- **User decision:** **Add a minimal `Example.Accounts.UserIdentity` schema + migration**,
  then seed Carol's GitHub identity row. The library admin surface already renders linked
  identities, so this makes her OAuth state genuinely observable — honors SC#3 honestly.
- **Reason:** The cost (1 schema + 1 migration) is modest and idiomatic, and the alternative
  (admin showing "Linked identities are not available") is a weak OAuth demo.

### Admin API-token row
- **Original assumption:** No admin surface + no table → cannot be seeded.
- **User decision:** **DEFER the row.** Surface the `sigra_sk_` prefix illustratively on the
  `/demo/credentials` page (Phase 142). Amend SC#3 to drop the admin-API-token-row claim.
- **Reason:** No admin surface exists to display it and no persistence table exists; building
  both is sizeable enough to be its own phase, not seed-data work.

## External Research

None performed — every flag was resolvable against internal example-app + Sigra-library
source.
