# Requirements — Sigra v1.4 GA readiness & audit trail completeness

**Defined:** 2026-04-20  
**Core value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — including defensible GA posture and durable audit trails.

This milestone intentionally **promotes** planted seeds **SEED-001** (residual human GA checks + backup-code rotation) and **SEED-002** (Phase 9 C-1 followup: `log_safe/3` hybrid → atomic `Ecto.Multi` at additional integration sites with audit-aware tests).

---

## GA residuals (SEED-001)

- [ ] **GA-01**: User with MFA can **rotate backup codes** end-to-end (invalidate old hashes, issue new set, audit events as applicable) — library + generated/example surfaces wired; no stale TODO-only path; automated regression covers happy path + at least one failure class.
- [ ] **GA-02**: **Email visual QA** — lockout + suspicious-login templates (Phase 04 family) and account-lifecycle templates (Phase 08 family) reviewed in **Gmail, Outlook, and Apple Mail** (or documented waiver with compensation — e.g. Litmus snapshot, screenshot bundle, or explicit “deferred with owner” row) with pass/fail recorded in the v1.4 GA artifact.
- [ ] **GA-03**: **Live Google OAuth** — register + login + provider linking / email-match confirmation exercised with **real** Google developer credentials; outcomes and any UX defects logged in the v1.4 GA artifact (link to CI mock coverage where it substitutes intent).
- [ ] **GA-04**: **Clean-machine getting-started** — a reviewer **not** on the core team follows `guides/introduction/getting-started.md` on a fresh Phoenix app within the agreed time budget (target ≤30 minutes wall-clock); friction notes captured in the v1.4 GA artifact.
- [ ] **GA-05**: **Consolidated GA evidence** — publish `.planning/v1.4-GA-UAT.md` (name may vary if merged into an INDEX) mapping each SEED-001 row to **Executed / Waived / Blocked**, with pointers to `docs/uat-ci-coverage.md`, CI job names, and human-run evidence (screenshots, URLs, dates).

**Primary phase mapping:** **41** (GA-01 product work); **42** (GA-02..05 evidence capture). See traceability table.

---

## Audit trail atomicity (SEED-002)

_v1.3 delivered **AUD-01..03** in the archived sense (`Sigra.Audit.Assertions`, atomic `api.token_create`, example login/MFA smoke). v1.4 continues **AUD-04+** below._

- [ ] **AUD-04**: **Inventory + batching plan** — documented list of remaining `Sigra.Audit.log_safe/3` production integration sites (grouped by module: Auth, MFA, Account, OAuth, API tokens, plugs, workers), with **priority order** and explicit “won’t convert in v1.4” exclusions (if any) justified against D-01 / C-1.
- [ ] **AUD-05**: **Auth core batch** — convert the agreed highest-priority `Sigra.Auth` `log_safe/3` sites (excluding the three already-atomic confirm/verify/reset paths from Phase 9) to audited `Ecto.Multi` (or established `log_multi_safe/3` pattern); every changed site gains or extends **audit-aware** tests (`Sigra.Audit.Assertions` or equivalent explicit repo assertions).
- [ ] **AUD-06**: **MFA batch** — convert `Sigra.Mfa` audit emissions on success paths identified in AUD-04 to atomic Multi + matching tests (minimum: enrollment verify / backup-code consumption / disable flows agreed in planning).
- [ ] **AUD-07**: **Account + API remainder batch** — convert `Sigra.Account` and remaining `Sigra.ApiToken` `log_safe/3` sites per AUD-04 inventory; tests prove audit row durability on `{:ok, _}` paths.
- [ ] **AUD-08**: **OAuth + operational paths** — convert selected `Sigra.OAuth`, lockout/suspicious-login, impersonation, and worker-related audit sites **or** document compliance-acceptable deferral with trigger to reopen; update `.planning/phases/09-audit-logging/09-03-SUMMARY.md` (and `09-VERIFICATION.md` caveat C-1) so the hybrid status matches reality post-v1.4.

**Primary phase mapping:** **43** (AUD-04 inventory + AUD-05 Auth batch), **44** (AUD-06 MFA + AUD-07 Account/API), **45** (AUD-08 OAuth/ops + C-1 sign-off). Adjust in ROADMAP if execution merges batches.

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
| GA-01 | 41 | Pending |
| GA-02 | 42 | Pending |
| GA-03 | 42 | Pending |
| GA-04 | 42 | Pending |
| GA-05 | 42 | Pending |
| AUD-04 | 43 | Pending |
| AUD-05 | 43 | Pending |
| AUD-06 | 44 | Pending |
| AUD-07 | 44 | Pending |
| AUD-08 | 45 | Pending |

**Coverage:**

- v1.4 requirements: **10** total  
- Mapped to phases: **10**  
- Unmapped: **0**

---

*Requirements defined: 2026-04-20 after `/gsd-new-milestone` (user-selected SEED-001 + SEED-002). Research skipped — scope anchored on existing seeds, `docs/uat-ci-coverage.md`, and Phase 9/39 artifacts.*
