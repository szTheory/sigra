---
gsd_state_version: 1.0
milestone: v1.20
milestone_name: — active
status: verifying
last_updated: "2026-04-28T20:54:13.969Z"
last_activity: 2026-04-28
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 12
  completed_plans: 12
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** Phase --phase — 88

## Current Position

Milestone: **v1.20** — GA Launch — SEED closure + public release

Phase: --phase (88) — EXECUTING

Plan: 3 of 3

Status: Phase complete — ready for verification

Last activity: 2026-04-28

**Completed Phase:** **85 — OAuth audit atomicity closure (AUD-21)**

## Performance Metrics

| Phase | Plans | Duration | Tasks | Files |
| --- | --- | --- | --- | --- |
| 85 | 2 | session | 5 | 13 |
| Phase 88 P01 | 5m | 3 tasks | 5 files |
| Phase 88 P02 | 2m | 3 tasks | 5 files |
| Phase 88 P03 | 15m | 3 tasks | 5 files |

## Decisions

- Use optional `SessionStore` multi callbacks only on adapters that support them.
- Return `:impersonation_aborted` on transactional audit failure.
- Mark Phase 9 C-1 as PASS for the AUD-21 slice.
- Validate SEED-002 and publish a phase merge-gate artifact.
- Ran the example-app background server with EXAMPLE_DB_PROBE_ENABLED=1 so Playwright tests could hit probe endpoints
- Relied entirely on the install-smoke.sh CI lane to serve as the single source of truth for the 'clean machine' getting-started evidence per D-88-06 through D-88-10.
- Kept the verification strict on generated-host route checks instead of human subjective friction logging, proving out the underlying document paths with machine reliability.
- Set launch-leg disposition to NO-GO (BLOCKED BY PROVENANCE) because of the pending Phase 87 URLs, and kept SEED-001 as deferred.
- Kept GAUAT-03..06 marked as BLOCKED in v1.20-GA-UAT-RESULTS.md until Phase 87 remote CI provenance (ci_run_url) is established.
- Modified sigra.uat.report.ex to resolve snapshot paths by wildcard instead of assuming the current git SHA, fixing the verification failure for previous phases.

## Accumulated Context

**v1.19 (shipped 2026-04-24)** — Phases 82–83 closed JWT refresh persistence + audit co-fate (AUD-19) and MFA invalid-TOTP enrollment audit (AUD-20). **Phase 84** (routing-honesty-reconciliation) closed 2026-04-25. After v1.20, the only known live audit-atomicity gap is the Phase 45 T2 OAuth/ops cluster (052–056, 058, 063) — explicitly in v1.20 scope.

**v1.20 framing:** This is the inflection-point milestone where Sigra goes from "evidence-capable on disk" to "publicly available." All three legs (SEED-002 OAuth audit closure, SEED-001 GA UAT closure, public launch sequence) are interdependent: legs 1 and 2 give the launch defensible evidence; the launch is the only reason to spend the engineering hours on legs 1 and 2 right now.

**v1.20 phase shape:** 6 phases.

- **Leg 1 (parallel-ready, single phase):** Phase 85 — AUD-21 OAuth audit atomicity closure → downgrades Phase 9 C-1 caveat to PASS; flips SEED-002 to `validated`.
- **Leg 2 (parallel-ready, three phases):** Phase 86 (email visual QA Phase 04 + Phase 08), Phase 87 (OAuth gen smoke + issuer-backed register/link/email-match), Phase 88 (backup-code rotation + generated-host getting-started + results filing + SEED-001 closure). 86 and 87 are independent; 88 depends on 86 and 87 (consolidates evidence into `v1.20-GA-UAT-RESULTS.md`).
- **Leg 3 (sequential, two phases):** Phase 89 (Hex publish + README promotion + CHANGELOG/ExDoc — depends on Phase 85 + Phase 88), then Phase 90 (announcement + HN + community soft-launch + MAINTAINING monitoring lane — depends on Phase 89).

**Selected seeds for this milestone:** SEED-001 (closes in Phase 88), SEED-002 (closes in Phase 85). Both close from release-authoritative evidence, not human witness runs.

**Explicit non-goals:** `sigra_lockspire` / ADR 001 glue (still awaiting companion-app trigger); 999.x archaeology; responding to week-one launch feedback (deferred to a follow-up patch milestone if signal warrants); marketing site / paid promotion.

### Pending Todos

_None as of milestone open. Will populate during phase planning._

### Blockers/Concerns

- **Phase 87 CI provenance** — OAuth machine evidence is implemented locally, but GAUAT closure still depends on the phase-close SHA being pushed and its CI run URLs being written back into the evidence READMEs.
- **Phase 86 evidence environment** — The Phase 86 harness is automation-only (`0 human MUA passes required`), but it still depends on the repo CI/browser environment staying reproducible: Chromium + WebKit available in Playwright, deterministic snapshot generation, and tag-time release-asset upload wiring for the same evidence bundle.
- **Hex.pm publish credentials + 2FA** — Phase 89 requires `mix hex.user auth` configured for the publishing maintainer. Verify before Phase 89 begins (ideally early in v1.20 so it's not the long-pole on launch day).
- **Generated-host reproducibility** — Phase 88 GAUAT-08 now depends on the disposable Phoenix host harness staying aligned with `guides/introduction/getting-started.md`; drift here is a CI problem, not a manual-witness scheduling problem.

## Session Continuity

**Next:** Push `367a164`, wait for `install_smoke` + `oauth_e2e_playwright`, then regenerate Phase 87 OAuth evidence with populated `ci_run_url`.

**Resume file:** None

**Artifacts (active):** `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

**Last completed phase:** **85** (oauth-audit-atomicity-closure-aud-21) — **2026-04-25**

**Planned Phase:** 87 (gauat-oauth-real-credential-cycle-gen-smoke-google-live-link) — 3 plans — 2026-04-27T02:20:58.433Z
