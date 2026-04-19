---
id: SEED-002
status: deferred
planted: 2026-04-11
planted_during: v1.0 milestone completion
trigger_when: When subsystem tests become audit-aware OR when a customer reports a missing audit row for a successful business op
scope: Medium
---

# SEED-002: Convert `log_safe/3` hybrid sites to atomic `Ecto.Multi` + audit-aware test pattern (Phase 9 C-1 followup)

## Why This Matters

Phase 9 (audit logging) landed with an accepted caveat — **C-1: PASS-WITH-CAVEATS** — documented in `.planning/phases/09-audit-logging/09-VERIFICATION.md` and in phase 9's `09-03-SUMMARY.md`. The original D-01 design decision called for universal atomic `Ecto.Multi` writes at every integration site, so that an audit row for a successful business operation could never be lost. What actually shipped is a **hybrid**: 3 sites use true atomic `Ecto.Multi` (confirm_user, verify_confirmation_code, reset_password in `lib/sigra/auth.ex`), and ~30+ other integration sites use a non-atomic `log_safe/3` helper that fires the audit insert in a separate transaction after the business-op transaction commits.

### The failure mode C-1 permits

If the business-op transaction commits successfully but the subsequent `log_safe/3` audit insert fails (DB down, disk full, unique constraint race, process killed between commits), the caller observes `{:ok, result}` and the audit trail is missing a row. All other security properties — reserved-prefix guardrail, metadata cap, forbidden-key policy, telemetry-on-commit — remain intact. So the specific thing at risk is **completeness** of the audit log for successful ops, not correctness of the audit entries that do land.

### Why it shipped as a hybrid

Converting all ~30 sites to atomic `Ecto.Multi` requires their test suites to be rewritten in an "audit-aware" style — every subsystem test that expects `{:ok, result}` has to also assert the audit row landed, or the Multi tests would drift from reality. That's a non-trivial refactor touching every auth-adjacent test file. Phase 9 made the judgment call that 3 atomic sites + telemetry-on-commit was enough v1.0 coverage and the full conversion could be deferred.

### Why this isn't a v1.0 blocker

- The 3 most critical atomic sites are the ones where audit row loss would actually matter for incident response (user confirm, password reset, login verification).
- Telemetry-on-commit fires BEFORE the audit insert, so a loss is at worst a stored-audit-row gap — the event itself is observable via the telemetry pipeline regardless.
- No customer has reported a missing audit row; this is a theoretical failure mode under specific conditions.
- The hybrid is explicitly documented in the SUMMARY, so any future investigator knows to look for it.

## When to Surface

**Trigger:** First of any of these conditions:
1. **A customer reports a missing audit row** for a successful business op — this turns the theoretical failure mode into an observed bug and upgrades the followup to a priority phase
2. **Subsystem test conversion becomes scheduled** — if a future milestone touches the auth subsystem tests for another reason (e.g. adding a new auth flow), rolling this conversion into the same refactor is cheap
3. **Security audit / compliance review requires it** — if Sigra enters SOC 2 / ISO 27001 scope, audit-trail completeness typically becomes a hard requirement

This seed should NOT surface on every new milestone — only when the triggers above match. Do not let it become background noise.

## Scope Estimate

**Medium** — 1–2 phases of real work:
- **Phase A (1 plan):** Add an "audit-aware" test pattern — a helper in `test/support/audit_case.ex` that wraps an operation, asserts both business-op success AND audit row presence, and is used by all new tests. Backport to 3–5 subsystem tests as proof of life.
- **Phase B (2–3 plans):** Convert each of the ~30 `log_safe/3` sites to atomic `Ecto.Multi` + `__log_internal__/3`, one subsystem at a time. Migrate subsystem tests to the audit-aware pattern in the same commit as the production code change. Update `09-03-SUMMARY.md` to downgrade C-1 from PASS-WITH-CAVEATS to PASS.

Could be done as one larger phase if the team has appetite. The scope estimate assumes ~40 hours total across planning + execution + verification.

## Breadcrumbs

- `lib/sigra/auth.ex:606` — atomic site #1: `confirm_user`
- `lib/sigra/auth.ex:712` — atomic site #2: `verify_confirmation_code`
- `lib/sigra/auth.ex:892` — atomic site #3: `reset_password`
- `lib/sigra/audit.ex` — the `log_safe/3` helper and `__log_internal__/3` internal function
- `.planning/phases/09-audit-logging/09-03-SUMMARY.md` — documents the hybrid decision and C-1 explicitly
- `.planning/phases/09-audit-logging/09-VERIFICATION.md` — frontmatter `caveats: - id: C-1` with `accepted_by: documented-in-summary`
- `.planning/phases/09-audit-logging/09-CONTEXT.md` — D-01 "universal atomic Multi" decision (this is what C-1 deviated from)
- Threat model reference: T-9-05 in phase 9 PLAN.md threat_model

## Phase 39 resolution (2026-04-18)

Partial closure in milestone v1.3 — see phase artifacts:

- `.planning/phases/39-audit-trail-completeness/39-01-SUMMARY.md` — `Sigra.Audit.Assertions` + testing recipe
- `.planning/phases/39-audit-trail-completeness/39-02-SUMMARY.md` — atomic `api.token_create`
- `.planning/phases/39-audit-trail-completeness/39-03-SUMMARY.md` — example smoke + docs trio

**Residual:** most other `log_safe/3` library sites remain intentionally hybrid
until a future phase converts them with matching audit-aware tests.

## Notes

- This is explicitly **post-v1.0** work. The v1.0 milestone audit marks C-1 as accepted, not deferred-and-unresolved.
- If item #7 from SEED-001 (backup code regeneration TODO) turns out to be wired via `log_safe/3` instead of atomic Multi, that's a related but separate fix — don't bundle them unless they land in the same phase.
- Converting tests to audit-aware style has a side benefit: it surfaces every business op that implicitly relies on an audit row, which is useful documentation in its own right.
- Do NOT rush this under a bug-fix patch milestone unless trigger #1 (real customer report) fires. The hybrid is load-bearing; yanking it carelessly risks breaking the 3 already-atomic sites.
