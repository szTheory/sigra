# Phase 85: OAuth audit atomicity closure (AUD-21) — Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>

## Phase boundary

Close the AUD-04 inventory rows **052–056, 058, 063** so each row is either **T1 atomic via `Repo.transaction/1` + `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`** *or* **explicitly retired with sharpened `EX-45-*` text classifying the row as a `D-AUD-06` audit-only / read-only / pre-domain site with a specific reopen trigger**. Then downgrade Phase 9 C-1 from `PASS-WITH-CAVEATS` to `PASS`, flip SEED-002 to `validated`, and file `85-VERIFICATION.md`.

**Explicitly out of scope:** Introducing new domain schemas (e.g. `oauth_state_records`, `oauth_callback_attempts`, `suspicious_login_events`, `impersonation_denied_attempts`); revisiting v1.0 stateless OAuth state HMAC decision; making Oban a hard dep; any AUD-04 row outside 052–056/058/063; phase 45 merge-gate work beyond regression for the new code paths.

</domain>

<decisions>

## Implementation decisions (research-backed, coherent set)

### D-85-01 — Per-row verdicts (the core decision)

Of the 7 target rows, only **one cluster** (impersonation start/stop, rows 053/054) has a real domain-entity write to co-fate against; the other five are detection-only / read-only / pre-domain paths where the audit row IS the durable forensic artifact. The phase verdict is therefore a **mix of T1 conversion and EX-classified retirement**, not a uniform conversion sweep.

| Row | Site | Verdict | Class |
|-----|------|---------|-------|
| **053** | `Sigra.Impersonation.start/5` | **T1 — convert** | Has `Auth.create_session` partner write |
| **054** | `Sigra.Impersonation.stop/4` | **T1 — convert** | Has `Auth.delete_session` partner write |
| **052** | `Sigra.SuspiciousLogin` notify path | **Retire — sharpen EX-45-03** | D-AUD-06 detection-only |
| **055** | `Sigra.Impersonation.evaluate_timeout/4` | **Retire — sharpen EX-45-04** | D-AUD-06 read-only evaluation |
| **056** | `Sigra.Impersonation.log_denied/5` | **Retire — sharpen EX-45-05** | D-AUD-06 pre-creation denial |
| **058** | `Sigra.OAuth.authorize_url/4` | **Retire — sharpen EX-45-01** | D-AUD-06 read-only URL gen |
| **063** | `Sigra.OAuth.handle_callback/4` failure branch | **Retire — sharpen EX-45-02** | D-AUD-06 pre-user-resolution |

**Rationale:** Cross-ecosystem evidence is unambiguous on the OAuth pre-domain rows — Auth0, Okta, NextAuth.js / Auth.js, Ueberauth, OmniAuth, Spring Security all use telemetry/log-only for `oauth.authorize` and pre-user `oauth.callback.failure`; none persist library-level durable rows for these. The same logic applies to `security.suspicious_login` (rack-attack, django-axes maintainer guidance #768), `admin.impersonation.timeout_expire` (read-only computation), and `admin.impersonation.denied` (matches AWS CloudTrail denied `sts:AssumeRole` model exactly — audit-only, SOC 2 CC7.2 defensible). Introducing new domain schemas to manufacture atomicity for these rows would be scope creep against PROJECT.md's minimal-schema DX value, with no forensic gain over the existing `audit_events` row + telemetry + rate-limit compensating controls. Only 053/054 have a real partner mutation, so they get the real T1 treatment.

### D-85-02 — `SessionStore` optional Multi-compose callbacks (rows 053/054)

- **Decision:** Extend the `Sigra.SessionStore` behaviour with **two optional callbacks**: `c:create_session_multi/3` and `c:delete_session_multi/3` (exact names at planner discretion; `Multi`-returning equivalents of the existing `create_session/3` and `delete_session/3`). Use `@optional_callbacks` so existing third-party adapters (ETS, Redis, host-custom) continue to compile and run unchanged.
- **Default Ecto adapter (`Sigra.SessionStores.Ecto`)** implements both — returns `Ecto.Multi` steps the orchestrator composes into ONE `Repo.transaction/1` along with `Sigra.Audit.log_multi_safe/3`.
- **`Sigra.Impersonation.start/5` and `Sigra.Impersonation.stop/4`** become orchestrators per **D-AUD-01**: do a capability check on the configured store (e.g. `function_exported?/3` after `Code.ensure_loaded/1`); if the store implements the optional callback, run one Multi (`SessionStore.*_multi` steps + `Audit.log_multi_safe`); if not, fall back to the current `create_session` → `log_safe` sequence with a documented adapter-keyed T2 footnote.
- **Public contract:** When the orchestrator runs the Multi path, return `{:ok, _}` only if **both** persistence and audit commit; any failure → full rollback + stable error atom **`{:error, :impersonation_aborted}`** (exception to D-AUD-06 per **D-AUD-08**, mirroring Phase 82 D-82-02). Existing return shape preserved on the fall-through path.
- **Why this pattern:** Mirrors `Ecto.Adapter.Transaction` — the canonical Elixir idiom for "subsystem capability that some adapters have and others don't." Same shape as Oban's `Oban.insert/2` composing into a caller's `Multi`. Avoids the failure mode of Spring `@Transactional(propagation=...)` and Rails multi-DB silent-atomicity-bug class — capability is **introspectable, testable, documented per adapter**, never hidden in a runtime branch the host can't see.
- **EX-45-06 rewrite:** Becomes adapter-keyed, not call-site-keyed: `T1 on Sigra.SessionStores.Ecto via create_session_multi/delete_session_multi; T2 on stores that don't implement the optional callbacks. Reopen for a given store when that store implements the optional callbacks.` Honest, not hybrid.

### D-85-03 — `EX-45-*` text rewrites for retired rows (052, 055, 056, 058, 063)

For each retired row, rewrite the EX entry from soft deferral language ("May remain T2 if…", "Notify decision persisted in DB without co-audit") to **architectural classification** language plus a **specific, behavior-keyed reopen trigger**:

- **EX-45-01 (058 `oauth.authorize`):** *"T2 by classification — read-only URL generation; no domain persistence at this site (D-AUD-06). Compensating controls: `[:sigra, :oauth, :authorize]` telemetry span + Hammer IP rate-limit + HMAC-signed state. **Reopen trigger:** authorize path gains a paired DB write (e.g. an `oauth_state_records` table replacing stateless HMAC) OR product / compliance requirement mandates durable pre-callback audit row."*
- **EX-45-02 (063 `oauth.callback.failure` pre-user):** *"T2 by classification — failure before user resolution; no actor / no target / no domain mutation (D-AUD-06). Compensating: `[:sigra, :oauth, :callback]` telemetry span (provider + failure reason), `oauth.callback.failure` `log_safe` row (best-effort), Hammer IP rate-limit, enumeration-safe error responses. Industry consensus across Auth0 / Okta / NextAuth.js / Ueberauth / OmniAuth / Spring Security is telemetry/log-only at this boundary. **Reopen trigger:** callback failure path gains a co-located DB write (e.g. introduction of `oauth_callback_attempts`) OR a compliance audit (SOC 2 / ISO 27001) explicitly requires durable queryable failure rows with retention beyond telemetry retention."*
- **EX-45-03 (052 `security.suspicious_login`):** *"T2 by classification — detection-only path; the audit row IS the durable forensic artifact (D-AUD-06). Notify email is a best-effort side-effect by design (security signals must NOT roll back on mailer failure). Forensic signals: telemetry event + `audit_events` row + `[:sigra, :audit, :log_safe_error]` telemetry on insert failure. Pattern matches rack-attack (notification-only) and is consistent with django-axes maintainer guidance (#768) preferring write-only log over Django-table for tamper resistance. **Reopen trigger:** introduction of a `notification_dispatch` durable record (e.g. Oban job row) co-fated with audit via `Multi`; only viable if Oban becomes a hard dep."*
- **EX-45-04 (055 `admin.impersonation.timeout_expire`):** *"T2 by classification — read-only timeout evaluation; pure computation, no partner mutation; the `audit_events` row IS the durable forensic record (D-AUD-06). **Reopen trigger:** the timeout path begins to mutate session lifecycle state in-library (e.g. `closed_at` column on session schema OR explicit `Auth.delete_session` call from `evaluate_timeout/4`)."*
- **EX-45-05 (056 `admin.impersonation.denied`):** *"T2 by classification — authorization denial fires BEFORE any session creation; no partner mutation (D-AUD-06). Matches AWS CloudTrail's denied `sts:AssumeRole` model — audit-only, SOC 2 CC7.2 / ISO 27001 defensible because the `audit_events` row is timestamped, actor-attributed, and tamper-evident. **Reopen trigger:** denial path begins to write a durable artifact in-library (e.g. an `impersonation_denied_attempts` table OR a `denied_at` mutation on a related entity)."*

**Why explicit reopen triggers matter:** They convert "deferred T2" (which reads as a punt) into "T2 with a named behavior-keyed reopen condition" (which reads as architecture). This is the difference between C-1 PASS-WITH-CAVEATS and C-1 PASS under audit review.

### D-85-04 — `D-AUD-06` sharpening in `AUDIT-ATOMICITY-DEFAULTS.md`

- **Decision:** Sharpen `D-AUD-06` to explicitly recognize three sub-classes that legitimately return `:ok` on audit insert failure (and therefore legitimately stay T2 by classification): **detection-only** (audit IS the business op; example: 052, 055), **pre-domain** (event fires before any persistence target exists; example: 056, 058, 063), and **audit-only helpers** (existing case from Phase 81; example: `APIToken.audit_jwt_refresh*`).
- This codifies the framing all five retired EX texts rely on, so future phases inherit the contract without each row reinventing it. Single edit to `.planning/AUDIT-ATOMICITY-DEFAULTS.md`; no behavior change.

### D-85-05 — Tests (AUD-21-02)

- **Decision:** **One** new dedicated test module — **`test/sigra/impersonation_audit_atomicity_test.exs`** (`async: false`) — covering the only newly-atomic site. The roadmap's suggested name `oauth_audit_atomic_test.exs` is **superseded by D-85-01** (no atomic OAuth site to exercise post-retirement); this is documented in the Phase 9 supersession footnote and the `45-AUD-04-INVENTORY.md` row updates.
- **Coverage:** Mirror Phase 82's `jwt_refresh_audit_cofate_test.exs` shape:
    1. Happy-path co-fate: `Auth.create_session` row + `admin.impersonation.start` audit row land in one transaction (Postgres adapter only — gated by capability check helper).
    2. Audit-off parity: with `:audit_schema` unset, persistence happens, no audit rows, no telemetry-on-commit divergence vs. current behavior.
    3. CHECK-guard fault injection: temporary `ALTER TABLE … ADD CHECK` on `audit_events` forcing the audit-row insert to fail; assert NO `sessions` row created, telemetry emits `[:sigra, :audit, :log_safe_error]` (or new co-fate failure event), public API returns `{:error, :impersonation_aborted}`. Restore via `try/after`.
    4. Symmetric coverage for `Impersonation.stop/4`.
    5. Fall-through path coverage: with a non-Ecto store (test stub that does NOT implement `*_multi` callbacks), confirm orchestrator runs the legacy `create_session` + `log_safe` sequence and that `start/stop` still work — validates the `@optional_callbacks` capability dispatch.
- **NOT covered by new tests:** Retired rows 052, 055, 056, 058, 063 (no behavior change at those sites; existing tests stay green). The "audit-off parity" check for those rows is implicit via existing test suites that already pass.
- **Style:** Named tests per scenario, unique telemetry handler ids per test, small private helpers for `ALTER TABLE … CHECK` + `try/after` restore, action-scoped SQL assertions. Match Phase 79/81/82 test ergonomics.

### D-85-06 — Two-commit closure sequencing (AUD-21-03 + AUD-21-04 + AUD-21-05)

- **Decision:** Land the phase as **two commits** (NOT one merge à la Phase 82):
    1. **Commit A — code + tests + inventory truth:** `SessionStore` optional callbacks, `SessionStores.Ecto` implementations, `Impersonation` orchestrator refactor, `impersonation_audit_atomicity_test.exs`, `EX-45-01..06` rewrites, `45-AUD-04-INVENTORY.md` row T-verdict updates (053/054 → T1 with phase 85 ref; 052, 055, 056, 058, 063 → T2 with classification + reopen trigger), `D-AUD-06` sharpening in `AUDIT-ATOMICITY-DEFAULTS.md`. **Gate:** `mix ci.audit_45` green; library test suite + 5 CI gates green.
    2. **Commit B — closure narrative:** `09-VERIFICATION.md` C-1 cell updated to `PASS` with phase 85 reference; frontmatter `caveats: []` (or field removed); `09-03-SUMMARY.md` post-batch narrative paragraph linking `85-VERIFICATION.md`; `SEED-002-phase-9-log-safe-atomicity-followup.md` frontmatter `status: validated` with phase 85 ref; `CHANGELOG.md` `[Unreleased]` AUD-21 trace bullet (one operator/maintainer-facing line); `85-VERIFICATION.md` records the merge gate outcome (`mix ci.audit_45` output, test-suite outcome, dated PASS attestation for each AUD-21-0X requirement).
- **Why two commits:** The C-1 downgrade is the v1.20 GA's defensibility hinge — burying it inside a code-heavy diff weakens the launch evidence. A dedicated closure commit is reviewable, citable from `README` / `89-VERIFICATION.md` / launch announcement, and survives `git log --oneline` skim. Phase 82's one-merge close worked because C-1 wasn't being downgraded; here it is, so the closure earns its own commit.

### Claude's discretion

- Exact callback names on `SessionStore` (`create_session_multi` / `create_multi` / `create_session_multi_step` etc.) and Multi step naming inside the orchestrator.
- Whether the capability check is `function_exported?/3` post-`Code.ensure_loaded/1`, behaviour-introspection via `behaviour_info(:callbacks)`, or an installation-time validated config flag — pick the most idiomatic.
- Whether to introduce a new telemetry event name for "co-fate rollback" (e.g. `[:sigra, :impersonation, :aborted]`) or reuse `[:sigra, :audit, :log_safe_error]`.
- Exact wording polish on the EX-45-01..06 rewrites (preserve the architectural classification + reopen-trigger structure).
- Whether `Repo.transact/2` (Ecto 3.13) replaces `Repo.transaction/1` for the new path only.

### Folded todos

_None._

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **AUD-21-01** through **AUD-21-05**
- `.planning/ROADMAP.md` — Phase 85 goal + success criteria 1–5 (`### Phase 85: OAuth audit atomicity closure (AUD-21)`)
- `.planning/PROJECT.md` — v1.20 GA framing + minimal-schema DX value + Phoenix 1.8+ / PostgreSQL primary constraints
- `.planning/STATE.md` — v1.20 leg-1 framing (Phase 85 = SEED-002 closure)

### Seed and prior-phase context (locked precedent)

- `.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md` — original C-1 hybrid framing this phase closes
- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — `D-AUD-01` (orchestrator owns txn), `D-AUD-06` (audit-only `:ok` semantics — to be **sharpened by this phase per D-85-04**), `D-AUD-08` (co-fated paths roll back with stable error atom)
- `.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-CONTEXT.md` — D-82-01 (orchestrator pattern), D-82-02 (public contract on co-fated paths), D-82-04 (test shape)
- `.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-RESEARCH.md` — Phase 82 research backing
- `.planning/phases/81-jwt-refresh-audit-atomicity/81-CONTEXT.md` — D-81-04 planning-truth surgical-update pattern
- `.planning/phases/79-api-token-verify-failure-audit/` — earlier instantiation of the audit-aware test pattern
- `.planning/phases/09-audit-logging/09-CONTEXT.md` — D-01 universal-atomic-Multi original intent
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — C-1 PASS-WITH-CAVEATS cell (frontmatter `caveats:` block) — the cell this phase downgrades
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — current C-1 narrative
- `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md` — rows 052–056, 058, 063 + EX-45-01..06 boundary table

### Code (integration points)

- `lib/sigra/impersonation.ex` — `start/5` (line 41), `stop/4` (line 76), `evaluate_timeout/4` (line 96), `log_denied/5` (line 180)
- `lib/sigra/auth.ex` — `create_session/4`, `delete_session/3` (orchestrator delegates)
- `lib/sigra/session_store.ex` — behaviour module (gains `@optional_callbacks`)
- `lib/sigra/session_stores/ecto.ex` — default adapter (gains `*_multi` impls)
- `lib/sigra/oauth.ex` — `authorize_url/4` (line ~71), `handle_callback/4` failure branch (line ~172) — **read-only for this phase; verifying call sites match EX text**
- `lib/sigra/suspicious_login.ex` — `detect/4` (line ~65) — **read-only for this phase**
- `lib/sigra/audit.ex` — `log_safe/3`, `log_multi_safe/3`, `__log_internal__/3`
- `test/sigra/jwt_refresh_audit_cofate_test.exs` — Phase 82 reference shape for the new impersonation atomicity test
- `test/sigra/api_token_audit_atomic_test.exs` — Phase 79/81 CHECK-fault-injection helpers

### Verification + planning truth touch points

- `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md` — row + EX text edits
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — C-1 cell + frontmatter caveats
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — narrative paragraph
- `.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md` — `status: validated` flip
- `CHANGELOG.md` — `[Unreleased]` AUD-21 bullet
- `.planning/phases/85-oauth-audit-atomicity-closure-aud-21/85-VERIFICATION.md` — to be authored at phase close

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Sigra.Audit.log_multi_safe/3`** — composes audit insert as a `Multi` step, the centerpiece of the established co-fate pattern (Phases 73, 77, 79, 80, 81, 82). No changes needed for Phase 85.
- **`Sigra.SessionStore`** behaviour — already plug-in for ETS / Postgres / Redis / host-custom adapters. Phase 85 adds **optional** callbacks via `@optional_callbacks` — additive, not breaking.
- **`Sigra.SessionStores.Ecto`** — default adapter; the only one that needs `*_multi` impls in this phase. Other adapters fall through.
- **Phase 82 `jwt_refresh_audit_cofate_test.exs`** — reference shape for `async: false`, scenario-named tests, telemetry-handler-id discipline, `ALTER TABLE … CHECK` + `try/after` fault injection helpers.
- **Phase 81 / 82 surgical planning-truth pattern** — dated supersession footnote on AUD-04 rows + one-paragraph `09-03-SUMMARY` update + one CHANGELOG bullet. Mirror it here.

### Established patterns

- **D-AUD-01** — orchestrator (public function) owns ONE `Repo.transaction`, domain modules stay audit-agnostic. Phase 85 applies this to `Impersonation.start/stop`.
- **D-AUD-06** — audit-only / detection-only paths return `:ok` on audit insert failure with telemetry-only observability. Phase 85 **sharpens** this with explicit sub-classes.
- **D-AUD-08** — co-fated paths roll back on audit failure with stable error atom. Phase 85 applies this with `:impersonation_aborted`.
- **`@optional_callbacks` + capability dispatch** — canonical Elixir pattern for "subsystem capability some adapters have, others don't" (mirrors `Ecto.Adapter.Transaction`, Oban Multi compose). New territory for `SessionStore` but not for the ecosystem.

### Integration points

- Hosts call `Sigra.Impersonation.start/5` and `stop/4` directly. The `{:error, :impersonation_aborted}` atom is the only new public-API surface for hosts running the default Ecto store; hosts running ETS/Redis stores see no contract change.
- `mix ci.audit_45` is the per-edit regression gate; no changes needed for Phase 85 — the new code paths inherit existing inventory enforcement.
- `mix sigra.gen.session` (or whichever generator emits SessionStore wiring) does **not** need changes — the new callbacks are additive on the library side.

</code_context>

<specifics>

## Specific ideas

- **Cross-agent consensus on the OAuth pre-domain rows (058, 063):** Auth0, Okta, NextAuth.js / Auth.js, Ueberauth, OmniAuth, and Spring Security all use telemetry/log-only at this boundary. Sigra retiring with sharpened EX is the consensus position, not a corner-cut.
- **AWS CloudTrail's denied `sts:AssumeRole` model** is the precedent cited for retiring 056 (`admin.impersonation.denied`) — audit-only, SOC 2 CC7.2 / ISO 27001 defensible because the audit row is timestamped, actor-attributed, tamper-evident.
- **rack-attack + django-axes maintainer guidance (#768)** are the precedents for retiring 052 (`security.suspicious_login`) — write-only log preferred over a Django-table for tamper resistance; the audit row IS the durable forensic record.
- **`Ecto.Adapter.Transaction` precedent** is the direct analogue for the SessionStore optional-callback pattern (D-85-02). Same shape: optional behaviour layered on a base behaviour, capability introspectable per adapter, public API uniform across adapters.
- **Stable error atom:** prefer one new atom — `:impersonation_aborted` — over leaking raw `Ecto.Multi` failure tuples (consistent with Phase 82's `:jwt_refresh_aborted`).

</specifics>

<deferred>

## Deferred ideas

- **`oauth_state_records` table replacing stateless HMAC OAuth state** — would convert 058 to T1 but reverses v1.0 stateless-state architectural decision. Reopen trigger lives in EX-45-01. Belongs in a future OAuth-hardening phase only if product/compliance forces it.
- **`oauth_callback_attempts` durable failure forensic table** — would convert 063 to T1. Reopen trigger lives in EX-45-02. Belongs in a future SOC 2 / forensic-tooling milestone if compliance scope expands.
- **`suspicious_login_events` schema** — would convert 052 to T1. Reopen trigger in EX-45-03. Only viable if Oban becomes a hard dep AND notify-as-Oban-job pattern is adopted (Oban `insert/2` composes into Multi → enqueue + audit co-fate). Out of v1.20 scope.
- **`impersonation_denied_attempts` durable forensic table** — would convert 056 to T1. Reopen trigger in EX-45-05. Belongs in a future PAM-hardening phase if Sigra grows into privileged-access-management territory.
- **Session lifecycle column (`closed_at`, `close_reason`)** — would convert 055 to T1 by capturing timeout as a durable session mutation. Reopen trigger in EX-45-04. Belongs with a broader session-schema refactor.
- **Sharpening `Sigra.Audit.log_safe/3` to surface insert errors via a new failure telemetry event** (vs. swallowing them) — observability improvement, not a per-site atomicity concern. Future phase.
- **GSD preference: "advisor-research-by-default for discuss-phase"** — user wants the parallel-subagent research pattern that produced this CONTEXT to be the default for all gray-area discussions, not opt-in. Lift to GSD config / workflow defaults; surface via `/gsd-settings` or `gsd-sdk query config-set workflow.research_before_questions true` (existing knob) or by enabling advisor mode globally (USER-PROFILE.md). **Not Phase 85 work; captured here so it isn't lost.**

</deferred>

---

*Phase: 85-oauth-audit-atomicity-closure-aud-21*
*Context gathered: 2026-04-25*
