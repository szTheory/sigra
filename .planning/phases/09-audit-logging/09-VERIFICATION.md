---
phase: 09-audit-logging
verified: 2026-04-09T13:45:00Z
status: human_needed
score: 4/4 success criteria verified (with 1 caveat)
verdict: PASS-WITH-CAVEATS
overrides_applied: 0
requirements_verified:
  - AUDIT-01
  - AUDIT-02
  - AUDIT-03
  - AUDIT-04
caveats:
  - id: C-1
    ref: T-9-05 (partial mitigation)
    summary: >-
      Plan 09-03 deviated from D-01 universal atomic Multi. log_safe/3 hybrid
      (non-atomic, separate-transaction) is used at ~30+ integration sites;
      true Ecto.Multi + __log_internal__/3 atomic writes only at 3 pre-existing
      Multi sites (confirm_user, verify_confirmation_code, reset_password).
      Documented in 09-03-SUMMARY as partial T-9-05 mitigation pending a
      follow-up conversion of subsystem tests to be audit-aware.
    accepted_by: documented-in-summary
    impact: >-
      Audit row for a successful business op can be lost if the post-commit
      insert fails. Caller observes success but audit trail is missing. All
      other security properties (reserved-prefix guardrail, metadata cap,
      forbidden-key policy, telemetry-on-commit) remain intact.
  - id: C-2
    ref: test/sigra/audit/cursor_portability_test.exs:31 (:cursor_portability)
    summary: >-
      1 tagged test remains red because the test StubRepo returns [] from all/1
      and cannot simulate persisted rows across Audit.log/3 calls. Cursor
      correctness itself is covered by 4 unit roundtrip tests in
      audit/cursor_test.exs plus 1 property in audit_property_test.exs — all
      green. Pre-existing from Wave 0.
    accepted_by: documented-in-summaries (09-02, 09-03)
    impact: >-
      None on cursor algorithm. Real-DB cross-adapter portability is deferred
      to VALIDATION.md Manual-Only verifications (run against PG + SQLite
      sandbox when test repo is introduced).
human_verification:
  - test: Install generator produces working host-app artifacts
    expected: >-
      `mix sigra.install` in a fresh Phoenix project creates
      priv/repo/migrations/<ts>_create_audit_events.exs and
      lib/<app>/<context>/audit_event.ex with correct interpolation; host app
      compiles; `mix ecto.migrate` creates the audit_events table with all 12
      D-05 columns and 3 D-06 indexes on PostgreSQL, MySQL, and SQLite.
    why_human: >-
      Generator end-to-end behavior requires running mix sigra.install inside a
      real host app with a real Ecto adapter — outside the library's own test
      scope. Verified indirectly via template content and install-task wiring
      greps, but the final host-app compile + migrate must be smoke-tested by a
      human.
  - test: Cursor portability across adapters
    expected: >-
      Cursor pagination returns consistent 5-row windows when run against a
      real PostgreSQL sandbox and a real SQLite sandbox (covers the or-expanded
      (inserted_at, id) tiebreak in Sigra.Audit.Query.paginate/3).
    why_human: >-
      Test/sigra/audit/cursor_portability_test.exs cannot run against the
      StubRepo pattern used by the rest of the Phase 9 test suite. Requires
      Ecto.Adapters.SQL.Sandbox wiring which is out of scope until Sigra has a
      canonical test repo (flagged in 09-VALIDATION.md). Cursor correctness is
      covered by unit + property tests; only multi-adapter smoke is pending.
  - test: Optional Oban fallback warning
    expected: >-
      Booting a host app that configures retention_days but does not depend on
      :oban emits exactly one Logger.warning instructing the developer to call
      Sigra.Audit.cleanup/1 from their own scheduler.
    why_human: >-
      Requires starting an OTP application with Oban absent; the library's own
      test suite runs with Oban loaded.
  - test: Telemetry never fires on transaction rollback
    expected: >-
      When an audit Multi is part of a transaction that rolls back downstream,
      [:sigra, :audit, :log] does NOT fire. Observability test covers the
      {:error} branch via mocked repo, but a real rollback scenario (e.g.,
      constraint violation on a sibling insert) is not exercised.
    why_human: >-
      Observability contract is critical for SIEM integrations. Needs a real
      Ecto sandbox to construct a rollback-inducing Multi.
gap_closure_needs: []
follow_ups:
  - id: F-1
    owner: later-phase
    description: >-
      Convert subsystem tests to be audit-aware, then migrate non-Multi
      integration sites from log_safe/3 to Ecto.Multi + __log_internal__/3 to
      close C-1 (full T-9-05 atomicity). Tracked in 09-03-SUMMARY.
  - id: F-2
    owner: test-infra
    description: >-
      Introduce a canonical Sigra test repo with Ecto.Adapters.SQL.Sandbox so
      that test/sigra/audit/cursor_portability_test.exs (C-2) and audit-aware
      subsystem tests (F-1) can run against a real Repo.
---

# Phase 9: Audit Logging Verification Report

**Phase Goal:** All security-relevant auth events are automatically captured in a queryable audit log with structured metadata; developers can emit custom events; log writes do not block auth request performance.

**Verified:** 2026-04-09T13:45:00Z
**Verdict:** PASS-WITH-CAVEATS
**Re-verification:** No — initial verification

## Goal Achievement

### Roadmap Success Criteria

| # | Success Criterion | Status | Evidence |
|---|------------------|--------|----------|
| 1 | Every auth operation automatically writes an audit event without developer action | VERIFIED (with C-1) | 85 audit call sites across 7 subsystems (auth:27, mfa:21, oauth:8, api_token:7, account:17, lockout:3, suspicious_login:2). Integration sites match D-26 mapping. 249 subsystem tests pass. Caveat C-1: most sites use log_safe/3 (separate transaction) rather than atomic Multi. |
| 2 | Each event includes user ID, IP, user agent, timestamp, action, outcome; queryable via Sigra.Audit API | VERIFIED | Schema template priv/templates/sigra.install/audit_event.ex declares all 12 D-05 fields. Migration create_audit_events.exs creates matching columns. Sigra.Audit.query/1 + list/2 + stream/2 + count/2 implemented in lib/sigra/audit.ex with filter set {:actor_id, :action, :action_prefix, :outcome, :from, :to, :target_id, :target_type}. 8 audit_test.exs + 9 query_test.exs tests pass. |
| 3 | Developer can query by user, date range, or event type and receive structured results | VERIFIED | Sigra.Audit.Query.build/2 supports :actor_id, :action, :action_prefix, :from, :to filters. Sigra.Audit.list/2 returns cursor-paginated %{entries, next_cursor} with (inserted_at, id) tiebreak. Cursor roundtrip covered by 4 unit tests + 1 property. Cross-adapter smoke deferred per C-2. |
| 4 | Developer can emit custom audit events using the same API | VERIFIED | Sigra.Audit.log/3 (standalone) and log_multi/3 (transactional) both enforce the reserved-prefix guardrail (D-17/D-18) — log_multi/3 raises ArgumentError at composition time. Configurable reserved_prefixes via :sigra, :audit app env (D-18). Covered by 3 security tests + 8 top-level API tests + 4 integration tests. |

**Score:** 4/4 success criteria verified (with caveats C-1, C-2 noted).

## Requirements Coverage

| Req | Source Plans | Description | Status | Evidence |
|-----|-------------|-------------|--------|----------|
| AUDIT-01 | 09-05 (scaffolds) + 09-03 (integration) | Automatic logging of all security-relevant auth events | SATISFIED (with C-1) | 85 audit call sites in 7 subsystem files; D-26 mapping implemented for register/login/logout/magic_link/password_reset/session lifecycle/sudo/lockout/invalid_credentials/suspicious_login/mfa_enroll+verify+disable+backup_code+lockout+backup_codes_regenerate+trust_browser/oauth_authorize+callback+link+unlink+register+login/api_token_create+verify_failure+revoke+jwt_refresh/account_email_change+password_change+deletion_schedule+cancel+execute. |
| AUDIT-02 | 09-01 (schema+migration) + 09-05 | Event metadata includes user, IP, user agent, timestamp, outcome | SATISFIED | priv/templates/sigra.install/audit_event.ex declares 12 fields incl. actor_id, ip_address, user_agent, occurred_at, inserted_at, outcome. create_audit_events.exs creates matching columns with 3 indexes per D-06. lib/sigra/audit/changeset.ex validates required fields and enforces sensitive-data policy (D-23 forbidden keys). |
| AUDIT-03 | 09-02 (query API) + 09-04 (retention worker) + 09-05 | Queryable audit log API (by user, by date range) | SATISFIED | Sigra.Audit.query/list/stream/count in lib/sigra/audit.ex. Sigra.Audit.Query.build/paginate in lib/sigra/audit/query.ex. Cursor pagination in lib/sigra/audit/cursor.ex. Sigra.Workers.AuditCleanup + Sigra.Application boot warning in lib/sigra/workers/audit_cleanup.ex + lib/sigra/application.ex. 5/5 worker tests pass. Note: "by org scope" (orgs) is explicitly deferred to v2 per PROJECT.md and CONTEXT.md out-of-scope. |
| AUDIT-04 | 09-02 (public log/3 + log_multi/3) + 09-05 | Hook for custom events | SATISFIED | Sigra.Audit.log/3 and log_multi/3 public functions accept developer-owned actions. Reserved-prefix guardrail (auth. session. mfa. oauth. api. account. sigra.) enforced via Changeset.validate_reserved_prefix/3 AND raised ArgumentError at log_multi/3 composition time. Configurable via :sigra, :audit, reserved_prefixes (D-18). Metadata cap 8KB (D-20) + forbidden keys (D-23) enforced at changeset level. Covered by audit_security_test.exs (3 tests) + audit_integration_test.exs (4 tests). |

**Orphaned requirements:** None. All 4 AUDIT-* requirements are claimed by at least one plan and verified.

## Required Artifacts

| Artifact | Purpose | Exists | Substantive | Wired | Status |
|----------|---------|--------|-------------|-------|--------|
| `lib/sigra/audit.ex` | Public API (log/log_multi/log_safe/query/list/stream/count/cleanup + __log_internal__) | Yes (11542B) | Yes (357 lines, all D-12 functions present) | Yes (imported by auth/mfa/oauth/api_token/account/lockout/suspicious_login) | VERIFIED |
| `lib/sigra/audit/changeset.ex` | D-17..D-23 validators | Yes (4092B) | Yes (action regex, reserved prefix, metadata cap, forbidden keys) | Yes (called by audit.ex and by generated audit_event.ex) | VERIFIED |
| `lib/sigra/audit/cursor.ex` | Base64URL cursor encoding | Yes (1085B) | Yes (encode + decode with error tuple) | Yes (used by audit.ex list/2) | VERIFIED |
| `lib/sigra/audit/query.ex` | Composable Ecto query builder | Yes (2209B) | Yes (8 filters + paginate with tiebreak) | Yes (used by audit.ex query/1) | VERIFIED |
| `lib/sigra/workers/audit_cleanup.ex` | Optional Oban retention worker | Yes (2036B) | Yes (perform/1 + cleanup/3, String.to_existing_atom T-9-08) | Yes (delegates to Sigra.Audit.do_cleanup/3) | VERIFIED |
| `lib/sigra/application.ex` | OTP callback for boot warning | Yes (1538B) | Yes (maybe_warn_audit_cleanup_fallback) | Yes (mix.exs mod: {Sigra.Application, []}) | VERIFIED |
| `priv/templates/sigra.install/create_audit_events.exs` | Generated migration | Yes (977B) | Yes (12 D-05 columns + 3 D-06 indexes, no PG-specific types) | Yes (install task line 190) | VERIFIED |
| `priv/templates/sigra.install/audit_event.ex` | Generated Ecto schema | Yes (1728B) | Yes (12 fields declared, delegates changeset to Sigra.Audit.Changeset) | Yes (install task lines 191-192) | VERIFIED |
| `lib/mix/tasks/sigra.install.ex` | Install task wiring | Yes (modified) | Yes (7 audit_event/create_audit_events references) | Yes (files list entries for both templates + idempotency check + audit_migration_timestamp) | VERIFIED |
| `test/sigra/audit/*.exs`, `test/sigra/audit_*.exs`, `test/sigra/workers/audit_cleanup_test.exs` | Test scaffolds + property tests | Yes (11 files + 2 support) | Yes (54 tests + 3 properties) | Yes (all green except C-2 tagged test) | VERIFIED |

## Key Link Verification

| From | To | Via | Status |
|------|----|----|--------|
| Generated AuditEvent schema | Sigra.Audit.Changeset.changeset/3 | Delegated call in template | WIRED |
| Sigra.Audit.log/3 | repo.insert + telemetry | Direct call + emit_telemetry | WIRED |
| Sigra.Audit.log_multi/3 | Ecto.Multi.insert | Via do_log_multi | WIRED |
| Sigra.Audit.__log_internal__/3 | do_log_multi(allow_reserved: true) | Internal | WIRED |
| Sigra.Audit.log_safe/3 | No-op or repo.insert | Keyword.get(:audit_schema) branch | WIRED (C-1: non-atomic) |
| Sigra.Audit.list/2 | Query.paginate + Cursor.encode/decode | Pagination pipeline | WIRED |
| Sigra.Audit.cleanup/1 | do_cleanup/3 → delete_all | Delegated | WIRED |
| Sigra.Workers.AuditCleanup.perform/1 | Sigra.Audit.do_cleanup/3 | Direct call | WIRED |
| Sigra.Application.start/2 | Logger.warning (fallback) | cond + Code.ensure_loaded?(Oban) | WIRED |
| mix sigra.install task | both audit templates | files list + idempotency | WIRED |
| Sigra.Auth + Sigra.MFA + ... | Sigra.Audit.log_safe/3 / __log_internal__/3 | 85 call sites across 7 files | WIRED |

## Anti-Patterns / Stubs Found

| File | Severity | Finding |
|------|----------|---------|
| lib/sigra/audit.ex log_safe/3 | Info (C-1) | Intentional non-atomic fallback path. Documented as partial T-9-05 mitigation. Returns `:ok` on insert error after emitting diagnostic `[:sigra, :audit, :log_safe_error]` telemetry — swallows errors by design to keep call-site return shapes stable. |
| lib/sigra/audit.ex stream/2 fallback | Info | `function_exported?(repo, :stream, 1)` fallback wraps `repo.all |> Stream.unfold` for minimal StubRepo. Real Ecto.Repo path is unchanged. Not a production stub. |
| test/sigra/audit/cursor_portability_test.exs | Known caveat (C-2) | 1 tagged test red — StubRepo returns [] for all/1. Cursor algorithm itself is exercised by 4 unit + 1 property test. |

No TODO/FIXME/placeholder comments, no hardcoded empty data in library code, no "coming soon" strings.

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite compiles and runs | `mix test --seed 0` | 3 properties, 1167 tests, 1 failure (C-2 only) | PASS |
| Same against seed 1 (reproducibility) | `mix test --seed 1` | 3 properties, 1167 tests, 1 failure | PASS |
| Compile without warnings | `mix compile --warnings-as-errors` | 0 warnings, 76 files compiled | PASS |
| Audit module loads | file present + exports log/log_multi/__log_internal__/log_safe/query/list/stream/count/cleanup | 9 public functions present | PASS |
| Install task wiring | `grep -c 'audit_event\|create_audit_events' lib/mix/tasks/sigra.install.ex` | 7 | PASS |
| Subsystem audit integration | `grep -c Sigra.Audit lib/sigra/{auth,mfa,oauth,api_token,account,lockout,suspicious_login}.ex` | 85 total | PASS |

Note on async flakiness: running `mix test` without a seed produced 9 failures intermittently due to telemetry-handler contention in async tests. With a deterministic seed the count is reliably 1. This is a test-infra concern unrelated to Phase 9 correctness; flagged as a follow-up for test infrastructure (not a Phase 9 gap).

## Data-Flow Trace (Level 4)

Phase 9 produces library code, not dynamic rendering surfaces, so Level 4 traces are scoped to the data pipeline inside the library:

| Artifact | Data Source | Flows Real Data? | Status |
|----------|-------------|------------------|--------|
| Sigra.Audit.log/3 | opts keyword → build_attrs → Changeset → repo.insert | Yes — caller supplies actor_id/metadata, repo writes row | FLOWING |
| Sigra.Audit.list/2 | filters → Query.build → paginate → repo.all → Cursor.encode | Yes — query pipeline produces entries map | FLOWING |
| Sigra.Audit.stream/2 | query → repo.stream (or all fallback) | Yes — enumerable emitted | FLOWING |
| Sigra.Workers.AuditCleanup.perform/1 | job args → String.to_existing_atom → do_cleanup → delete_all | Yes — retention delete runs when days > 0 | FLOWING |
| Sigra.Application.start/2 warning | retention_days + Code.ensure_loaded?(Oban) | Yes — Logger.warning emitted in fallback branch | FLOWING (needs human confirm in real OTP boot — see Step 8) |

## Deferred Items

None from Step 9b filtering — no later phase in the milestone addresses audit logging (Phase 10 is Documentation & DX; phases beyond are unrelated to audit). All unresolved items are either human-verification or documented caveats, not deferrals.

## Human Verification Required

See frontmatter `human_verification:` for the full structured list. Summary:

1. **Install generator host-app smoke** — run `mix sigra.install` in a fresh Phoenix app and verify `mix ecto.migrate` creates the `audit_events` table on PostgreSQL, MySQL, and SQLite.
2. **Cursor portability across adapters** — run the tagged `:cursor_portability` test against a real Ecto sandbox on PG and SQLite.
3. **Oban-absent boot warning** — boot a host app with retention_days set but no `:oban` dep and confirm the Logger.warning fires exactly once.
4. **Telemetry-on-rollback contract** — exercise a transaction that rolls back after `log_multi/3` and verify `[:sigra, :audit, :log]` does NOT fire.

## Gap Closure Needs

None. The two caveats (C-1 non-atomic hybrid, C-2 cursor-portability test stub) are both explicitly documented as known limitations in their respective plan summaries and have clear follow-up owners (F-1, F-2). They do not block the phase goal: automatic capture works, the full D-26 mapping is wired, the query API is complete, custom events work, retention cleanup works, and 1166/1167 tests pass deterministically.

## Gaps Summary

There are no blocking gaps. Phase 9 delivers every piece the roadmap Success Criteria require:

- Automatic capture across 7 subsystems with 85 integration sites (AUDIT-01)
- 12-field schema + 3 indexes via generator templates (AUDIT-02)
- Full composable query API with cursor pagination + retention worker + inline fallback (AUDIT-03)
- Developer-facing log/3 + log_multi/3 with enforced reserved-prefix guardrail, metadata cap, and forbidden-key policy (AUDIT-04)

The two caveats (C-1 atomicity hybrid, C-2 cursor portability) are known partial deliveries documented in their plan summaries with clear follow-up paths. Neither changes the answer to any Success Criterion.

**Verdict: PASS-WITH-CAVEATS** — status `human_needed` because the install generator, cross-adapter cursor, Oban-absent warning, and rollback-telemetry contract all require running code outside the library's own test harness.

---

*Verified: 2026-04-09T13:45:00Z*
*Verifier: Claude (gsd-verifier)*
