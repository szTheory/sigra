# v1.50 Cross-Phase Integration Audit

**Scope:** Phases 252–255; source inspection at the current checkout. This report checks the actual producer-to-consumer paths. Phase verification reports are evidence for their historical source versions only; they are not treated as current-source fingerprints. No network, GitHub, CI, application, database, browser, or acceptance action was run for this audit.

## Result

**Expected integration connections: 17; WIRED 17, BROKEN 0.** This includes 14 software/data links and three cross-phase requirement handoffs. **E2E flows: 7; implementation paths wired 7, acceptance complete 6, acceptance open 1, broken software flows 0.** The final speed flow's code path exists, but the evidence needed to pass its target is absent: the comparison result is expressly `insufficient_data`, with zero comparable successful pairs and null median/p95.

**Performance acceptance gap:** CISPEED-01 and CISPEED-02 remain unmet/open because the fixed hosted comparison could not be run; this is missing acceptance evidence, not broken implementation wiring. Phase 254 Plan 08 records the exact frozen baseline cannot run through the current required PR path, and that no preparation or comparison families started. Phase 255 replay independently preserves the earlier terminal `insufficient_data` result.

**Historical evidence limitation:** Phase 252 passed its original verification on 2026-10-13 and Phase 253 on 2026-10-23. Phase 255's final report says later fixes were checked locally and hosted runs remain bound to their original producer commit. Accordingly, historical passed reports support the described test/evidence history, not a blanket assertion that every byte of current source was rerun. Phase 254 has no verification report; its 254-08 summary says whole-phase verification is pending.

## Provides / consumes map

| Phase | Provides (from summaries and code) | Consumes |
|---|---|---|
| 252 | `ci-run-metrics.sh` collection, baseline/replay, timing producers, Playwright JSON normalizer, measurement metadata/workflow integration | GitHub run/check/artifact inputs; ExUnit and Playwright outputs; workflow runtime/cache metadata |
| 253 | selected browser reliability fix, required-gate semantics, five named browser owners, no retry/sleep policy | Phase 252 measurements/failure diagnosis; workflow lane outcomes and test results |
| 254 | setup/browser optimization changes and frozen comparison contract/evaluation artifacts | Phase 252 baseline and Phase 253 preserved workload/gate; measured candidate and baseline hosted families |
| 255 | `mix ci` receiver records, browser local selectors/diagnostics, failure bundles, offline comparison replay/report/distribution | Phase 254 saved comparison inputs and Phase 252 evaluator; CI workflow invocations and contributor docs |

The supplied `SUMMARIES.json` omits `CIMEAS-01`, `CIMEAS-02`, and `CIDX-01` from summary `requirements_completed` metadata. I did not retrofit those IDs into historical summaries. The repository requirements table assigns them to Phases 252/255, and this audit maps the observable source-to-consumer paths below.

## Itemized connection results (17/17 WIRED)

Evidence paths are relative to repository root; line numbers refer to the current checkout unless the entry explicitly cites a historical report.

| # | Expected connection | Status | Trace evidence |
|---:|---|---|---|
| 1 | Workflow measurement collection → source-bound baseline/replay | WIRED | `.github/workflows/ci.yml:669-745` emits run/job/cache/timing metadata; `scripts/ci/ci-run-metrics.sh` consumes ledgers and artifacts; 252 verification historical key links at `252-VERIFICATION.md:173-178` trace identity checks and offline rankings. |
| 2 | ExUnit opt-in env → formatter → timing JSON | WIRED | Workflow sets `SIGRA_EXUNIT_TIMING_JSON` at `ci.yml:613-626`; `test/test_helper.exs` installs the formatter conditionally; `test/support/ci_timing_formatter.ex:10-27,101-142` writes complete event timing and marks unavailable/incomplete results; workflow uploads at `ci.yml:627-635`. Historical 252 link at `252-VERIFICATION.md:175`. |
| 3 | Playwright native report → normalized records → metrics consumer | WIRED | `playwright.config.ts:55-89` configures native JSON and failure JSONL; `scripts/ci/ci-playwright-report.mjs` normalizes; `scripts/ci/ci-browser-records.mjs:7-8` imports normalizer and selectors; workflow browser jobs use those records. Historical 252 link at `252-VERIFICATION.md:176`. |
| 4 | Phase 252 failure/measurement findings → Phase 253 selected reliability work | WIRED | Phase 253 verification maps selected issue to controlled reproduction/config fix and names its evidence at `253-VERIFICATION.md:361,415`; requirements map CIREL-01 to 253. Exact original hosted initiating event remains unknown, recorded in 255 `REPORT.json`, so this is a verified downstream mechanism/fix connection, not proof of the original trigger. |
| 5 | Reliability fix → CI config and real browser coverage | WIRED | Current Playwright config remains `workers: 1`, `retries: 0` at `playwright.config.ts:96-102`; `253-VERIFICATION.md:361` records targeted and integration checks. Historical required-check names/canary findings at `253-VERIFICATION.md:362,382-385`; source boundaries remain historical. |
| 6 | Five browser lane selections → CI owners/aggregate gate | WIRED | `scripts/ci/ci-browser-command.mjs:44-88` defines exact seam/project/spec selections and retries=0; `.github/workflows/ci.yml` invokes it for browser owners and includes their results in the gate; 253 verification traces workflow → browser records/aggregate at `253-VERIFICATION.md:382-383`. |
| 7 | Phase 253 preserved workload/gate → Phase 254 candidate comparison | WIRED | Phase 254 `254-08-SUMMARY.md` says reviewed native-map/receipt digests and comparison contract were retained, and stop occurred before comparison collection. `255-replay/REPORT.json` records the 2,046s baseline and 1,589s candidate observations, but not a valid successful pair. |
| 8 | Phase 254 saved observations → Phase 255 replay inputs | WIRED | `255-replay/REPORT.json:evidence_paths` identifies captured before/after receipts and measurement package; `scripts/ci/ci-comparison-replay.py:162-189` materializes pinned inputs, invokes `ci-run-metrics.sh --evaluate-comparison`, blocks network commands, and checks input hashes unchanged. `255-VERIFICATION.md:214-216` and replay report confirm independent offline retrieval/replay. |
| 9 | Replay calculator result → human and machine report | WIRED | `scripts/ci/ci-comparison-replay.py` generates replay result; `255-replay/REPORT.json` records `insufficient_data`, sample counts/outcomes/limitations; `255-replay/REPORT.md` explains result and links it from `CONTRIBUTING.md:105`. |
| 10 | `mix ci` entry point → seven receiver legs → CI library job | WIRED | `mix.exs:143-170` defines format, locked deps, compile, ordinary tests, scaffold, and dep-off legs; CI invokes `mix ci` via recorder at `ci.yml:613-626`; `CONTRIBUTING.md:11-25` documents parity and `MIX_ENV=test mix ci`. |
| 11 | Native Mix command → identity, output, and seed records | WIRED | `mix.exs` wraps test legs with `scripts/ci/ci-mix-receivers.py`; that invokes `scripts/ci/ci-command-record.py`. Recorder `ci-command-record.py:51-89` captures argv identity, source/runtime/config, and seed; `101-120` runs and retains stdout/stderr. Final actual receivers are listed in `255-replay/REPORT.json` and `255-VERIFICATION.md:218-219`. |
| 12 | Browser selection contract → CI and local reproduction | WIRED | `ci-browser-command.mjs:44-88` is imported by `ci-browser-records.mjs`; workflow invokes shared selectors; `CONTRIBUTING.md:123-133` documents local wrapper and exact diagnostic fixture commands. Historical 255 verification says selection tests passed at `255-VERIFICATION.md:218-220`. |
| 13 | Browser invocation → traces/failure detail → retained diagnostic artifact | WIRED | Workflow sets diagnostic root and invokes browser command (`ci.yml:1562-1603`); Playwright config writes native JSON/failure JSONL and retains failure traces (`playwright.config.ts:55-93,121-126`); upload action referenced at `ci.yml:663-668` and browser owner steps. Final local evidence is source-bound in `255-replay/REPORT.json`; cancellation's absent files remain explicitly absent. |
| 14 | Contributor reproduction docs → actual command/replay helpers | WIRED | `CONTRIBUTING.md:11-25,117-148` has `mix ci`, focused browser, and offline replay commands; `MAINTAINING.md:742-747` links replay verification and artifact handling. 255 report contract tests and local records are cited at `255-VERIFICATION.md:219-220`. |
| 15 | CIMEAS-01/02 producer path → consumer report/rankings | WIRED | workflow timing/cache metadata and 252 collector path above feed the saved baseline and ranked measurement report; 252 historical requirements/links at `252-VERIFICATION.md:173-178,214-215`. Current fingerprint is not established by that historical verifier. |
| 16 | CIREL-01/02 reliability work → required check verdict and diagnostics | WIRED | workflow and helper connect browser results to required aggregation; 253 verification identifies actual failure/missing/skip/cancel canaries and preserved names at `253-VERIFICATION.md:362,382-385`. Current source retains no retries (`playwright.config.ts:96-102`). |
| 17 | CIMEAS-03 / CIDX-01 / CIDX-02 phase outputs → contributor/maintainer consumption | WIRED | Replay report and docs connections in rows 8-14. 255 verification maps these requirements to actual report/native receivers/docs at `255-VERIFICATION.md:250-252`. |

## E2E user flows (7/7 complete as documented)

| Flow | Status | Full path and boundary |
|---|---|---|
| Inspect current CI baseline and ranked costs (CIMEAS-01/02) | WIRED | workflow jobs/checks/cache/timing → artifacts/measurement metadata → collector validation/replay → baseline report/rankings. Historical 252 verifier passed its saved inputs; it does not certify current-source replay. |
| Reproduce and fix selected flaky browser behavior (CIREL-01) | WIRED | measured failure shortlist → controlled component reproduction → source/config repair → scoped tests and repeated project invocations. Original initiating CI event is expressly unknown, and final runs do not retroactively establish it. |
| Confirm required gate stays red for bad/missing/skipped/cancelled work (CIREL-02) | WIRED | five named browser owners → coverage/gate aggregation → verifier/canary outcomes; historical 253 records injected failure, missing seam, skip and cancellation. |
| Run contributor library CI locally (CIDX-01) | WIRED | `MIX_ENV=test mix ci` → seven legs → command receiver captures native status/output/identity; docs name prerequisites and CI-only lanes. |
| Diagnose failed CI/browser invocation (CIDX-02) | WIRED | CI/local wrapper → command identity and streams / Playwright report and failure trace → bounded sanitized bundle and documented retrieval; absent trace on pre-context/runner loss is stated, and cancellation artifact remains incomplete. |
| Replay final comparison and limitations (CIMEAS-03) | WIRED | exact saved package and hashes → pinned offline evaluator → unchanged-input result → REPORT.md/JSON and documented retrieval; actual conclusion remains `insufficient_data`. |
| Meet PR speed and runner-cost targets (CISPEED-01/02) | BROKEN FOR ACCEPTANCE / NOT A SOFTWARE WIRING BREAK | required flow would be approved fixed baseline/candidate PR workloads → matched success pairs → median, p95 wait, runner-cost calculation. Source/evaluator/report links work, but no comparison population exists (0 successful comparable pairs; median/p95 null), and Phase 254 stopped before preparation due baseline PR path mismatch. Therefore target cannot be claimed; no absent software call is identified. |

## API routes and authentication

No product routes, auth UI, or auth protection requirements are in this milestone. API-consumer count: **0 expected / 0 applicable**. Auth-sensitive routes: **0 expected / 0 applicable**. No route is classified orphaned or unprotected for this scope.

## Orphaned exports / broken connections

No expected cross-phase export or consumer call is orphaned in the 17 checked links. No BLOCKER-class missing software connection found. The three requirement IDs omitted from `SUMMARIES.json` completion metadata (CIMEAS-01, CIMEAS-02, CIDX-01) are a reporting metadata omission, not evidence that their paths are disconnected; they remain visible as a source-matrix limitation.

## Requirements integration map

| Requirement | Integration path | Status | Issue |
|---|---|---|---|
| CIMEAS-01 | Workflow run/check records + cache/runtime metadata → Phase 252 collector/replay → separated baseline report | WIRED | Historical verifier passed; not current-source fingerprint proof. Summary metadata lacks this ID. |
| CIMEAS-02 | ExUnit/Playwright timing + job/setup/cache facts → normalizers/collector → ranked report | WIRED | Historical verifier passed; not current-source fingerprint proof. Summary metadata lacks this ID. |
| CIMEAS-03 | Phase 254 saved receipts/package → pinned offline replay → REPORT.json/REPORT.md | WIRED | Replay works; honest result is insufficient_data and speed cannot be derived. |
| CISPEED-01 | Fixed baseline + candidate PR families → successful comparable durations → median | WIRED (measurement route); acceptance OPEN | No successful comparable pairs, zero of required 20; no median. Phase 254 blocked before collecting comparison. |
| CISPEED-02 | Same matched PR families → p95 wait and per-PR runner cost | WIRED (measurement route); acceptance OPEN | No valid family sample; p95 null. Missing acceptance is not broken code wiring. |
| CIREL-01 | Measurements → selected issue → controlled reproduction/fix → no-retry regression checks | WIRED | Original hosted trigger remains unknown; controlled downstream race and fix are evidenced. |
| CIREL-02 | Workflow owner jobs → gate aggregation → failure/missing/skip/cancel verdicts | WIRED | Historical canary and required names recorded; current source keeps browser retries at zero. |
| CIDX-01 | CONTRIBUTING.md commands → shared CI selectors and `mix ci` executor | WIRED | Summary metadata lacks this ID; current `mix.exs`, workflow, and docs agree on entry point. |
| CIDX-02 | CI/local command → identity/output/seed + browser diagnostics → bounded artifact and reproduction docs | WIRED | Missing trace situations and cancellation partial artifact are disclosed explicitly. |

**Requirements with no cross-phase wiring:** none. All nine requirements have a producer-to-consumer path. CISPEED-01/02 have missing acceptance evidence despite wired measurement/reporting components.

## Safe audit actions

Read-only file tracing and line-number extraction only. No tests or application checks were run; no prohibited network, GitHub, CI, DB, browser, or native acceptance actions were performed. `INTEGRATION.json` contains the machine-readable statuses, denominators, requirement mapping, and limitations.
