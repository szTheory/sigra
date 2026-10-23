---
phase: 252-measure-current-ci
verified: 2026-10-13T01:16:02Z
status: passed
score: 27/27 must-haves verified
covered_files:
  - ".github/workflows/ci.yml"
  - ".planning/phases/252-measure-current-ci/252-01-PLAN.md"
  - ".planning/phases/252-measure-current-ci/252-01-SUMMARY.md"
  - ".planning/phases/252-measure-current-ci/252-02-PLAN.md"
  - ".planning/phases/252-measure-current-ci/252-02-SUMMARY.md"
  - ".planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json"
  - ".planning/phases/252-measure-current-ci/252-03-PLAN.md"
  - ".planning/phases/252-measure-current-ci/252-03-SUMMARY.md"
  - ".planning/phases/252-measure-current-ci/252-04-PLAN.md"
  - ".planning/phases/252-measure-current-ci/252-04-SUMMARY.md"
  - ".planning/phases/252-measure-current-ci/252-05-INTEGRATION-RECHECK.json"
  - ".planning/phases/252-measure-current-ci/252-05-MIX-CI-DIAGNOSTIC.json"
  - ".planning/phases/252-measure-current-ci/252-05-PLAN.md"
  - ".planning/phases/252-measure-current-ci/252-05-STATE-PRESERVATION.json"
  - ".planning/phases/252-measure-current-ci/252-05-SUMMARY.md"
  - ".planning/phases/252-measure-current-ci/252-06-ACQUISITION-ATTEMPTS.json"
  - ".planning/phases/252-measure-current-ci/252-06-PLAN.md"
  - ".planning/phases/252-measure-current-ci/252-06-REPAIR-PRESERVATION.json"
  - ".planning/phases/252-measure-current-ci/252-06-SECURITY-REFRESH-PRESERVATION-72c71eb.json"
  - ".planning/phases/252-measure-current-ci/252-06-SECURITY-REFRESH-PRESERVATION.json"
  - ".planning/phases/252-measure-current-ci/252-06-STATE-PRESERVATION.json"
  - ".planning/phases/252-measure-current-ci/252-06-SUMMARY.md"
  - ".planning/phases/252-measure-current-ci/252-BASELINE.json"
  - ".planning/phases/252-measure-current-ci/252-BASELINE.md"
  - ".planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz"
  - ".planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json"
  - ".planning/phases/252-measure-current-ci/252-CONTEXT.md"
  - ".planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT-active-rulesets.json"
  - ".planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT-branch-protection.json"
  - ".planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT-effective-rules.json"
  - ".planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT-request-ledger.json"
  - ".planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT.json"
  - ".planning/phases/252-measure-current-ci/252-EXECUTION-RECORD.json"
  - ".planning/phases/252-measure-current-ci/252-PATTERNS.md"
  - ".planning/phases/252-measure-current-ci/252-RESEARCH.md"
  - ".planning/phases/252-measure-current-ci/252-REVIEW-DISPOSITION.md"
  - ".planning/phases/252-measure-current-ci/252-REVIEW-FINAL-RECHECK.md"
  - ".planning/phases/252-measure-current-ci/252-REVIEW-RECHECK.md"
  - ".planning/phases/252-measure-current-ci/252-REVIEW-REPAIR-FAMILY.json"
  - ".planning/phases/252-measure-current-ci/252-REVIEW-REPAIR.json"
  - ".planning/phases/252-measure-current-ci/252-REVIEW-SCOPE.json"
  - ".planning/phases/252-measure-current-ci/252-REVIEW.md"
  - ".planning/phases/252-measure-current-ci/252-SECURITY-AUDIT.json"
  - ".planning/phases/252-measure-current-ci/252-SECURITY.md"
  - ".planning/phases/252-measure-current-ci/252-UI-APPLICABILITY.json"
  - ".planning/phases/252-measure-current-ci/252-VALIDATION-AUDIT.json"
  - ".planning/phases/252-measure-current-ci/252-VALIDATION.md"
  - ".planning/phases/252-measure-current-ci/acquisition-attempts/producer-source-run-38317383419.json"
  - "scripts/ci/ci-exunit-timing.test.sh"
  - "scripts/ci/ci-measure-report.sh"
  - "scripts/ci/ci-measure-report.test.sh"
  - "scripts/ci/ci-measure-workflow.test.mjs"
  - "scripts/ci/ci-metrics-security.test.py"
  - "scripts/ci/ci-playwright-report.mjs"
  - "scripts/ci/ci-playwright-report.test.mjs"
  - "scripts/ci/ci-run-metrics-comparison.test.sh"
  - "scripts/ci/ci-run-metrics-replay.test.mjs"
  - "scripts/ci/ci-run-metrics.sh"
  - "scripts/ci/ci-run-metrics.test.sh"
  - "scripts/ci/ci_metrics_security.py"
  - "scripts/ci/exunit_timing_contract.py"
  - "scripts/ci/exunit_timing_contract_test.py"
  - "scripts/ci/sigra-dep-off.sh"
  - "scripts/ci/test-sigra-dep-off.sh"
  - "test/example/priv/playwright/playwright.config.ts"
  - "test/sigra/planning/ci_timing_formatter_test.exs"
  - "test/support/ci_timing_formatter.ex"
  - "test/test_helper.exs"
covered_digest: "v3:sha256:a32e94548013a6ba9d99ec31aa415ae55ad7d7a97a651aad671099d174820ad9"
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 21
  total: 21
  not_honored: []
---

# Phase 252: Measure Current CI — Verification Report

**Phase Goal:** Contributors and maintainers can identify today's CI waiting time, failure patterns, and largest runtime costs before choosing fixes.
**Verified:** 2026-10-13T01:16:02Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The codebase contains a working collection and offline replay path, a source-hashed current baseline and report, and a frozen comparison contract. I verified the report against the saved archive and ran the focused local tests; SUMMARY claims were not used as proof.

### Roadmap Success Criteria

| # | Observable truth | Status | Evidence |
|---|---|---|---|
| 1 | The report separates pull-request, main-push, and nightly runs and presents waiting, execution, literal outcomes, reruns, and their saved sources. | VERIFIED | [252-BASELINE.md](252-BASELINE.md) reports 100 PR, 81 main, 30 nightly runs, literal outcome counts, source-linked wait/cost rows and attempt history. The source archive hash is `95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30`; `--verify-baseline` confirms it matches the baseline. |
| 2 | Ranked job, step, and test measurements expose the largest costs and a bounded, evidence-linked failure shortlist. | VERIFIED | Baseline ranks wait and runner cost separately, reports stage costs, ExUnit and Playwright results, and one recurring signature backed by two retained PR failure logs. It classifies additional test, infrastructure, cancellation, and missing-job outcomes separately. |
| 3 | A contributor can reproduce the baseline and rankings from saved inputs; timeout constants and historical estimates are not presented as measurements. | VERIFIED | Two independent offline replays were byte-identical at SHA-256 `0e047cb23f8c33e4aa41cb03da7fc6043f46047ed49e26842f80d58b4501643a`. Baseline validation returned `ready` with no diagnostics. The report identifies measured values, unknowns, and source links. |
| 4 | The later comparison contract fixes workload and source identities, cache conditions, runner class, sample size, percentile method, and acquisition limits before optimization. | VERIFIED | [252-COMPARISON-CONTRACT.json](252-COMPARISON-CONTRACT.json) fixes 20 pairs/40 families, a 48-hour window, runner class, baseline revisions, observed cache stratum, nearest-rank p95, and 600-request/60-minute/250-core acquisition bounds. Candidate identity and exact window dates are intentionally to be set before any comparison run; this phase makes no claim that 40 comparison families have run. |

### Plan Must-Haves

All 27 distinct plan truths were verified. The plans express `artifacts` and `key_links` as scalar strings, so the GSD artifact/link query returned zero structured entries; I manually checked each declared file and traced each listed connection below.

| Plan truth | Status | Evidence |
|---|---|---|
| 01.1 Offline family replay preserves required wait and summed job cost without GitHub access. | VERIFIED | Collector Tests P and V; two archive replay outputs match. |
| 01.2 Current effective required contexts are compared to the five approved names; changes remain diagnostic. | VERIFIED | Tests O and Q; final rules snapshot and source archive contain the five approved names; altered rules produce unknown. |
| 01.3 Every live read obeys request/time/core/retry bounds and interruption logging. | VERIFIED | Tests O2 and W cover request 600/601, 60 minutes, core 250, retry, rate stop, lock and incomplete ledger. |
| 01.4 Missing hosted inputs remain unknown and cannot pass baseline validation. | VERIFIED | Test O2 exercises a blocked preflight; test Q and the archive-backed validator preserve unknown states and reject incomplete evidence. |
| 01.5 Run, attempt, job, and context identities stay distinct; incomplete requirements remain unknown. | VERIFIED | Tests P2, Q, R, S, and T cover conflicting identities, missing timestamps, reruns, revisions, and literal conclusions. |
| 01.6 Equal-duration job and attempt records remain separate. | VERIFIED | Test P keeps two equal-duration jobs and reports 300 summed seconds. |
| 02.1 Frozen UTC cutoff selects separate PR/main/nightly populations, at most 100 per event over 30 days. | VERIFIED | Test U; retained source population counts are 100/81/30 and the cutoff is `2026-10-12T22:41:22Z`. |
| 02.2 Attempts and literal outcomes survive selection; workload labels are source-backed or unknown. | VERIFIED | Tests T and U plus the replay preserve literal conclusions; report states missing changed-file detail as unknown. |
| 02.3 Interrupted collection preserves its ledger and exclusive snapshot lock. | VERIFIED | Test W verifies interruption status, saved request/selection data, and that a concurrent collector cannot mutate the snapshot. |
| 02.4 Offline replay makes no network request. | VERIFIED | Test V uses a replay with GitHub unavailable and passes; the collector test suite confirms offline bundle replay. |
| 03.1 Opt-in ExUnit timing emits test identity, result, microseconds, totals, and normal CLI output. | VERIFIED | `ci-exunit-timing.test.sh` and the focused ExUnit formatter contract passed; output remained opt-in and complete. |
| 03.2 Formatter/report write failure cannot turn a failing test run green. | VERIFIED | ExUnit timing shell contract passed for deliberate failures and unavailable output paths; the separate 8-test contract suite passed. |
| 03.3 Shared startup and compilation are separate from summed test duration. | VERIFIED | ExUnit contract tests passed; current report separates suite elapsed from summed test duration. |
| 04.1 Native Playwright JSON is added without changing serial one-worker, zero-retry browser selections. | VERIFIED | Playwright tests (8) and workflow tests (4) passed; current config retains one worker, serial execution, and zero retries. |
| 04.2 Normalization preserves project, seam, identity, retry, and duration; partial reports are unknown. | VERIFIED | Playwright tests (8) passed, including malformed, empty, truncated, duplicate, and invalid-duration inputs. |
| 04.3 Skips and shared app/fixture startup remain separate from summed test durations. | VERIFIED | Normalizer and report tests passed; baseline exposes suite/test and startup stages separately. |
| 04.4 Playwright overhead is measured or explicitly unmeasured, never treated as zero. | VERIFIED | Baseline and contract both state per-seam overhead is unmeasured because paired selections were not recorded; report shows null with the reason. |
| 05.1 The single library `mix ci` owner and five browser seams emit timing artifacts while retaining original exits. | VERIFIED | Workflow contract tests (4) passed, checking `mix ci`, exact browser selections, artifact uploads, and invocation separation. |
| 05.2 Actual runtime version output is distinct from configured pins, or null with a reason. | VERIFIED | Workflow tests passed; report shows observed PR runtime versions separately from pins and explicitly reports missing main/nightly artifact versions. |
| 05.3 Wait rankings are separate from runner rankings and include measured setup/cache/compile/database/app/test stages. | VERIFIED | Collector V2 tests passed; current baseline has separate rankings and reports setup, cache, compilation, database, app boot, and tests. |
| 05.4 Failure diagnostics preserve literal failures/cancellations/skips and avoid calling one red run a flake. | VERIFIED | Collector T/V3 tests passed; current report links its sole recurring signature to two runs and lists other failure classes separately. |
| 05.5 Distinct job/test/attempt identities and deterministic tie order survive replay. | VERIFIED | Collector ranking tests and Playwright normalization tests passed with equal-cost identities preserved. |
| 06.1 Fresh snapshot, report, and source-bound costs cover PR/main/nightly populations. | VERIFIED | Archive-backed baseline validation returned `ready`; report test passed; archive and baseline digests match. |
| 06.2 Missing eligible costs remain unknown; one observation is explicitly `n=1`. | VERIFIED | Replay contract test passed; report identifies the selected full-PR measurement as one observation with a single-observation limitation. |
| 06.3 Repeated replay produces identical rankings and comparison arithmetic. | VERIFIED | Two replay outputs matched exactly at SHA-256 `0e047cb23f8c33e4aa41cb03da7fc6043f46047ed49e26842f80d58b4501643a`; comparison tests passed. |
| 06.4 Both timing paths disclose overhead; measured rows carry producer runtime evidence or null. | VERIFIED | Current baseline/report disclose ExUnit overhead and unmeasured Playwright overhead; producing job runtime versions are source-linked or explicitly unknown. |
| 06.5 Later contract fixes 20 pairs/40 families, 48 hours, and measured cache allocation without running comparison families. | VERIFIED | Comparison contract tests passed; contract records one measured warm-cache stratum allocated across 20 pairs and no comparison runs. Candidate identity/dates remain deferred by design. |

**Score:** 27/27 plan truths verified; all four roadmap success criteria are also verified.

### Required Artifacts

Each declared artifact exists, contains substantive implementation or evidence, and is connected to the collector, workflow, report, or a documented acquisition. Common artifacts shared by several plans are listed once.

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `scripts/ci/ci-run-metrics.sh` | Guarded collection, source validation, replay, ranking, and baseline verification | VERIFIED | 1,900+ lines of functional shell/Python CLI logic; collector tests exercise live-call guards and offline paths. |
| `scripts/ci/ci-run-metrics.test.sh` | Hermetic source and replay contracts | VERIFIED | 47 tests pass, including embedded comparison suite. |
| `.planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT.json` | Captured source preflight and bounded request record | VERIFIED | Present and paired with effective-rules, branch-protection, and request-ledger inputs. |
| `test/support/ci_timing_formatter.ex` | Opt-in ExUnit event formatter | VERIFIED | Connected through `test/test_helper.exs`, exercised by focused contract tests and producing artifacts. |
| `test/sigra/planning/ci_timing_formatter_test.exs` | Formatter behavior tests | VERIFIED | Focused suite and timing shell contract pass. |
| `scripts/ci/ci-exunit-timing.test.sh` | Timing/output/exit preservation contract | VERIFIED | Passed; records local five-pair overhead evidence to stdout without replacing the archived baseline. |
| `test/example/priv/playwright/playwright.config.ts` | Native JSON reporter with existing scheduling | VERIFIED | Connected to the report normalizer and workflow selections; 8 normalizer tests pass. |
| `scripts/ci/ci-playwright-report.mjs` | Validate and normalize Playwright JSON | VERIFIED | CLI and transform have explicit incomplete/error handling and stable identity ordering. |
| `scripts/ci/ci-playwright-report.test.mjs` | Normalizer and failure-path tests | VERIFIED | 8 tests pass. |
| `.github/workflows/ci.yml` | Instrumented library/browser jobs and uploads | VERIFIED | Existing `mix ci` owner and five browser seams retained; workflow contract tests pass. |
| `scripts/ci/ci-measure-workflow.test.mjs` | CI wiring contract | VERIFIED | 4 tests pass. |
| `scripts/ci/ci_metrics_security.py` and `scripts/ci/ci-metrics-security.test.py` | Identity, archive, and comparison security checks | VERIFIED | Used by collector validation; all 20 registered security threats are closed with zero accepted risks. |
| `scripts/ci/exunit_timing_contract.py` and `scripts/ci/exunit_timing_contract_test.py` | ExUnit report validation | VERIFIED | Called by measurement validation; 8 focused tests pass. |
| `scripts/ci/sigra-dep-off.sh` and `scripts/ci/test-sigra-dep-off.sh` | Separate dependency-off invocation and evidence | VERIFIED | Source-bound to a separate timing output; no result is merged into the main run. |
| `scripts/ci/ci-measure-report.sh` | Render the baseline and contract as a contributor report | VERIFIED | Reads the checked-in baseline and contract, rejects a digest mismatch, and renders ranks, sources, unknowns, and commands. |
| `scripts/ci/ci-measure-report.test.sh` | Report content, safety, and determinism contract | VERIFIED | Passed. |
| `.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz` | Immutable source bundle for the baseline | VERIFIED | SHA-256 `95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30`; replay validates its contents. |
| `.planning/phases/252-measure-current-ci/252-BASELINE.json` | Machine-readable source-derived measurements | VERIFIED | Archive-backed validation returns ready with no diagnostics. |
| `.planning/phases/252-measure-current-ci/252-BASELINE.md` | Ranked current report | VERIFIED | Generated report contains population outcomes, waits, runner and test costs, source links, limitations, and commands. |
| `.planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json` | Fixed later comparison method | VERIFIED | Hash-bound to the actual baseline archive; comparison arithmetic is tested. |

**Scope cross-check:** `252-REVIEW-SCOPE.json` names 21 changed source/test paths; all 21 exist and are included in the fingerprint. No other phase source path is omitted from that review scope.

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Effective rules, run/check responses | Collector replay | Guarded GET → raw source bundle → hash-checked identity and endpoint calculation | WIRED | Tests O, P, P2, and Q verify changed rules, source hashes, required check/job identity and actual family replay. |
| Fixed cutoff | Three run populations | Explicit GET pagination → selected IDs/attempts/jobs → snapshot ledger | WIRED | Test U verifies cutoff, 100-run cap, API totals, separate events, and capped/exhausted states. |
| ExUnit opt-in variable | Formatter events | `test_helper.exs` → formatter → complete JSON → producing job artifact | WIRED | Focused ExUnit test and workflow contract pass; saved archive includes producer artifact evidence. |
| Playwright selections | Normalized timing rows | Native JSON → `ci-playwright-report.mjs` → source-bound collector | WIRED | Playwright and workflow tests pass; archived reports identify the five seams and producer jobs. |
| Workflow job timing | Cost/failure rankings | Artifact owner/run/SHA checks → offline replay rows → separate rankings | WIRED | Collector and security fixtures reject forged identity and preserve actual source references. |
| Hosted source bundle | Baseline/report/contract | Replay → validated baseline JSON → report renderer and comparison contract | WIRED | `--verify-baseline` returns ready; report test passes; repeated replay hash is stable. |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real source data | Status |
|---|---|---|---|---|
| Source bundle → replay | Run, attempts, jobs, checks, steps, artifacts, literal outcomes | Retained API responses and producer artifact archives, each checked against manifest hashes | Yes | FLOWING |
| Replay → baseline JSON | Waits, job/step/test costs, cohorts, failure classes and rankings | Collector calculation over the checked-in bundle | Yes | FLOWING |
| Baseline JSON + comparison contract → report | Ranked costs, sample limits, unknowns and replay commands | Checked-in baseline and contract; report renderer validates matching bundle digest | Yes | FLOWING |
| ExUnit timing rows | Test result and duration | Opt-in ExUnit formatter events from the producing job | Yes | FLOWING |
| Playwright timing rows | Test, project, seam, retry, result and duration | Built-in Playwright JSON reports from producing jobs | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Collector identities, bounds, interruptions, unknowns, outcomes, replay, and rankings | `PYTHONDONTWRITEBYTECODE=1 bash scripts/ci/ci-run-metrics.test.sh` | 47 passed; comparison-contract suite passed | PASS |
| Baseline archive and required contexts are complete and source-matched | `PYTHONDONTWRITEBYTECODE=1 bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` | `ready`, no diagnostics | PASS |
| Saved source can be replayed without network and produces stable arithmetic | `bash scripts/ci/ci-run-metrics.sh --replay --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --format json` (run twice) | Both outputs SHA-256 `0e047cb23f8c33e4aa41cb03da7fc6043f46047ed49e26842f80d58b4501643a` | PASS |
| Ranked contributor report validates and renders deterministically | `PYTHONDONTWRITEBYTECODE=1 bash scripts/ci/ci-measure-report.test.sh` | PASS | PASS |
| ExUnit timing and original test exit status | `PYTHONDONTWRITEBYTECODE=1 bash scripts/ci/ci-exunit-timing.test.sh` | PASS; five paired focused timing samples and failure/write-error probes completed | PASS |
| Playwright JSON normalization and failure handling | `node scripts/ci/ci-playwright-report.test.mjs` | 8 passed | PASS |
| CI job and artifact wiring | `node scripts/ci/ci-measure-workflow.test.mjs` | 4 passed | PASS |
| ExUnit report schema and validation | `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/exunit_timing_contract_test.py` | 8 passed | PASS |
| Offline replay unknowns and cost dimensions | `node scripts/ci/ci-run-metrics-replay.test.mjs` | 1 passed | PASS |

No Phase 252-declared or conventional `scripts/*/tests/probe-*.sh` probe was found. The full `mix ci` suite was not repeated: the final source repair only changed the collector, its 47-test suite and the archived baseline verification passed, and the phase validation/audit records 15/15 task checks green.

### Probe Execution

No probe scripts were declared by the plans or summaries, and none were found under `scripts/`.

### Requirements Coverage

| Requirement | Source plan | Description | Status | Evidence |
|---|---|---|---|---|
| CIMEAS-01 | Plans 01, 02, 05, 06 | Current PR, main, and nightly baseline with waits, execution, literal outcomes, reruns, and saved source data | SATISFIED | Current source bundle, separate population counts/rankings, replay tests, and ready baseline validator. |
| CIMEAS-02 | Plans 01, 03, 04, 05, 06 | Ranked measured job/step/test costs, including setup/cache work | SATISFIED | Source-backed costs and rankings, ExUnit/Playwright contract tests, report test, and saved producing-run data. |

CIMEAS-03 is assigned to Phase 255 in REQUIREMENTS.md and is not an orphan for Phase 252.

### Test Quality Audit

| Test file | Linked requirement | Active | Disabled | Circular | Assertion strength | Verdict |
|---|---|---:|---:|---:|---|---|
| `scripts/ci/ci-run-metrics.test.sh` | CIMEAS-01, CIMEAS-02 | 47 | 0 | 0 | Value and behavior | PASS |
| `test/sigra/planning/ci_timing_formatter_test.exs`, `scripts/ci/ci-exunit-timing.test.sh` | CIMEAS-02 | Active contracts | 0 | 0 | Behavior and failure-path | PASS |
| `scripts/ci/ci-playwright-report.test.mjs` | CIMEAS-02 | 8 | 0 | 0 | Value and behavior | PASS |
| `scripts/ci/ci-measure-workflow.test.mjs` | CIMEAS-01, CIMEAS-02 | 4 | 0 | 0 | Structural and wiring | PASS |
| `scripts/ci/exunit_timing_contract_test.py`, `scripts/ci/ci-measure-report.test.sh` | CIMEAS-02 | 8 plus report contract | 0 | 0 | Value and failure-path | PASS |

Disabled-test scan found no skipped requirement tests. Fixture expected values are authored as independent source/contract cases; no test generates its expected result by running the code under test. No insufficient assertion blocker was found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `.github/workflows/ci.yml` | 2067 | Tracked `TODO` text for sibling-lane drift handling | INFO | Outside the Phase 252 measurement/report paths; no `TBD`, `FIXME`, or `XXX` debt marker and no impact on CIMEAS-01/02. |

The code review's original changed-rules and failed-download findings are fixed. The independent final recheck validates the changed paths and its two review findings; current HEAD adds documentation only after the reviewed collector implementation. Security audit is `SECURED` with 20/20 threats closed and zero accepted risks. Validation audit is `validated`, 15/15 task checks green. UI audit is correctly marked not applicable because this phase adds no user-facing UI.

The acquisition ledger preserves earlier incomplete and failed-download attempts as such. The accepted source bundle was subsequently refreshed after source-binding/security repairs; the preservation record at `72c71eb` records the prior bundle hash `e0e662a8e546c95386651a33407341b23046524d50083eb740d1b2689e37640a`, while the current bundle hash is `95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30`. I validated the current bundle against the baseline; the older attempt statuses remain historical evidence, not the status of the current archive.

### Decision Coverage

All trackable CONTEXT.md decisions are honored by shipped artifacts. (21/21; no unhonored decisions.)

### Human Verification Required

N/A — infrastructure and CI measurement phase. The source archive, calculations, report contents, and instrumentation contracts are covered by deterministic local tests; there is no UI or live user flow requiring manual UAT.

### Known Limits, Not Goal Gaps

- The selected instrumented full-PR run is one observation (`n=1`); the report labels this limitation. It is a current baseline, not a population estimate.
- Some historical PR workload labels and main/nightly runtime-version artifacts are unknown because saved changed-path or artifact evidence was unavailable. The report preserves those as unknown rather than assigning a class or version.
- Pure runner queue time and dependency-graph gaps are unknown because the saved API evidence does not expose them. Playwright reporter overhead is unmeasured because paired same-selection runs were not captured.
- The later candidate identity and actual 48-hour dates are deliberately unset until before comparison starts. The contract fixes the method and no comparison families are claimed or dispatched here.

These limits are stated in the report and do not turn missing observations into zero-cost results or false success.

### Gaps Summary

No required truth failed. The current report exposes source-backed waiting time, failure patterns, and largest measured runtime costs; its evidence can be replayed from the saved archive. CIMEAS-01 and CIMEAS-02 are satisfied. The later comparison remains scheduled for its own phase under the frozen contract.

---

_Verified: 2026-10-13T01:16:02Z_  
_Verifier: the agent (gsd-verifier)_
