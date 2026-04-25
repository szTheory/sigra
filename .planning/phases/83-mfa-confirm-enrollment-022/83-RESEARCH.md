# Phase 83 — Technical research: AUD-04-022 (`confirm_enrollment` invalid TOTP)

**Question:** What do we need to know to plan promotion of **022** from standalone `log_safe/3` to **D-AUD-05** (`Repo.transaction` + `Ecto.Multi` + `log_multi_safe`)?

## Current behavior

- **`Sigra.MFA.confirm_enrollment/5`** (`lib/sigra/mfa.ex`): on `verify_totp` **`{:error, _}`**, calls **`Sigra.Audit.log_safe("mfa.enroll.failure", …)`** with scope from **`Sigra.Scope.from_config(config, user)`**, **`mfa_audit_opts(config)`**, **`actor_id: user.id`**, **`outcome: "failure"`**, **`metadata: %{method: "totp", reason: "invalid_code"}`**, then returns **`{:error, :invalid_code}`**.
- **`log_safe/3`** with **`:audit_schema` nil** is a no-op (`do_log_safe` short-circuit) — **no DB round-trip**.
- **`commit_ad_hoc_mfa_audit/5`** always runs **`repo.transaction/1`**. With nil schema, **`log_multi_safe`** returns **`Multi`** unchanged, so the transaction is effectively empty but still commits **`{:ok, %{}}`**. **Phase 83 CONTEXT (D-83-01)** requires **no** transaction when audit is off — implementation must **guard** the call (e.g. only invoke **`commit_ad_hoc_mfa_audit`** when **`Keyword.get(mfa_audit_opts(config), :audit_schema)`** is non-**`nil`**), mirroring the spirit of **`log_safe`** without adding empty transactions.

## Reference implementation

- **`commit_ad_hoc_mfa_audit/5`** (~`lib/sigra/mfa.ex` L72–115): **`Multi.new() |> Audit.log_multi_safe(action, opts)`**, **`repo.transaction`**, **`emit_telemetry_from_changes`** on **`{:ok}`**, **`emit_enroll_failure_audit_error_telemetry`** on changeset failures, **`rescue`** with **`failure_audit_followup_rescue?/1`** → **`[:sigra, :audit, :log_safe_error]`** **`reason: :constraint_violation`**. Reuse this shell for invalid-code audit with a distinct **`:audit_multi_step`** (e.g. **`:audit_mfa_enroll_invalid_code`**) so telemetry keys do not collide with insert-failed follow-up (**`:audit_mfa_enroll_insert_failed`**).
- **`emit_enroll_insert_failed_audit/3`** and **`enroll_insert_failed_opts/2`** show the **Keyword** shape for **`mfa.enroll.failure`** with scope + outcome + metadata — invalid-code path should align **metadata** **`reason: "invalid_code"`** / **`method: "totp"`** per existing **`log_safe`** call site.
- **`Sigra.APIToken`** **`@moduledoc`** and **`verify/2`** failure-audit pattern: domain tuple stays cryptographic failure; audit is side-channel — matches **D-83-02**.

## Test harness

- **`test/sigra/mfa_audit_atomicity_test.exs`**: **`async: false`**, raw SQL migrations, **`cfg/2`**, **`AuditTestEvent`**, existing **`mfa.enroll.failure`** / CHECK guard patterns (**L747–841**). New cases should follow **unique telemetry handler IDs**, **`assert_receive`** for **`[:sigra, :audit, :log_safe_error]`**, and **COUNT** assertions on **`audit_events`** / credential tables.

## Risks / non-goals

- **D-AUD-08** does not apply: no enrollment persistence to co-fate with audit on invalid code.
- Do **not** add **`:jwt_refresh_aborted`**-class atoms; caller contract remains **`{:error, :invalid_code}`** always on bad TOTP.

## Validation Architecture

- **Dimension 8 (Nyquist):** Every implementation task must have an automated verify command touching **`mfa_audit_atomicity_test.exs`** and/or **`mix compile --warnings-as-errors`** after code edits.
- **Primary proof:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` exits **0** after Phase 83 deliverables.
- **Sampling:** After **`lib/sigra/mfa.ex`** edits — compile; after test file edits — targeted test file; before merge — full **`mix test`** per project CI.

## RESEARCH COMPLETE

Findings are sufficient to plan **promote** path (no waiver) with guarded **`commit_ad_hoc_mfa_audit`**, test matrix A/B/C from **83-CONTEXT.md**, and surgical planning-truth updates.
