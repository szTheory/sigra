# Phase 83: MFA AUD-04-022 closure — Context

**Gathered:** 2026-04-24  
**Status:** Ready for planning

<domain>

## Phase boundary

Close **AUD-04-022** for **`Sigra.MFA.confirm_enrollment/5`**: the **invalid TOTP before any enrollment DB work** path must either (1) align with **D-AUD-05** using **`Repo.transaction/1` + `Ecto.Multi` + `log_multi_safe`** when **`:audit_schema`** is set, with tests and planning truth (**AUD-20-01..03**), or (2) ship an **explicit waiver** with updated **EX-44-02** and matrix honesty. This context **locks the promote branch** after subagent research and user delegation (“all” + synthesize).

**Explicitly out of scope:** Changing success-path **020** / post-rollback **021** mechanics; JWT co-fate (**D-AUD-08**); new HTTP surfaces.

</domain>

<decisions>

## Implementation decisions (research-backed, coherent set)

### D-83-01 — Mechanism: **promote** (do not waive)

- **Decision:** When **`:audit_schema`** is set, replace standalone **`log_safe/3`** on the **`{:error, _}`** branch of **`verify_totp`** in **`confirm_enrollment/5`** with the **same audit-only transaction shell** used elsewhere in **`Sigra.MFA`**: **`Repo.transaction/1`** on **`Multi.new() |> Sigra.Audit.log_multi_safe("mfa.enroll.failure", …)`**, factored to **reuse or mirror `commit_ad_hoc_mfa_audit/5`** (rescue for constraint class → **`[:sigra, :audit, :log_safe_error]`** with **`reason: :constraint_violation`**, changeset failures → **`emit_enroll_failure_audit_error_telemetry/2`** pattern). When audit is off, **no** transaction solely for audit.
- **Rationale:** **D-AUD-05** already standardizes audit-only durability; **022** was **T2** for phase-scope / “no paired domain write” reasons, not because **`log_safe`** is technically superior. Promotion removes the **last `mfa.enroll.*` hybrid** on this surface, improves **grep-level DX**, and matches **v1.19 / AUD-20-01** first branch without pretending **D-AUD-08** co-fate (there is **no** enrollment persistence to roll back with the audit row on invalid code).
- **Not “optics”:** Frame closure as **defaults alignment**; cite **Phase 83** superseding **073-CONTEXT D-05** for **022** only (parallel narrative to **077** promoting **033/034**).

### D-83-02 — Public caller contract (invalid TOTP + promoted audit)

- **Decision:** **Always** return **`{:error, :invalid_code}`** when the TOTP check fails, **regardless** of audit insert outcome (success, changeset failure, constraint, DB unavailable). **Do not** introduce **`jwt_refresh_aborted`-class** atoms for this path. **Do not** return **`{:ok, _}`** on audit failure.
- **Telemetry:** On audit subsystem failure, emit **`[:sigra, :audit, :log_safe_error]`** (and keep **`emit_telemetry_from_changes`** only after a **successful** audit txn), matching **`commit_ad_hoc_mfa_audit/5`** and **`Sigra.APIToken.verify/2`** failure-audit posture — **domain tuple stays the crypto failure**, audit is **forensic side-channel**.
- **`@doc`:** Add an explicit **Returns** note: invalid code ⇒ **`{:error, :invalid_code}`**; with **`:audit_schema`**, Sigra **may** attempt a durable **`mfa.enroll.failure`** row in an audit-only transaction; **audit persistence failure does not change the return**; operators monitor **`[:sigra, :audit, :log_safe_error]`**.
- **Relation to defaults:** This is **not** the “always `:ok`” **D-AUD-06** class (**`audit_jwt_refresh/2`**); it is the **“domain error + best-effort durable audit”** class (closer to **verify** failure auditing). **D-AUD-08** explicitly **does not** apply (no security state granted without audit).

### D-83-03 — Tests (**AUD-20-02**)

- **Decision:** Extend **`test/sigra/mfa_audit_atomicity_test.exs`** only (**D-AUD-07**): keep **`async: false`**, named tests, unique telemetry handler ids, **`cfg/2`** audit on/off.
- **Matrix (minimal):**
  1. **Invalid TOTP + audit on** — **`{:error, :invalid_code}`**; **0** credential/backup rows; **1** **`mfa.enroll.failure`** with **`invalid_code`** / **`totp`** in metadata.
  2. **Invalid TOTP + audit off** — same return; **0** audit rows.
  3. **Fault injection** — **`CHECK`** rejecting **`mfa.enroll.failure`** for the test window: expect **no** audit row, **`{:error, :invalid_code}`**, **`assert_receive`** **`[:sigra, :audit, :log_safe_error]`** (implementation follows **`commit_ad_hoc_mfa_audit`** rescue path, **not** bare **`ConstraintError`** to callers).
- **Claude's discretion:** Exact constraint name / SQL helper duplication vs shared private — keep consistent with existing MFA atomicity tests.

### D-83-04 — Planning truth (**AUD-20-03**)

- **Decision:** **Surgical** updates with **dated Phase 83 supersession** (footnotes, not wholesale rewrites — **D-AUD-11**): **44-AUD-04-INVENTORY** row **022** mechanism → **`Repo.transaction` + `Multi` + `log_multi_safe`**; **09-VERIFICATION** C-1 **022** → **T1** with evidence pointers to **`mfa_audit_atomicity_test.exs`** + **`lib/sigra/mfa.ex`**; **09-03-SUMMARY** — short **Phase 83** paragraph superseding any “022 remains T2” **present-tense** where misleading; **CHANGELOG [Unreleased]** — **`### Changed`** for runtime audit behavior when **`:audit_schema`** set; **`### Documentation`** for matrix/inventory/summary; **`83-VERIFICATION.md`** merge gate lists evidence; **EX-44-02** — **retire** for **022** only (pointer to **83**), without orphaning **066/067** history (note “superseded by **83**”).
- **CHANGELOG audience split:** operators read **`Changed`**; maintainers read **`Documentation`** bullets with verification links.

### Claude's discretion

- Whether **`confirm_enrollment`** calls **`commit_ad_hoc_mfa_audit/5`** directly with composed **`extra_opts`** or a thin **`commit_enroll_invalid_code_audit/3`** wrapper for readability.
- Minor **`@doc`** wording polish.

### Folded todos

_None._

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-20-01**–**AUD-20-03**
- `.planning/ROADMAP.md` — Phase **83** row
- `.planning/PROJECT.md` — v1.19 **AUD-20** intent

### Defaults and prior decisions

- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — **D-AUD-01**–**D-AUD-11**, **D-AUD-12** (added with Phase **83**)
- `.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-CONTEXT.md` — **D-82-*** (JWT; **out of scope** but **D-AUD-08** contrast)
- `.planning/phases/73-bounded-audit-atomicity-batch/73-CONTEXT.md` — **D-05** on **022** (historical; **superseded for 022** by **83**)

### Inventories and verification

- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — row **022**
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — C-1 **022**
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md`
- `CHANGELOG.md` — `[Unreleased]`

### Code

- `lib/sigra/mfa.ex` — **`confirm_enrollment/5`**, **`commit_ad_hoc_mfa_audit/5`**, **`emit_enroll_failure_audit_error_telemetry/2`**
- `lib/sigra/audit.ex` — **`log_safe/3`**, **`log_multi_safe/3`**
- `lib/sigra/api_token.ex` — **`verify/2`** failure audit pattern (reference for **D-83-02**)
- `test/sigra/mfa_audit_atomicity_test.exs`

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`commit_ad_hoc_mfa_audit/5`** — transaction + **`log_multi_safe`** + rescue/**`:log_safe_error`** + **`:ok`** internal result; **022** promotion should **share this shell** so behavior and tests stay uniform.
- **`mfa_audit_atomicity_test.exs`** — Postgres **`CHECK`** fault injection, telemetry, **`cfg/2`**.

### Established patterns

- **D-AUD-05** — audit-only **`Multi`** still runs inside **`Repo.transaction/1`** when audit schema set.
- **D-AUD-07** — named tests, **`async: false`**, unique telemetry ids.

### Integration points

- Host apps already handle **`{:error, :invalid_code}`** for enrollment UX; **no** new error atoms.

</code_context>

<specifics>

## Specific ideas

- User preference (Phase **83** discuss): **subagent research** on all gray areas, **one-shot** coherent recommendations, **shift-left** in GSD config for delegated discuss (see `.planning/config.json` **`discuss_*`** keys).
- Cross-agent synthesis: promote **022**, preserve **`{:error, :invalid_code}`**, tests **A/B/C**, surgical planning docs.

</specifics>

<deferred>

## Deferred ideas

- **Waiver path** — Not taken; if planning discovers a **hard semantic blocker**, re-open discuss with explicit contrast to **D-83-01**.

### Reviewed todos (not folded)

_None._

</deferred>

---

*Phase: 83-mfa-confirm-enrollment-022*  
*Context gathered: 2026-04-24*
