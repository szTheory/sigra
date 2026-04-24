# Phase 80: Forced password change audit atomicity — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`80-CONTEXT.md`**.

**Date:** 2026-04-24  
**Phase:** 80 — Forced password change audit atomicity  
**Areas discussed:** Multi placement; `audit_forced_password_change/2` evolution; opts contract; testing split  
**Method:** User selected **all** areas; parallel **generalPurpose** research subagents; maintainer chose coherent defaults aligned with codebase + `.planning/AUDIT-ATOMICITY-DEFAULTS.md`.

---

## 1 — Multi placement (Account vs PasswordChange)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Account facade | `Sigra.Account` owns `Multi` + `log_multi_safe`; `PasswordChange` stays audit-free | ✓ |
| B — PasswordChange + Audit | Domain module imports `Sigra.Audit` and composes `Multi` internally | |

**User's choice:** **A** (via maintainer one-shot mandate + research alignment).  
**Notes:** Matches existing `change_password` / `set_password` in `lib/sigra/account.ex`. Avoids Django/Rails callback-class footguns; single transaction owner; best generator seam.

---

## 2 — `audit_forced_password_change/2` evolution

| Option | Description | Selected |
|--------|-------------|----------|
| 1 — Hard remove immediately | Clean break | |
| 2 — Deprecate then remove next minor | `@deprecated` warning → removal | ✓ |
| 3 — Long-lived no-op shim | Heuristic duplicate suppression | |
| 4 — Default runtime raise on double-audit | Strict production guard | |

**User's choice:** **2**.  
**Notes:** Best SemVer + DX balance for pre-1.0 auth lib; mitigates silent missing audit on skewed upgrades.

---

## 3 — `opts` contract

| Option | Description | Selected |
|--------|-------------|----------|
| Full physical parity | Same `opts` keyword as `change_password` at `Sigra.Account` boundary | ✓ |
| New minimal public shape | Smaller keyword per operation | |

**User's choice:** **Full physical parity** with internal take/validate composition.  
**Notes:** Prevents silent ignore of `:audit_schema`; simplest generator forwarding.

---

## 4 — Testing split

| Option | Description | Selected |
|--------|-------------|----------|
| MockRepo + focused Postgres | Unit on MockRepo; atomicity/rollback in `account_audit_atomicity_test.exs` | ✓ |
| Duplicate happy paths on both | Higher CI cost, low extra proof | |

**User's choice:** **MockRepo + focused Postgres**.  
**Notes:** One proof per concern; mirrors existing SEED-002 test strategy.

---

## Claude's discretion

- Final public function naming left to implementer (`clear_password_change_requirement/3` suggested in CONTEXT).

## Deferred ideas

- NimbleOptions for all Account opts (cross-phase).
- Optional nested-transaction cleanup for `change_password` inner `Repo.transaction` (separate phase).
