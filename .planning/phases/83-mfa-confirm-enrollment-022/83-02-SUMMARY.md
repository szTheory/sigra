---
phase: 83
plan: "02"
status: complete
---

# Plan 83-02 — MFA invalid-code audit matrix (tests)

## Outcome

- **`test/sigra/mfa_audit_atomicity_test.exs`**: three named tests — audit on writes **`mfa.enroll.failure`** with **`invalid_code`** / **`totp`** metadata; audit off skips rows; **`CHECK`** guard on audit table + **`[:sigra, :audit, :log_safe_error]`** assertion while return stays **`{:error, :invalid_code}`**.
- **`EnrollInvalidCodeTelemetryHandler`** for deterministic **`assert_receive`**.

## Self-Check: PASSED

- `SIGRA_TEST_PG_USERNAME=jon MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` (or **`postgres`** per **CLAUDE.md**)

## Deviations

- Telemetry assertion accepts **`:constraint_violation`** or **`:invalid_changeset`** depending on how Postgres surfaces **`CHECK`** failures through Ecto.
