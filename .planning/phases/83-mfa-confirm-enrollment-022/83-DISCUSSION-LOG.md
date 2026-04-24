# Phase 83: MFA AUD-04-022 closure — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`83-CONTEXT.md`**.

**Date:** 2026-04-24  
**Phase:** 83 — MFA **`AUD-04-022`** / **`confirm_enrollment`**  
**Mode:** User selected **all** gray areas + requested **parallel subagent research** + **one-shot synthesis** (delegated to research-backed recommendations).

**Areas discussed:** (1) Promote vs waive, (2) Public contract if promoted, (3) Test matrix, (4) Planning truth / Nyquist docs.

---

## 1 — Promote vs waive (AUD-20-01)

| Option | Description | Selected |
|--------|-------------|----------|
| **Promote** | `Repo.transaction` + `Multi` + `log_multi_safe` when `:audit_schema` set; align **D-AUD-05** | ✓ |
| **Waive** | Retain `log_safe`, strengthen **EX-44-02** + planning waiver | |

**User's choice:** Delegate “all” + synthesize — **promote** (see **83-CONTEXT** **D-83-01**).  
**Notes:** Subagent compared Rails/Rodauth/Spring/Auth0 patterns; concluded single-insert txn is **ceremony for uniformity** not new atomicity vs Postgres; **D-AUD-05** + DX outweigh **073** “no optics upgrade” when **v1.19** explicitly scoped **022** closure.

---

## 2 — Public contract (invalid TOTP + promoted audit)

| Option | Description | Selected |
|--------|-------------|----------|
| **A** | Always `{:error, :invalid_code}` + telemetry on audit failure | ✓ |
| **B** | Distinct atom (e.g. audit aborted) | |
| **C** | `:ok` on audit failure | |

**User's choice:** **A** — **D-83-02**.  
**Notes:** Avoid enumeration channel via new atom; not **D-AUD-08** (no persisted security grant); parallel **APIToken.verify** failure-audit story.

---

## 3 — Test matrix (AUD-20-02)

| Option | Description | Selected |
|--------|-------------|----------|
| **Minimal A/B/C** | Happy invalid + audit on/off + CHECK fault + telemetry | ✓ |
| **Broader** | Extra NimbleTOTP edge coverage | |

**User's choice:** **D-83-03** — three named tests, **`async: false`**, rescue path consistent with **`commit_ad_hoc_mfa_audit`**.

---

## 4 — Planning truth (AUD-20-03)

| Option | Description | Selected |
|--------|-------------|----------|
| **Surgical supersession** | Footnotes, **022** → **T1**, **EX-44-02** retire for slice, **CHANGELOG** split | ✓ |
| **Full rewrite** | Replace large matrix sections | |

**User's choice:** **D-83-04**.

---

## Claude's discretion

_Internal synthesis only — user delegated “don’t make me think” defaults._

## Deferred ideas

_None recorded — waiver path deferred only as contingency in **83-CONTEXT**._
