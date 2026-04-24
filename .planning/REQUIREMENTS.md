# Requirements: Sigra — v1.18 JWT refresh / reuse audit atomicity

**Defined:** 2026-04-24  
**Milestone:** v1.18 — bounded **SEED-002** slice (**AUD-18** / **AUD-04-048** / **AUD-04-049**)

## v1.18 Requirements

- [x] **AUD-18-01** — Maintainer can rely on **`api.jwt_refresh`** audit durability when audit is enabled: **`Sigra.APIToken.audit_jwt_refresh/2`** uses **`Repo.transaction/1`** + audit-only **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (not standalone **`log_safe/3`** after successful host-visible **`{:ok, _}`** semantics for the audit write itself).
- [x] **AUD-18-02** — Same for **`api.jwt_refresh_reuse`**: **`audit_jwt_refresh_reuse/2`** uses the transactional **`log_multi_safe`** pattern when `:audit_schema` is set; preserves **`outcome: "failure"`** + metadata for reuse detection.
- [x] **AUD-18-03** — **`test/sigra/api_token_audit_atomic_test.exs`** proves **`audit_jwt_refresh/2`** and **`audit_jwt_refresh_reuse/2`** emit expected audit rows when audit is on, omit when audit is off, and surface **`[:sigra, :audit, :log_safe_error]`**-class telemetry (or documented equivalent) when audit insert is fault-injected — mirroring **Phase 79** **`verify/2`** failure test posture.
- [x] **AUD-18-04** — Planning truth: **`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`** rows **048–049**, **`.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`** + **EX-45-JWT-*** appendix as needed, **`.planning/phases/09-audit-logging/09-VERIFICATION.md`** C-1 rows **048–049**, **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`** bounded-batch note for **phase 81** / **AUD-18**, and **`CHANGELOG.md` [Unreleased]** trace bullet.

## Future requirements

_Defer unchanged:_ **`AUD-04-022`** (**EX-44-02**); remaining **phase 45** **`log_safe`** **T2** rows unless a future milestone promotes them; wiring **`audit_jwt_*`** into **`Sigra.JWT`** refresh rotation (if not already) — only if discovered in scope during **Phase 81** discuss.

## Out of scope

- Co-fating **JWT** audit rows with refresh-token **DB** rotation in **`Sigra.JWT`** / **`RefreshToken`** — **v1.18** closes the **`APIToken`** audit helper durability gap only; a later milestone may compose **Multi** across refresh persistence + audit if product requires single-txn co-fate.
- **SEED-001** human UAT matrix — not part of this milestone.

## Traceability

| REQ-ID     | Phase |
|------------|-------|
| AUD-18-01  | 81    |
| AUD-18-02  | 81    |
| AUD-18-03  | 81    |
| AUD-18-04  | 81    |
