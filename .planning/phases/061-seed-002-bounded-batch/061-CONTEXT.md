# Phase 61: SEED-002 bounded batch - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship **AUD-01**: move **one** bounded subsystem from the Phase **9** **C-1** / **SEED-002** set from hybrid `log_safe/3` (post-commit or non-co-fated) toward **`Ecto.Multi`-atomic** audit co-fate (or a **named, documented substitute**), with **audit-aware tests** merged under the same gate as production changes. Scope is **one** subsystem batch — not full SEED-002 (see `.planning/REQUIREMENTS.md` out-of-scope list).

</domain>

<decisions>
## Implementation Decisions

### Subsystem choice (which bounded batch)

- **D-01:** Primary target is the **MFA** vertical (`lib/sigra/mfa.ex` and existing `test/sigra/mfa_audit_atomicity_test.exs`), scoped to **one coherent user-facing command cluster** for this phase (planner names the exact cluster — e.g. enrollment/verify path **or** disable/cleanup — **not** “all MFA in one PR”). Rationale: dense **AUD-04-020+** “T2 / target Multi” rows in C-1 matrices, existing atomicity test harness, and high impact when security state changes without a matching audit row.
- **D-02 (fallback only):** If MFA scope would force a **god `Multi`** or unacceptable lock time, **narrow the batch to API token create/revoke** (`test/sigra/api_token_audit_atomic_test.exs`) as the single subsystem instead — same AUD-01 boundary, must be explicit in PLAN with traceability to **AUD-04** rows. Do **not** pick plugs-only or “random smallest `log_safe` sites” without inventory linkage.

### T1 Multi vs documented T2 substitute

- **D-03:** **Default:** **T1** — same **Repo** transaction as domain writes using `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` (or `__log_internal__/3` where already normative), for every path in the batch that is **same-DB, short, no external I/O inside the transaction**. Prefer `Multi.merge/3` and small `build_*_multi/1` functions over abandoning co-fate.
- **D-04 (exceptions):** **T2** or another **documented substitute** is allowed **only** when structurally required: second non-SQL store (e.g. SessionStore), second Repo, or work that would **lengthen the transaction with network I/O**. Every such path **must** gain or update an **`EX-*`** row (or equivalent per `docs/audit-semantics.md`) — **no silent** “awkward Multi” opt-out for same-Postgres flows.

### Audit-aware test bar

- **D-05 (primary — matches AUD-01 wording):** For every **success** outcome the batch touches (`{:ok, _}` or equivalent), tests **must** assert the **expected audit row(s)** exist (stable **action** names + key metadata) — failures must read as *which operation, which audit, what was observed*.
- **D-06 (surgical co-fate):** Add **at least one** focused **rollback / fault-injection** test **per critical Multi** introduced or tightened, proving domain effects do **not** commit if the audit step fails — use **deterministic** failure (constraint, invalid changeset, or test-only seam), not flaky timing. Do **not** mandate broad property-style suites unless the repo already standardizes on them.
- **D-07:** Prefer **shared assertion helpers** (existing or small new module under `test/support` / test patterns already used in `*audit_atomicity_test.exs`) so CI failures are **actionable** for contributors.

### Verification docs in the same merge as code

- **D-08:** Update **affected C-1 matrix rows** in `.planning/phases/09-audit-logging/09-VERIFICATION.md` and **any inventory lines that 1:1 track** the changed **AUD-04-* IDs** in the **same PR** as production + tests for Phase **61**. Merge must not leave C-1 claiming the pre-batch mechanism for rows this batch changes.
- **D-09:** Reserve **Phase 62 (AUD-02)** for **`09-03-SUMMARY.md`**, cross-cutting prose, and holistic “post-batch truth” — **not** for retro-fitting matrix rows Phase 61 should already have updated.

### Claude's Discretion

- Exact MFA **function boundaries** inside `mfa.ex` for the chosen cluster, internal helper naming, and the minimal set of **A-style** fault tests — provided **D-01–D-09** are satisfied and **AUD-04** traceability stays explicit in PLAN/review.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-01** definition, v1.7 scope (one batch, not full SEED-002)
- `.planning/ROADMAP.md` — Phase **61** goal row (v1.7 table)
- `.planning/PROJECT.md` — v1.7 milestone intent (audit durability + adoption)

### Audit semantics and C-1 truth

- `docs/audit-semantics.md` — T1 vs T2 vocabulary, co-fate rules
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — **C-1** matrices (**AUD-04-*** rows); **must be updated** for rows touched by this batch
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — inventory pointers (Phase **62** narrative alignment)

### AUD-04 inventories (Phase 43–45)

- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md`
- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — MFA / account / API token row definitions
- `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`

### Likely implementation / test touchpoints

- `lib/sigra/mfa.ex` — primary MFA orchestration (subject to planner’s chosen cluster)
- `test/sigra/mfa_audit_atomicity_test.exs` — extend/align with **D-05** / **D-06**
- `lib/sigra/audit.ex` (and related) — `log_multi_safe/3`, `log_safe/3` usage patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`test/sigra/mfa_audit_atomicity_test.exs`** — established patterns for MFA audit atomicity; extend rather than invent a parallel harness.
- **`Sigra.Audit.log_multi_safe/3` / `__log_internal__/3`** — preferred T1 mechanism already used across auth/OAuth/account paths; MFA batch should compose into the same model.
- **Credo check `lib/sigra/credo/no_log_safe2_in_lib.ex`** — library code must use `log_safe/3` with explicit scope; keep new calls consistent.

### Established Patterns

- **Command-sized `Ecto.Multi` + `Repo.transact`** — idiomatic for co-fated domain + audit; avoid external I/O inside the transaction (email/Oban after commit or via documented T2).
- **C-1 honesty** — T2 rows require explicit **EX-*** or documented substitute; inventories + `09-VERIFICATION.md` are merge-gated evidence.

### Integration Points

- Host apps invoke Sigra contexts from **their** `Repo` transaction boundaries; library should expose **composable** `Multi` steps where possible rather than hidden global side effects.

</code_context>

<specifics>
## Specific Ideas

- Research synthesis (parallel review, 2026-04-23): prefer **inventory-backed** batches over ad-hoc grep-driven refactors; lessons from **Rails callbacks / Django signals / Spring AOP** argue for **explicit** `Multi` pipelines over magic audit side effects; **success-path audit assertions** match AUD-01 literal while **surgical** rollback tests prove co-fate where Multi is the story.

</specifics>

<deferred>
## Deferred Ideas

- **Full SEED-002** sweep — explicitly out of scope for v1.7 (`.planning/REQUIREMENTS.md`).
- **Session-store deferred cluster** (**AUD-04-015..017**) — separate batch unless explicitly chosen by future planning; not the default Phase **61** target.
- **Plugs-only audit** (`load_active_organization`, etc.) — poor first batch (infrastructure vs domain command, weak C-1 narrative); defer unless a future phase ties to **AUD-04** with clear product policy.
- **Holistic `09-03-SUMMARY.md` rewrite** — Phase **62 (AUD-02)**.

</deferred>

---

*Phase: 061-seed-002-bounded-batch*  
*Context gathered: 2026-04-23*
