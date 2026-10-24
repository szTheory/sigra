# Requirements: Sigra

**Milestone:** v1.50 CI-SPEED-AND-RELIABILITY
**Defined:** 2026-10-12
**Status:** Implementations complete; seven requirements have passed phase behavior reports. The milestone audit records four fully cross-checked, three partial summary-metadata records, and two unproved speed targets.
**Core Value:** Authentication that works out of the box with a clear path for Phoenix adopters.

## v1.50 Requirements

### Measurements

- [x] **CIMEAS-01:** Contributors can see the current CI baseline for pull requests, main pushes, and nightly runs, with waiting time, execution time, run conclusions, and reruns recorded separately.
- [x] **CIMEAS-02:** Maintainers can identify the largest runtime costs from saved job/step/test measurements, including setup and cache work, and use a ranked list to select improvements.
- [x] **CIMEAS-03:** Maintainers can replay the final before/after comparison from saved inputs and a documented calculation, with failures, cancellations, reruns, sample sizes, and limitations disclosed.

### Speed

- [ ] **CISPEED-01:** Contributors receive the required PR CI result at least 20% faster by ordinary median elapsed time than a newly declared repaired control. Necessary correctness and environment repairs are common to control and candidate; only declared speed optimizations differ. Freeze the comparison method and exact conditions before new collection.
- [ ] **CISPEED-02:** The same repaired-control comparison shows no increase in total actual runner time per comparable PR or in empirical nearest-rank 95th-percentile wait for the required PR CI result. Include family retry delay and all actual attempt costs.

**Amendment approved 2026-10-24:** The user selected option 1 in Phase 255.1 discussion, permitting the repaired-control reference and a method fixed before new collection, after the existing optimization work. This does not establish improvement against the unchanged historical Phase 252 baseline or retroactively pass Phase 254's terminal `insufficient_data` experiment. Both requirements remain open. Approval covers context/planning only; preparation and collection need a separately bounded execution scope. Original wording and approval are retained in `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/DECISION.json`; prior file bytes are recoverable through `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/PRESERVATION.json`.

### Reliability

- [x] **CIREL-01:** The flaky failures selected from current measurements are reproduced and fixed with deterministic regression checks and repeat runs, without increasing blanket retries or replacing readiness with sleeps.
- [x] **CIREL-02:** Useful test coverage and required-check names remain intact; injected failures, cancellations, missing expected jobs, and unexpected skips still prevent a green required gate. Any proposed redundant-check removal needs a recorded coverage comparison before it is accepted.

### Contributor experience

- [ ] **CIDX-01:** Contributors can run the relevant updated CI checks locally through documented commands that agree with the CI execution paths, preserving `mix ci` as the contributor entry point.
- [x] **CIDX-02:** A failed updated CI check reports the failed test or command and the reproduction information it needs, with retained logs/traces and random seed when applicable.

## How the baseline phase makes this concrete

The original Phase 252 method was fixed before changing CI behavior and remains historical. For the amended Phase 255.1 experiment, before new collection record the affected job/test list, exact common/control/candidate revisions, comparison scenarios, run counts, timeout/rate-limit budget, cache conditions and percentile method; capture the repaired control numerically within that fixed experiment. Include all observed conclusions in the report; do not make failed or cancelled work disappear from the inventory. Compare successful equivalent workloads for the speed target and report other outcomes separately.

The 20% target is the approved milestone target, not a claimed current result. The 95th percentile means the wait near the slowest 5% of runs. The measurement plan must state what its sample can and cannot establish. Do not collect runs indefinitely to get a favorable number. If the target cannot be demonstrated within the fixed measurement plan, record the failure and its cause.

Use available current records and, when required by the approved phase workflow, bounded new comparison runs. Missing release approvals or old signed performance archives are not inputs or blockers. The baseline phase must choose a concrete flaky-failure list; if none is found, it must record that result and define deterministic repeated checks of the relevant isolation/readiness behavior without inventing a failure.

## Existing work to build on

- `scripts/ci/ci-run-metrics.sh` and its hermetic self-test provide existing runtime measurement tools.
- `.github/workflows/ci.yml` already runs five example-browser jobs with separate databases/ports.
- `test/example/priv/playwright/playwright.config.ts` deliberately uses one worker per invocation and zero retries because each invocation shares its own app/database.
- The full-library job runs `mix ci`; preserve the single contributor entry point.
- SEED-005 and SEED-006 are implemented history. They are not selected as new work.

## Future Requirements

The missing 1.6 upgrade guide remains a separately scoped documentation task: `.planning/todos/pending/2026-10-12-add-missing-v16-upgrade-guidance.md`. Other unmatched backlog items are not promoted into this milestone.

## Out of Scope

| Work | Reason |
|------|--------|
| Product features or public API/authentication changes | This milestone improves CI and contributor workflows. |
| UI redesign | Browser checks may be made deterministic; changing the product design requires separate scope. |
| Package publishing or release-history repair | v1.49 is closed with READY-01 unfinished; the missing old approval is not a prerequisite here. |
| Broad dependency upgrades or paid runners | Optimize and validate the current stack and runner class first. |
| Broad ecosystem research | The user chose to skip it for this milestone; the persistent research setting stays unchanged. |

## Traceability

The user confirmed all nine requirements and approved the four-phase roadmap. Each requirement below maps to exactly one phase. The traceability statuses below reflect phase behavior reports. The stricter milestone audit records missing SUMMARY completion metadata for CIMEAS-01/02 and CIDX-01; CISPEED-01/02 remain Pending. See `v1.50-MILESTONE-AUDIT.md`.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CIMEAS-01 | Phase 252 | Complete |
| CIMEAS-02 | Phase 252 | Complete |
| CIMEAS-03 | Phase 255 | Complete |
| CISPEED-01 | Phase 255.1 (Phase 254 origin) | Pending |
| CISPEED-02 | Phase 255.1 (Phase 254 origin) | Pending |
| CIREL-01 | Phase 253 | Complete |
| CIREL-02 | Phase 253 | Complete |
| CIDX-01 | Phase 255 | Complete |
| CIDX-02 | Phase 255 | Complete |

**Coverage:** 9 requirements; 9 mapped exactly once; 0 unmapped; 0 duplicate assignments.

---
*Requirements confirmed: 2026-10-12 — user selected “Accept these requirements and create the roadmap.”*
*Phase mappings approved: 2026-10-12 — user selected “Approve and commit this roadmap.”*
