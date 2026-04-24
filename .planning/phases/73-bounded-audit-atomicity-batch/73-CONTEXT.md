# Phase 73: Bounded audit atomicity batch - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

<domain>
## Phase Boundary

**AUD-11:** Close **one** additional bounded **C-1** deferral batch: align **canonical planning truth** and **merge-gated audit-aware tests** with **actual** `lib/sigra/mfa.ex` behavior for the **MFA verify / lockout / disable / regen** slice (**AUD-04-023..032**), where implementation is already predominantly **`Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`** but **`09-VERIFICATION.md`** and **`44-AUD-04-INVENTORY.md`** still describe legacy **`log_safe`** hybrid rows (“target Multi (phase 44 closure)”).

**Explicitly out of scope for this phase:** Whole-library SEED-002; **022** (invalid enroll — **EX-44-02**); **033** / **034** (**EX-44-03** / **EX-44-04**) except honest wording cross-checks; **account 035–043**, **API 044–047**, **session 015–017** (separate bounded batches per **066-CONTEXT**); **`09-03-SUMMARY.md`** substantive updates (**phase 74 / AUD-12**).

</domain>

<decisions>
## Implementation Decisions

### 1 — Subsystem / AUD-04 slice (research: bounded batch + ecosystem patterns)

- **D-01 (locked scope):** Phase **73** owns the **MFA “phase 44 closure” numeric band `AUD-04-023`..`032`** — verify TOTP success/failure/lockout (**023–025**), disable/cleanup (**028–029**), regen success/failure/lockout (**030–032**). **Do not** expand into account/API/session in the same phase (**066-CONTEXT D-03** anti-pattern: god `Multi`).

- **D-02 (why not other clusters):** **Account** and **API** surfaces are already largely **`Multi`-first** in `lib/` with narrow **`log_safe`** helpers or intentional **EX-*** read-volume paths; **session store** needs **behaviour + contract** work, not one batch. **MFA** is the highest-density **C-1 vs code drift** after **61**/**66**, so closing it maximizes **honest audit truth** per **PROJECT.md** north star with **least surprise** for contributors (one module family, one primary test file).

- **D-03 (code vs docs):** Treat **`lib/sigra/mfa.ex`** as **authoritative** for mechanism until review finds a **live** `log_safe` post-mutation path that still maps to **023–032**. If drift is **documentation-only**, the batch is still **AUD-11-valid**: it **moves** the **claimed** hybrid disposition to **T1** in **C-1** + inventory to match shipped code, and adds or tightens **tests** that prove co-fate (see **D-12**). If review finds a **real** stray `log_safe` hot path, fold that fix into the **same** PR as matrix/inventory updates.

### 2 — T1 vs documented T2 (research: transactions, OWASP honesty, Rails/Django/Spring)

- **D-04 (default T1):** For every **023–032** path that performs **same-Repo durable mutations**, keep or establish **`Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`** inside **one** `repo.transaction/1` (or **`Repo.transact/2`** where already idiomatic). Callers emit **`Sigra.Audit.emit_telemetry_from_changes/2`** only on **`{:ok, changes}`** — never imply telemetry co-fates with DB when it does not.

- **D-05 (locked T2 — do not “upgrade” for optics):** **AUD-04-022** stays **`log_safe`** (**EX-44-02**, no DB writes). **AUD-04-033** / **034** stay **`log_safe` + EX-44-03 / EX-44-04** unless a **new** paired durable write lands in-library in the same batch (not expected). **Oban/email** remain **outside** the co-fate transaction unless explicitly designing enqueue-in-`Multi` (out of scope).

- **D-06 (policy one-liner):** **T1** = “audit row and claimed DB security state change share one commit boundary.” **T2** = “audit is intentional best-effort or structurally decoupled” — must be **EX-***-backed in inventory. Reject **after_commit**-style security narratives for T1 claims.

### 3 — Audit-aware tests (research: Sandbox, fault injection, file layout)

- **D-07 (file layout):** Extend **`test/sigra/mfa_audit_atomicity_test.exs`** for this batch; do **not** spin a new umbrella module unless a **new** public API surface is introduced.

- **D-08 (minimum bar):** For **each distinct `Multi` composition** implicated by **023–032** that lacks a rollback receipt today, add **at least one** deterministic **fault-injection** test: prefer **dynamic `CHECK` constraint** on `audit_events` (or equivalent) so audit insert failure aborts the transaction; assert **no partial domain persistence** and **no orphan audit** semantics inconsistent with the scenario. Reuse patterns from **061**/**066** atomicity tests.

- **D-09 (avoid):** Mock-only “audit failed” stubs for T1 proofs — too weak vs real **`Ecto`** abort semantics; nested `Repo.transaction` in tests that **hide** savepoint behavior vs production callers.

### 4 — Planning / traceability (research: same-PR honesty, PLAN.md receipts, D-06)

- **D-10 (same PR):** **`09-VERIFICATION.md` C-1**, **`44-AUD-04-INVENTORY.md`** rows **023–032**, and **tests** ship in **one atomic merge** whenever **mechanism / tier / verdict** cells change — avoids **49-CONTEXT**-class “green CI / stale matrix” windows.

- **D-11 (`073-*-PLAN.md` minimum):** Named list of **`AUD-04-xxx`** rows with **before → after** mechanism/tier/verdict, **evidence pointers** (`lib/...`, `test/...`), **subsection anchors** in **`09-VERIFICATION.md`**, and **mechanical receipts** (documented greps / scoped `mix test` invocations). No “see tests” placeholders.

- **D-12 (`09-VERIFICATION.md` unchanged case):** Valid **only** for a **D-06-class** outcome: reconciliation proves cells already match `lib/` + tests and only **non-semantic** edits occur (e.g. evidence path typo, cross-link). If **any** auditable column would change from truth, the file **must** diff. Phase **74** then carries **`09-03-SUMMARY.md`** (**AUD-12**); phase **73** does not substitute summary work for matrix work.

### Claude's Discretion

- Exact **constraint** text for fault injection, **Micro** step naming, and whether one **parameterized** test covers symmetric verify vs regen failure **`Multi`**s — provided **D-07–D-09** and row-level traceability hold.

### Folded Todos

- None (todo matcher returned no items for phase **73**).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-11**; v1.12 milestone scope
- `.planning/ROADMAP.md` — Phase **73** goal and success criteria
- `.planning/PROJECT.md` — North star: production trust, honest machine/human boundaries, great DX

### C-1 truth surfaces (edit targets for this phase)

- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — **C-1 — Phase 44 inventory** rows **AUD-04-023`..`032**
- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — matching rows + **EX-44-02`..`04** appendix

### Normative vocabulary

- `docs/audit-semantics.md` — **T1** vs **T2**, `log_multi_safe` / `log_safe`

### Prior bounded-batch precedent (do not contradict)

- `.planning/phases/066-seed-002-bounded-batch/066-CONTEXT.md` — batch sizing, **020–022**, matrix merge policy
- `.planning/phases/061-seed-002-bounded-batch/061-CONTEXT.md` — **AUD-04-067** / verify_backup precedent
- `.planning/phases/067-c-1-planning-closure/067-CONTEXT.md` — **09-03** vs **09-VERIFICATION** split (**AUD-10** / phase **74**)

### Implementation + tests

- `lib/sigra/mfa.ex` — **`verify/4`**, **`verify_backup/4`**, **`disable/*`**, **`regenerate_backup_codes/4`**, **`cleanup_mfa/6`**, legacy **`audit_*`** helpers
- `test/sigra/mfa_audit_atomicity_test.exs` — primary extension target

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`Sigra.MFA`** dispatch header (**D-26** comment block) already documents **`Multi` + `log_multi_safe`** for verify success/failure, verify_backup, disable via **`cleanup_mfa`**, regen rotation.
- **`Sigra.Audit.log_multi_safe/3`** + **`emit_telemetry_from_changes/2`** — established telemetry ownership pattern in **`lib/sigra/audit.ex`**.

### Established patterns

- **Explicit `Multi` pipelines** over callback-hidden audit; **named** `:audit_multi_step` atoms when multiple audit inserts commit in one transaction.

### Integration points

- **`Lockout.increment/4`**, **`BackupCodes.consume/4`**, **`Trust.revoke_all/3`** participate inside **`Multi.run/3`** / deletes — audit steps must stay ordering-correct relative to these runs.

### Creative constraint (from research + grep)

- **C-1 / inventory currently lag `lib/`** for **023–032**: expect **documentation-first** closure with **test hardening**; treat any remaining **`log_safe`** in this ID band as a **bug** unless it maps to **022 / 033 / 034**.

</code_context>

<specifics>
## Specific Ideas

- User requested **all** discuss areas with **parallel subagent research** (subsystem choice, T1/T2 policy, ExUnit fault-injection patterns, C-1 same-PR traceability). Synthesis above is **one coherent** recommendation set: **MFA 023–032 truth + tests**, preserve **EX-44-02`..`04**, defer other clusters.
- Cross-ecosystem takeaway: **Rails/Django/Spring** “audit after commit” defaults are **wrong** for DB co-fate claims; **Sigra**’s explicit **`Multi`** + post-success telemetry is the idiomatic **Ecto** expression of the same integrity bar.

</specifics>

<deferred>
## Deferred Ideas

- **Account `AUD-04-035`–`043`**, **API `044`–`047`**, **session `015`–`017`** — future bounded batches (**066-CONTEXT**).
- **Trust browser `034` → T1** — only when/if optional DB-backed trust persistence ships (**EX-44-04** reopen trigger).
- **Legacy `audit_backup_codes_regenerate/3` removal** — hygiene batch if call sites go to zero (**EX-44-03**).

### Reviewed Todos (not folded)

- None.

</deferred>

---

*Phase: 73-bounded-audit-atomicity-batch*  
*Context gathered: 2026-04-23*
