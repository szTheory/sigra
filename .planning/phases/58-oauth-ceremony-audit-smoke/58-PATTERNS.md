# Phase 58 — Pattern Map

Analogs for **`Sigra.OAuthCeremonyAuditTest`** and CI contract (if implemented).

## Files to create / modify

| Planned artifact | Role | Closest analog | Excerpt / pattern |
|------------------|------|----------------|-------------------|
| `test/sigra/oauth/oauth_ceremony_audit_test.exs` | OA-01 merge-blocking ceremonies | `test/sigra/oauth/oauth_audit_atomicity_test.exs` | `use ExUnit.Case, async: false`; `PostgresRepo`; raw SQL `CREATE TABLE audit_events`; `Assertions.assert_audit_fields` |
| `test/sigra/oauth/oauth_audit_atomicity_test.exs` | Rollback / constraint only | Same file (post-edit) | Keep `ALTER TABLE … CONSTRAINT` tests; remove moved happy-path per **D-58-08** |
| `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` | CI honesty (optional) | `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` | `File.read!(".github/workflows/ci.yml")`; substring asserts on job/step/run lines |
| `lib/sigra/oauth.ex` | Reference only | N/A | `log_safe("oauth.authorize", …)` + `metadata: %{provider: …}` |

## Data flow (registration ceremony)

`Callback.process_callback(config, provider, user_info, token)` → `Ecto.Multi` → user + identity inserts → **`oauth.register_via_oauth`** audit in same transaction → assert via **`Sigra.Audit.Assertions`**.

## Data flow (authorize ceremony)

`OAuth.authorize_url(config, provider, opts)` → strategy `authorize_url/1` → **`Audit.log_safe("oauth.authorize", …)`** (when `:audit_schema` present) → row in **`audit_events`**.

---

## PATTERN MAPPING COMPLETE
