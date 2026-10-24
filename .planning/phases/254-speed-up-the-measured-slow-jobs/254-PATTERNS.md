# Phase 254: Speed Up the Measured Slow Jobs - Pattern Map

**Mapped:** 2026-10-23  
**Files analyzed:** 8 implementation/test seams named or implied by CONTEXT and RESEARCH  
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/example/priv/playwright/tests/admin-theme.spec.ts` | test | request-response / browser state | `tests/admin-design.setup.ts`; `tests/organizations.spec.ts` | role-match |
| `test/example/priv/playwright/tests/organizations.spec.ts` | test | request-response / browser state | same file, registration/invitation helpers | exact |
| `test/example/priv/playwright/playwright.config.ts` | config | request-response | existing serial config and `admin-design.setup.ts` project setup | exact |
| `.github/actions/example-playwright-boot/action.yml` | config | batch | existing composite action | exact |
| `.github/workflows/ci.yml` | config | event-driven | existing required browser owners and composite-action call sites | exact |
| `scripts/ci/ci-browser-records.mjs` | utility | transform / batch | same verifier and `ci-browser-records.test.mjs` | exact |
| `scripts/ci/ci-run-metrics.sh` | utility | batch / transform | same evaluator and `ci-run-metrics-comparison.test.sh` | exact |
| `scripts/ci/ci-browser-records.test.mjs`, `ci-run-metrics-comparison.test.sh` | test | batch | their current fixture-driven contract tests | exact |

All named analogs were confirmed tracked with `git ls-files`; no ignored runtime mirrors are referenced.

## Pattern Assignments

### Opt-in authentication fixture and invitation preconditions

**Analogs:** `test/example/priv/playwright/tests/admin-design.setup.ts` and `tests/organizations.spec.ts`.

The setup precedent imports Playwright's setup test, filesystem helpers, UUID generation and `TEST_PASSWORD` (setup lines 1-5). It registers a unique admin, waits for connected LiveView and fonts, then writes storage state into `test-results/.auth/` (lines 7-16, 18-34). Keep any Phase 254 fixture invocation-local and opt-in; this precedent has separate chromium/mobile/dark state files (lines 36-58), so do not adopt its global-project state for unrelated tests. Continue one worker, no retries, and fresh per-test browser contexts as configured in `playwright.config.ts` lines 75-81.

The organization helpers expose the key state guarantee: `registerAndConfirmUser` calls `logInIfNeeded` before returning ( `organizations.spec.ts` lines 48-60). `logInIfNeeded` visits the login route and only submits credentials if still there (lines 62-74). In the invite lifecycle, the owner is registered, then redundantly passed through `logInIfNeeded` again before creating a fresh organization and sending the invite (lines 445-458). That is the candidate navigation to remove only after helper proof; preserve owner zero-org creation and invitee signup/login/acceptance, which are real assertions (lines 460-484). A new browser context isolates cookies but does not reset database state.

### Mix and composite-action setup sequencing

**Analog:** `.github/actions/example-playwright-boot/action.yml` lines 61-120. The pinned setup-beam action uses `.tool-versions` with strict versions (61-67); Node is pinned to 20 and npm cache is keyed from the lockfile (68-72). Runtime/port-specific example dependency cache keys preserve Phoenix compile-time configuration (74-84). Preparation currently runs `mix deps.get` and warning-strict compile under `MIX_ENV=dev`/`PORT` (86-98), followed by database create, migrate and seeds with explicit PostgreSQL environment (99-115), then `npm ci` (116-120). Any combined `mix do` experiment should copy this ordering, working directories and environment, while server readiness remains a separate step. Remove only redundant setup-beam/Hex/Rebar or outer library dependency work where the pinned action/`mix ci` alias proves it redundant; retain the cache dimensions and browser OS dependency installation.

### Comparison evaluator and regression fixtures

**Analogs:** `scripts/ci/ci-run-metrics.sh` lines 1823-1922 and `scripts/ci/ci-run-metrics-comparison.test.sh` lines 48-71. The evaluator replays both snapshots and validates frozen source identities and reservation registration before pairing rows (1823-1870). It checks family outcomes, costs, retries and matched workload/cache/image identity (1871-1904), then computes ordinary median, nearest-rank p95 and pass/miss/insufficient-data (1905-1922). Current runner totals sum only pairs where both families succeeded (1901-1904); Phase 254's regression cases should extend this exact seam so failed/cancelled attempts and diagnosed retries contribute their actual runner seconds, while fewer than 20 comparable successful pairs stays insufficient.

The shell regression fixture builds temporary snapshots and reservations, invokes the real CLI, and asserts expected JSON verdicts (comparison test lines 48-71). Extend its fixture/mutations for balanced order/proximity, retry cost and insufficient outcomes; preserve the established CLI and frozen contract. Do not create a second collector or change the acceptance math.

### Native browser selection/status parity

**Analogs:** `scripts/ci/ci-browser-records.mjs` lines 110-142 and `scripts/ci/ci-browser-records.test.mjs` lines 110-140. The verifier checks producer/run identity, report hashes, expected selected test IDs, and current outcomes. Its current predicate permits each row to be passed or skipped as long as some row passed (records lines 132-140), which is why exact before/after identity and skip/exclusion parity belongs in this verifier. The test creates complete temporary native reports, applies one malformed mutation at a time, and asserts rejection (test lines 110-140). Follow that fixture style for intentional-skip policy and changed/missing test-project rows; if ownership is rebalanced, preserve an explicit before/after mapping.

## Shared Patterns

- **Authentication and state:** fresh random identities, explicit browser context, connected-LiveView readiness and backend-state setup are already used by the Playwright setup/specs. Auth storage must stay temporary under ignored `test-results`, with no upload/cache path.
- **CI setup:** retain pinned actions, explicit working directories/environment, runtime/port-partitioned cache keys, `set -euo pipefail`, and browser dependency installation.
- **Evidence and failures:** use the current native report, execution-record, registration and snapshot formats. Negative fixtures should fail closed and preserve identity/provenance; missing values are not zero.
- **Coverage:** compare normalized product test/project identities and expected/actual status, not counts alone. Preserve serial worker and zero retry settings.

## No Analog Found

None. The balanced nearby schedule is new validation logic, but the existing comparison reservation/evaluator and shell fixture are the closest direct analogs.

## Metadata

**Analog search scope:** `test/example/priv/playwright`, `.github/actions`, `.github/workflows`, `scripts/ci`  
**Files scanned:** 8 focused tracked analog/test files  
**Pattern extraction date:** 2026-10-23
