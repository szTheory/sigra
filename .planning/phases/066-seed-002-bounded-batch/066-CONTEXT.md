# Phase 66: SEED-002 bounded batch - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

<domain>
## Phase Boundary

**AUD-09:** One bounded subsystem batch from Phase **9** **C-1** deferrals moves from hybrid **`log_safe/3`** (post-commit or non-co-fated) toward **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (or a **named, documented substitute** per `docs/audit-semantics.md`), with **audit-aware tests** merged under the same gate as production. Inventory rows and **`09-VERIFICATION.md`** stay traceable to **`.planning/phases/43-*` / `44-*` / `45-*`**. **Narrative / executive alignment** in **`09-03-SUMMARY.md`** is **phase 67 (AUD-10)** — not a reason to defer matrix fixes for rows this batch changes.

</domain>

<decisions>
## Implementation Decisions

### Subsystem and inventory slice (research: cross-ecosystem + Sigra-specific agents)

- **D-01:** **Primary subsystem for phase 66** is **`Sigra.MFA.confirm_enrollment/5`** (same vertical as phase **61** / **AUD-04-067**, extended—not account **035–043**, API tokens **044–047**, or session store **015–017**). Rationale: **one Repo**, **`mfa_audit_atomicity_test.exs`** reuse, dense **AUD-04-020..022** story, and **least surprise** for contributors (“finish MFA enroll audit story before opening account/API epics”).
- **D-02 (exact AUD-04 focus):** Planner **must** name and link in **PLAN.md**: **`AUD-04-020`** (enroll success — verify code vs inventory; success path already **`Multi` + `log_multi_safe`** in `mfa.ex`; align matrix/inventory if still marked hybrid), **`AUD-04-021`** (enroll failure after failed credential / backup insert — **primary T1 target**, same class as **067**: audit must **not** disagree with rolled-back DB effects), **`AUD-04-022`** (invalid TOTP **before** DB — inventory notes **pure validation** / **EX-44-02**). **Default for 022:** keep **documented T2** (no fake `Multi` for audit-only) unless a **new EX-*** or semantic change is approved in the same PR **with** test + doc updates—**principle of least surprise** beats forcing artificial transactions.
- **D-03 (explicit deferrals):** **Out of scope for phase 66:** **`regenerate_backup_codes`** follow-ups (**031–032** alignment), **`audit_backup_codes_regenerate/3`** (**033** / **EX-44-03**), **`audit_trust_browser/2`** (**034** / **EX-44-04**), **`disable` / `disable!`** (**028–029**), **account**, **API token**, and **session-store** clusters—each is its **own** bounded batch unless roadmap is amended. Avoid a **god `Multi`** spanning unrelated MFA concerns.

### Batch size and risk

- **D-04:** **Minimal coherent batch (locked):** Phase **66** ships **one** reviewable narrative: **`confirm_enrollment/5`** success/failure audit **co-fate** for **paths that touch the DB**, plus honest **C-1** rows for **020–022**. Do **not** widen to backup regen, trust browser, or verify/lockout rows (**023–025**) in the same phase unless the executor proves **identical transaction boundary** without merge sprawl—default is **no**.

### T1 vs documented T2 (same bar as phase 61, refined by research)

- **D-05:** **Default T1:** Same **Repo** transaction, **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (or **`__log_internal__/3`** where already normative) for every path in the batch that performs **same-DB mutations** in scope. Prefer **`Repo.transact/2`** and **telemetry only after `{:ok, changes}`** (`emit_telemetry_from_changes/1-2`) — matches Ecto 3.13+ direction and avoids callback/event **phase** confusion seen in Rails/Django/Spring stacks.
- **D-06:** **T2 or substitute** only when **structurally required** (no paired domain write, second store, or I/O that would lengthen the transaction). Must remain **explicit** in **`docs/audit-semantics.md`** vocabulary and **EX-*** / inventory notes—**no silent** opt-out for same-Postgres flows. **Oban/email** remain **after** commit—never inside the audit co-fate transaction (industry footgun from agent research).

### Verification and documentation merge policy

- **D-07:** **Same PR** as production + tests: update **`.planning/phases/09-audit-logging/09-VERIFICATION.md`** and **any 1:1 inventory lines** for **AUD-04-*** rows whose **mechanism, tier, or verdict** changes. Merge must not leave **C-1** claiming pre-batch mechanisms for rows this batch touches.
- **D-08:** **`09-03-SUMMARY.md`** and holistic “post-batch truth” prose → **phase 67 (AUD-10)** per roadmap; if **no** matrix row changes, phase **67** carries **“no `09-VERIFICATION.md` edit required”** rationale (same class as v1.7 **D-06** for **AUD-02**).

### Audit-aware tests

- **D-09:** Extend **`test/sigra/mfa_audit_atomicity_test.exs`**: (1) **Success** paths touched—assert **expected audit action(s)** and stable metadata; (2) **at least one** deterministic **rollback / fault-injection** per **new or tightened `Multi`** proving domain effects do **not** commit if audit step fails. Reuse helpers from existing atomicity tests—**contributor-friendly** failure messages.

### Research synthesis (coherent principles)

- **D-10:** Prefer **explicit `Multi` pipelines** over **implicit callbacks / magic post-commit audit** (lessons from ActiveRecord/PaperTrail, Django signals, Spring `@TransactionalEventListener` **AFTER_COMMIT** misuse, EF interceptor double-`SaveChanges`). **Transactional outbox / event sourcing** judged **overkill** for library auth—**single-repo `Multi` + transact** is the sweet spot for **DX + auditability**.
- **D-11:** Library surfaces should stay **composable** (`Multi` builders / steps the host runs with **their** `Repo`)—avoid hidden `Repo.transaction` + side effects that break nesting and **Sandbox** tests.
- **D-12 (DX / compliance narrative):** **Atomicity-first** for “no successful security state change without matching audit row” **inside the commit boundary**; **tamper-evidence / retention** remain **host/infra**—document honestly per **`docs/audit-semantics.md`**.

### Claude's Discretion

- Exact **`Multi` step names**, internal helper extraction, and minimal **A-style** fault seams—provided **D-01–D-12** and **AUD-04** traceability hold.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-09**; v1.9 bounded **SEED-002** scope
- `.planning/ROADMAP.md` — Phase **66** goal and success criteria
- `.planning/PROJECT.md` — v1.9 milestone intent (audit atomicity + honest **D-01** narrative)

### Audit semantics and C-1 truth

- `docs/audit-semantics.md` — **T1** vs **T2**, `log_multi_safe` / `log_safe` vocabulary
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — **C-1** matrices (**AUD-04-*** rows)
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — pointers only; **substantive narrative updates = phase 67**

### Inventories (AUD-04)

- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — **AUD-04-020** through **022** (and neighbors for cross-check only)
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md` — upstream auth rows if needed for cross-links

### Prior batch precedent

- `.planning/phases/061-seed-002-bounded-batch/061-CONTEXT.md` — **AUD-01** / **AUD-04-067** decisions (T1 default, test bar, verification merge)

### Implementation touchpoints

- `lib/sigra/mfa.ex` — **`confirm_enrollment/5`** cluster
- `lib/sigra/audit.ex` — `log_multi_safe/3`, `log_safe/3`
- `test/sigra/mfa_audit_atomicity_test.exs` — extend for this batch

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`test/sigra/mfa_audit_atomicity_test.exs`** — patterns from **AUD-04-067** / **`verify_backup/4`**; extend for **enroll** co-fate.
- **`Sigra.Audit.log_multi_safe/3`** + **`emit_telemetry_from_changes/1`** — established success-branch telemetry discipline.

### Established patterns

- **`Ecto.Multi` per command** with short transactions; avoid nested ambiguous transaction ownership.
- **C-1 honesty** — matrix + inventories track **T1** vs **EX-*** **T2**; phase **61** set the merge-gated precedent.

### Integration points

- Host apps supply **`Repo`**; library composes **`Multi`** steps—keep boundaries explicit for **Sandbox** and **transact** ergonomics.

</code_context>

<specifics>
## Specific Ideas

- User requested **all** discuss areas with **parallel subagent research** (cross-ecosystem audit patterns, Ecto **`Multi`/`Repo.transact`** footguns, Sigra slice selection); recommendations above are the **one-shot coherent** merge aligned with **Sigra** goals (production trust, honest audit trail, contributor **DX**, least surprise).
- Cross-ecosystem takeaway: co-fate wins when **transaction phase is explicit**; **after_commit**-style audit for **DB-backed security evidence** is a common **footgun** unless carefully justified (**T2** + doc).

</specifics>

<deferred>
## Deferred Ideas

- **`AUD-04-023`–`025`** (`verify/4` / lockout), **`028`–`034`** (disable, regen side paths, legacy helpers, trust browser)—future bounded batches.
- **`AUD-04-035+`** account, **`044`–`047`** API tokens, **`015`–`017`** session store—separate phases per **061** precedent.
- **Transactional outbox** as default—rejected for library-scope auth; revisit only for explicit multi-system product requirements.

</deferred>

---

*Phase: 066-seed-002-bounded-batch*  
*Context gathered: 2026-04-23*
