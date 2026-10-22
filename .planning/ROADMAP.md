# Roadmap: Sigra

## Milestones

- 🚧 **v1.50 CI-SPEED-AND-RELIABILITY** — Phases 252–255 (Phase 252 complete and verified; Phase 253 partly implemented; reviewed load recovery plans ready)
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
**Roadmap approval:** User-approved on 2026-10-12. Phase 252 implementation and verification are complete; CIMEAS-01 and CIMEAS-02 are satisfied.
**Research:** Broad ecosystem research skipped by the user; the project research default stays unchanged.

The work follows four delivery boundaries: measure current CI, remove the selected flaky failures and protect required checks, optimize the measured costs, then finish the contributor commands and reproducible result report. The existing five browser-test jobs, runtime measurement script, and mix ci are starting points, not work to rebuild automatically.

## Next

**Next command:** $gsd-execute-phase 253 --gaps-only — Execute reviewed plans 178–180, starting with 178. Both requirements and phase verification remain open.

The user does not need to produce old release records. v1.49 READY-01 remains unfinished in its archive and does not block these phases. The missing 1.6 upgrade guide stays a separate documentation task. No product feature, public API/authentication change, package release, broad dependency upgrade, or paid runner change is included.

## Phases

- [x] **Phase 252: Measure Current CI** — Contributors and maintainers can identify today's CI waiting time, failure patterns, and largest runtime costs before choosing fixes. (completed 2026-10-12)
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

**Plans**: 6/6 plans complete across 4 waves (implementation and phase verification passed)
**Wave 1**
- [x] 252-01-PLAN.md — Source-bound collection and offline replay

**Wave 2**
- [x] 252-02-PLAN.md — Bounded populations, attempts and safe artifact acquisition
- [x] 252-03-PLAN.md — Opt-in ExUnit timing and exit preservation
- [x] 252-04-PLAN.md — Native Playwright JSON and completeness checks

**Wave 3** *(plan 07 halted after the first hosted run failed)*
- [x] 252-05-PLAN.md — CI timing integration, cost rankings and failure shortlist

**Wave 4** *(blocked by halted plans 02 and 07)*
- [x] 252-06-PLAN.md — Hosted baseline, reproducible report and later comparison contract

### Phase 253: Fix Flaky CI and Preserve Required Checks

**Goal**: Selected flaky CI failures are reproducible and fixed, while real failures still prevent the required checks from passing.
**Depends on**: Phase 252
**Requirements**: CIREL-01, CIREL-02
**Success Criteria** (automatically verifiable):
  1. Each selected current flaky failure has a deterministic reproduction, a root-cause fix in the test or CI harness, and passing regression/repeat checks under the fixed budget. If the baseline found no flake, that result and repeated isolation/readiness checks are recorded without inventing a bug.
  2. Browser/test retries are not increased and readiness is asserted without sleeps; tests continue to use isolated application/database state where needed.
  3. Required-check names and useful test ownership remain intact. Any accepted removal of a redundant check includes a comparison showing its useful coverage still executes.
  4. Injected failures, cancellations, missing expected jobs, and unexpected skips prevent a green required gate; documented intentional skips remain distinguishable from missing execution.

**Plans**:183 total:81 completed implementation plans,29 historical halts,73 without summaries;0 runnable. Current required-gate evidence and local contracts verify. Original registration failure remains not_reproduced; the strict checker rejects acceptance. Direct review:253-CURRENT-REQUIREMENT-REVIEW.md. No status detour, automatic repair successor or spent-budget restart.

**Wave 1**
- [x] 253-01-PLAN.md — Preserved replay and corrected failed-step diagnosis
- [ ] 253-02-PLAN.md — Pinned registration reproduction, controls and conditional fix
- [x] 253-03-PLAN.md — Example unit smoke internal gate ownership
- [x] 253-04-PLAN.md — Selected-body skip manifest and documentation parity
- [x] 253-05-PLAN.md — Five-seam execution records and complete native reports

**Wave 2** *(required plans 03/04/05 complete; plan 06 complete)*
- [x] 253-06-PLAN.md — Browser producer artifacts and aggregate workflow wiring

**Wave 3** *(plan 07 halted after the first hosted run failed)*
- [ ] 253-07-PLAN.md — Bounded hosted canary and independent source verification

**Wave 4** *(blocked by halted plans 02 and 07)*
- [ ] 253-08-PLAN.md — Normal PR proof and honest requirement completion record

**Recovery plans** *(09/12 halted; new planning required before any further execution; original plans and terminal records remain preserved)*

| Recovery wave | Plans | Work |
|---|---|---|
| 1 | 09, 11 | Native registration receipt path; charged canary transport and fresh freezes |
| 2 | 10, 12 | Signal/state/trace controls and conditional repeats; six real canary scenarios |
| 3 | 13 | Normal production PR and real docs-only PR proof |
| 4 | 14 | Honest completion and accepted-only disposition of blocked original 08 |

- [ ] 253-09-PLAN.md — Halted before browser; corrected local build isolation awaits new frozen proof
- [ ] 253-10-PLAN.md — Real controls and cause-backed fresh target repeats
- [x] 253-11-PLAN.md — Exact charged request transport and new canary freeze
- [ ] 253-12-PLAN.md — Halted in required-check query; corrected local preflight awaits new frozen hosted proof
- [ ] 253-13-PLAN.md — Normal and real docs-only draft PR evidence
- [ ] 253-14-PLAN.md — Evidence-linked requirements and historical-plan reconciliation

**Additional recovery plans** *(15–25 passed independent review; old plans01–14 and failed records remain preserved)*

| Recovery wave | Plans | Work |
|---|---|---|
| 1 | 15,18 | Remaining registration diagnostics; measured HTTP transport |
| 2 | 16,19 | Native readiness/state/trace controls; independent source verifier |
| 3 | 17,20 | Cause-backed repair and reserved repeats; counted Git object publication |
| 4 | 21 | Normal/docs-only PR collector and completion verification contracts |
| 5 | 22 | Final local candidate/fixture and explicit finite source/window freeze |
| 6 | 23 | Six real hosted outcomes and separate hosted verifier |
| 7 | 24 | Normal and real docs-only PR native required-check proof |
| 8 | 25 | Accepted-only historical-plan disposition and phase-verification route |

- [x] 253-15-PLAN.md — Remaining native registration diagnostics
- [ ] 253-16-PLAN.md — Halted: first combined dark/control command timed out; native readiness, state, and trace controls remain incomplete
- [ ] 253-17-PLAN.md — Cause assessment, scoped repair and fresh repeats
- [x] 253-18-PLAN.md — Measured actual HTTP transport
- [x] 253-19-PLAN.md — Independent source and transport verifier
- [x] 253-20-PLAN.md — Local Git publication helper; complete tree fits 16 of 24 requests; GitHub availability unproven
- [ ] 253-21-PLAN.md — Real PR collector and completion contracts
- [ ] 253-22-PLAN.md — Final local source/window freeze
- [ ] 253-23-PLAN.md — Six hosted outcomes and separate verifier
- [ ] 253-24-PLAN.md — Normal and real docs-only PR proof
- [ ] 253-25-PLAN.md — Accepted-only reconciliation and full phase verification route

**Control recovery plans** *(26–35 passed independent review with one informational advisory; all old failed outcomes remain unchanged)*

**Recovery wave 1** *(ready first)*

- [x] 253-26-PLAN.md — Diagnose the stopped native command and repair demonstrated control contracts offline.

**Recovery wave 2** *(blocked on preceding recovery dependencies)*

- [ ] 253-27-PLAN.md — Halted: Node 20 parse5 load failure before selected tests; 33409ms charged, no retry; Task2 not started.

**Recovery wave 3** *(blocked on preceding recovery dependencies)*

- [ ] 253-28-PLAN.md — Complete the remaining native signal, collision, isolation and trace controls.

**Recovery wave 4** *(blocked on preceding recovery dependencies)*

- [ ] 253-29-PLAN.md — Establish the selected cause and accept only genuine fresh post-fix repetitions.

**Recovery wave 5** *(blocked on preceding recovery dependencies)*

- [ ] 253-30-PLAN.md — Prepare real normal/docs PR collection and full completion predicates before source freezing.

**Recovery wave 6** *(blocked on Plan 30)*

- [ ] 253-31-PLAN.md — Prepare accepted-only historical disposition using the actual installed SDK.
- [ ] 253-32-PLAN.md — Complete final registered-path canary assembly and regenerate exact candidate publication.

**Recovery wave 7** *(blocked on preceding recovery dependencies)*

- [ ] 253-33-PLAN.md — Prove six actual hosted outcomes and a separate verifier inside the sealed canary allocation.

**Recovery wave 8** *(blocked on preceding recovery dependencies)*

- [ ] 253-34-PLAN.md — Prove real normal production and docs-only PR required checks under one allocation.

**Recovery wave 9** *(blocked on preceding recovery dependencies)*

- [ ] 253-35-PLAN.md — Record accepted reliability proof and prepare honest historical disposition plus full-verification routing.

Cross-cutting constraints: preserve original Phase 252 and failed Phase 253 records; carry spent charges and retry without reset; zero browser retries and signal-driven readiness; retain five required-check names; native and hosted proof required before accepted-only historical dispositions.

**Load recovery plans** *(36–47 passed independent review; all original plans and failed receipts remain preserved)*

**Load recovery wave 1** *(ready first)*

- [ ] 253-36-PLAN.md — Repair actual Node 20 transformed spec loading and awaited canonical DOM hashing.
- [ ] 253-37-PLAN.md — Validate safe redaction and require independent exact database absence receipts.
- [ ] 253-42-PLAN.md — Implement real normal/docs PR collector and full completion contracts.
- [ ] 253-43-PLAN.md — Implement accepted-only historical disposition against the installed SDK.

**Load recovery wave 2** *(blocked on earlier recovery dependencies)*

- [ ] 253-38-PLAN.md — Make runner contracts portable and test cumulative limits and descendant cleanup.

**Load recovery wave 3** *(blocked on earlier recovery dependencies)*

- [ ] 253-39-PLAN.md — Implement and freeze the four remaining control allocations with complete source identities.

**Load recovery wave 4** *(blocked on earlier recovery dependencies)*

- [ ] 253-40-PLAN.md — Run all mandatory controls in four bounded native commands.

**Load recovery wave 5** *(blocked on earlier recovery dependencies)*

- [ ] 253-41-PLAN.md — Record actual cause, any evidenced repair, and nine conditional fresh acceptance passes.

**Load recovery wave 6** *(blocked on earlier recovery dependencies)*

- [ ] 253-44-PLAN.md — Assemble final hosted candidate and regenerate exact source publication.

**Load recovery wave 7** *(blocked on earlier recovery dependencies)*

- [ ] 253-45-PLAN.md — Prove six actual hosted outcomes and independent verifier.

**Load recovery wave 8** *(blocked on earlier recovery dependencies)*

- [ ] 253-46-PLAN.md — Prove normal and docs-only PR native required checks.

**Load recovery wave 9** *(blocked on earlier recovery dependencies)*

- [ ] 253-47-PLAN.md — Prepare accepted-only completion/disposition bundle and whole-phase verification route.

Cross-cutting constraints: preserve all failed records and spent allocations; first prove actual Node 20 collection offline; use only four remaining regular commands and nine conditional acceptance commands; retain all three-project controls and required-check names; require independent native/hosted proof before dispositions or whole-phase completion.

**Current execution-halt recovery** *(one new plan; five unexecuted continuations repaired; independent review passed)*

| Active wave | Plan | Dependency and remaining work |
|---|---|---|
| 1 | 253-173 | Independent entry; check completed inputs, run the corrected offline acceptance block and bind its new result to the unchanged Plan 167 halt. |
| 2 | 253-168 | After 173; derive the final R13 publication proposal and source freeze within the existing byte/request limits. |
| 3 | 253-169 | After 168; retain 21 halted records and the same 71 unexecuted-summary targets in the R13 reconciliation contract. |
| 4 | 253-170 | After 168/169; obtain the scoped approval and actual six-scenario canary evidence. |
| 5 | 253-171 | After 170; obtain the scoped approval and normal/docs-only PR required-check proof. |
| 6 | 253-172 | After 169/171; reopen completion evidence and prepare historical dispositions, then route to whole-phase verification. |

- [ ] 253-173-PLAN.md — Correct the stopped verification command and produce a separately checked local result; Plan 167 remains halted.
- [ ] 253-168-PLAN.md — Final source/publication freeze.
- [ ] 253-169-PLAN.md — R13 responsibility and disposition contract.
- [ ] 253-170-PLAN.md — Real canary and separate verifier.
- [ ] 253-171-PLAN.md — Real normal and docs-only PR proof.
- [x] 253-172-PLAN.md — Completion records and full-verification route.

Cross-cutting constraints: preserve every historical halt and spent allocation; keep original Plan 167 bytes; keep CIREL-01 partial under the existing not-reproduced disposition; require actual hosted proof before CIREL-02 acceptance; retain existing approval, request, retry and 2,097,152-byte tree limits. Planning review is complete; execution and whole-phase verification remain incomplete. Current records: `253-173-PLANNING-RECORD.json`, `253-173-CHECK-02.md`, `253-173-PLANNING-CHECKS.json`, `253-173-ROUTING-CHECKS.json`.

**Latest execution result (2026-10-20):** Plan 173 halted with `VERIFY-EXIT 1`: the default sandbox denied Git object creation before projection or regression. The exact failed log and summary are committed. A separate elevated Git object write/readback probe passed; the acceptance command was not rerun. Plans 168–172 remain blocked. Next: `$gsd-plan-phase 253 --gaps`. Records: `253-173-EXECUTION-RECORD.json`, `253-173-ENVIRONMENT-DIAGNOSTIC.json`. Implementation and whole-phase verification remain incomplete.

**Current Git permission recovery** *(planning review passed; execution not started)*

| Active wave | Plan | Work |
|---|---|---|
| 1 | 174 | Root-launched elevated Git write/readback and one new offline acceptance result; preserve halted 167/173. |
| 2 | 168 | Independently verify the new 174 receipt, then freeze final R13 inputs. |
| 3 | 169 | Preserve 22 halts and the same 71 unstarted disposition targets; pin all 174 plans. |
| 4 | 170 | Actual six-scenario canary and separate verifier within existing limits. |
| 5 | 171 | Normal and docs-only PR native required-check proof. |
| 6 | 172 | Reopen completion evidence and prepare historical dispositions before full phase verification. |

- [ ] 253-174-PLAN.md — Fresh permission-checked acceptance attempt; previous failures remain unchanged.

Cross-cutting constraints: unchanged request/retry/tree/time limits; exact source/log/receipt identities; CIREL-01 partial_not_reproduced; CIREL-02 unaccepted pending hosted proof; whole-phase verification not_started. Only 174 is ready now. Next: `$gsd-execute-phase 253 --gaps-only`. Current records: `253-174-PLANNING-RECORD.json`, `253-174-CHECK-01.md`, `253-174-SOURCE-AUDIT.md`.


### Latest gap planning — fixture and receipt repair (2026-10-20)

Plan174 halted after one of118 publication tests failed; its exact log remains VERIFY-EXIT1. No rerun or success receipt. Additive plans preserve original instructions and failure bytes.

| Wave | Plan | Result required |
|---|---|---|
| 1 |175| Historical config fixture and tested successor producer/consumer contract |
| 2 (after175) |176| One separately identified elevated offline acceptance attempt |
| 3 (after176) |177| Preserve original168–172 plans, then amend their receipt readers and dependency route |

- [ ]253-175-PLAN.md — Fixture/receipt contract repair
- [ ]253-176-PLAN.md — Once-only successor acceptance
- [ ]253-177-PLAN.md — Preserved downstream amendments

Cross-cutting constraints: exact historical publisher allowance, retained173/174 failure logs, same-process elevated probe/acceptance, unchanged limits, no acceptance retry, actual hosted proof still required. The future route after177 is168→169→170→171→172 in waves4–8. Existing168–172 bytes remain unchanged during planning. Records:253-175-177-PLANNING-RECORD.json and253-175-177-CHECK-01.md. Planning checks passed; implementation and phase verification remain incomplete.


### Latest additive repair plans 178–180 (2026-10-20)

Plan 175 halted because the bridge accepted stale executable checks and failed proof owners. Plans 176/177 never ran; their instructions remain unchanged. New planning passed independent review with no blockers or warnings.

**Wave 1**
- [ ] 253-178-PLAN.md — Repair strict executable validation, receipt lifecycle and SDK-copy fixtures.

**Wave 2 (blocked on Wave 1 completion)**
- [ ] 253-179-PLAN.md — One distinct offline acceptance attempt; preserve every older result.

**Wave 3 (blocked on Wave 2 completion)**
- [ ] 253-180-PLAN.md — Preserve seven originals, then amend five blocked continuation plans.

Cross-cutting constraints: keep Plan 175 halted, all failed results and original instructions recoverable, and the existing request/retry/time/tree limits. Local acceptance and copied SDK simulations cannot satisfy hosted CI requirements. The future contract must account for 180 plan pins, 24 halts and 73 dispositions. The current 180-plan set has 75 completed implementation plans, 24 halts and 81 without summaries. Records: `253-178-180-PLANNING-RECORD.json`, `253-178-180-CHECK-01.md`, `253-178-180-SOURCE-AUDIT.md`. Next: `$gsd-execute-phase 253 --gaps-only`, starting with 178. Implementation and whole-phase verification remain incomplete.

### Latest gap repair planning — Plan181 (2026-10-20)

Plan178 remains halted with its original review and full-suite error. Plan181 covers all four recorded defects and passed independent review after one focused correction. No existing instructions are amended during planning.

**Wave 1**
- [ ] 253-181-PLAN.md — Repair both receipt prefixes, real Git fixture, strict SDK reports and exact181-plan inventory; preserve and amend unrun179/180.

Future waves2–8 depend on successful181 and its preserved instruction amendments:179→180→168→169→170→171→172. Until then only181 is runnable.

Cross-cutting constraints: preserve all failed results and original instructions; keep the existing acceptance identity179 and request/retry/time/tree limits; 181pins/25halts/73dispositions in the eventual contract; actual hosted proof required for CIREL-02. Requirements and whole-phase verification remain incomplete. Records:253-181-CHECK-02.md,253-181-PLANNING-CHECKS.json,253-181-ROUTING-CHECKS.json. Next:$gsd-execute-phase 253 --gaps-only.

### Latest gap repair planning — Plan182 (2026-10-20)

Plan181 remains halted with its complete failed native output. Plan182 passed independent review with no blockers or warnings. No existing helper/tests or179/180 instructions changed during planning.

**Wave 1**
- [ ] 253-182-PLAN.md — Repair real25/26-to22 mutation controls, preserve failed181, add strict182 review and exact182/26/73 lifecycle, then preserve/amend unrun179/180 during execution.

Future waves2–8 are blocked on successful182 and execution-time amendments:179→180→168→169→170→171→172. Cross-cutting constraints: retain all26 historical halts, exact73 dispositions, original179 acceptance identity and fixed budgets; local simulation cannot replace hosted proof. Requirements remain open and whole-phase verification not_started. Next:$gsd-execute-phase 253 --gaps-only. Records:253-182-PLANNING-RECORD.json,253-182-PLAN-CHECK.json,253-182-PLANNING-CHECKS.json,253-182-ROUTING-CHECKS.json.

**Latest additive gap plan:** 253-183-PLAN.md — one wave, three tasks: real mutation tracer; strict183/27/73 lifecycle; preserved179/180 continuation. Cross-cutting constraints: retain all27 historical halts, exact73 dispositions, original179 acceptance identity and fixed budgets; local simulation cannot replace hosted proof. Independent review253-183-PLAN-CHECK-04.json passed; both requirements and whole-phase verification remain open. Next:$gsd-execute-phase 253 --gaps-only.

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

**Execution order:**252→253→254→255. Phase252complete;253remains incomplete with183plans,75completed implementation plans,28halted,80without summaries and0runnable. Local checker maintenance26/26passed;recovery reset active. Phase254/255pending.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 252. Measure Current CI | v1.50 | 6/6 | Complete    | 2026-10-12 |
| 253. Fix Flaky CI and Preserve Required Checks | v1.50 | 81/183 | Partial implementation; 29 historical halts; no runnable plans; phase verification not started | — |
| 254. Speed Up the Measured Slow Jobs | v1.50 | 0/TBD | Not started | — |
| 255. Make Failures Reproducible and Report the Result | v1.50 | 0/TBD | Not started | — |

## Historical Closeout

Phases 246–251 are archived under `milestones/v1.49-phases/`. Phase 251 implementation is summarized; its verification remains `gaps_found` at 9/10. The strict v1.49 audit remains 8/9. See [the closeout decision](milestones/v1.49-CLOSEOUT-DECISION.json) and [known gaps](milestones/v1.49-CLOSEOUT.md).

**Latest execution — Plan183:** Task1 complete; Task2 halted on6tests/1failure/2errors. Task3unrun;179/180unchanged;0runnable plans. Both requirements and whole-phase verification stay open. The repeated evidence-checker repair loop needs review before another successor. Record:`.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-183-EXECUTION-RECORD.json`. Next:`$gsd-plan-phase 253 --gaps`.

**Current recovery route:** User-requested lessons and process reset recorded in`253-LEARNINGS.md` and`253-RECOVERY-RESET.md`. Local checker suite26/26passed;no new numbered plan or acceptance. Original requirements remain open. Read the reset before choosing further work. Immediate status command:`$gsd-progress`;old gap-planning routes above are historical.
