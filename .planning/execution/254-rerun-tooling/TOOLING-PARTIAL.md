# Plan 254-08 attempt-scoped tooling handoff

Status: **partial tooling only**. No hosted preparation, CI run, polling, acceptance window, or budget spend occurred. This report does not complete Plan 254-08.

## Implemented

- Added amended `(run_id, run_attempt)` reservation and registration checks. A run ID may be reused only for a distinct attempt; the exact run ID and attempt must be frozen in the reservation before early registration.
- Registration reads the attempt endpoint, records the authenticated `run_started_at` or `queued_at`, and binds the API response bytes and sample ID. The CLI fixture deliberately gives `created_at` a historical value outside the window and verifies the attempt endpoint, request ledger entry, and registered origin.
- Added attempt-isolated raw family paths and exact-attempt run/jobs acquisition. Attempt-mode cost and required-result wait calculations read only the selected attempt. Missing attempt queue/start origin returns unknown; it does not use historical `created_at`.
- Bound required checks to native job IDs from the selected attempt. Added attempt-specific origin checks for raw jobs, checks, and attempt-native artifacts. Legacy family mode remains on its previous run-family path.
- Added adversarial tests for duplicate/wrong/late attempt registration, cross-attempt check/job inputs, historical `created_at` misuse, and attempt-only cost accounting.

## Verified locally

- `bash -n scripts/ci/ci-run-metrics.sh` — passed.
- `bash scripts/ci/ci-run-metrics-comparison.test.sh` — passed, including the new real CLI early-registration fixture.
- `python3 -B scripts/ci/ci-metrics-security.test.py` — 23 tests passed.
- `python3 -B scripts/ci/ci-hosted-gate-verify.test.py` — 154 tests passed.
- `node scripts/ci/ci-run-metrics-replay.test.mjs` — 1 test passed.
- Immutable Phase252 baseline verifier — `ready`, no diagnostics, source SHA `4ed2edf5f1c231a3889fbf02b7179f9093df4883`.

## Still required before tooling is ready for hosted preparation

1. Add the approved bounded synthetic collector trace: attempt-mode CLI registration → actual mocked `--collect-comparison` acquisition of the exact attempt’s run, jobs, required checks, changed paths, and accepted artifacts → independent hosted-origin verifier passes → native coverage comparator trace. It must retain and assert the raw response and artifact bytes and show that no prior attempt endpoint or artifact was used. Existing fixtures in `scripts/ci/ci-run-metrics-comparison.test.sh` already provide the 108-row coverage map/parity receipt and generated family/artifact structures; extend those helpers instead of creating a parallel collector.
2. Transform/reuse that suite’s existing 20-pair evaluator fixture for attempt mode, reusing each pair’s run ID across the two roles with different reserved attempts. Assert pass, performance miss, and insufficient-data outcomes; verify the evaluator’s 40 independent origin results and that cost is restricted to each reserved attempt.
3. Run the affected suites and immutable baseline verifier again after those fixtures are added.

The current separate attempt registration/security and origin-verifier fixtures do not prove the integrated collector-to-origin-to-parity path. Therefore the current evidence is not sufficient to start the hosted preparation or claim Plan 254-08 complete. The parent executor is continuing these two fixture tasks in the existing Plan 254-08; no new plan or budget is requested here.
