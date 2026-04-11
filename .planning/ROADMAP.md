# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library — Initial Release** — Phases 1–10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md) for full details.

## Phases

<details>
<summary>✅ v1.0 Phoenix Auth Library — Initial Release (Phases 1–10.1.1) — SHIPPED 2026-04-11</summary>

- [x] Phase 1: Foundation (3/3 plans) — completed 2026-04-05
- [x] Phase 2: Core Auth (2/2 plans) — completed 2026-04-06
- [x] Phase 3: Email Flows and Transactional Email (6/6 plans) — completed 2026-04-07
- [x] Phase 4: Session Management and Security Baseline (6/6 plans) — completed 2026-04-08
- [x] Phase 5: OAuth and Social Login (3/3 plans) — completed 2026-04-08
- [x] Phase 6: Multi-Factor Authentication (5/5 plans) — completed 2026-04-08
- [x] Phase 7: API Authentication (4/4 plans) — completed 2026-04-09
- [x] Phase 8: Account Lifecycle (5/5 plans) — completed 2026-04-08
- [x] Phase 9: Audit Logging (5/5 plans) — completed 2026-04-09 (PASS-WITH-CAVEATS; see SEED-002)
- [x] Phase 10: Developer Experience (6/6 plans) — completed 2026-04-10
- [x] Phase 10.1: Installer and Library Fixes (INSERTED, 7/7 plans) — completed 2026-04-10
- [x] Phase 10.1.1: example-app repair + CI install/usage smoke harness (INSERTED, 8/8 plans) — completed 2026-04-11

**Full details:** [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

### 📋 Next Milestone (TBD)

Run `/gsd-new-milestone` to start planning. Two seeds will surface automatically during milestone scoping:

- `SEED-001` — Run 8 human-only UAT items before v1.0 GA public announcement (email visual, OAuth real-credential, backup code regen, clean-machine docs read)
- `SEED-002` — Phase 9 `log_safe/3` → atomic `Ecto.Multi` conversion (trigger: customer report of missing audit row OR compliance review)

## Backlog

Unsequenced ideas parked for a future milestone. Promote via `/gsd-review-backlog` when the triggering milestone is defined.

### Phase 999.1: Retroactive Nyquist validation pass (BACKLOG)

**Goal:** Complete Nyquist validation contracts for the 6 phases whose `*-VALIDATION.md` files are still in `status: draft` with `nyquist_compliant: false`, and create the missing VALIDATION.md for phase 10.1. Produces audit-grade records for any future compliance review without blocking v1.0 shipment.
**Requirements:** TBD (no new REQ-IDs; remediation phase)
**Depends on:** v1.0 archived
**Plans:** 0 plans — promote with `/gsd-review-backlog` or `/gsd-discuss-phase 999.1`

**Scope (from v1.0 audit):**
- Phase 02 (core-auth) — VALIDATION.md draft, nyquist_compliant: false
- Phase 03 (email-flows) — VALIDATION.md draft, nyquist_compliant: false
- Phase 04 (session-mgmt) — VALIDATION.md draft, nyquist_compliant: false
- Phase 06 (mfa) — VALIDATION.md draft, nyquist_compliant: false
- Phase 07 (api-auth) — VALIDATION.md draft, nyquist_compliant: false
- Phase 09 (audit-logging) — VALIDATION.md draft, nyquist_compliant: false
- Phase 10.1 (installer-fixes) — no VALIDATION.md exists (remediation phase, never validated)

**Traceability:** `milestones/v1.0-MILESTONE-AUDIT.md` Section 6 "Nyquist Compliance" table.

**Notes:** Run `/gsd-validate-phase {N}` for each entry. Each phase should be a separate plan inside this single backlog phase. Total effort estimate: 3–5 hours. Not a v1.0 release blocker — the 1249-test suite + 5 CI smoke jobs + Playwright golden path provide functional coverage, this just closes out the formal sampling contracts.

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

### Phase 999.2: Dependabot major-version bumps cleanup (BACKLOG)

**Goal:** Review and safely land the 3 open Dependabot PRs that bump major versions of SHA-pinned GitHub Actions used across the 5 CI jobs. Major bumps require per-job CI verification because they can change default Node runtime, cache semantics, or artifact behavior.
**Requirements:** TBD
**Depends on:** v1.0 archived
**Plans:** 0 plans — promote with `/gsd-review-backlog` or handle as a v1.0.1 patch milestone

**Scope (open PRs as of 2026-04-11):**
- [szTheory/sigra#1](https://github.com/szTheory/sigra/pull/1) — actions/setup-node 4.0.4 → 6.3.0 (v5 dropped Node 16; v6 changed default cache behavior)
- [szTheory/sigra#3](https://github.com/szTheory/sigra/pull/3) — actions/upload-artifact 4.4.3 → 7.0.1 (v5 removed "upload to same name twice"; v6 changed compression defaults — this is the riskiest one)
- [szTheory/sigra#4](https://github.com/szTheory/sigra/pull/4) — actions/checkout 4.3.1 → 6.0.2 (v5 Node 20 default; v6 Node 22 default)

**Traceability:** IN-03 (SHA-pinned Actions from phase 10.1), `.github/dependabot.yml` config, `.github/workflows/ci.yml` action pin sites.

**Notes:** Do NOT merge blindly. Land each bump on its own commit, verify all 5 required CI checks pass on a PR, confirm upload-artifact behavior (failure trace upload in `example_playwright_smoke` is the most likely regression surface). Consider bundling into a v1.0.1 patch milestone alongside any post-GA hotfixes.

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)
