# Phase 44: MFA + Account/API atomic batches — Context

**Gathered:** 2026-04-20  
**Status:** Ready for planning

**Note:** `/gsd-discuss-phase` `init.phase-op` currently returns `phase_found: false` for table-form rows in `.planning/ROADMAP.md`; this context is anchored on the published roadmap + requirements anyway.

<domain>

## Phase boundary

Deliver **AUD-06** (MFA): convert agreed **`Sigra.MFA` success paths** (and other high-signal paths that **share DB fate** with audit) from post-commit **`Sigra.Audit.log_safe/3`** to audited **`Ecto.Multi`** (`Audit.log_multi_safe/3` or `__log_internal__/3`) with **audit-aware tests**. Deliver **AUD-07** (`Sigra.Account` in-process APIs + agreed **`Sigra.APIToken`** lifecycle mutations): same atomicity bar where domain writes and audit must not diverge on `{:ok, _}`. **Full library CI green.** OAuth, session-store-only paths, and **Oban worker** audit hardening stay in **Phase 45 / AUD-08** unless explicitly listed in the phase-44 inventory with exclusion-grade rationale.

</domain>

<decisions>

## Implementation decisions

### D-44-01 — Inventory & waves (AUD-04 continuity)

- **Artifact:** Add **`44-AUD-04-INVENTORY.md`** (or equivalent name under this phase folder) for **MFA + Account + API token** rows only; **keep** `43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md` as the **Auth-only** slice. Link both directions (43 file footer → 44 file; 44 file header → 43) so **AUD-04** reads as one governed program across files.
- **Row IDs:** Continue **`AUD-04-020+`** monotonic IDs (Auth table ends at **AUD-04-019**). Add columns **`REQ batch`** (`AUD-06` / `AUD-07`) and **`Phase`** (`44`) on each new row.
- **Wave A / B:** Repeat **D-43-05**: **Wave A** = behavior-neutral extended inventory + exclusions + priority table on `main`; **Wave B+** = implementation PRs **keyed to row IDs**. Do **not** treat moduledoc/`rg` alone as the inventory (fails D-43-03 / compliance friendliness).
- **Closing AUD-04:** Update `.planning/REQUIREMENTS.md` checklist for **AUD-04** only when the **combined** Auth + 44 inventory satisfies “grouped by module” intent or every gap is a **numbered exclusion** with owner + reopen trigger.

### D-44-02 — Library prerequisite: multiple audit steps in one Multi

- **Problem:** `Audit.log_multi_safe/3` appends a fixed **`Ecto.Multi.insert(..., :audit, ...)`** step. **Two** audit inserts in one Multi **collide** on the `:audit` key (backup verify needs **`mfa.verify.success`** + **`mfa.backup_code_used`** in one transaction).
- **Decision:** Implement a **supported** pattern in **`Sigra.Audit`** before (or in the same PR series as) MFA double-audit Multis — e.g. **optional step name** for `log_multi_safe` / a thin **`__log_internal__`** wrapper that accepts `:audit_step`, or **documented** internal helper. **Do not** fork ad hoc `Multi.insert` copies inside `Sigra.MFA`.
- **Telemetry:** Whatever emits today from `emit_telemetry_from_changes/1` must remain correct when **multiple** audit steps exist (extend or emit per-step — planner picks minimal correct behavior).

### D-44-03 — MFA batch (AUD-06): priority & hybrid policy

**Implementation order (highest forensic risk first, aligned with D-43-02 spirit + Phase 41 template):**

1. **`verify/4` success** — `last_verified_step` / `last_used_at` updates + **`mfa.verify.success`** share one transaction (mirror **`regenerate_backup_codes/4`** Multi style in `mfa.ex`).
2. **`verify_backup/4` success** — `BackupCodes.consume` + lockout reset + **two audit rows** (**`mfa.verify.success`** with `metadata.method: "backup_code"`** and **`mfa.backup_code_used`**) in **one** `repo.transaction`, using D-44-02 API.
3. **`confirm_enrollment/4` success** — promote **`mfa.enroll.success`** into the **same** Multi as credential + backup `insert_all` so “enrolled” and “audited success” share fate when `:audit_schema` is set (accept stricter `{:error, _}` if audit insert is invalid — consistent with atomic create elsewhere).
4. **`disable/4` / `disable!/4`** — append audit to the **existing** cleanup **Multi** (`cleanup_mfa/5`) so **`mfa.disable`** does not commit after a successful Multi without audit pairing.
5. **Lockout / counter paths on verify failure** — where **`Lockout.increment`** or equivalent **mutates MFA state**, prefer **Multi** (counter + **`mfa.verify.failure`**; if locked, add **`mfa.lockout`** in the **same** transaction **or** one row with explicit `metadata` — pick one style per inventory row and test it). Aligns D-43-02 “counters that gate access” with atomic audit.
6. **Pure validation / read-only exits** (`:not_enrolled`, lockout from `Lockout.check` with **no** new write, invalid enrollment code **before** DB work) — **remain `log_safe`** or unaudited; **tier-9-style** volume-sensitive paths stay hybrid **only** when **no** paired domain mutation exists.

**Explicit carries from Phase 41:** **`mfa.backup_codes_regenerate`** with audit on is **owned by Phase 41** — AUD-06 focuses **other** MFA sites unless 41 left a documented gap.

**DX / least surprise:** Document that **`disable/4` may emit `mfa.verify.success` (step-up) then `mfa.disable`** — product/analytics should not double-count “challenges” without reading action strings. Changelog + audit semantics doc when behavior shifts.

### D-44-04 — Account batch (AUD-07): scope & ordering

- **In scope (Phase 44):** All **in-process** `Sigra.Account` public entrypoints that today use **`log_safe` after success**: email change request/confirm/cancel, `change_password`, `set_password`, `schedule_deletion`, `cancel_deletion`, **`execute_deletion`**, `audit_forced_password_change/2` (and any sibling in `account.ex` covered by inventory rows).
- **`execute_deletion` special case:** Preserve the **documented** “audit row before hard delete” semantics unless REQ is amended; implement **Multi** so the **audit insert and deletion steps share rollback**, not “delete committed, audit best-effort.”
- **Default-defer to Phase 45 (AUD-08):** **`Sigra.Workers.AccountDeletion`** (`account.deletion_executed`) — crosses **Oban** boundary; REQ maps **worker-related** sites to AUD-08. Only pull into 44 if **`44-AUD-04-INVENTORY.md`** adds an explicit AUD-07 row with C-1/D-01 traceability.
- **Priority stack for PRs:** (1) password / forced password change, (2) **`confirm_email_change`**, (3) request/cancel email change, (4) schedule/cancel deletion, (5) **`execute_deletion`** last so simpler Multis land first without destabilizing the pre-delete audit story.

**Ecosystem hygiene:** Email and Oban enqueue stay **after commit** (Ecto `after_transaction` / explicit ordering) — never SMTP inside DB transactions.

### D-44-05 — API token remainder (AUD-07)

- **`revoke/2`:** Convert to **`Multi.update` + `Audit.log_multi_safe("api.token_revoke", …)`** in one `repo.transaction` — symmetric to atomic **`api.token_create`**; add Postgres audit atomicity test mirroring `api_token_audit_atomic_test.exs` patterns.
- **`revoke_all/2`:** Today **no audit** — add **one summary action** (e.g. **`api.token_revoke_all`**) with `metadata` including **count** (and no raw secrets), implemented via **`Multi.run` + `update_all`** + `log_multi_safe`, unless an exclusion row documents why not.
- **`api.token_verify.failure`:** **Keep `log_safe`** as **intentional hybrid** (read-heavy path, no domain row update); compensate with telemetry + documented volume stance (GitHub/Stripe-style: lifecycle in audit, verification mostly operational). Revisit only if REQ or incidents demand durable failure rows.
- **`audit_jwt_refresh*`:** **Defer** to JWT refresh persistence work / **AUD-08** unless inventory places them in 44 with a clear DB co-fate story — avoid pretending JWT audits share fate with `api_tokens` rows.

**`maybe_update_last_used`:** Treat **async `last_used_at`** as **observability**, not audit-grade; document. If later “last used” becomes security-critical, plan throttled sync updates without per-request audit spam.

### D-44-06 — Testing & verification (inherits D-43-04 / D-39)

- **Modules:** `test/sigra/**/*_audit_atomicity_test.exs` (or extend existing audit atomicity modules) for **each converted boundary** — one deep test (happy + rollback via invalid audit / constraint) per row moved to Multi.
- **Assertions:** Partial fields, **`order_by: [asc: id]`** on audit queries, **no** `Repo` mocks for atomicity proofs, **no** exact timestamp equality.
- **Example app:** Follow Phase **41** precedent — merge-blocking proof only when behavior is **host-delegate shaped**; library tests remain authoritative for **`Sigra.MFA`** / **`Sigra.Account`** contracts.

### D-44-07 — Cross-cutting architecture principles (cohesion)

- **Single-transaction rule:** If a **domain mutation** committed on `{:ok, _}` must **never** be narrated without its audit row when audit is enabled, use **Multi**. If audit is **best-effort observability** and return tuples must never flip on audit failure, use **`log_safe`** and **document** in inventory as **EX-44-NN** hybrid with compensating control (telemetry, rate limits, tests).
- **Library vs Rails/Django callback hell:** Prefer **explicit Multi composition** over implicit `after_commit` magic inside Sigra — hosts keep control; tests stay deterministic.
- **Honesty at non-Ecto edges:** Same class as SessionStore — if a path **cannot** be made atomic without host cooperation, **exclusion row** + compensating control, not fake Multi.

### Claude's discretion

- Exact **`AUD-04-0NN`** numbering for each MFA/Account/API row after Wave A grep pass.
- Whether MFA lockout uses **one** vs **two** audit inserts on threshold (metadata-only consolidation vs separate actions) **within** the “single transaction” constraint.
- Filename choice between `44-AUD-04-INVENTORY.md` vs `44-AUD-06-07-INVENTORY.md` (content rules above stay the same).

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **AUD-06**, **AUD-07**, **AUD-04** closure criteria, **AUD-08** boundary
- `.planning/ROADMAP.md` — Phase **44** row + success criteria
- `.planning/PROJECT.md` — v1.4 SEED-002 / GA readiness narrative

### Prior phase decisions

- `.planning/phases/39-audit-trail-completeness/39-CONTEXT.md` — D-39 audit vs Multi, `log_safe` semantics, tests
- `.planning/phases/41-backup-codes-ga-product-closure/41-CONTEXT.md` — regenerate + audit atomicity vs AUD-06 split (**D-41-03**)
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-CONTEXT.md` — D-43-01 inventory shape, D-43-02 priority stack analogy, D-43-03 exclusions, D-43-04 tests, D-43-05 waves
- `.planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md` — Auth-only AUD-04 rows (**AUD-04-001..019**); forward pointer for 44

### Runtime code (primary conversion surfaces)

- `lib/sigra/audit.ex` — `log_safe/3`, `log_multi_safe/3`, `__log_internal__/3`, `emit_telemetry_from_changes/1`
- `lib/sigra/mfa.ex` — MFA orchestration + D-26 dispatch comments
- `lib/sigra/account.ex` — account lifecycle + D-26 dispatch comments
- `lib/sigra/workers/account_deletion.ex` — deferred default (**AUD-08**)
- `lib/sigra/api_token.ex` — token lifecycle (`create` already Multi — template for `revoke`)

### Tests (patterns)

- `test/sigra/api_token_audit_atomic_test.exs` — reference for token create atomicity
- Phase **39** / **43** references in `43-CONTEXT.md` canonical list for audit assertion style

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Sigra.APIToken.create/3`** — canonical **`Multi.insert` + `Audit.log_multi_safe("api.token_create", …)` + `emit_telemetry_from_changes/1`** pattern to mirror for **`revoke/2`**.
- **`Sigra.MFA` `regenerate_backup_codes/4`** (Phase 41) — template for MFA Multi + audit + telemetry after transaction.
- **`Sigra.Audit.log_multi_safe/3` / `__log_internal__/3`** — same contracts as Auth conversions in Phase 43.

### Established patterns

- **`log_safe` on success:** `{:ok, _}` stable even if audit insert fails — operators use **`[:sigra, :audit, :log_safe_error]`** telemetry.
- **`log_multi_safe` on success:** audit insert participates in rollback — callers may see **`{:error, _}`** when audit schema rejects row; document for LiveView / API surfaces.

### Integration points

- Generated **`MyApp.Auth`** delegates stay thin — **do not** add nested `Repo.transaction` wrappers around library Multis without an explicit host contract (document in planning if unavoidable).

</code_context>

<specifics>

## Specific ideas

- User requested **all four** discuss areas with **parallel subagent research** and a **single cohesive recommendation set** emphasizing: idiomatic Elixir/Ecto (`Multi`, `Repo.transaction`, post-commit email), **least surprise** for host apps, **strong DX**, lessons from **Rails/Django callback pitfalls**, **GitHub/Stripe-style PAT lifecycle auditing** (mutations audited, verify mostly operational), and **honest hybrid tiers** for hot failure paths.
- Subagent consensus highlights: **`revoke/2` atomicity is non-negotiable for AUD-07 symmetry**; **backup verify keeps two audit actions in one txn**; **Audit API must support multiple audit steps per Multi** before MFA backup path lands.

</specifics>

<deferred>

## Deferred ideas

- **`Sigra.Workers.AccountDeletion` / `account.deletion_executed`** — default **Phase 45 / AUD-08** (job boundary + retry semantics) unless promoted via inventory.
- **`audit_jwt_refresh` / `audit_jwt_refresh_reuse`** — defer until JWT persistence + AUD-08 unless explicitly inventoried in 44.
- **Per-token audit rows for `revoke_all`** — default **summary event** only; revisit if enterprise customers demand per-credential revocation rows (likely new table or export — not v1.4 default).

### Reviewed todos (not folded)

- None — `todo.match-phase` returned no matches for phase 44.

</deferred>

---

*Phase: 44-mfa-account-api-atomic-batches*  
*Context gathered: 2026-04-20*
