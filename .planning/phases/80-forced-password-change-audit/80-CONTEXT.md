# Phase 80: Forced password change audit atomicity — Context

**Gathered:** 2026-04-24  
**Status:** Ready for planning

<domain>

## Phase boundary

Close **AUD-04-043** / **EX-44-05** by co-fating clearing **`must_change_password`** with a durable **`account.password_change`** audit row (`metadata: %{forced: true}`) in **one** transaction (**`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`**), retire standalone **`log_safe`** for that completion path, extend **`account_audit_atomicity_test.exs`**, and refresh planning truth (**44** inventory, **09**, **09-03-SUMMARY**, **`CHANGELOG` [Unreleased]**). No new product capabilities beyond atomicity + documentation alignment.

</domain>

<decisions>

## Implementation decisions

### D-80-01 — Where the `Multi` + audit live (cohesive with existing code)

- **Decision:** Add a **`Sigra.Account`** public entry (exact name for planner: e.g. `clear_password_change_requirement/3` — mirror mental model of existing `require_password_change/2` delegate) that:
  - When **`:audit_schema` absent** — delegates to **`Sigra.Account.PasswordChange.clear_force_change/2`** only (current behavior, no audit).
  - When **audit enabled** — builds **`Ecto.Multi`** with **`Multi.run(:domain, fn r, _ -> PasswordChange.clear_force_change(r, user) end)`** (or equivalent **`Multi.update`** on the same changeset semantics), then **`Sigra.Audit.log_multi_safe("account.password_change", …, metadata: %{forced: true})`**, then **`finish_audit_multi/2`** + telemetry parity with **`change_password` / `set_password`**.
- **Rationale:** Matches **`Account.change_password/5`** and **`set_password/4`** architecture already in `lib/sigra/account.ex` (orchestrator owns `Multi` + `log_multi_safe`; domain module stays free of `Sigra.Audit`). Subagent + ecosystem review: Rails/Django callback-style audit inside “model” modules causes ordering and transaction-boundary bugs; Phoenix-style **explicit context** composition is idiomatic and **least surprise** for Sigra’s generator-driven hosts.
- **Do not** move `Sigra.Audit` into **`PasswordChange`** for this slice.

### D-80-02 — `audit_forced_password_change/2` (AUD-17-02)

- **Decision:** **`@deprecated`** the function for **one minor** with a message naming the **`Sigra.Account`** entry from D-80-01 as the **only** supported path when audit is on; **remove** in the **next minor** after deprecation ships. CHANGELOG + upgrade stub call out “do not pair old helper with new atomic path” to avoid **double audit**.
- **Rationale:** Pre-1.0 SemVer permits hard breaks, but Elixir compile **deprecation warnings** maximize DX and reduce **silent missing audit** when library and generated code skew. Rejects long-lived heuristic no-ops and default **runtime raise** for double-audit (availability / false-positive risk).

### D-80-03 — `opts` keyword contract

- **Decision:** The new **`Sigra.Account`** entry takes **`(repo, user, opts)`** with the **same physical `opts` keyword** as **`change_password/5`** / **`set_password/4`** (reuse **`account_audit_opts/1`**, **`password_change_scope_kw/2`**, **`audit_repo_opts/2`**, **`Scope.from_opts`** patterns). Internally **`Keyword.take`** / future NimbleOptions composition may ignore operation-irrelevant keys, but **call sites** (generator + host) pass **one** `opts` bag — no parallel “minimal subset” public shape.
- **Rationale:** Avoids typo-driven **silent ignore** of `:audit_schema`; keeps generator forwards simple; subagent consensus: shrink surface at call sites only when strict validation exists, not by splitting public keywords per function.

### D-80-04 — Testing layout

- **Decision:** Keep **`test/sigra/account/password_change_test.exs`** on **`Sigra.MockRepo`** for **`PasswordChange.clear_force_change/2`** contract tests (no Postgres duplication of every branch).
- **Decision:** Add **forced-clear** coverage to **`test/sigra/account_audit_atomicity_test.exs`**: (1) happy path — user flag cleared + exactly one matching audit row; (2) **one** `CHECK` / fault-injection rollback proving user update does not commit without audit (same mechanical pattern as existing **`change_password`** rollback test).
- **Rationale:** “One proof per concern” — mocks for API shape, Postgres only where the engine proves atomicity.

### D-80-05 — Host / generator DX

- **Decision:** Documented happy path: hosts (and future generator output) call the **new `Sigra.Account` function** when audit is configured; they **stop** calling **`audit_forced_password_change/2`** after migration. **`PasswordChange.clear_force_change/2`** remains supported for low-level / non-audit scenarios.
- **Rationale:** Single obvious orchestration seam; aligns with **`PROJECT.md`** trust + DX goals.

### Claude's discretion

- Exact public function name (`clear_password_change_requirement/3` vs `clear_must_change_password/3`, etc.) — pick for symmetry with **`require_password_change/2`** and ExDoc clarity.
- Whether to extract a **private** `clear_force_changeset/1` in `PasswordChange` to share between `clear_force_change/2` and `Multi.update` — only if it reduces duplication without widening public API.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and inventory

- `.planning/REQUIREMENTS.md` — **AUD-17-01..04**, v1.17 milestone checklist
- `.planning/ROADMAP.md` — Phase 80 goal + success criteria
- `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` — **AUD-04-043**, **EX-44-05**
- `.planning/phases/44-mfa-account-api-atomic-batches/44-CONTEXT.md` — Phase 44 batch intent (Account owns `Multi` for AUD-07)

### Defaults (this session)

- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — **D-AUD-01..04** reusable defaults for future SEED-002 / audit phases

### Code (integration points)

- `lib/sigra/account.ex` — `change_password/5`, `set_password/4`, `finish_audit_multi/2`, dispatch comment block (~L37–49)
- `lib/sigra/account/password_change.ex` — `clear_force_change/2`
- `lib/sigra/account.ex` — `audit_forced_password_change/2` (deprecation target)
- `test/sigra/account_audit_atomicity_test.exs` — `change_password` happy + `CHECK` rollback patterns
- `test/sigra/account/password_change_test.exs` — MockRepo `clear_force_change` tests

### Verification / planning truth (outputs of phase work)

- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — C-1 row **043**
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md`
- `CHANGELOG.md` [Unreleased]

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Account.change_password/5` / `set_password/4`** — template for `Multi.run(:domain, …)` + **`log_multi_safe("account.password_change", metadata: …)`** + **`finish_audit_multi/2`**.
- **`PasswordChange.clear_force_change/2`** — domain update to reuse inside **`Multi.run`** (no nested `Repo.transaction` today — safe composition).
- **`account_audit_atomicity_test.exs`** — `CHECK` constraint fault injection for rollback proofs.

### Established patterns

- **Audit off:** delegate straight to domain module without `Multi`.
- **Audit on:** orchestrator-only `Multi` + telemetry from **`emit_telemetry_from_changes/1`**.

### Integration points

- Generator / host `Auth` contexts that today might call **`clear_force_change`** then **`audit_forced_password_change/2`** should migrate to the **single** `Sigra.Account` orchestrated call.

</code_context>

<specifics>

## Specific ideas

- Cross-ecosystem lesson (subagent synthesis): **explicit context/facade** beats **implicit model callbacks** for audit + transactions (Rails/Django pain points). NextAuth-style **explicit** configuration aligns with Sigra’s library boundary.
- Nested `Repo.transaction` inside `Multi.run` (seen on **`PasswordChange.change`**) is a pre-existing pattern for password change; **forced clear** avoids extra nesting because **`clear_force_change`** is a single `update` — prefer keeping it that way.

</specifics>

<deferred>

## Deferred ideas

- NimbleOptions validation for full `Sigra.Account` opts — valuable follow-up, not required to ship AUD-17 if docs + types stay clear.
- Broader refactor to remove nested transaction in **`change_password`** domain path — separate phase if ever scheduled.

### Reviewed todos (not folded)

_None._

</deferred>

---

*Phase: 80-forced-password-change-audit*  
*Context gathered: 2026-04-24*
