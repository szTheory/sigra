# Phase 39: Audit trail completeness — Context

**Gathered:** 2026-04-18  
**Status:** Ready for planning  
**Source:** `REQUIREMENTS.md` (AUD-01–AUD-03), `ROADMAP.md`, `SEED-002`, prior discuss-phase synthesis + parallel research (ExUnit/Ecto patterns, Multi vs post-commit audit, subsystem ROI, doc traceability)

<domain>

## Phase boundary

Satisfy **AUD-01–AUD-03** for **SEED-002** / Phase 9 **C-1** follow-up: **audit-aware** library test pattern; **one** non-trivial **`log_safe/3` → atomic `Ecto.Multi`** conversion **or** a bounded phased plan with explicit v1.3 “done” scope if conversion is blocked; **three** additional integration surfaces covered by audit-aware tests **or** documented deferral with next-milestone hook. **No new product features** — tests, transactional audit completeness posture, and honest documentation only.

</domain>

<decisions>

## Implementation decisions

### AUD-01 — Audit-aware test harness

- **D-39-01 — Default API shape:** Ship **plain-function** test helpers (qualified or `import`), not macros as the primary surface — explicit `repo` argument; optional thin wrappers around `Repo.one` / `Repo.all` with **partial field** matching (Oban.Testing–style), not full struct equality.
- **D-39-02 — Assertion scope:** Assert **stable fields** — `action`, `outcome` (if present), `actor_id`, `effective_user_id`, `target_id`, `organization_id`, and **selected** `metadata` keys — never raw token, hash, or volatile timestamps unless isolated in a dedicated test.
- **D-39-03 — Optional audit:** When `audit_schema` is nil / audit disabled, tests use a **tag or setup branch** to **skip** audit assertions or assert **no row** — same tests must stay green on minimal hosts.
- **D-39-04 — CaseTemplate:** Do **not** require a `CaseTemplate` in the library default; document a **copy-paste `DataCase` snippet** for hosts that need **`Phoenix.Ecto.SQL.Sandbox`** / `allow` patterns for cross-process requests.
- **D-39-05 — Sandbox footguns:** Document **ordering** (`order_by` on audit queries), **`async: true`** allowances, and **no** `Repo.all` without ordering when multiple rows exist.

### AUD-02 — First atomic conversion vs bounded plan

- **D-39-06 — Primary conversion target:** **`Sigra.APIToken` token create** (`do_create/4` in `lib/sigra/api_token.ex`) — refactor to **`Ecto.Multi`** with **`Sigra.Audit.__log_internal__/3`** on the success path so **insert + audit** share one transaction; preserve existing **return shapes** (`{:ok, raw_key, token}` / `{:error, changeset}`) and **metadata rules** (no raw secret in audit).
- **D-39-07 — Telemetry:** After `Repo.transaction/1`, call **`Sigra.Audit.emit_telemetry_from_changes/1`** (or equivalent documented pattern from `Sigra.Audit` moduledoc) **only** on `{:ok, changes}` — never on rollback (same contract as existing atomic sites in `lib/sigra/auth.ex`).
- **D-39-08 — Fallback if blocked:** If a **semver or host-compat** issue blocks the Multi landing in v1.3, produce a **bounded phased plan** (explicit waves + “done for v1.3” line) and still **downgrade ambiguity** in narrative per AUD-02 — **plan is fallback**, not first choice.

### AUD-03 — Three additional integration sites

- **D-39-09 — Site 1:** **`api.token_create`** — covered by the same change as D-39-06; tests must assert **business + audit** atomically when audit schema is enabled.
- **D-39-10 — Site 2:** **Login success / failure / lockout** cluster in **`lib/sigra/auth.ex`** (or the narrowest integration test module that already exercises those paths) — audit-aware assertions on **representative** success and **at least one** security-relevant failure path where audit exists today.
- **D-39-11 — Site 3:** **MFA verify / enrollment completion** **or**, if test cost is prohibitive, **OAuth link/unlink** in **`lib/sigra/oauth.ex`** — pick the suite with **existing** strong DB integration coverage; document the choice in the plan if MFA is deferred.
- **D-39-12 — Deferral path:** If fewer than three sites ship in v1.3, **`REQUIREMENTS.md` AUD-03** must gain an explicit **deferral paragraph** (owner, trigger, next milestone hook) — do not silently leave the checkbox ambiguous.

### Documentation / verification narrative (C-1)

- **D-39-13 — Canonical trio:** **`CHANGELOG.md`** (when guarantees shift), **`.planning/REQUIREMENTS.md`** (shall/shall-not + evidence links), **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`** (resolution pointer when closed). Do **not** rely on missing `.planning/phases/09-audit-logging/*` paths as sole authority.
- **D-39-14 — Optional public doc:** Add **`docs/audit-semantics.md`** (or an ExDoc page) summarizing **`log_safe/3`** vs **`Multi` + `__log_internal__`**, **`[:sigra, :audit, :log_safe_error]`**, and **non-goals** — link from README or guides if created.
- **D-39-15 — Anti-theater:** Any verification file must distinguish **tested** vs **promised** vs **explicitly not promised** (residual C-1 outside converted sites until Phase B waves).

### Cross-cutting engineering rules

- **D-39-16 — Two primitives:** Keep **same-transaction** (`Multi` / `log_multi_safe`) vs **best-effort** (`log_safe`) story explicit in code comments + docs — do not blur without a deliberate REQ change.
- **D-39-17 — Conversion waves (post–AUD-02):** Prefer **high-stakes success paths** and flows already near a **single transaction** before touching **high-volume failure-only** audits.

### Claude's discretion

- Exact helper module name (`Sigra.Test.*` vs `Support.*`) and public vs `:test`-only mix group.
- MFA vs OAuth pick for D-39-11 if both are similarly costly — default preference **MFA** for compliance narrative unless tests are materially thinner.
- Subdirectory naming under `docs/` if D-39-14 lands as a multi-page section instead of one file.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing Phase 39.**

### Requirements & seeds

- `.planning/REQUIREMENTS.md` — AUD-01, AUD-02, AUD-03 (Phase 39)
- `.planning/ROADMAP.md` — Phase 39 row
- `.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md` — C-1 background, phased A/B estimate, breadcrumbs
- `.planning/PROJECT.md` — SEED-002 / C-1 pointer, D-01 audit atomicity revisit note

### Runtime audit implementation

- `lib/sigra/audit.ex` — `log_safe/3`, `__log_internal__/3`, `log_multi_safe/3`, telemetry contracts
- `lib/sigra/auth.ex` — existing **atomic** `__log_internal__` patterns (confirm / code / reset) as templates
- `lib/sigra/api_token.ex` — **AUD-02 target** (`do_create/4` insert + `log_safe` today)
- `CHANGELOG.md` — audit API / caveat history

### Existing tests (integration anchors)

- `test/sigra/audit/log_safe_scope_test.exs` — scope / impersonation behavior for `log_safe/3`
- `test/sigra/credo/no_log_safe2_in_lib_test.exs` — arity-2 ban in `lib/sigra/**`
- `test/support/audit_test_event.ex` — minimal audit schema for tests

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Sigra.Audit.__log_internal__/3`** + **`emit_telemetry_from_changes/1`** — same pattern as atomic flows in `auth.ex`.
- **`Sigra.Audit.log_multi_safe/3`** — appends audit when schema present, no-op when nil — useful when composing public multis.
- **`Sigra.Test.AuditEvent`** — schema stand-in for audit changeset tests.

### Established patterns

- **Hybrid audit:** `log_safe/3` returns `:ok` on insert failure; observability via **`[:sigra, :audit, :log_safe_error]`** — tests and docs must not imply stronger guarantees for `log_safe` paths.
- **Library return contracts:** Audit failure must not flip `{:ok, _}` to error on **integration** sites using `log_safe` today; **Multi** paths may fail the whole op — callers must already expect transaction failure.

### Integration points

- **`Sigra.APIToken.create/3`** — primary AUD-02 refactor surface.
- **Auth / OAuth / MFA test modules** under `test/sigra/` — AUD-03 expansion targets (pick files with strongest existing DB coverage).

</code_context>

<specifics>

## Specific ideas

- User requested **all** discuss areas in one pass with **subagent research**; recommendations were synthesized for **mutual coherence** (harness → first Multi at API token create → three integration surfaces → docs).
- Ecosystem anchors explicitly used in synthesis: **ExUnit + Ecto Sandbox**, **Oban.Testing** partial assertions, **Rails/Django/Spring** after-commit vs in-txn audit lessons.

</specifics>

<deferred>

## Deferred ideas

- **Full conversion** of all remaining `log_safe/3` sites (~30+) — **post–v1.3** waves (SEED-002 Phase B); out of scope except as explicitly bounded plan under AUD-02 fallback.
- **Outbox / async audit** for external consumers — not v1.3 unless a REQ is promoted.

### Reviewed todos (not folded)

- None — `gsd-sdk query todo.match-phase` unavailable in this environment; no todo file merge performed.

</deferred>

---

*Phase: 39-audit-trail-completeness*  
*Context gathered: 2026-04-18*
