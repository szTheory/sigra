# Phase 58: OAuth ceremony + audit smoke — Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning

`[--all]` Auto-selected all gray areas: ceremony path breadth, audit outcomes vs substitute, test deliverable shape, CI merge gate explicitness. Decisions below synthesize parallel maintainer research (subagents) with **in-repo verification** of `Sigra.OAuth.authorize_url/3` (`log_safe` → **`oauth.authorize`** row when `:audit_schema` is set).

<domain>
## Phase boundary

Deliver **OA-01** (`.planning/REQUIREMENTS.md`): merge-blocking tests that exercise at least one **library-owned OAuth ceremony** (mocked / in-process is fine) and **assert audit outcomes** where production already emits audit on success — **or** assert an explicitly documented substitute with a **code comment** referencing **OA-01** so absence of a row is intentional. **No live-provider secrets.** Tests run in an existing **required** CI job (`library_tests` → `mix test`) or a **new** required job if the workflow is ever split.

**Out of scope:** Live IdP OAuth in CI; new providers; **OA-02** doc naming (phase **59**); broad link/unlink **matrix** as a merge-blocking requirement (optional single extra path only where it proves a **distinct** audit writer).

</domain>

<decisions>
## Implementation decisions

### Ceremony path breadth (OA-01 “at least one” vs honest hybrid story)

- **D-58-01 (OA-01 core — locked):** Treat **`Callback.process_callback/4` → `oauth.register_via_oauth`** on successful **new user registration** as the **primary** merge-blocking ceremony for **OA-01**. It is the longest **T1** vertical slice (domain + audit co-fate) without HTTP to a real provider. Pattern: real **`Ecto.Adapters.SQL.Sandbox` / `PostgresRepo`**, minimal schemas (reuse harness from `oauth_audit_atomicity_test.exs` or shared support), **no** `Repo` mocks for audit assertions.
- **D-58-02 (second ceremony — recommended, same phase):** Add a **thin** test for **`Sigra.OAuth.authorize_url/3`** success that asserts a persisted **`oauth.authorize`** audit row when `audit: [audit_schema: _]` is configured. **Rationale (code-verified):** `lib/sigra/oauth.ex` calls `Audit.log_safe("oauth.authorize", …)` after the `Telemetry.span`; when `:audit_schema` is present, `log_safe` **inserts** an audit row (T2 boundary in the phase **45** sense — not co-fated with Assent HTTP, but still **machine-checkable audit**). This teaches contributors the **hybrid** model without expanding to link/unlink **matrices**.
- **D-58-03 (explicitly not required for OA-01):** **Link**, **unlink**, and full **`handle_callback`** plug-style matrices are **not** merge-blocking for phase **58** unless a regression proves a **different** audit emission path than registration/authorize. Footgun avoided: duplicating three near-identical tests that share the same audit helper → CI cost and fixture drift (OmniAuth/Ueberauth lesson). Defer breadth to a future phase or non-merge suite if product scope demands it.

### Audit outcomes vs documented substitute

- **D-58-04 (default proof — locked):** Prefer **DB audit row assertions** (`Sigra.Audit.Assertions.assert_audit_fields/3` or equivalent) wherever production **already persists** audit — including **`log_safe`** paths when `audit_schema` is set (authorize is **not** “telemetry-only” today).
- **D-58-05 (substitute path — locked, narrow):** Use **telemetry / log-string / comment-only** proof **only** where the inventory or code **genuinely** emits no row (e.g. `:audit_schema` absent, or explicit **EX-45-\*** waiver). OA-01 **requires** either row assertion **or** **test-asserted** substitute behavior **plus** **`# OA-01`** (or equivalent) at the **emission site** in `lib/` so “no row” is grep-able — **never** comment-only in tests without an assertion.
- **D-58-06 (metadata hygiene):** Follow **45-CONTEXT** / **D-23**: assertions use **stable action strings** and **allow-listed metadata** keys (`:provider` only on authorize); **never** tokens, codes, or raw PII in metadata or test fixtures.

### Test module layout & OA-02 discoverability

- **D-58-07 (split by contract — locked):** Introduce **`test/sigra/oauth/oauth_ceremony_audit_test.exs`** with module **`Sigra.OAuthCeremonyAuditTest`**. **`@moduledoc`** must cite **OA-01** and point to **`.planning/REQUIREMENTS.md`**. Group with **`describe`** by ceremony (`registration`, `authorize`, …), not by internal function line noise.
- **D-58-08 (keep atomicity file focused — locked):** Retain **`test/sigra/oauth/oauth_audit_atomicity_test.exs`** for **rollback**, **constraint rejection**, and **“no partial commit”** proofs (phase **45** / AUD narrative). **Move** the existing happy-path test **`persists oauth.register_via_oauth after successful registration`** into **`Sigra.OAuthCeremonyAuditTest`** (or duplicate once then delete from atomicity in the same PR — executor chooses to avoid drift). Atomicity file name must not imply it is the sole OA-01 entry point.
- **D-58-09 (naming — locked):** Prefer **`…ceremony_audit…`** over generic **`smoke`** in **library** `test/sigra/oauth/` — “smoke” is reserved for **`test/example/`** and install harnesses per existing Sigra patterns (`OAuthSettingsTemplateContractTest`, install smoke scripts).

### CI merge gate explicitness

- **D-58-10 (behavioral gate — locked):** Keep **`library_tests` → `Run library tests` → `mix test`** (no default `--exclude` — already true in `test/test_helper.exs`) as the **single** required behavioral merge gate for OA-01. **Do not** add a **second** full `mix test` run of the same files in the same job (duplicated compile/run, footgun if the two runs diverge).
- **D-58-11 (explicitness / honesty — recommended):** Optionally add **`test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs`** in the **phase 50–52** style: read **`.github/workflows/ci.yml`** and assert the **`library_tests`** job still runs **plain `mix test`** without OAuth-related **`--exclude`** (stable anchor strings; update test if workflow intentionally changes). This is **structural** insurance only — it does **not** replace integration tests. **Claude’s discretion:** ship in phase **58** PR vs follow-up micro-phase if YAML brittleness is a concern.

### Claude's Discretion

- Exact contract-test assertion shape for **D-58-11** (substring vs parsed YAML) if implemented.
- Whether **`authorize_url`** test uses the same DDL setup module as atomicity tests vs a **minimal** shared **`test/support/oauth_audit_repo_case.ex`** — bounded by **least duplication** and **fast** setup.
- Provider atom in tests (`:google` vs `:mock`) as long as **MockStrategy** / config matches existing **`oauth_test.exs`** patterns.

### Folded Todos

_None._

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **OA-01** (authoritative wording: ceremony + audit or documented substitute + comment).
- `.planning/ROADMAP.md` — Phase **58** row, success criteria, canonical refs.
- `.planning/PROJECT.md` — v1.6 goal: OAuth machine proof without live-provider CI.

### Prior decisions (audit hybrid & OAuth surfaces)

- `.planning/phases/45-oauth-ops-c1-signoff/45-CONTEXT.md` — **T1 / T2 / T3** vocabulary; **`oauth.authorize`** as **T2** `log_safe`; OAuth **Multi** mutations as **T1**.
- `.planning/phases/57-nyquist-41-44-posture-matrix/57-CONTEXT.md` — defers **OA-01** to phase **58**.

### Implementation & tests (baseline)

- `lib/sigra/oauth.ex` — **`authorize_url`**, **`log_safe("oauth.authorize", …)`** (lines ~72–100 region).
- `lib/sigra/audit.ex` — **`log_safe/3`** persistence when `:audit_schema` set.
- `lib/sigra/oauth/callback.ex` — **`Callback.process_callback`**, **`emit_telemetry_from_changes`**, **`log_multi_safe`** paths.
- `test/sigra/oauth/oauth_audit_atomicity_test.exs` — current **registration** audit + rollback proofs.
- `test/sigra/oauth/oauth_test.exs` — MockStrategy / authorize / callback behavior patterns.
- `.github/workflows/ci.yml` — **`library_tests`** job, **`Run library tests`** step.

### CI honesty precedents (optional contract symmetry)

- `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` — workflow string drift guard pattern.
- `test/sigra/planning/phase_52_milestone_honesty_contract_test.exs` — planning artifact coupling pattern.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Sigra.OAuthAuditAtomicityTest`** harness: **`PostgresRepo`**, raw SQL DDL for `oauth_atomic_*` + `audit_events`, **`oauth_config/1`** with **`Sigra.Test.AuditEvent`** — factor shared setup if **`Sigra.OAuthCeremonyAuditTest`** duplicates it.
- **`Sigra.Audit.Assertions.assert_audit_fields/4`** — field-level audit assertions already used for **`oauth.register_via_oauth`**.
- **`Sigra.Test.OAuthHelpers`** — used by **`Sigra.OAuthTest`** for config/fixtures.

### Established Patterns

- **Real Repo + Sandbox** for audit proofs; **no** `Repo` mocks for row-level claims (phases **43–45**).
- **Mocked provider HTTP** via test strategies — not live OAuth (matches **REQUIREMENTS.md** v1.6 out-of-scope).
- **Contract tests** under **`test/sigra/planning/`** for “CI / docs say X” invariants.

### Integration Points

- **`mix test`** in **`library_tests`** is the merge gate; **`test_helper.exs`** documents no tag exclusions.
- **Phase 59** will reference the **OA-01** module name in **`docs/uat-ci-coverage.md`** — **`Sigra.OAuthCeremonyAuditTest`** should be the **stable** human + doc pointer.

</code_context>

<specifics>
## Specific Ideas

- Subagent consensus: **OmniAuth / Ueberauth / Passport** pain = **real HTTP in CI** and **over-broad strategy matrices** → keep merge-blocking tests **hermetic** and **one or two** high-signal paths.
- **Assent-aligned:** test **your** normalization + callback routing after strategy returns maps — not every upstream provider edge case in **`mix test`**.

</specifics>

<deferred>
## Deferred Ideas

- **Full** OAuth matrix (link, unlink, email-match confirmation, conflict) as **merge-blocking** — belongs in a **later** phase if product demands it; not required to satisfy **OA-01** numeric “at least one.”
- **Live-provider** or browser OAuth — explicitly **out of scope** per **REQUIREMENTS.md** v1.6.

### Reviewed Todos (not folded)

_None._

</deferred>

---

*Phase: 58-oauth-ceremony-audit-smoke*  
*Context gathered: 2026-04-23*
