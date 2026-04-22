# Phase 45: OAuth, ops paths & C-1 sign-off — Context

**Gathered:** 2026-04-20  
**Status:** Ready for planning

**Note:** `gsd-sdk query init.phase-op "45"` may still return `phase_found: false` for markdown-table roadmap rows; this file is anchored on `.planning/ROADMAP.md` phase **45** and **AUD-08**.

<domain>

## Phase boundary

Close **AUD-08**: convert or honestly exclude **`Sigra.OAuth`**, **lockout**, **suspicious-login**, **impersonation**, and **worker-related** audit sites per a **Phase 45 AUD-04 extension**; align **C-1** narrative with post–v1.4 reality via **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`** and **`09-VERIFICATION.md`** (create if missing). **Full library CI green.** No net-new OAuth providers or unrelated product scope.

**North star:** When `:audit_schema` is set and a **Postgres** domain mutation must be explainable in an incident, that mutation and its **primary** audit evidence share one **`Repo.transaction`** (`Ecto.Multi` + `Audit.log_multi_safe/3` / `__log_internal__/3`). Natural seams (HTTP redirect, Assent I/O, SMTP, Oban bookkeeping) use **`log_safe/3`** or telemetry only when the co-fate invariant does not apply—each such site is **inventory-listed** (EX-*) with compensating controls, not hand-waved.

</domain>

<decisions>

## Implementation decisions

### D-45-01 — Unified tier vocabulary (all AUD-08 surfaces)

Use the **same** three-tier model in inventory rows, code comments, and Phase 9 verification:

| Tier | Mechanism | Use when |
|------|------------|----------|
| **T1 — Co-fated** | `Ecto.Multi` + audit step in one transaction; caller **`emit_telemetry_from_changes/2`** on `{:ok, changes}` | Monotonic security state, irreversible lifecycle, OAuth **domain** inserts/updates/deletes, lockout transitions that must match audit, canonical **deletion executed** evidence, etc. |
| **T2 — Durable observability, fail-open** | `log_safe/3` after `{:ok, _}` | No paired domain commit in the same DB txn (e.g. `oauth.authorize`, pre-persistence failures), or explicit high-volume **failure** paths where flipping `{:error, _}` on audit failure is worse DX—**requires EX-* row**. |
| **T3 — Volume / edge** | Telemetry (optional sampling) | Ultra-hot paths; **rare**; **EX-*** with reopen trigger; never marketed as row-level compliance evidence. |

**Cohesion rule:** Phase 45 must **not** introduce a different philosophy than Phases **43–44**; extend **AUD-04** IDs monotonically and link **43** / **44** / **45** inventory files both directions.

### D-45-02 — `Sigra.OAuth` (hybrid B — locked)

- **Reject** “Multi only everywhere” for OAuth: external I/O and redirects are not co-fatable with a DB audit row in one transaction.
- **Reject** “`log_safe` only for all mutations” when audit is enabled: contradicts C-1 / SEED-002 program for paired writes.
- **Adopt hybrid:** Any **`repo.insert` / `update` / `delete`** on user-owned domain data while audit is enabled must be composed into **`Ecto.Multi` + `log_multi_safe`** (or `__log_internal__` for multiple audit steps) in **one** `repo.transaction`. Concretely: extend **`Sigra.OAuth.Callback`** registration / link / unlink / identity-update paths that already use `Multi` so audit steps live **inside** the same transaction—not “commit then `log_safe`”.
- **Reserve `log_safe`** for **T2** boundaries: `oauth.authorize`, callback failures / rolled-back work, token-exchange failures **before** persistence, and other events where **no** domain commit pairs—**never** put tokens/secrets in metadata (D-23); provider name / stable reason codes only.
- **DX:** Document explicitly that **T1 OAuth mutations** may surface **`{:error, _}`** if audit insert fails when `:audit_schema` is set; **T2** paths keep fail-open semantics.

### D-45-03 — Lockout, suspicious login, impersonation

- Apply **D-45-01** tiers: **T1** for counter increments that feed lockout, **locked** transitions, and any **DB-backed** impersonation / risk rows that downstream automation treats as truth.
- **T2** for read-heavy **`*.failure`** paths with **no** state mutation—mirror **`api.token_verify.failure`** style from Phase 44; require **EX-*** + telemetry / rate limits.
- **Suspicious login:** durable **“decision to notify”** may be **T1** if backed by a row; **SMTP** stays **outside** the transaction (enqueue / Oban); never block auth on mail success.
- **Plugs:** enrich **request_id / IP / UA** only; **one audit writer** per outcome in the **context** module to avoid double-audit on retries.
- **Footguns to avoid:** secrets/PII in `metadata`; enumeration-sensitive timing differences between branches.

### D-45-04 — Oban workers (`AccountDeletion` and peers)

- **Keep** delayed deletion as an **Oban** worker (grace period, retries, uniqueness)—good separation of concerns.
- **Change forensic posture:** **`account.deletion_executed`** (canonical post-execution row) must be **T1**—**same `Repo.transaction`** as `Deletion.execute/3` domain effects, not **`log_safe`** after commit. Prefer **one internal API** shared with **`Sigra.Account.execute_deletion/3`** (or equivalent `Multi`) so HTTP and Oban do not fork composition.
- **Retries:** `perform/1` must be **idempotent** when user already deleted or not scheduled; guard against **duplicate audit rows** on retry (conditional insert, unique logical key, or txn-scoped no-op path).
- **Document** outside the txn: Oban job state transitions are still not co-fated with app txn—honest in C-1 matrix.

### D-45-05 — Phase 9 docs & C-1 sign-off

- **Create** `.planning/phases/09-audit-logging/` with **`09-03-SUMMARY.md`** (executive counts + pointer to inventories + trust model paragraph) and **`09-VERIFICATION.md`** containing a **C-1** section that is **falsifiable**:
  1. Scope: C-1 applies to claims of **DB co-fate** only.  
  2. Link **`docs/audit-semantics.md`** as normative vocabulary.  
  3. **Matrix:** AUD-04-id → mechanism (`log_multi_safe` / `__log_internal__` / `log_safe`) → tier → test evidence → EX- id.  
  4. **Intentional hybrid** block (tier-9 style) with exact orphan/missing-audit failure semantics.  
  5. **Sign-off rule:** every remaining `log_safe` site is T1-converted or EX-* waiver with owner + reopen trigger.
- If historical links expected these paths, **stub** files first with forward pointers, then fill content in the same PR series that closes AUD-08.
- Optional hygiene: link checker or script to grep internal doc paths—planner decides cost/benefit.

### D-45-06 — Execution order (planner-default wave)

1. **`45-AUD-04-INVENTORY.md`** (or agreed name) — OAuth + ops + workers; monotonic **AUD-04-xxx**; bidirectional links to **43** / **44** inventories.  
2. **OAuth** — implement **T1** Multis for agreed mutation rows; **T2** boundaries documented.  
3. **Lockout / suspicious / impersonation** — convert **T1** rows; **EX-*** the rest.  
4. **`Sigra.Workers.AccountDeletion`** — align execution audit with **T1**.  
5. **Phase 9 files** — land summaries + verification matrix; cross-link **`docs/audit-semantics.md`**.  
6. **Tests** — extend **`Sigra.Audit.Assertions` / `*_audit_atomicity_test.exs`** pattern per converted boundary (rollback + ordering-safe queries).

### D-45-07 — Testing & verification (inherits 43–44)

- Same bar as **D-43-04** / **D-44-06**: real repo, **no** `Repo` mocks for atomicity proofs; partial field assertions; `order_by: [asc: :id]` where ordering matters; invalid audit metadata to force rollback on **T1** paths.

### Claude's discretion

- Exact **AUD-04-0NN** numbering for new Phase 45 rows after Wave A grep.  
- Whether MFA-style **metadata consolidation** vs separate audit rows for some lockout edge cases—**within** single-transaction constraint.  
- Filename choice **`45-AUD-04-INVENTORY.md`** vs a longer composite name—content rules in **D-45-01** / **D-44-01** win regardless of filename.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **AUD-08**, SEED-002 / C-1, traceability table  
- `.planning/ROADMAP.md` — Phase **45** row + success criteria  
- `.planning/PROJECT.md` — v1.4 GA readiness & audit completeness narrative  

### Prior phase decisions & inventories

- `.planning/phases/39-audit-trail-completeness/39-CONTEXT.md`  
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-CONTEXT.md`  
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md` — Auth slice **AUD-04-001..019**  
- `.planning/phases/44-mfa-account-api-atomic-batches/44-CONTEXT.md`  
- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — MFA + Account + API token slice  

### Normative semantics & guides

- `docs/audit-semantics.md` — primitives, C-1 / SEED-002 vocabulary  
- `guides/recipes/testing.md` — audit atomicity testing patterns (as referenced from prior phases)  
- `guides/flows/audit-logging.md` — linked from audit-semantics  

### Primary implementation surfaces (Phase 45)

- `lib/sigra/oauth.ex` — OAuth orchestrator + `log_safe` call sites  
- `lib/sigra/oauth/callback.ex` — callback routing, **`Ecto.Multi`** registration / mutations  
- `lib/sigra/lockout.ex` — lockout + audit  
- `lib/sigra/suspicious_login.ex` — notifications + audit  
- `lib/sigra/impersonation.ex` — impersonation lifecycle + audit  
- `lib/sigra/workers/account_deletion.ex` — **post-`Deletion.execute` `log_safe`** — flagged for **D-45-04**  
- `lib/sigra/account.ex` — `execute_deletion` / deletion orchestration (align worker path)  
- `lib/sigra/audit.ex` — `log_safe/3`, `log_multi_safe/3`, `__log_internal__/3`, telemetry ownership  

### Phase 9 deliverables (to be created/updated per D-45-05)

- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — **planned**  
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — **planned** (C-1 matrix)  

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Sigra.OAuth.Callback`** — already uses **`Ecto.Multi`** for user + identity; extend with **`Audit.log_multi_safe`** / `__log_internal__` for **T1** parity (today success audits often follow via **`log_safe`** after transaction).  
- **`Sigra.Account.execute_deletion`** — **`Multi`** + audit precedent for deletion lifecycle; worker should converge on same composition for **execution + audit**.  
- **Phase 43–44 conversions** — `log_multi_safe` + `emit_telemetry_from_changes/2` + **`Sigra.Audit.Assertions`** patterns.  

### Established patterns

- **`log_safe`:** return shape stable; errors on **`[:sigra, :audit, :log_safe_error]`** telemetry.  
- **`log_multi_safe`:** audit failure rolls back domain steps in that **Multi**—document for hosts.  

### Integration points

- **Oban** — job retries and completion state are **orthogonal** to app transaction; document in verification matrix (**D-45-04**).  
- **Optional Oban** — `Code.ensure_loaded?(Oban.Worker)` compile guards must remain valid.  

</code_context>

<specifics>

## Specific ideas

- User chose **all four** discuss areas (OAuth, ops modules, workers/C-1 docs), ran **parallel subagent research**, then asked for a **single cohesive** recommendation set emphasizing: idiomatic **Elixir/Ecto** (`Multi`, explicit transactions), **least surprise** for library consumers, **strong DX**, lessons from **Rails / NextAuth / Auth0 / paper_trail / Spatie**-shaped ecosystems (callback magic vs explicit contracts; token-in-logs footguns; defensible verification matrices), and **honest hybrid** documentation.  
- User requested this context be **frozen as planning** — captured here without a separate SPEC.md for phase 45.  

</specifics>

<deferred>

## Deferred ideas

- **`audit_jwt_refresh` / `audit_jwt_refresh_reuse`** — remains deferred per **44-CONTEXT** unless explicitly added to Phase 45 inventory.  
- **OAuth example-app ceremony smoke** — optional post-v1.4; `docs/audit-semantics.md` already notes non-guarantee per milestone.  
- **CI markdown link checker** — optional; listed under Claude's discretion / planner in **D-45-05**.  

### Reviewed todos (not folded)

- None — `todo.match-phase "45"` returned empty when discuss started.  

</deferred>

---

*Phase: 45-oauth-ops-c1-signoff*  
*Context gathered: 2026-04-20*
