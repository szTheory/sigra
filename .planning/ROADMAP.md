# Roadmap: Sigra

## Milestones

- 🚧 **v1.50 CI-SPEED-AND-RELIABILITY** — Phases 252–255 (roadmap approved; implementation not started)
- ⚠️ **v1.49 RELEASE-1.6.0** — Phases 246–251 (closed 2026-10-12 with one known failed readiness check; 8/9 requirements proved) · full record in [milestones/v1.49-ROADMAP.md](milestones/v1.49-ROADMAP.md)
- ⚠️ **v1.48 CLEAN-BASELINE** — Phases 236–245; 21/27 requirements satisfied, four partial, two unsatisfied; seven stale verification reports and Phase 245 gaps_found. [Full roadmap](milestones/v1.48-ROADMAP.md) · [requirements](milestones/v1.48-REQUIREMENTS.md) · [audit](milestones/v1.48-MILESTONE-AUDIT.md)
- ⚠️ **v1.47 CI-EFFICIENCY** — Phases 230-235 (shipped 2026-09-15 · `override_closeout`, 21/24 requirements, TEST-01/TEST-02 unsatisfied, 46 artifacts acknowledged) · full detail in milestones/v1.47-ROADMAP.md
- ✅ **v1.46 ADOPTER-EXPERIENCE** — Phases 224-229 (shipped 2026-07-27 · `override_closeout`, 15/15 requirements, 8 audit findings deferred) · full detail in milestones/v1.46-ROADMAP.md
- ⚠️ **v1.45 RELEASE-CURRENCY** — Phases 221-223 (shipped 2026-07-11 · `override_closeout`, Phase 223 deferred) · full detail in milestones/v1.45-ROADMAP.md
- ✅ **v1.44 ADMIN-UX-RATCHET** — Phases 216-220 (shipped 2026-07-10) · full detail in milestones/v1.44-ROADMAP.md
- ✅ **v1.43 STABILIZE** — Phases 213-215 (shipped 2026-07-03) · full detail in milestones/v1.43-ROADMAP.md
- ✅ **v1.42 ADMIN-DS-ELEVATION** — Phases 205-212 (shipped 2026-07-02) · full detail in milestones/v1.42-ROADMAP.md
- ✅ **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (shipped 2026-06-27)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## v1.50 — CI-SPEED-AND-RELIABILITY

**Goal:** Make CI faster and more reliable while keeping useful tests and straightforward local reproduction.
**Requirements:** 9 confirmed; each maps to exactly one phase.
**Roadmap approval:** User-approved on 2026-10-12. No phase implementation or verification has started.
**Research:** Broad ecosystem research skipped by the user; the project research default stays unchanged.

The work follows four delivery boundaries: measure current CI, remove the selected flaky failures and protect required checks, optimize the measured costs, then finish the contributor commands and reproducible result report. The existing five browser-test jobs, runtime measurement script, and mix ci are starting points, not work to rebuild automatically.

## Next

**Next command:** `$gsd-execute-phase 252` — execute six independently checked plans across four waves. Research, pattern mapping and plan review are complete; readiness finds six incomplete plans and no execution blocker. Implementation and phase verification have not started.

The user does not need to produce old release records. v1.49 READY-01 remains unfinished in its archive and does not block these phases. The missing 1.6 upgrade guide stays a separate documentation task. No product feature, public API/authentication change, package release, broad dependency upgrade, or paid runner change is included.

## Phases

- [ ] **Phase 252: Measure Current CI** — Contributors and maintainers can identify today's CI waiting time, failure patterns, and largest runtime costs before choosing fixes.
- [ ] **Phase 253: Fix Flaky CI and Preserve Required Checks** — Selected flaky CI failures are reproducible and fixed, while real failures still prevent the required checks from passing.
- [ ] **Phase 254: Speed Up the Measured Slow Jobs** — Contributors receive the required PR CI result at least 20% sooner without increasing slow-run waits or total runner time.
- [ ] **Phase 255: Make Failures Reproducible and Report the Result** — Contributors can reproduce updated CI checks locally and maintainers can independently replay the final speed and reliability comparison.

## Phase Details

### Phase 252: Measure Current CI

**Goal**: Contributors and maintainers can identify today's CI waiting time, failure patterns, and largest runtime costs before choosing fixes.
**Depends on**: Nothing — first phase of v1.50; prior release-record gaps are not prerequisites.
**Requirements**: CIMEAS-01, CIMEAS-02
**Success Criteria** (automatically verifiable):
  1. A current report separates pull-request, main-push, and nightly runs and shows waiting time, execution time, literal conclusions, and rerun attempts with their saved source data.
  2. Measured job, step, and test costs identify the largest setup/cache/execution costs; current failure signatures form a concrete, bounded flaky-test shortlist.
  3. The baseline and ranked findings can be reproduced with documented commands using the saved inputs; static timeout values or old audit conclusions are not used as runtime measurements.
  4. Before any optimization, the report fixes the comparison workloads, code revisions, cache conditions, runner class, sample sizes, percentile method, and finite collection/rate-limit budget. The 20% median improvement and non-increasing p95/runner-time targets stay unchanged.

**Plans**: 6 plans across 4 waves (independent plan review passed; implementation pending)
**Wave 1**
- [ ] 252-01-PLAN.md — Source-bound collection and offline replay

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 252-02-PLAN.md — Bounded populations, attempts and safe artifact acquisition
- [ ] 252-03-PLAN.md — Opt-in ExUnit timing and exit preservation
- [ ] 252-04-PLAN.md — Native Playwright JSON and completeness checks

**Wave 3** *(blocked on Wave 2 completion)*
- [ ] 252-05-PLAN.md — CI timing integration, cost rankings and failure shortlist

**Wave 4** *(blocked on Wave 3 completion)*
- [ ] 252-06-PLAN.md — Hosted baseline, reproducible report and later comparison contract

### Phase 253: Fix Flaky CI and Preserve Required Checks

**Goal**: Selected flaky CI failures are reproducible and fixed, while real failures still prevent the required checks from passing.
**Depends on**: Phase 252
**Requirements**: CIREL-01, CIREL-02
**Success Criteria** (automatically verifiable):
  1. Each selected current flaky failure has a deterministic reproduction, a root-cause fix in the test or CI harness, and passing regression/repeat checks under the fixed budget. If the baseline found no flake, that result and repeated isolation/readiness checks are recorded without inventing a bug.
  2. Browser/test retries are not increased and readiness is asserted without sleeps; tests continue to use isolated application/database state where needed.
  3. Required-check names and useful test ownership remain intact. Any accepted removal of a redundant check includes a comparison showing its useful coverage still executes.
  4. Injected failures, cancellations, missing expected jobs, and unexpected skips prevent a green required gate; documented intentional skips remain distinguishable from missing execution.

**Plans**: TBD

### Phase 254: Speed Up the Measured Slow Jobs

**Goal**: Contributors receive the required PR CI result at least 20% sooner without increasing slow-run waits or total runner time.
**Depends on**: Phase 253
**Requirements**: CISPEED-01, CISPEED-02
**Success Criteria** (automatically verifiable):
  1. The recorded optimization targets the measured costs from Phase 252 and is tested on the same predeclared workloads, runner class, and cache conditions.
  2. Saved real before/after run data show required PR-result median elapsed time at or below 80% of the baseline, calculated by the fixed method.
  3. The same comparison shows a 95th-percentile required-result wait no higher than baseline and total runner time per comparable PR no higher than baseline.
  4. The changed CI paths still pass the Phase 253 coverage/gate checks and applicable isolation/cache tests. A target miss is recorded as a miss; the collection window is not extended until the numbers look favorable.

**Plans**: TBD

### Phase 255: Make Failures Reproducible and Report the Result

**Goal**: Contributors can reproduce updated CI checks locally and maintainers can independently replay the final speed and reliability comparison.
**Depends on**: Phase 254
**Requirements**: CIDX-01, CIDX-02, CIMEAS-03
**Success Criteria** (automatically verifiable):
  1. Documented local commands execute the relevant updated CI paths, with mix ci retained as the contributor entry point and any browser/database preparation made explicit.
  2. A deliberately failed updated check identifies the failed test or command, reproduction command and applicable seed, and retained logs/traces needed to diagnose it.
  3. A documented calculation replays the final before/after comparison from saved inputs, including sample sizes, literal failure/cancellation/rerun outcomes, cache conditions, and limitations.
  4. The final report names the tested code, states whether the 20% median and non-increasing p95/runner-time targets hold, and records any remaining failures separately from implemented changes. Missing old release approvals or signed historical performance archives are not required inputs.

**Plans**: TBD

## Progress

**Execution order:** 252 → 253 → 254 → 255. Phase 252 has six plans in four waves; later plan counts are determined during their planning.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 252. Measure Current CI | v1.50 | 0/6 | Planned; ready to execute | — |
| 253. Fix Flaky CI and Preserve Required Checks | v1.50 | 0/TBD | Not started | — |
| 254. Speed Up the Measured Slow Jobs | v1.50 | 0/TBD | Not started | — |
| 255. Make Failures Reproducible and Report the Result | v1.50 | 0/TBD | Not started | — |

## Historical Closeout

Phases 246–251 are archived under `milestones/v1.49-phases/`. Phase 251 implementation is summarized; its verification remains `gaps_found` at 9/10. The strict v1.49 audit remains 8/9. See [the closeout decision](milestones/v1.49-CLOSEOUT-DECISION.json) and [known gaps](milestones/v1.49-CLOSEOUT.md).
