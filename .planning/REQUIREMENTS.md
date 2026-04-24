# Requirements: Sigra — v1.15 Account + API C-1 planning truth

**Defined:** 2026-04-24  
**Core value:** (from `PROJECT.md`) Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Milestone focus:** Bounded **SEED-002** slice — reconcile **phase 44** inventory and **phase 9** C-1 matrix with **`lib/sigra/account.ex`** and **`lib/sigra/api_token.ex`** for **AUD-04-035..042** and **047** (already **`Multi` + `log_multi_safe`**); extend **`account_audit_atomicity_test.exs`** for **`change_password`**. No **`SEED-001`** matrix; no **`AUD-04-022`** change (**EX-44-02**).

## v1.15 Requirements

### Audit atomicity / planning truth (AUD)

- [x] **AUD-14-01**: **`44-AUD-04-INVENTORY.md`** rows **AUD-04-035..042** list **`Multi` + `log_multi_safe`** (same `Repo.transaction/1` as domain `Multi.run`), **Phase 78**, evidence **`lib/sigra/account.ex`** + **`test/sigra/account_audit_atomicity_test.exs`**. Row **AUD-04-043** remains **`log_safe`** (**EX-44-05**).
- [x] **AUD-14-02**: **`44-AUD-04-INVENTORY.md`** row **AUD-04-047** lists **`Multi` + `log_multi_safe`** for **`Sigra.APIToken.revoke/2`**; **AUD-04-044..046** remain **`log_safe`** (**EX-44-01**); **048–049** unchanged deferral.
- [x] **AUD-14-03**: **`09-VERIFICATION.md`** C-1 **Phase 44** rows **035–042** and **047** show **T1** with **`Multi` + `log_multi_safe`** mechanism; **043** **T2** / **EX-44-05**; **044–046** **T2** / **EX-44-01**; **048–049** unchanged.
- [x] **AUD-14-04**: **`09-03-SUMMARY.md`** — document status + planning trace include **phase 78** / **AUD-14**; bounded-batch paragraph cites **035–042**, **047**.
- [x] **AUD-14-05**: **`CHANGELOG.md` [Unreleased]** roadmap trace bullet; **`test/sigra/account_audit_atomicity_test.exs`** adds **`change_password`** success + CHECK-guard rollback (parity with **`set_password`** test).

## Future requirements

_Defer:_ **JWT** ad-hoc rows **048–049**; full **OAuth/ops** **AUD-08** batches; **SEED-001** human matrix; further **Account**-only test expansion (email change harness) unless a phase touches **`EmailChange`** integration tests.

## Out of scope (v1.15)

| Item | Reason |
|------|--------|
| **`AUD-04-022`** | **`log_safe`** invalid enroll — **EX-44-02** |
| **`api.token_verify.failure`** **044–046** | Intentional **EX-44-01** hybrid |
| **`api.jwt_refresh`** **048–049** | Deferred **AUD-08** / phase **45** inventory |
| **`999.x`** | Archaeology only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUD-14-01 | 78 | Complete |
| AUD-14-02 | 78 | Complete |
| AUD-14-03 | 78 | Complete |
| AUD-14-04 | 78 | Complete |
| AUD-14-05 | 78 | Complete |

**Coverage:** v1.15 requirements: 5 total; mapped to phases: 5; unmapped: 0.

---
*Requirements defined: 2026-04-24 — v1.15 bounded SEED-002 Account + API C-1 planning truth (**AUD-14**).*
