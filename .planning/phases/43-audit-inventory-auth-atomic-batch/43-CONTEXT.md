# Phase 43: Audit inventory + Auth atomic batch — Context

**Gathered:** 2026-04-20  
**Status:** Ready for planning

**Source:** Subagent research (inventory docs, prioritization, exclusions, ExUnit layout, delivery waves) + alignment to Phase **39** / **41** context, `lib/sigra/auth.ex` audit dispatch comments, and `REQUIREMENTS.md` **AUD-04** / **AUD-05**.

<domain>

## Phase boundary

Deliver **AUD-04** (checked-in inventory of remaining `Sigra.Audit.log_safe/3` integration sites, grouped by module, **priority order**, explicit **v1.4 exclusions** with REQ/D-01/C-1 traceability) and **AUD-05** (convert agreed **highest-priority `Sigra.Auth`** hybrid sites — excluding the three paths already atomic per roadmap — to **`Ecto.Multi` + `__log_internal__` / `log_multi_safe`** with **audit-aware** tests). **Full library CI green.** No MFA bulk beyond what accidentally touches Auth-only paths (**AUD-06** owns MFA-specific sites per inventory).

</domain>

<decisions>

## Implementation decisions

### D-43-01 — AUD-04 inventory artifact (structure & location)

- **Split layout (default):** One **inventory** markdown (rows + stable IDs + status) and a short **exclusions appendix** in the same phase folder (or a single file with two clearly labeled sections — same review unit). Add a separate **batching / execution checklist** subsection only if AUD-05 spans more than one merge.
- **Location:** Primary artifact under **`.planning/phases/43-audit-inventory-auth-atomic-batch/`** (satisfies ROADMAP “43-* or .planning/”); **link once** from `CHANGELOG.md` or milestone notes when AUD-04 lands so GA readers find it without spelunking.
- **Granularity:** Rows keyed by **named transaction / use-case boundary** (e.g. “login success path: session row + audit”) and **canonical audit action string**, not by every private function. Per-function rows are **out** — too much churn when refactors split helpers.
- **Stable IDs:** Use **`AUD-04-NNN`** (or `SIGRA-AUD04-NNN`) per row; reference lightly from code comments or moduledoc where it helps grep — optional but **recommended** for top-tier sites.
- **Machine-readable twin:** **Defer** (no YAML/JSON source of truth) unless integration surface grows past ~**30** distinct sites or CI-driven drift checks become cheaper than review; Sigra is not there for Auth alone in v1.4.

### D-43-02 — AUD-05 Auth batch ordering (priority stack)

Apply this **default stack** before lower tiers (aligns with OWASP-style “trust-changing events first,” Ecto explicit-transaction culture, and `auth.ex` comment block). **Do not** skip upward for DX — if a lower tier is easy, still finish higher tiers first unless a row is provably independent.

1. **Credential + authenticator mutations** affecting next login — password change / hash upgrade paths that must stay consistent with **session invalidation** narrative (coordinate with any existing Multi there first).
2. **Bulk session / token invalidation tied to (1)** — same-transaction or explicitly documented ordering if already split; audit row must not claim success when invalidation did not commit.
3. **Successful session minting** — `auth.login.success` (and equivalent “session established”) — forensic anchor for “who had access from when.”
4. **Lockout / unlock / DB-backed deny counters** — dispute and abuse value; promote failure paths to **Multi** when they share fate with **counters or flags** that gate access (Phase 39: failure-only spam can stay `log_safe` until it participates in gating state).
5. **Magic link request + verify success** — replay- and phishing-adjacent; match roadmap “future Multi form” in dispatch comments.
6. **Registration success** — account provenance; compose with existing `register_user_multi` where the public API already exposes Multi.
7. **Password reset request** (token issuance) — time-bounded token state; pair with verify/complete already on `__log_internal__` where applicable.
8. **Routine logout / single-session revoke** — completeness; **after** (1)–(6) unless a quick win is needed for morale — still subject to inventory row and test.
9. **Bare failed-attempt logs** without lockout mutation — **default stays `log_safe`** until AUD-08 or a later wave unless tests prove a forensic gap; document in inventory as **intentional hybrid** with rationale.

**Exclusions from AUD-05 (already satisfied elsewhere):** Confirm link, confirm code, password reset **complete** — already **`__log_internal__`** per `auth.ex` comments; **inventory lists them as DONE**, not conversion targets.

### D-43-03 — Exclusions & “won’t convert in v1.4”

- **Bias:** **Minimal high-signal register** — every **remaining** hybrid Auth row is either **AUD-05**, **forwarded to 44/45/46** with phase ID, or a **numbered exclusion** — no silent omission.
- **Each exclusion row must include:** **ID**, **REQ/control** (e.g. AUD-05, D-01, C-1), **scope** (module + action prefix or path), **current mechanism** (`log_safe` / telemetry), **residual risk** (one plain sentence), **compensating control** (tests, rate limits, `log_safe_error` telemetry), **owner**, **reopen trigger** (milestone, metric, or incident class), **evidence** (PR or test name), **last reviewed** (date).
- **Forbidden:** “TODO later”, unnamed owner, or exclusions that contradict **CHANGELOG** / **REQUIREMENTS** without an explicit REQ amendment.

### D-43-04 — Verification layout (tests)

- **Primary pattern:** **`test/sigra/**`** (or existing convention) **dedicated modules** named **`*_audit_atomicity_test.exs`** only for **same-transaction** guarantees — one module can cover multiple related operations if setup is shared; prefer **verb–noun–property** filenames (e.g. `login_audit_atomicity_test.exs`).
- **Case template:** Reuse / extend **one** integration-style case (e.g. existing DataCase / repo + Sandbox pattern from Phase 39) — centralize Sandbox checkout and “create user → call API → query audit” helpers; **no** new macro-heavy harness.
- **Assertions:** **Partial fields** only (`action`, stable metadata keys, `actor_id` / `target_id` per D-39); **`order_by: [asc: id]`** (or stable compound) on audit queries; **never** assert exact timestamps; **never** mock `Repo` for atomicity proofs.
- **Duplication budget:** **One deep test per converted boundary** (happy + rollback/control where meaningful) + **at most one** light smoke elsewhere if it catches a distinct regression class — **not** full payload equality in every feature test.
- **Example app:** Follow Phase **41** precedent — **merge-blocking** proof for the **highest-value** path can live in **`test/example`** when the behavior is host-delegate shaped; library tests remain authoritative for **`Sigra.Auth`** contracts.

### D-43-05 — Delivery shape (waves inside Phase 43)

- **Default: two-wave within the phase —** **Wave A:** merge **AUD-04** inventory + exclusions + priority table (**behavior-neutral**, CI green). **Wave B:** one or more PRs implementing **AUD-05** scoped strictly to the inventory, each PR keeping bisect story clean.
- **Single combined PR** only if solo maintainer, tiny uncontroversial inventory, and **multiple logical commits** preserved inside the merge for `git bisect`.
- **After Wave A merges:** treat inventory as **batching authority** — amendments use small follow-up PRs; **do not** close AUD-04 in REQUIREMENTS until the artifact and links exist on **main**.

### Claude's discretion

- Exact `AUD-04-NNN` numbering scheme and whether IDs appear in comments vs only in the inventory table.
- Whether `login` vs `magic_link` sub-steps land in one PR or two (ordering within D-43-02 stack still respected).
- Fine-grained helper naming under `test/support/` for audit query helpers.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **AUD-04**, **AUD-05**; Out of scope / exclusion rules for v1.4
- `.planning/ROADMAP.md` — Phase **43** row + success criteria
- `.planning/PROJECT.md` — SEED-002 / GA readiness narrative

### Prior phase decisions (carry-forward)

- `.planning/phases/39-audit-trail-completeness/39-CONTEXT.md` — D-39 audit-aware tests, Multi vs `log_safe`, telemetry, conversion wave philosophy
- `.planning/phases/41-backup-codes-ga-product-closure/41-CONTEXT.md` — MFA regenerate atomicity vs **AUD-06** split
- `.planning/phases/42-human-ga-matrix-evidence/42-CONTEXT.md` — GA vs AUD boundary (reference only)

### Runtime code

- `lib/sigra/audit.ex` — `log_safe/3`, `__log_internal__/3`, `log_multi_safe/3`, `emit_telemetry_from_changes/1`, `[:sigra, :audit, :log_safe_error]`
- `lib/sigra/auth.ex` — D-26 dispatch comment block (lines ~246–262 region); existing atomic confirm / code / reset patterns as templates

### Testing references

- `guides/recipes/testing.md` — audit testing recipe (if present)
- Phase **39** canonical list: `test/sigra/audit/log_safe_scope_test.exs`, `test/support/audit_test_event.ex` — patterns for audit assertions

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Sigra.Audit.__log_internal__/3`** + **`emit_telemetry_from_changes/1`** — same contract as existing atomic flows in `auth.ex`.
- **`Sigra.Audit.log_multi_safe/3`** — append audit inside host-configured Multi without changing return shapes when audit is disabled.
- **`register_user_multi/2`** — public Multi composition hook for registration-shaped work.

### Established patterns

- **Hybrid `log_safe`:** must not flip `{:ok, _}` on audit insert failure; **Multi** paths own full transaction semantics — callers’ expectations must match Phase **39** D-39-16.
- **Comments in `auth.ex`** already classify atomic vs hybrid — inventory should **normalize** that truth into AUD-04 rows to avoid drift.

### Integration points

- **`Sigra.Auth`** public entry points and internal `handle_*` helpers — AUD-05 conversion surface.
- **Generated host `Auth` delegates** — thin; behavior changes flow from library, tests may span **example** app per Phase **41** bar for critical paths.

</code_context>

<specifics>

## Specific ideas

- User requested **all five** discuss areas in one pass with **subagent research**, then a **single coherent recommendation set** emphasizing Elixir/Ecto idioms, cross-ecosystem lessons (Rails/Django/Spring/OWASP-style), DX, least surprise, and alignment with Sigra’s hybrid lib + generator vision.

</specifics>

<deferred>

## Deferred ideas

- **Machine-generated inventory from static analysis** — only if manual inventory drifts; not default v1.4.
- **MFA / OAuth / Account bulk conversions** — Phases **44–45** per ROADMAP; cite rows in AUD-04, do not implement here except Auth-only overlap.

**None otherwise** — discussion stayed within Phase **43** scope.

</deferred>

---

*Phase: 43-audit-inventory-auth-atomic-batch*  
*Context gathered: 2026-04-20*
