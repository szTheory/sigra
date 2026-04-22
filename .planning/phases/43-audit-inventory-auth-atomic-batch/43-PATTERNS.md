# Phase 43 — Pattern map

## Analog: Multi + internal audit (production)

| New / target work | Closest existing analog | Excerpt / lesson |
|-------------------|-------------------------|------------------|
| Token lifecycle + audit in one commit | `Sigra.Auth.reset_password/4` | `Multi` + `Sigra.Audit.__log_internal__` + `repo.transaction` + `emit_telemetry_from_changes` |
| API row + audit atomicity test | `test/sigra/api_token_audit_atomic_test.exs` | PostgresRepo DDL, `TRUNCATE`, assert audit row count across rollback |
| Assertion helpers | `lib/sigra/audit/assertions.ex` | `latest_audit_event/3`, `assert_audit_fields/3` with ordered queries |
| Hybrid `log_safe` scope rules | `test/sigra/audit/log_safe_scope_test.exs` | Category 2/3 scope + metadata constraints |

## Files likely modified (AUD-05)

- `lib/sigra/auth.ex` — primary conversion surface.
- `test/sigra/**/*audit*atomicity*.exs` — new proof modules (naming per `43-CONTEXT.md` D-43-04).

## Anti-patterns

- Changing public function return shapes when audit insert fails (forbidden — Multi / `log_safe` semantics from Phase 39).
- Asserting full metadata payloads in every test (use partial stable keys per D-43-04).
