# Phase 82: JWT refresh persistence + audit co-fate — Context

**Gathered:** 2026-04-24  
**Status:** Ready for planning

<domain>

## Phase boundary

Deliver **AUD-19-01**–**AUD-19-04**: when **`:audit_schema`** is set, **`user_tokens`** effects for JWT refresh (rotation / reuse-driven family revocation) and **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`** share **one** transactional boundary so the host never observes persisted rotation or revocation without a matching audit row, and audit failure rolls back persistence. Tests prove co-fate; planning truth (**44** / **45** / **09** / **`CHANGELOG`**) + **`82-VERIFICATION.md`** close the **AUD-08** footnote for these rows.

**Explicitly out of scope:** Phase **83** (**AUD-04-022**), new HTTP surfaces, broad phase **45** merge-gate work beyond JWT-path regression.

</domain>

<decisions>

## Implementation decisions (research-backed, coherent set)

### D-82-01 — Transaction ownership and module boundaries

- **Decision:** **`Sigra.JWT.refresh/3`** remains the **stable public entrypoint** and owns **exactly one** **`Repo.transaction/1`** (or **`Repo.transact/2`** if the codebase standardizes on 3.13) when **`:audit_schema`** is set, composing **`Ecto.Multi`** steps for persistence + audit. If **`jwt.ex`** grows unwieldy, extract orchestration to a **`@moduledoc false`** internal module (e.g. **`Sigra.JWT.RefreshCoFate`**) — same architecture, clearer SRP; **not** a new public API.
- **`Sigra.JWT.RefreshToken`:** stays **audit-agnostic** and **transaction-naive** for rotation mechanics: expose **`Multi`-friendly** operations (e.g. **`rotate_multi/3`** or equivalent **private** functions used only by the orchestrator) replacing bare **`repo.update!` / `insert!`** sequences **inside** the orchestrator’s Multi. **No** optional audit callbacks on rotate (avoids Rails-style hidden ordering).
- **`Sigra.APIToken`:** refactor **`commit_api_token_jwt_audit/3`** (or add a sibling) so JWT audit can append **`Audit.log_multi_safe`** steps to a **caller-supplied** **`Multi`** **without** opening a **nested** **`Repo.transaction`** when composed into the refresh transaction. Keep **`audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** as **thin standalone** entrypoints that run the **audit-only** transaction shell **for backward compatibility** (Phase **81** / **D-AUD-06** semantics) where hosts still call them **outside** refresh — document that **co-fated** refresh should use **`JWT.refresh`** only so audit is not double-emitted.
- **`Sigra.Auth.refresh_jwt/2`:** remains a **one-line delegate** to **`JWT.refresh/3`**; do **not** move the transaction boundary here (library facade ≠ host Phoenix context).
- **Rationale:** Matches **D-AUD-01** (orchestrator owns txn, domain modules stay thin), Ecto idioms (one txn at the workflow edge), avoids nested-transaction / savepoint footguns, contrasts with Spring **`REQUIRES_NEW`** / Rails callback ordering. Auth0-style reuse still fits **branch-specific** Multis inside the **same** outer transaction discipline.

### D-82-02 — Public caller-visible contract (exception to D-AUD-06)

- **Decision:** When **`:audit_schema`** is set and the **co-fate** transaction is used: **`{:ok, tokens}`** only if **both** persistence and audit commit. **Any** failed step (including audit insert / CHECK / constraint) → **full rollback** and **`{:error, :jwt_refresh_aborted}`** from **`JWT.refresh/3`** (name bikeshed OK if planner aligns with existing error naming — the invariant is **one stable atom** meaning “no new persisted refresh/access material from this call”). **Do not** return **`:ok`** with tokens for this path — that would contradict **AUD-19** and confuse hosts vs **D-AUD-06** audit-only helpers.
- **Existing errors unchanged** where they denote **business** outcomes before a co-fate txn completes: **`{:error, :invalid_token}`**, **`{:error, :token_expired}`**. **`{:error, :reuse_detected}`** is returned only **after** the reuse-path transaction **commits** successfully (family revoked + **`api.jwt_refresh_reuse`** when audit on) — preserves today’s “reuse wins over happy refresh” semantics.
- **`:jwt_refresh_aborted`:** **`@doc`** must state it covers audit/txn failure inside the co-fate boundary; operators use **`[:sigra, :audit, :log_safe_error]`** (or a **distinct** telemetry event if added) **in addition** to the error tuple — telemetry complements **`:error`**, does not replace it (contrast audit-only paths where **`:ok`** + telemetry is honest).
- **When audit is off:** keep current behavior (no co-fate requirement); no need for a transaction solely for audit.
- **Rationale:** Ecto **`Multi`** already rolls back all steps on failure — public API must mirror that for DX and compliance (no “rotated in DB, no audit row”). Explicit **exception** to **D-AUD-06** documented in **`AUDIT-ATOMICITY-DEFAULTS.md`** (**D-AUD-08**).

### D-82-03 — Reuse path (`:reuse_detected`) symmetry

- **Decision:** When audit on, **family-wide revocation** persistence and **`api.jwt_refresh_reuse`** live in the **same** **`Multi`** / **`Repo.transaction`** as **D-82-01** (reuse branch). **Never** commit **`revoke_family`** in one transaction and audit in another.
- **Telemetry:** **`[:sigra, :jwt, :refresh_reuse_detected]`** (and similar) **after** successful transaction commit (or from the success branch of **`transaction`**) so operators never see “reuse detected” when DB state rolled back — fixes ordering footgun vs current **`refresh_token.ex`**.
- **Performance (Claude’s discretion):** Prefer shrinking lock time with **`update_all`** / fewer round-trips when metadata updates remain correct; **`LIKE` on `sent_to`** family matching is a known cost but **out of scope** for **AUD-19** unless a planner finds a safe one-statement formulation without schema migration.

### D-82-04 — Tests (**AUD-19-03**)

- **Decision:** Add a **dedicated** module/file (e.g. **`test/sigra/jwt_refresh_audit_cofate_test.exs`**) with **`async: false`**, proving **persistence + audit co-fate** (happy, audit-off, CHECK/trigger fault injection per action). **`@moduledoc`** points readers to **`api_token_audit_atomic_test.exs`** for **audit-only** **`APIToken.audit_jwt_refresh*`** behavior (Phase **81**).
- **Keep** audit-only / helper-level tests in **`api_token_audit_atomic_test.exs`**; **do not** overload that file with full refresh rotation co-fate stories (different contract, worse CI labels).
- **Mirror Phase 79/81 style:** named tests per scenario, unique telemetry handler ids, small private helpers for **`ALTER TABLE … CHECK`** / restore **`try`/`after`**, action-scoped SQL counts.
- **Coverage:** (1) successful rotate + **`api.jwt_refresh`** row; (2) audit-off → persistence without audit rows; (3) fault injection → **no** partial **`user_tokens`** state + expected telemetry; (4) reuse path + **`api.jwt_refresh_reuse`** + rollback on audit failure.

### D-82-05 — Planning truth (**AUD-19-04**)

- **Decision:** **Surgical** updates to **44** / **45** / **09-VERIFICATION** cells for **048–049** (mechanism + **T1** wording) so **one** current claim: co-fate of **`user_tokens`** effects and **`api.jwt_refresh*`** when **`:audit_schema`** set. Add **one dated supersession footnote** per row or row-pair: Phase **81** = audit-row-only txn; Phase **82** = closes **AUD-08** persistence co-fate — preserves Nyquist trace without wholesale rewrites.
- **`09-03-SUMMARY`:** one short paragraph linking **`82-VERIFICATION.md`**.
- **`CHANGELOG` [Unreleased]:** one **operator/maintainer-facing** bullet for co-fate behavior; avoid noise for pure matrix churn without a behavior story.
- **Rationale:** Same discipline as **D-81-04**, but footnote **narrows** “deferred **AUD-08**” instead of expanding ambiguous **T1** silently.

### Claude's discretion

- Internal **`Multi` step names**, exact **`rotate_multi`** arity, and whether **`Repo.transact/2`** replaces **`transaction/1`** project-wide for this path only.
- Whether **`{:error, :jwt_refresh_aborted}`** maps internally from raw **`{:error, step, changeset, _}`** vs a tiny **`normalize_jwt_refresh_error/1`** helper.
- Optional concurrency tests for double reuse replay — only if cheap and stable.

### Folded todos

_None._

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-19-01**–**AUD-19-04**
- `.planning/ROADMAP.md` — Phase **82** goal + success criteria
- `.planning/PROJECT.md` — v1.19 intent (**AUD-08** closure)

### Prior phase (narrower slice)

- `.planning/phases/81-jwt-refresh-audit-atomicity/81-CONTEXT.md` — **D-81-01**–**D-81-04**; audit-only JWT audit (**explicitly excludes** persistence co-fate)

### Defaults (shift-left)

- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — **D-AUD-01**–**D-AUD-07** plus **D-AUD-08**–**D-AUD-11** (persistence co-fate class)

### Inventories and verification

- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — rows **048–049**
- `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md` — JWT appendix as needed
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — C-1 **048–049**
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md`
- `CHANGELOG.md` — `[Unreleased]`

### Code (integration points)

- `lib/sigra/jwt.ex` — **`refresh/3`**
- `lib/sigra/jwt/refresh_token.ex` — **`rotate/3`**, **`revoke_family/3`**
- `lib/sigra/api_token.ex` — **`audit_jwt_refresh/2`**, **`audit_jwt_refresh_reuse/2`**, **`commit_api_token_jwt_audit/3`**, **`commit_api_token_verify_failure_audit/2`**
- `lib/sigra/audit.ex` — **`log_multi_safe/3`**
- `test/sigra/api_token_audit_atomic_test.exs` — Phase **79**/**81** patterns

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`commit_api_token_jwt_audit/3`** — transaction shell + **`log_multi_safe`**; must gain a **compose-into-Multi** variant to avoid nested **`Repo.transaction`** when called from **`JWT.refresh`**.
- **`api_token_audit_atomic_test.exs`** — Postgres CHECK fault injection, telemetry handlers, **`sigra_config/1`** patterns.

### Established patterns

- **D-AUD-01** — orchestrator owns **`Repo.transaction`**, domain **`RefreshToken`** without **`Sigra.Audit`** imports.
- **Phase 81** — **`APIToken`** audit-only **`Multi`** for **`api.jwt_refresh*`**; **D-AUD-06** **`:ok`** on audit insert failure applies **only** to those standalone audit calls, **not** to co-fated **`JWT.refresh`**.

### Integration points

- Hosts call **`Sigra.JWT.refresh/3`** (or **`Sigra.Auth.refresh_jwt/2`**); co-fate work **internalizes** audit so applications are not required to call **`audit_jwt_refresh/2`** after refresh for the audited path — document migration for any host that currently double-calls.

</code_context>

<specifics>

## Specific ideas

- Cross-agent consensus: **one orchestrator transaction**, **no nested transactions**, **Auth0-style reuse** stays in a **reuse branch** of the same orchestration story, **telemetry after commit** on reuse.
- Error surface: prefer **one** new atom **`jwt_refresh_aborted`** for txn failures (including audit) over leaking raw **`Ecto.Multi`** tuples to callers.

</specifics>

<deferred>

## Deferred ideas

- **Dedicated `family_id` column / index** instead of **`LIKE` on `sent_to`** — performance milestone, not **AUD-19**.
- **Okta-style grace / overlap window** for concurrent refresh — product/security milestone if requested.
- **Phase 83** — **AUD-04-022** / **`confirm_enrollment`**.

**None** — discussion stayed within phase **82** scope for execution.

</deferred>

---

*Phase: 82-jwt-refresh-persistence-audit-cofate*  
*Context gathered: 2026-04-24*
