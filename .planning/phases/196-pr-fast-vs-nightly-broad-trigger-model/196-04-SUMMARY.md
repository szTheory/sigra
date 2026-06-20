---
phase: 196-pr-fast-vs-nightly-broad-trigger-model
plan: "04"
subsystem: docs
tags: [ci, nightly, maintaining, residuals, probe, runbook, verification, audit-trail]

requires:
  - phase: 196-03
    provides: "Dedicated nightly_probe job + force_fail_probe boolean dispatch input in ci.yml"

provides:
  - "MAINTAINING.md CI-cadence subsection: nightly schedule, PR-fast vs broad split, two D-07 residuals, force_fail_probe probe runbook"
  - "guides/recipes/local-development.md one-line nightly/broad-cadence pointer"
  - "196-VERIFICATION.md: D-13 stale-CRIT-03 correction (5 lane names enforced; ci-gate NOT required) + full D-08 per-moved-job never-strand proxy table (all 5 moved jobs)"

affects: []

tech-stack:
  added: []
  patterns:
    - "ADD-only doc discipline: new CI cadence subsection appended to MAINTAINING.md without touching the already-correct required-check section"
    - "Honest-truth residual disclosure: two coverage gaps (upgrade_smoke whole-path; generated-host template parity) named explicitly with their backstops — not silently treated as covered"

key-files:
  created:
    - .planning/phases/196-pr-fast-vs-nightly-broad-trigger-model/196-VERIFICATION.md
  modified:
    - MAINTAINING.md
    - guides/recipes/local-development.md

key-decisions:
  - "ADD-only discipline preserved: the already-correct required-check section (5 lane names, ci-gate NOT required) was not rewritten — only the new CI-cadence subsection was appended"
  - "D-13 correction recorded in VERIFICATION only, not by editing REQUIREMENTS.md or ROADMAP prose — MAINTAINING.md already correct, stale premise is in CRIT-03 text"
  - "D-08 full per-moved-job never-strand proxy table (all 5 jobs) recorded in VERIFICATION as the CRIT-02 audit trail, not just the 2 residuals"
  - "All 4 phase_51 51-02-asserted strings preserved: v1.4-GA-UAT.md, 50-VERIFICATION.md, install_golden_contract, mix ci.install_golden"

requirements-completed: [CRIT-02, CRIT-03]

duration: ~4min
completed: 2026-06-20
status: complete
---

# Phase 196 Plan 04: Documentation — CI Cadence, Residuals, Probe Runbook, Verification Record Summary

**MAINTAINING.md gains a CI-cadence subsection (ADD-only) with the nightly schedule, PR-fast vs broad split, two D-07 honest-truth residuals, and the force_fail_probe probe runbook; 196-VERIFICATION.md created with D-13 stale-CRIT-03 correction and full D-08 per-moved-job never-strand proxy table; one-line nightly pointer added to local-development.md.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-20T16:21:55Z
- **Completed:** 2026-06-20T16:25:23Z
- **Tasks:** 2
- **Files modified:** 3 (MAINTAINING.md, guides/recipes/local-development.md, 196-VERIFICATION.md created)

## Accomplishments

### Task 1: MAINTAINING.md CI-cadence subsection (D-07/D-13/D-14)

Added a new `### CI cadence — PR-fast vs nightly/main-broad (Phase 196)` subsection to MAINTAINING.md positioned between the existing "Branch protection — enforced required checks" section and "Artifact, log, and cache retention":

- **Nightly cadence and split:** Documents the `30 4 * * *` cron schedule, names the 5 nightly-only jobs (install_matrix ×4, upgrade_smoke, passkeys_manual_fallback_smoke, passkeys_opt_out_smoke, generated_admin_playwright_smoke, nightly_probe), and the PR-fast gate jobs.
- **Two D-07 residuals (explicit disclosure):**
  1. `upgrade_smoke` whole upgrade path — no per-PR behavioral proxy; release-boundary coverage accepted
  2. Generated-host template parity — nightly-only; explicitly backstopped by DIST-06 `scripts/ci/admin-acceptance-smoke.sh` (RUN_PARITY)
- **D-14 forced-failure probe runbook:** Documents `gh workflow run "CI" -f force_fail_probe=true` reds the dedicated `nightly_probe` job; default-false keeps all normal runs green; nightly_probe is not in ci-gate.needs.
- **ADD-only:** The already-correct required-check section (5 lane names, ci-gate NOT required, lines 100-122) was not touched.
- **Phase_51 test:** All 4 asserted strings preserved — `v1.4-GA-UAT.md`, `50-VERIFICATION.md`, `install_golden_contract`, `mix ci.install_golden`. Test result: 2/2 green.

### Task 2: local-development.md + 196-VERIFICATION.md

**local-development.md:** Added a new `### PR-fast vs nightly CI split` subsection noting that exhaustive broad coverage (install matrix, upgrade smoke, generated-admin Playwright) now runs nightly/main, and that the fast loop is `mix test` + PR-fast gate.

**196-VERIFICATION.md (created):**

(a) **D-13 correction recorded:** States explicitly that CRIT-03's "single stable required check (ci-gate aggregator)" phrasing is stale. The live ruleset 14941512 (confirmed at Phase 196 execution, 2026-06-20) enforces exactly 5 required status-check contexts (the 5 lane name strings). `ci-gate` is NOT a required check context — it is an internal aggregator. Correction recorded in VERIFICATION only; REQUIREMENTS.md/ROADMAP prose unchanged per RESEARCH §7/Open Q2.

(b) **Full D-08 per-moved-job never-strand proxy table (all 5 jobs):**

| Moved job | PR-path proxy | Residual |
|-----------|---------------|----------|
| install_matrix (×4) | install_smoke (required lane) | flag-breadth only |
| passkeys_manual_fallback_smoke | example_playwright_smoke passkey specs | manual-fallback edge |
| passkeys_opt_out_smoke | example_playwright_smoke passkey specs | opt-out edge |
| upgrade_smoke | none (release-boundary) | whole upgrade path off PRs (disclosed) |
| generated_admin_playwright_smoke | example_playwright_smoke admin specs | template parity → DIST-06 admin-acceptance-smoke.sh |

## Task Commits

1. **Task 1** — `a06555ee`: docs(196-04): add CI cadence + two residuals + probe runbook to MAINTAINING.md
2. **Task 2** — `6ab29f1e`: docs(196-04): one-line nightly note in local-dev guide + create 196-VERIFICATION.md

## Verification Results

All automated checks passed:

```
grep -qi 'force_fail_probe' MAINTAINING.md                          OK
grep -qi 'admin-acceptance-smoke' MAINTAINING.md                    OK
grep -qi 'upgrade_smoke' MAINTAINING.md                             OK
grep -q 'v1.4-GA-UAT.md' MAINTAINING.md                            OK
grep -q 'mix ci.install_golden' MAINTAINING.md                      OK
grep -qi 'nightly|schedule' guides/recipes/local-development.md     OK
grep -qi 'ci-gate' 196-VERIFICATION.md                              OK
[all 5 moved job names found in 196-VERIFICATION.md]                OK
grep -qi 'install_smoke' 196-VERIFICATION.md                        OK
grep -qi 'example_playwright_smoke' 196-VERIFICATION.md             OK
grep -qi 'admin-acceptance-smoke' 196-VERIFICATION.md               OK
phase_51 test: 2 tests, 0 failures                                  OK
```

## Deviations from Plan

None — plan executed exactly as written. ADD-only discipline preserved throughout.

## Threat Model Verification

- **T-196-04-01 (Repudiation — silent move of coverage to nightly):** MITIGATED. The full D-08 per-moved-job never-strand proxy table (all 5 moved jobs → PR-path observer → residual) is recorded in 196-VERIFICATION.md. The two residuals (upgrade_smoke whole-path; generated-host template parity) are written explicitly into MAINTAINING.md and 196-VERIFICATION.md with the DIST-06 backstop named.
- **T-196-04-02 (Tampering — accidental rewrite of the correct required-check list):** MITIGATED. ADD-only discipline preserved; the 5-lane / ci-gate-not-required section is byte-stable; the 51-02-asserted strings are verified present (2/2 test passes).
- **T-196-04-SC (Tampering — npm/pip/cargo installs):** N/A. No package installs in this plan (Markdown edits only).

## Known Stubs

None.

## Threat Flags

None — this plan edits Markdown documentation only; no new network endpoints, auth paths, file access patterns, or schema changes introduced.

---

## Self-Check

- [x] Created files exist:
  - `.planning/phases/196-pr-fast-vs-nightly-broad-trigger-model/196-VERIFICATION.md` — FOUND
- [x] Modified files exist:
  - `MAINTAINING.md` — FOUND
  - `guides/recipes/local-development.md` — FOUND
- [x] Commits exist:
  - `a06555ee` (Task 1) — FOUND
  - `6ab29f1e` (Task 2) — FOUND

## Self-Check: PASSED

*Phase: 196-pr-fast-vs-nightly-broad-trigger-model*
*Completed: 2026-06-20*
