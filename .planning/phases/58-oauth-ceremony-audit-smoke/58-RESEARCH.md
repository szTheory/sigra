# Phase 58 — Technical Research

**Question:** What do we need to know to plan **OA-01** (OAuth ceremony + audit smoke) well?

## Findings

### OA-01 requirement (authoritative)

From **`.planning/REQUIREMENTS.md`**: merge-blocking tests must exercise at least one **library-owned OAuth ceremony** (mocked / in-process is fine) and **assert audit outcomes** where production already persists audit — **or** assert a documented substitute with **`# OA-01`** (or equivalent) at the emission site in `lib/` so missing rows are intentional. **No live-provider secrets.**

### Ceremony surfaces (code-verified)

| Surface | Library module | Audit on success (when `audit: [audit_schema: _]`) | Notes |
|---------|----------------|-----------------------------------------------------|-------|
| **Registration** | `Sigra.OAuth.Callback.process_callback/4` | **`oauth.register_via_oauth`** via Multi + audit insert (co-fated with user/identity) | Existing happy-path proof in **`oauth_audit_atomicity_test.exs`** — **58-CONTEXT D-58-01** moves it to ceremony module |
| **Authorize URL** | `Sigra.OAuth.authorize_url/3` | **`oauth.authorize`** via `Audit.log_safe("oauth.authorize", …)` after `Telemetry.span` | Metadata restricted to **`%{provider: to_string(provider)}`** per **D-23** / comments in **`lib/sigra/oauth.ex`** |

### Test harness baseline

- **`Sigra.OAuthAuditAtomicityTest`** (**`test/sigra/oauth/oauth_audit_atomicity_test.exs`**): `PostgresRepo`, raw SQL DDL for `oauth_atomic_users`, `oauth_atomic_identities`, `audit_events`, **`Sigra.Test.AuditEvent`** as `audit_schema`, **`oauth_config/1`** map shape matches **`Callback.process_callback/4`** expectations. **Rollback / constraint** tests stay here per **D-58-08**.
- **`Sigra.OAuthTest`**: `MockStrategy`, local **`build_config/1`** with **`Sigra.Test.MockRepo`** — **no** `audit_schema`; unsuitable alone for row-level **`oauth.authorize`** assertions.
- **`Sigra.Audit.Assertions.assert_audit_fields/3`** (or `/4`): already used for **`oauth.register_via_oauth`** field checks.

### CI merge gate

- **`.github/workflows/ci.yml`** job **`library_tests`**, step **`Run library tests`**, runs plain **`mix test`** (no OAuth-specific `--exclude`). Env: **`MIX_ENV=test`**, **`PGUSER`/`PGPASSWORD`/`PGHOST`** for Postgres service.

### Optional structural lock (D-58-11)

Precedent: **`test/sigra/planning/phase_51_install_golden_ci_contract_test.exs`** reads **`ci.yml`** as a string and asserts stable substrings. A **phase 58** contract can anchor **`library_tests`**, **`Run library tests`**, and **`run: mix test`** without parsing full YAML — reduces drift risk if **`library_tests`** is renamed.

### Pitfalls (industry + in-repo)

- **Matrix explosion:** OmniAuth/Ueberauth-style broad matrices in default CI → slow, flaky. **58-CONTEXT** locks **one primary + one thin second path** only.
- **Repo mocks for audit rows:** Forbidden for OA-01 proofs — use **Sandbox + real repo** like phase **45**.
- **Secrets in fixtures:** Use **`MockStrategy`** / static non-secret strings; never real client secrets or tokens in metadata.

## Validation Architecture

**Nyquist dimension:** Machine-checkable OAuth audit ceremonies + honest CI gate for **`mix test`**.

| Dimension | How this phase validates |
|-----------|---------------------------|
| 1–7 | Primarily **test / CI structure** — no new production auth API surface |
| 8 (feedback / honesty) | **`MIX_ENV=test mix test`** (full or scoped **`test/sigra/oauth/`** + planning contract if Plan 02 added); **`mix compile --warnings-as-errors`** on Elixir edits |
| Sign-off | New **`Sigra.OAuthCeremonyAuditTest`** documents **OA-01** in **`@moduledoc`**; registration + authorize paths assert persisted **`oauth.*`** actions or documented substitute per **D-58-04–D-58-05** |

**Feedback sampling:**

- After each test-file edit: **`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/oauth/oauth_ceremony_audit_test.exs test/sigra/oauth/oauth_audit_atomicity_test.exs`**
- Before phase close: full library OAuth tests + compile; if Plan 02 exists, include **`test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs`**

---

## RESEARCH COMPLETE

Research sufficient to author **`58-VALIDATION.md`**, **`58-PATTERNS.md`**, and **`58-*-PLAN.md`** with concrete grep / **`mix test`** acceptance criteria aligned to **58-CONTEXT** decisions **D-58-01** through **D-58-11**.
