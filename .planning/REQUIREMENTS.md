# Requirements — Sigra v1.4 GA readiness & audit trail completeness

**Defined:** 2026-04-20  
**Core value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — including defensible GA posture and durable audit trails.

This milestone intentionally **promotes** planted seeds **SEED-001** (residual human GA checks + backup-code rotation) and **SEED-002** (Phase 9 C-1 followup: `log_safe/3` hybrid → atomic `Ecto.Multi` at additional integration sites with audit-aware tests).

---

## GA residuals (SEED-001)

- [x] **GA-01**: User with MFA can **rotate backup codes** end-to-end (invalidate old hashes, issue new set, audit events as applicable) — library + generated/example surfaces wired; no stale TODO-only path; automated regression covers happy path + at least one failure class. *(Validated in Phase 41.)*
- [x] **GA-02**: **Email visual QA** — lockout + suspicious-login templates (Phase 04 family) and account-lifecycle templates (Phase 08 family) reviewed in **Gmail, Outlook, and Apple Mail** (or documented waiver with compensation — e.g. Litmus snapshot, screenshot bundle, or explicit “deferred with owner” row) with pass/fail recorded in the v1.4 GA artifact. *(Waived with machine baseline in Phase 46 — see `.planning/v1.4-GA-UAT.md` / `uat-evidence/v1.4/GA-02/`.)*
- [x] **GA-03**: **Live Google OAuth** — register + login + provider linking / email-match confirmation exercised with **real** Google developer credentials; outcomes and any UX defects logged in the v1.4 GA artifact (link to CI mock coverage where it substitutes intent). *(Waived with `Sigra.OAuthTest` substitute in Phase 46 — see `v1.4-GA-UAT.md` / `GA-03/`.)*
- [x] **GA-04**: **Clean-machine getting-started** — a reviewer **not** on the core team follows `guides/introduction/getting-started.md` on a fresh Phoenix app within the agreed time budget (target ≤30 minutes wall-clock); friction notes captured in the v1.4 GA artifact. *(Waived with CI getting-started contract substitute in Phase 46 — see `v1.4-GA-UAT.md` / `GA-04/`.)*
- [x] **GA-05**: **Consolidated GA evidence** — publish `.planning/v1.4-GA-UAT.md` (name may vary if merged into an INDEX) mapping each SEED-001 row to **Executed / Waived / Blocked**, with pointers to `docs/uat-ci-coverage.md`, CI job names, and human-run evidence (screenshots, URLs, dates). *(Executed in Phase 46 — matrix header + row GA-05.)*

**Primary phase mapping:** **41** (GA-01 product work); **42** (GA matrix scaffolding); **46** (gap closure: execute and record **GA-02..GA-05** per `v1.4-MILESTONE-AUDIT.md`). See traceability table.

---

## Audit trail atomicity (SEED-002)

_v1.3 delivered **AUD-01..03** in the archived sense (`Sigra.Audit.Assertions`, atomic `api.token_create`, example login/MFA smoke). v1.4 continues **AUD-04+** below._

- [x] **AUD-04**: **Inventory + batching plan** — documented list of remaining `Sigra.Audit.log_safe/3` production integration sites (grouped by module: Auth, MFA, Account, OAuth, API tokens, plugs, workers), with **priority order** and explicit “won’t convert in v1.4” exclusions (if any) justified against D-01 / C-1. *(Closed in Phase 47 — see `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md`.)*
- [x] **AUD-05**: **Auth core batch** — convert the agreed highest-priority `Sigra.Auth` `log_safe/3` sites (excluding the three already-atomic confirm/verify/reset paths from Phase 9) to audited `Ecto.Multi` (or established `log_multi_safe/3` pattern); every changed site gains or extends **audit-aware** tests (`Sigra.Audit.Assertions` or equivalent explicit repo assertions). *(Closed in Phase 47 — see `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md`.)*
- [x] **AUD-06**: **MFA batch** — convert `Sigra.Mfa` audit emissions on success paths identified in AUD-04 to atomic Multi + matching tests (minimum: enrollment verify / backup-code consumption / disable flows agreed in planning). *(Closed in Phase 48 — see `.planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md`.)*
- [x] **AUD-07**: **Account + API remainder batch** — convert `Sigra.Account` and remaining `Sigra.ApiToken` `log_safe/3` sites per AUD-04 inventory; tests prove audit row durability on `{:ok, _}` paths. *(Closed in Phase 48 — see `.planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md`.)*
- [x] **AUD-08**: **OAuth + operational paths** — convert selected `Sigra.OAuth`, lockout/suspicious-login, impersonation, and worker-related audit sites **or** document compliance-acceptable deferral with trigger to reopen; update `.planning/phases/09-audit-logging/09-03-SUMMARY.md` (and `09-VERIFICATION.md` caveat C-1) so the hybrid status matches reality post-v1.4. *(Closed in Phase **49** — see `.planning/phases/45-oauth-ops-c1-signoff/45-VERIFICATION.md` merge gate `mix ci.audit_45` + exhaustive **C-1** matrices in `09-VERIFICATION.md`.)*

**Primary phase mapping:** **43–45** (AUD-04..AUD-08 implementation batches); **47–49** (gap closure: formal `*-VERIFICATION.md` for phases 43–45 + REQUIREMENTS / ROADMAP reconciliation); **50** (Nyquist **41–44** + CI long-test gate hygiene). Adjust in ROADMAP if execution merges batches.

---

## Out of scope (v1.4)

- Net-new auth features unrelated to GA-01..05 or audit conversion (e.g. new providers, SAML, IdP mode).
- Full conversion of **every** `log_safe/3` call site if risk analysis defers low-value rows — such rows must appear in AUD-04 exclusions with rationale (still satisfies AUD-08 if documented honestly).
- Rewriting unrelated admin UI or org/passkey product surfaces except where GA-01 forces generator/LiveView touch.

---

## Future (post-v1.4)

- Broader GA **announcement** packaging (blog, Hex marketing copy) — may follow v1.4 evidence but is not required for these REQ IDs.
- Optional OAuth ceremony audit smoke (explicitly out of v1.3 AUD-03) — consider a later milestone if compliance demands.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GA-01 | 41 | Complete (2026-04-20) |
| GA-02 | 46 | Waived (2026-04-21) |
| GA-03 | 46 | Waived (2026-04-21) |
| GA-04 | 46 | Waived (2026-04-21) |
| GA-05 | 46 | Complete (2026-04-21) |
| AUD-04 | 47 | Complete (2026-04-21) |
| AUD-05 | 47 | Complete (2026-04-21) |
| AUD-06 | 48 | Complete (2026-04-21) |
| AUD-07 | 48 | Complete (2026-04-21) |
| AUD-08 | 49 | Complete (2026-04-21) |

**Milestone process (no discrete REQ-ID):** Phase **50** — Nyquist validation sweep (**41–44**) and CI gate hygiene from `v1.4-MILESTONE-AUDIT.md` tech_debt (golden_diff / long `mix test` policy).

**Coverage:**

- v1.4 requirements: **10** total  
- Mapped to phases: **10**  
- Unmapped: **0**  
- Gap-closure process phases: **50** (see above)

---

*Requirements defined: 2026-04-20 after `/gsd-new-milestone` (user-selected SEED-001 + SEED-002). Research skipped — scope anchored on existing seeds, `docs/uat-ci-coverage.md`, and Phase 9/39 artifacts.*
