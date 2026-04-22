# Phase 44: MFA + Account/API atomic batches — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `44-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-04-20  
**Phase:** 44 — MFA + Account/API atomic batches  
**Areas discussed:** MFA success-path priority & hybrid policy (AUD-06); Account scope & ordering (AUD-07); API token remainder (AUD-07); Inventory / Wave A (AUD-04 extension)

**Mode:** User selected **all** areas and requested **parallel subagent research** + one-shot synthesis (no interactive Q/A per area).

---

## 1 — MFA success-path priority & dual-audit backup verify

| Option | Description | Selected |
|--------|-------------|----------|
| A — Priority stack + Multi for co-fated mutations | Align with D-43-02: verify successes, backup consume, enroll success, disable cleanup, lockout+counter failures in Multi where DB writes exist | ✓ |
| B — Minimal movement | Only document gaps; defer Multi | |
| C — Collapse backup verify to one audit action | Simpler telemetry; loses separate `mfa.backup_code_used` queries | |

**User's choice:** Research-led synthesis — **A** with **two audit rows on backup verify** in **one transaction**; prerequisite **Audit API** change for multiple `:audit` steps (see D-44-02).

**Notes:** Subagent flagged `log_multi_safe` **hardcoded `:audit` step** in `lib/sigra/audit.ex` as a blocker for two inserts in one Multi; D-44-02 resolves centrally.

---

## 2 — Account batch boundary & ordering

| Option | Description | Selected |
|--------|-------------|----------|
| A — In-process `Sigra.Account` only in 44; defer Oban worker | Matches REQ AUD-07 vs AUD-08 split | ✓ |
| B — Include `AccountDeletion` worker in 44 | Single milestone for all deletion audits | |

**User's choice:** **A** — **`Sigra.Workers.AccountDeletion` → Phase 45** by default; **`execute_deletion`** pre-delete audit semantics preserved inside Multi design.

**Notes:** Password / confirm-email-first ordering for PR sequencing; Laravel `afterCommit`-class footguns called out for email sends.

---

## 3 — API token remainder

| Option | Description | Selected |
|--------|-------------|----------|
| A — Multi for `revoke/2`; summary audit for `revoke_all/2`; hybrid for verify failures | Matches PAT lifecycle patterns (GitHub/Stripe) | ✓ |
| B — Multi-wrap all verify failures | Higher DB load; questionable shared fate | |

**User's choice:** **A**

**Notes:** `create` already atomic — `revoke` symmetric; `api.jwt_refresh*` deferred to JWT co-fate work.

---

## 4 — Inventory artifact (Wave A)

| Option | Description | Selected |
|--------|-------------|----------|
| A — New `44-*-INVENTORY.md`, continue `AUD-04-020+` IDs | Matches D-43-01 split layout; clean bisect | ✓ |
| B — Extend `43-AUD-04-INVENTORY.md` | Single file; merge conflict + naming mismatch risk | |
| C — Grep-only | Fails governance / D-43-03 | |

**User's choice:** **A** + **D-43-05 two-wave** for phase 44.

---

## Claude's discretion

- Exact row catalog and optional consolidation of lockout audit shape (one vs two rows) within “single txn” constraint.

## Deferred ideas

- See `<deferred>` in `44-CONTEXT.md`.
