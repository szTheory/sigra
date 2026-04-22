# Phase 45: OAuth, ops paths & C-1 sign-off — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in **`45-CONTEXT.md`**.

**Date:** 2026-04-20  
**Phase:** 45 — OAuth, ops paths & C-1 sign-off  
**Areas discussed:** OAuth audit strategy; Lockout / suspicious login / impersonation; Oban workers & audit boundaries; C-1 & Phase 9 verification docs  

---

## 1 — OAuth module audit fate (`Sigra.OAuth`)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Multi everywhere | Every path uses `Ecto.Multi` + audit | |
| B — Hybrid | **T1** for domain mutations in Postgres; **T2** `log_safe` at HTTP/OAuth seams | ✓ |
| C — `log_safe` + inventory only | Defer Multi for mutations | |

**User's choice:** **B (hybrid)** — research + user “freeze” instruction.  
**Notes:** Reject A (fake atomicity across Assent/HTTP). Reject C for mutations when audit enabled. Extend **`OAuth.Callback`** `Multi`s with audit steps; keep **`oauth.authorize`** etc. as **`log_safe`**. Document **`{:error, _}`** possibility for **T1** when audit schema rejects row.

---

## 2 — Operational / security modules (lockout, suspicious login, impersonation)

| Option | Description | Selected |
|--------|-------------|----------|
| Strict Multi everywhere | All audit emissions in Multis | |
| Tiered T1/T2/T3 | Co-fate vs fail-open vs telemetry—same framework as D-45-01 | ✓ |
| Mostly `log_safe` | Minimize `{:error, _}` surface | |

**User's choice:** **Tiered (T1/T2/T3)** per **D-45-01** / **D-45-03**.  
**Notes:** Plugs enrich only; single writer in context. SMTP outside txn. EX-* for intentional **T2** high-volume failures.

---

## 3 — Workers & Oban (`AccountDeletion`, peers)

| Option | Description | Selected |
|--------|-------------|----------|
| Document deferral only | Keep post-commit `log_safe` for execution row | |
| Refactor to T1 + idempotent perform | Execution + `account.deletion_executed` in one txn; dedupe on retry | ✓ |
| Outbox-style async audit | Separate job for audit row | |

**User's choice:** **Refactor to T1** (aligned with **`Account.execute_deletion`** composition); keep worker for wall-clock/retry value.  
**Notes:** Oban completion still not in app txn—disclose in C-1 matrix. Reject “deferral only” for canonical execution evidence.

---

## 4 — C-1 narrative & Phase 9 docs

| Option | Description | Selected |
|--------|-------------|----------|
| Skip Phase 9 files | Only update CHANGELOG | |
| Create `09-audit-logging/` + matrix | **09-03-SUMMARY.md**, **09-VERIFICATION.md** with falsifiable C-1 table | ✓ |
| Merge only into 43/44 summaries | No new Phase 9 tree | |

**User's choice:** **Create canonical Phase 9 paths** + matrix linking **AUD-04** inventories (**D-45-05**).  
**Notes:** Stub-first acceptable; link **`docs/audit-semantics.md`**. PaperTrail-style honesty over hand-wavy “we log everything.”

---

## Claude's discretion

- Exact **AUD-04** row numbering after Wave A inventory.  
- Minor consolidation choices (e.g. one vs two audit rows on some lockout edge) within single-txn constraint.  
- Optional doc link checker scope.  

## Deferred ideas

- JWT refresh audit persistence (**AUD-08** unless promoted).  
- OAuth example smoke beyond **`audit-semantics.md`** non-goal note.  
