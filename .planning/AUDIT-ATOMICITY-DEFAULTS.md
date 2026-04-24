# Sigra — audit atomicity defaults (GSD / planning)

**Purpose:** Capture **default engineering choices** for bounded **SEED-002**–style phases and `/gsd-discuss-phase` so planners rarely re-open settled tradeoffs. **Override** in phase CONTEXT when a requirement truly demands an exception (call that out explicitly).

**Status:** Established **2026-04-24** (Phase 80 research synthesis); extended **D-AUD-05..07** **2026-04-24** (Phase 81 JWT audit-only slice + discuss shift-left).

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

- Public functions that today return **`:ok`** and use **`log_safe`/`log_multi_safe`** for **side-channel audit** keep **`:ok`** on audit subsystem failure; emit **`[:sigra, :audit, :log_safe_error]`** (or the same telemetry contract as `emit_log_safe_error`) so operators can alert; **raise** only on programmer-wiring errors. **`@doc`** must state **`:ok` does not guarantee** the audit row exists.

### D-AUD-07 — ExUnit layout for audit fault injection

- **Separate named tests** per action × fault story (no parametrized loops for fault paths). Reuse **only** small private helpers for `ALTER … CHECK` + `try/after` + telemetry attach; **unique** handler IDs per test; **`async: false`**; action-scoped SQL counts.

## When to still run discuss-phase

Use `/gsd-discuss-phase` when any of: new **external** contract (HTTP, host generator output), **semver exception**, **cross-cutting** audit API change (e.g. new `log_multi_safe` step names), or **explicit** stakeholder preference. Otherwise planners may treat **D-AUD-01..07** as locked unless phase SPEC says otherwise.
