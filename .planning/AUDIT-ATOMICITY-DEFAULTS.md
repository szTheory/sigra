# Sigra — audit atomicity defaults (GSD / planning)

**Purpose:** Capture **default engineering choices** for bounded **SEED-002**–style phases and `/gsd-discuss-phase` so planners rarely re-open settled tradeoffs. **Override** in phase CONTEXT when a requirement truly demands an exception (call that out explicitly).

**Status:** Established **2026-04-24** (Phase 80 research synthesis); extended **D-AUD-05..07** **2026-04-24** (Phase 81 JWT audit-only slice + discuss shift-left); **D-AUD-12** + discuss delegation prefs **2026-04-24** (Phase **83**).

## Defaults

### D-AUD-01 — Orchestration layer

- **`Sigra.Account`** (and analogous top-level orchestrators) **own** `Repo.transaction/1`, `Ecto.Multi`, and `Sigra.Audit.log_multi_safe/3` when audit must share fate with domain writes.
- **Domain modules** (`Sigra.Account.PasswordChange`, `EmailChange`, `Deletion`, …) stay **audit-agnostic**: no `Sigra.Audit` imports; they expose changesets, `Repo` operations, or small `Multi.run`-friendly steps.
- **Rationale:** Matches Phoenix **context** orchestration, avoids ActiveRecord/Django-signal-style hidden coupling, keeps **one transaction owner**, reduces nested-transaction footguns, improves generator DX (single extension seam).

### D-AUD-02 — Deprecation of superseded audit-only helpers

- When a standalone `log_safe/3` helper is replaced by an atomic **`Multi` + `log_multi_safe`** path: **`@deprecated`** with a **compile-time** warning for **at least one minor**, then **remove** in the following minor (pre-1.0). Document the **single supported** call sequence in CHANGELOG + upgrade guide.
- **Avoid:** immediate patch removal of public APIs; long-lived “smart no-op” shims without idempotency keys; default **runtime raise** for “double audit” in production (prefer CI / docs / generator alignment).

### D-AUD-03 — Options keyword shape

- Public **`Sigra.Account.*`** arities keep **`(repo, …, opts)`** with the **same physical `opts` keyword** hosts/generators already pass for `change_password`, email flows, etc.
- Implementations **`Keyword.take`** / NimbleOptions **composed schemas** so each operation uses the **audit context slice** consistently; operation-specific keys are validated per function without inventing a second public opts bag.

### D-AUD-04 — Testing split

- **MockRepo / unit:** API contracts, branches, error tuples, composition (no second Postgres copy of every branch).
- **Postgres + fault injection (`CHECK` / similar):** **one** happy path + **one** rollback proof per atomic story in `*_audit_atomicity_test.exs` (or equivalent), mirroring existing `change_password` patterns.

### D-AUD-05 — Audit-only `Multi` (no domain step)

- Helpers that **only** persist an audit row (e.g. **`api.jwt_refresh`**, **`api.jwt_refresh_reuse`**) still use **`Repo.transaction/1` + `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set — same **durability class** as token verify failure audits — with a **single private `commit_*`** owning the transaction shell and **thin `def` wrappers** for action-specific opts.
- **Do not** imply **shared fate** with unrelated domain tables unless a future phase explicitly joins them in the same `Multi` (**AUD-08**-class work stays out of bounded SEED-002 slices unless scoped).

### D-AUD-06 — Caller contract when audit insert fails (audit-only paths)

- Public functions that today return **`:ok`** and use **`log_safe`/`log_multi_safe`** for **side-channel audit** keep **`:ok`** on audit subsystem failure **when the audit row is not co-fated with a durable partner write**. This covers three legitimate sub-classes: **detection-only** (the audit row is the forensic record), **pre-domain** (the event fires before a persistence target exists), and **audit-only helpers**. Emit **`[:sigra, :audit, :log_safe_error]`** (or the same telemetry contract as `emit_log_safe_error`) so operators can alert; **raise** only on programmer-wiring errors. **`@doc`** must state **`:ok` does not guarantee** the audit row exists.

### D-AUD-07 — ExUnit layout for audit fault injection

- **Separate named tests** per action × fault story (no parametrized loops for fault paths). Reuse **only** small private helpers for `ALTER … CHECK` + `try/after` + telemetry attach; **unique** handler IDs per test; **`async: false`**; action-scoped SQL counts.

### D-AUD-08 — Persistence + audit co-fate (JWT refresh class; **AUD-19**)

- When requirements mandate **one commit** for **domain `user_tokens` effects** and **`api.jwt_refresh*`** audit rows (**:audit_schema** set):
  - **Orchestrator** (**`Sigra.JWT.refresh/3`**, optionally delegated to an internal **`@moduledoc false`** module) owns **exactly one** **`Repo.transaction/1`** (or **`Repo.transact/2`** if the project adopts it here).
  - **`Sigra.APIToken`** (or equivalent) must expose audit as **`Ecto.Multi` steps** composable into that transaction — **do not** call **`Repo.transaction`** inside helpers used from that **`Multi`** (no nested txn / savepoint surprise).
  - **Public contract:** **`{:ok, tokens}`** iff the **full bundle** commits; **any** step failure → rollback and **`{:error, _}`** — **explicit exception** to **D-AUD-06** for this class only. **`@doc`** must contrast with **`audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** standalone semantics (**`:ok`** + telemetry on audit-only failure).
- **Rationale:** **D-AUD-06** exists because audit-only paths cannot roll back already-committed host work; co-fate paths **can** and **must** roll back persistence when audit fails — returning **`:ok`** with tokens would violate least surprise and audit integrity.

### D-AUD-09 — Security telemetry after commit (reuse / co-fate)

- **`Telemetry.event/3`** (or similar) that implies **persisted** security outcomes (**reuse detected**, family revoked) must run **after** the transaction **commits** (success branch), not interleaved between persistence and audit where a later audit failure would roll back DB state but leave misleading signals.

### D-AUD-10 — ExUnit split: audit-only vs persistence co-fate

- **Audit-only** stories (helpers that do not join **`user_tokens`** writes in the same txn) stay in **`api_token_audit_atomic_test.exs`** (or the established audit-atomicity module for that surface).
- **Persistence + audit co-fate** proofs live in a **dedicated** file (e.g. **`jwt_refresh_audit_cofate_test.exs`**) with **`@moduledoc`** cross-linking the audit-only module — preserves CI failure labels and avoids conflating **D-AUD-06** contracts with **D-AUD-08** contracts in one module.

### D-AUD-11 — Planning matrix updates when **T1** semantics strengthen

- Prefer **surgical cell edits** + **one dated supersession footnote** (phase id + what narrowed, e.g. **AUD-08** closed) across **44** / **45** / **09-VERIFICATION** / **09-03-SUMMARY** in lockstep; **`CHANGELOG` [Unreleased]** carries the user-visible behavior story; phase **`NN-VERIFICATION.md`** is the merge gate spine. Avoid wholesale matrix rewrites unless the row taxonomy is wrong.

### D-AUD-12 — MFA invalid pre-DB enrollment attempt (**AUD-04-022**)

- When **`:audit_schema`** is set, **`Sigra.MFA.confirm_enrollment/5`** wrong-TOTP path (**before** enrollment `Multi`) persists **`mfa.enroll.failure`** via **`Repo.transaction/1` + `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`**, using the **same audit-only shell** as **`commit_ad_hoc_mfa_audit/5`** (success → **`emit_telemetry_from_changes`**; failure → **`[:sigra, :audit, :log_safe_error]`** per existing rescue/changeset paths).
- **Public return:** **`{:error, :invalid_code}`** whenever the TOTP check fails — **independent** of audit insert outcome (**not** **D-AUD-08**; not a new failure atom for audit DB issues).
- **Explicit waiver** (retain **`log_safe`**) remains valid only if a phase **CONTEXT** records an intentional **exception to D-AUD-05** with updated **EX-44-02** rationale (**AUD-20-01** second branch).

## Discuss-phase preferences (this project)

- When the user **delegates** (“all”, “synthesize”, “don’t make me think”), default orchestrator behavior: **parallel research** (subagents or equivalent) on listed gray areas → **one coherent CONTEXT** aligned with **PROJECT.md** / **REQUIREMENTS.md** / these defaults.
- **Still require explicit user choices** for topics in **`.planning/config.json` → `workflow.discuss_always_surface_for_user`** (semver/public API, security model vs published OWASP stance, generator/host output contracts).

## When to still run discuss-phase

Use `/gsd-discuss-phase` when any of: new **external** contract (HTTP, host generator output), **semver exception**, **cross-cutting** audit API change (e.g. new `log_multi_safe` step names), **persistence + audit co-fate** scope not already covered by **D-AUD-08**, or **explicit** stakeholder preference. Otherwise planners may treat **D-AUD-01..11** as locked unless phase SPEC says otherwise.
