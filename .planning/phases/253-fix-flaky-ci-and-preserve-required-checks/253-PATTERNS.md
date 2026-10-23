# Phase 253: Fix Flaky CI and Preserve Required Checks - Pattern Map

**Mapped:** 2026-10-12  
**Files analyzed:** 17 existing or likely new/modified paths  
**Analogs found:** 15 / 17

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/ci/ci-run-metrics.sh` | utility / CLI | request-response, file-I/O | same file: `replay_family`, `validate_artifact_metadata`, bounded API helpers | exact |
| `scripts/ci/ci_metrics_security.py` | utility | transform | `sanitize_failure_log` in same file | exact |
| `scripts/ci/ci-run-metrics.test.sh` | test | transform / file-I/O | same hermetic fake-`gh` test | exact |
| `scripts/ci/honest-skip-verdict.sh` | utility / gate | transform | same verdict script, `LANES` and input validation | exact |
| `scripts/ci/honest-skip-verdict.test.sh` | test | transform | same hermetic verdict test | exact |
| `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` | test | transform | same manifest/workflow contract test | exact |
| `scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs` | test | transform | same manifest/docs parity test | exact |
| `.github/workflows/ci.yml` | config / workflow | event-driven | existing browser matrix, aggregate and `ci-gate` jobs | exact |
| `.github/ci-skip-manifest.tsv` | config / data | transform | current manifest rows checked by p10/p21 | exact |
| `MAINTAINING.md` | documentation | transform | active skip inventory checked by p21 | exact |
| `scripts/ci/<new-browser-record-validator>.mjs` (path TBD) | utility / validator | transform / file-I/O | `scripts/ci/ci-playwright-report.mjs` | role-match |
| `scripts/ci/<new-browser-record-validator>.test.mjs` (path TBD) | test | transform | p10/p21 Node `node:test` contracts | role-match |
| hosted evidence verifier (path TBD) | utility / verifier | request-response / file-I/O | `scripts/ci/ci-run-metrics.sh` artifact metadata validation | partial |
| `test/example/priv/playwright/tests/admin-eval.spec.ts` | test / browser flow | request-response | existing `registerUser` flow in same spec | exact |
| `test/example/priv/playwright/helpers/adminFlows.ts` | hook / utility | request-response | `waitForLiveViewReady` in same helper | exact |
| `test/example/priv/playwright/playwright.config.ts` | config | event-driven | same global serial/zero-retry config | exact |
| readiness/state control specs (paths TBD) | test | request-response | `admin-eval.spec.ts` registration and diagnostics | role-match |

The phase documents do not settle names for the new record validator, its test, or the hosted verifier. Keep those as small standard-library helpers under `scripts/ci`; do not create package dependencies. Registration remains an investigation lead. Choose a test change only after a reproduced condition identifies its seam.

## Pattern Assignments

### Metrics diagnosis, collection, replay and sanitizing

**Targets:** `scripts/ci/ci-run-metrics.sh`, `scripts/ci/ci_metrics_security.py`, `scripts/ci/ci-run-metrics.test.sh`  
**Analogs:** those tracked source files themselves. Their line ranges below are the established pattern to extend.

The metrics shell entrypoint uses `set -euo pipefail`, resolves repository root from `BASH_SOURCE`, stores mode flags as explicit variables and has dedicated validation modes before entering live collection (`ci-run-metrics.sh:47-99,1947-1961`). Relevant functions include `validate_artifact_metadata()` (`:196`), `redact_log_file()` (`:262`), `api_download_no_follow()` (`:335`), `api_get()` (`:426`), and `replay_family()` (`:1183`). Keep the legacy replay verifier's complete-object comparison (`:1743-1780`, verified in research) untouched; expose a separate versioned diagnosis output/command instead of adding diagnosis keys to the legacy object.

Existing provenance acquisition validates numeric run and attempt identity, stores each attempt's jobs response with SHA-256 and endpoint metadata, and records unavailable or over-budget inputs as unknown (`ci-run-metrics.sh:665-692`). Artifact intake checks run id, source SHA, digest format and the downloaded archive digest before extraction (`:727-755`). This is the closest pattern for a diagnosis companion bound to archive/report hashes, analyzer source, producer job/step, outcome and missing-input status. Preserve independent per-producer completeness; do not promote an unavailable or truncated log to a no-flake result.

Current failure-log acquisition selects only the first failed/timed-out job and redacts the downloaded whole log before writing `failed-job.log` (`ci-run-metrics.sh:756-770`). Phase 253 needs selection of relevant failed steps/context before the excerpt cap. Keep the existing sanitized-write boundary, but bind excerpts to original hashes and line ranges and expose clipping/completeness. The sanitizer already removes environment dumps, token/Bearer patterns and URLs, caps output, and returns `truncated`, `input_bytes`, and `output_bytes` (`ci_metrics_security.py:405-435`). Extend this primitive only after extracting context; do not weaken its redaction/cap behavior.

**Test pattern:** `ci-run-metrics.test.sh:1-38,106-150` uses a temporary directory and a recording `gh` stub on a prepended `PATH`, scripted responses and assertions on both status and output. Its established commands are:

```bash
bash scripts/ci/ci-run-metrics.test.sh
bash scripts/ci/ci-run-metrics.sh --verify-baseline <baseline.json> --source-bundle <phase252-bundle>
```

Extend tests for a late failure after a passing banner, intentional `FAIL:` output, multiple failed producers/steps, hashes changing, partial/missing jobs, and truncation. The live replay invocation must continue to compare the original full replay object. No hosted API call belongs in the offline test.

### Honest gate verdict ownership

**Targets:** `scripts/ci/honest-skip-verdict.sh`, `scripts/ci/honest-skip-verdict.test.sh`, `.github/workflows/ci.yml` (`ci-gate`, `example_unit_smoke`).  
**Analog:** current `LANES` set and test harness.

`honest-skip-verdict.sh:101-112` owns one fixed lane list; `extract_ci_gate_needs()` reads the workflow dependency list (`:114-125`). The existing verdict normalizes docs-only only for pull requests and documents the missing `example_unit_smoke` ownership as advisory (`:215-227`). Phase 253 should move that lane into fixed `LANES`, dependency extraction/result ownership and the workflow `needs` list together; retain failure/cancellation as non-green and keep `changes` as the input-provider exclusion.

The workflow currently defines the independently required unit lane as `example_unit_smoke` (`ci.yml:762-775`), while internal `ci-gate.needs` omits it (`:1780-1791`). The already-run pattern is an always-executed gate with an explicit `needs` list, checkout of the manifest/workflow and the verdict step before legacy lane checks (`:1775-1808`). Keep required check names and native job outcomes unchanged.

`honest-skip-verdict.test.sh:1-51,87-115` is hermetic, writes a JSON lane map under `mktemp`, captures output and exit status in separate helpers, and checks missing/failed/cancelled lanes plus static workflow wiring. Run:

```bash
bash scripts/ci/honest-skip-verdict.test.sh
```

Add the unit lane to the all-success fixture and negative fixtures for omitted `needs`, skipped, failure and cancelled results. Preserve the test's explicit non-vacuity and wiring checks.

### Browser producer records and native report validation

**Targets:** `.github/workflows/ci.yml`, new standard-library validator and its test.  
**Analogs:** workflow matrix/aggregate and `scripts/ci/ci-playwright-report.mjs`.

The five matrix entries define distinct seams, databases, ports, URLs, and browser selection (`ci.yml:1376-1425`). Each body already writes native JSON using `SIGRA_PLAYWRIGHT_JSON` and explicit project/spec selections, with zero retries (examples `:1445-1553`). The matrix has `fail-fast: false`; preserve it. The `example_playwright_smoke` aggregate currently checks native shard job result and logs a docs-only message when the classifier says true (`:1606-1632`). Its job-level condition is `always()`, so docs-only eligibility belongs on selected body steps, never on the aggregate.

Artifact uploads already use pinned `actions/upload-artifact` and unique run/attempt names for measurement metadata (`ci.yml:1598-1604`). Follow that convention with a per-seam record artifact whose name includes seam, run id and attempt; require the report/record files, use `if-no-files-found: error`, and download each producer to its own directory. Matrix outputs are not an appropriate shared channel. Native failed job results remain authoritative.

`ci-playwright-report.mjs:32-57,63-84,87-99` is the closest validator design: explicit `schema_version`, named identity, required shape checks, stable incomplete reasons, and rejection of duplicate/invalid project identity. `normalizeReport(report, identity)` is exported and pure (`:64`); its CLI validates unique required flags, handles malformed or unavailable JSON as incomplete, writes atomically, then exits nonzero (`:245-302`). Reuse these conventions for a compact record/report validator: exact five-seam set; seam/run/attempt/event/source; selected step IDs; pre/post `continue-on-error` outcomes; full-body status; native report presence and expected selected projects/tests. Only an actual PR with successful classification and exactly `true` may exempt documented body skips. Missing, duplicate, malformed, wrong-identity, cancelled or unexpectedly skipped records must fail validation.

The reporter tool's current unit test is not named in the phase docs; discover it from its `node --test` invocation when planning. The new contract test should use Node built-ins and fixtures, checking expected failing directions including missing, duplicate, unknown seam, wrong source/run/attempt, skip, incomplete/empty report and malformed JSON. No dependency is needed.

### Skip parity and documentation

**Targets:** `.github/ci-skip-manifest.tsv`, p10/p21 tests and `MAINTAINING.md`.  
**Analogs:** `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` and `p21-honest-skip-parity.test.mjs`.

p10 parses manifest rows, strips YAML comments, resolves job/step ids and compares declared conditions (`p10:23-49,51-87,118-175`). It includes minimum row/tier floors so a parser that matches nothing cannot pass. Add coverage for the exact current mismatch: manifest's docs-only condition names the terminal `example_playwright_smoke` aggregate although actual docs-only skips are on selected browser body steps. Keep populated-inventory guards; correct the row and test both the manifest-to-workflow direction and missing/stale entry direction.

p21 reads the manifest plus delimited active-id inventory in `MAINTAINING.md`, checks non-vacuity and exact set parity, and explicitly delegates structural checks to p10 rather than duplicating parsers (`p21:1-29,33-74,80-114`). Follow that ownership boundary when documenting the actual selected-body skip rules. Run:

```bash
node --test scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs
```

### Registration readiness, isolation and trace controls

**Targets:** `admin-eval.spec.ts`, `adminFlows.ts`, `playwright.config.ts`, and any new narrowly scoped signal-control specs.  
**Analogs:** current registration flow and LiveView helper.

`registerUser(page, email, password)` waits for `domcontentloaded`, then the actual connected LiveView marker before filling and submitting; it listens for request, request failure and response on `/users/log_in`, and captures response status/redirect (`admin-eval.spec.ts:153-197`). Its failure branch gathers page state and diagnostics (`:198+`). The surrounding `beforeEach` uses that registration helper and again waits for LiveView connection after navigating to `/admin/_design` (`:410-418`). This gives diagnostic wiring and server-confirmed result patterns; it does not establish the recurring failure's cause.

`waitForLiveViewReady(page: Page): Promise<void>` waits on `[data-phx-session].phx-connected` and documents that the controller login route must not use it (`adminFlows.ts:37-48`). Keep role/label selectors and concrete signals. For test controls, prefer explicitly signaled delayed/missing readiness and a broken-wait negative control over sleeps. Preserve the distinction between controller and LiveView routes.

The Playwright config sets `fullyParallel: false`, `workers: 1`, `retries: 0`, and global `trace: 'on-first-retry'` (`playwright.config.ts:61-68,85-97`). Since retries remain zero, request `--trace=retain-on-failure` only on frozen diagnostic/repeat invocations, with trace capture beginning before navigation/submission. Verify failure trace retention and passing trace cleanup. The closest static guard is `p17-no-playwright-retry-wrapper.test.mjs:63-101`, which checks config and every spec for retries, `waitForTimeout` and `test.slow`; do not weaken it.

Relevant commands to plan from the repository's ordinary owners:

```bash
MIX_ENV=test mix ci
npx playwright test <frozen-selected-spec-and-projects> --retries=0 --trace=retain-on-failure
```

The Playwright command is a scoped invocation template, not a proven reproduction. Freeze selected source/spec/project/order and use the lockfile-pinned Playwright 1.59.1 before evidence collection. Browser runs use their real `MIX_ENV=dev` app/database; Sandbox ownership examples at `test/example/test/support/data_case.ex:30-41` apply to ExUnit only. Do not label browser state Sandbox-isolated.

## Shared Patterns

### Identity, bounded acquisition and incomplete evidence

**Sources:** `scripts/ci/ci-run-metrics.sh:665-692,727-770`, `scripts/ci/ci_metrics_security.py:405-435`, `scripts/ci/ci-playwright-report.mjs:32-57,63-84`  
**Apply to:** diagnosis records, per-seam records, aggregate validation and hosted verifier.

Bind each record to concrete producer identity and source; validate hashes/digests when available; retain bounded request/time budgets; report missing or clipped inputs as unknown/incomplete. Keep raw outcomes, diagnosis and test-body proof separate. Use stable machine-readable reason strings and nonzero exits on invalid/incomplete required evidence.

### Gate and skip ownership

**Sources:** `scripts/ci/honest-skip-verdict.sh:101-125,215-227`, `p10:51-87,118-175`, `p21:80-114`  
**Apply to:** `ci-gate`, manifest, docs and contract tests.

Keep one fixed lane-set owner and tests that compare it with workflow wiring. Keep p10 responsible for workflow/manifest structure; p21 checks documentation parity and delegates those structural assertions. Unknown classifier values and real cancellation must remain non-green.

### Failure-readable tests

**Sources:** `honest-skip-verdict.test.sh:72-115`, `ci-run-metrics.test.sh:106-150`, `p10:51-87`  
**Apply to:** new validators and regression controls.

Use temporary fixtures, deterministic fake inputs and both positive and negative controls. Assertions should preserve the expected failure status and explain the missing identity/body/lane; keep anti-vacuity checks so broken parsers cannot pass an empty comparison.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Phase 253 browser execution-record validator (new path TBD) | utility / validator | transform | Existing Playwright report validator covers native reports but no current utility validates exact five-seam execution records plus selected-body skip semantics. Reuse its schema/exit style. |
| Phase 253 independent hosted evidence verifier (new path TBD) | utility / verifier | request-response / file-I/O | Existing metrics collection checks some job/artifact provenance, but no tracked standalone verifier independently compares hosted job attempts and artifact metadata with fixture/PR source and workflow identities. |

## Metadata

**Analog search scope:** `.github/workflows/`, `.github/`, `scripts/ci/`, `scripts/ci/prohibitions/`, `test/example/priv/playwright/`, `test/example/test/support/`, and `test/support/`.  
**Tracked-source check:** every named existing analog was confirmed with `git ls-files`; no ignored runtime mirror paths are used.  
**Files scanned:** 17 likely existing or new paths; detailed excerpts came from the strongest matches above.  
**Pattern extraction date:** 2026-10-12.
