# Phase 81: JWT refresh / reuse audit atomicity — Context

**Gathered:** 2026-04-24  
**Status:** Ready for planning

<domain>

## Phase boundary

Close **AUD-18** / **AUD-04-048** / **AUD-04-049** by replacing standalone **`Sigra.Audit.log_safe/3`** on **`Sigra.APIToken.audit_jwt_refresh/2`** and **`audit_jwt_refresh_reuse/2`** with **`Repo.transaction/1`** + audit-only **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set; extend **`test/sigra/api_token_audit_atomic_test.exs`**; align **44** / **45** / **09** / **`CHANGELOG` [Unreleased]**; record merge gate in **`81-VERIFICATION.md`**.

**Explicitly out of scope:** JWT refresh **persistence** / refresh-token **row** co-fate with audit (**AUD-08**), new HTTP surfaces, and any new product capability beyond audit durability for these two actions.

</domain>

<decisions>

## Implementation decisions (research-backed, coherent set)

### D-81-01 — Code structure (`api_token.ex`)

- **Decision:** Introduce **one shared private** `commit_api_token_jwt_audit/3` (or arity that fits existing `Audit.log_multi_safe` opts) that owns **`Multi.new()` → `Audit.log_multi_safe/3` → `config.repo.transaction/1` → success telemetry / error handling**, mirroring the mechanical shell of **`commit_api_token_verify_failure_audit/2`**.
- **`audit_jwt_refresh/2`** and **`audit_jwt_refresh_reuse/2`** remain **thin public wrappers** that only assemble **action-specific** opts: action string (`"api.jwt_refresh"` / `"api.jwt_refresh_reuse"`), scope from `user_id`, **`outcome: "failure"`** + **`metadata: %{reason: "refresh_token_reuse_detected"}`** only on reuse, **`audit_multi_step`** atom per function, and pass through **`api_token_audit_opts(config)`**.
- **Rationale (subagent + patterns):** Library-idiomatic **DRY for orchestration** (transaction branches, telemetry, rescue discipline) and **locality for intent** (two small `def` at call sites). Avoids duplicated `case transaction(multi)` / rescue blocks that drift on review. Aligns with **D-AUD-01** (orchestrator owns transaction) scoped to **`Sigra.APIToken`** for this slice. Contrasts with Rails callbacks / Django signals / Spring aspects where **hidden ordering** caused double-skip or wrong-commit audits — **grepable explicit `commit_*`** is the fix.

### D-81-02 — Caller-visible behavior on audit insert failure

- **Decision:** **Same policy for both functions:** caller-visible result stays **`:ok`** whenever the audit subsystem cannot persist (invalid changeset, constraint / rescued DB surface, or `log_safe_error`-class path), with **`[:sigra, :audit, :log_safe_error]`** telemetry (metadata includes **`action`** and **`reason: :constraint_violation`** where applicable — match **`emit_log_safe_error`** contract used in Phase 79 tests). **Raise** only on **unexpected** `Multi` / transaction wiring (same posture as **`commit_api_token_verify_failure_audit/2`**).
- **Rationale:** Preserves existing **`@spec … :: :ok`** and **`log_safe`** integrator mental model: **JWT refresh correctness is not the same artifact as audit row presence**; returning **`{:error, _}`** after host code may have already committed refresh work is **misleading and high surprise**; **raise on transient DB** turns observability gaps into **outages**. OWASP-adjacent posture here: **do not deny the refresh path solely because append-only audit failed**; **observe** via telemetry for SIEM/SRE. **Doc obligation:** `@doc` states **`:ok` does not prove the audit row exists** — point operators at **`log_safe_error`** handlers (same honesty as `log_safe`).

### D-81-03 — Tests (`api_token_audit_atomic_test.exs`)

- **Decision:** **Separate named `test` blocks** per scenario so CI failures read **`api.jwt_refresh`** vs **`api.jwt_refresh_reuse`**. **Fault injection:** one dedicated test per action (CHECK rejects that action on `audit_events`), asserting **no row** for that action + **`assert_receive`** on **`[:sigra, :audit, :log_safe_error]`** with **`count: 1`**, **`action`**, **`reason: :constraint_violation`** — **mirror Phase 79 verify failure posture** per **AUD-18-03** (not necessarily line-copy). **Happy path + audit-off:** short dedicated tests (two for happy if clearer than one combined). **DRY only** via a **small private helper** for `ALTER` / `try` / `after` + optional telemetry attach (unique handler id per test — **do not** reuse `:verify_failure_guard`). **No** property-based or loop-parametrized fault tests. Keep **`async: false`**, action-scoped counts, truncate in `setup`.
- **Rationale:** ExUnit signal-to-noise; avoids flaky shared CHECK `setup`; matches established file culture.

### D-81-04 — Planning truth (44 / 45 / 09 / CHANGELOG)

- **Decision:** After implementation **matches** `lib/sigra/api_token.ex`, perform a **surgical honesty pass**, not a cosmetic “green flip”:
  - **44** / **45** inventories: update **mechanism** and **implementation pointer** to reflect **`Repo.transaction/1` + `Multi` + `log_multi_safe`** for 048–049; set verification / tier language to **T1 for AUD-18 bounded slice** only when tests + code prove it.
  - Add **one explicit footnote** per row or summary line: **T1 here means audit-row durability for `api.jwt_refresh*` (audit-only Multi)** — **AUD-08** (JWT persistence / refresh-token storage co-fate) remains **deferred**; do **not** imply phase 45 “signoff” already delivered 048/049 before this code landed.
  - **EX-45-JWT-*** appendix: **prefer additive dated clarification** over wholesale historical rewrite; edit only if cross-links or triggers are wrong.
  - **09-VERIFICATION.md** C-1 **048–049**, **09-03-SUMMARY** bounded-batch note, **`CHANGELOG` [Unreleased]**: user-facing trace per **AUD-18-04**; **no** CHANGELOG noise for pure internal matrix churn without behavior story.
- **Rationale:** Nyquist / C-1 integrity — **minimal mechanism-only flips without narrative** mislead maintainers; **full appendix rewrites** erase audit trail. Middle path: **truthful cells + short clarifying sentences**.

### Claude's discretion

- Exact **`audit_multi_step`** atom names and **`commit_*` arity** as long as they stay private, consistent with **`commit_api_token_verify_failure_audit`**, and readable in stack traces.
- Whether happy paths for refresh + reuse live in **two tests** or **one** test calling both — prefer **two** if CI failure labels matter more than line count.

### Folded todos

_None._

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-18-01..04**, v1.18 milestone checklist
- `.planning/ROADMAP.md` — Phase 81 goal + success criteria
- `.planning/PROJECT.md` — v1.18 JWT refresh audit atomicity intent

### Inventories and verification

- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — rows **048–049**
- `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md` — **EX-45-JWT-*** appendix as needed
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — C-1 rows **048–049**
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md`
- `CHANGELOG.md` — `[Unreleased]`

### Defaults (shift-left)

- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — **D-AUD-01..07** (includes audit-only JWT slice)

### Code (integration points)

- `lib/sigra/api_token.ex` — `audit_jwt_refresh/2`, `audit_jwt_refresh_reuse/2`, `commit_api_token_verify_failure_audit/2`, `api_token_audit_opts/1`
- `lib/sigra/audit.ex` — `log_multi_safe/3`, `log_safe/3`, telemetry for `log_safe_error`
- `test/sigra/api_token_audit_atomic_test.exs` — Phase 79 patterns (fault injection, telemetry)

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`commit_api_token_verify_failure_audit/2`** — template for audit-only **`Multi` + `transaction` + `emit_telemetry_from_changes` + rescue / `log_safe_error`** discipline.
- **`api_token_audit_atomic_test.exs`** — Postgres setup, CHECK guards, **`VerifyFailureTelemetryHandler`**, action-scoped counts.

### Established patterns

- **Audit off:** early return without `Repo.transaction` (same as other `APIToken` audit paths).
- **Audit on:** single transaction owner inside **`Sigra.APIToken`**.

### Integration points

- Callers (JWT refresh flow, host apps) keep calling **`audit_jwt_refresh/2`** and **`audit_jwt_refresh_reuse/2`** — no new public seam required for this phase.

</code_context>

<specifics>

## Specific ideas

- Subagent consensus: **explicit orchestration** over ActiveRecord/Django-signal-style magic; **telemetry as contract** for audit-loss observability.

</specifics>

<deferred>

## Deferred ideas

- **AUD-08** — JWT refresh **persistence** / refresh-token **row** atomicity with audit co-fate (explicitly not phase 81).

### Reviewed todos (not folded)

_None._

</deferred>

---

_Phase: 81-jwt-refresh-audit-atomicity_  
_Context gathered: 2026-04-24_
