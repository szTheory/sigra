---
phase: "248"
slug: "exact-source-release-gate"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-07"
---

# Phase 248 — Validation Strategy

> Per-phase validation contract for the guarded Release Please to Hex release lane.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit workflow-contract tests, hermetic Bash tests, and Node `node:test` policy/fixture tests |
| **Config file** | `mix.exs`; `.github/workflows/release-please.yml`; `scripts/ci/` |
| **Quick run command** | `bash scripts/ci/wait-for-ci-gate.test.sh` plus the focused auto-merge, exact-source, environment-policy, and receipt fixture tests |
| **Full suite command** | `mix test` and `actionlint` on changed workflows; final verification also requires the exact-head `ci-gate` and retained release receipts |
| **Estimated runtime** | Focused local suite plus workflow syntax check: about 6.5 seconds observed on this checkout; hosted proof retrieval is an external probe |

## Sampling Rate

- **After every task commit:** Run the hermetic test for each changed script and the focused workflow contract test; run `git diff --check`.
- **After every plan wave:** Run all Phase 248 fixture tests and `actionlint` on every changed workflow.
- **Before final phase verification:** Run the full relevant test suite, `actionlint`, the exact-source gate against its immutable tag/SHA, and deterministic receipt/cancellation fixture checks. Retrieve machine-readable hosted receipts from the non-publishing canary; missing terminal evidence remains open.
- **Observed feedback latency:** The focused Phase 248 shell fixtures, ExUnit contracts, and workflow syntax check completed in about 6.5 seconds on this checkout. This is an observation, not a guaranteed upper bound.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 248-01-01 | 01 | 1 | AUTO-01 | T-248-01 | Release tag commit, Release Please SHA, and checked-out HEAD must agree before package setup. | Temporary Git fixture + workflow order contract | `bash scripts/ci/release-exact-source.test.sh` | ✅ | ✅ green |
| 248-01-02 | 01 | 1 | AUTO-01 | T-248-02 | The successful `ci-gate` run head SHA must equal the requested release SHA; run identity and the approved timeout ceiling remain observable. | Existing poller fixtures extended with wrong-head and JSON cases | `bash scripts/ci/wait-for-ci-gate.test.sh` | ✅ | ✅ green |
| 248-02-01 | 02 | 2 | AUTO-01 | T-248-03 | Only a push-triggered CI run on the Release Please branch with head SHA equal to the current PR head can be considered. | Candidate and workflow-run fixtures + `actionlint -shellcheck=0` | `bash scripts/ci/release-candidate-preflight.test.sh && actionlint -shellcheck=0 .github/workflows/ci.yml .github/workflows/release-pr-automerge.yml` | ✅ | ✅ green |
| 248-02-02 | 02 | 2 | AUTO-01 | T-248-04 | The one candidate passes metadata, exact-head CI, Unreleased, duplicate-note, and source-backed adopter-content checks before a final reread and merge. | Candidate-content fixtures + `actionlint` | `bash scripts/ci/release-candidate-preflight.test.sh && actionlint .github/workflows/release-pr-automerge.yml` | ✅ | ✅ green |
| 248-03-01 | 03 | 3 | AUTO-01 | T-248-05,T-248-06 | Release and merge token use is scoped to release-automation, manual Release Please dispatch retains its main guard, candidate CI has no release secrets, each evaluation has unique non-cancelling concurrency, and the 120-attempt/75-minute ceiling remains. | Phase 222-style ExUnit workflow contract + `actionlint -shellcheck=0` | `mix test test/sigra/planning/phase_248_release_gate_contract_test.exs && actionlint -shellcheck=0 .github/workflows/release-please.yml .github/workflows/hex-publish.yml .github/workflows/release-pr-automerge.yml .github/workflows/ci.yml` | ✅ | ✅ green |
| 248-03-02 | 03 | 3 | AUTO-01 | T-248-11 | The live policy preflight accepts only environments with exactly one selected deployment branch policy named main; a missing or broader policy fails before Release Please event operations. | Hermetic policy fixtures + primary workflow contract | `bash scripts/ci/release-environment-preflight.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs` | ✅ | ✅ green |
| 248-03-03 | 03 | 3 | AUTO-01 | T-248-05,T-248-11 | Each privileged job references its matching main-only environment; every policy caller has actions:read; manual recovery runs trusted workflow code from main and validates a separate source ref; required secret names are checked as booleans; dry-run receives only the read-only key; final publish receives only the write key; manual dry-run cannot publish. | ExUnit environment and secret-scope contract + `actionlint -shellcheck=0` | `bash scripts/ci/release-environment-preflight.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs && actionlint -shellcheck=0 .github/workflows/release-please.yml .github/workflows/release-pr-automerge.yml .github/workflows/hex-publish.yml` | ✅ | ✅ green |
| 248-04-01 | 04 | 4 | AUTO-02 | T-248-07,T-248-08 | Receipt schema rejects incomplete identity and keeps success, failed stages, dry-run, cancellation, source_event, timestamps, and retry state distinct. | JSON receipt fixtures | `bash scripts/ci/release-receipt.test.sh` | ✅ | ✅ green |
| 248-04-02 | 04 | 4 | AUTO-02 | T-248-07,T-248-08 | Terminal receipt upload runs before issue/label notification, preserves source_event including workflow_dispatch, and covers both primary and manual release workflows. | Receipt fixtures + ExUnit workflow contract + `actionlint` | `bash scripts/ci/release-receipt.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs && actionlint .github/workflows/release-please.yml .github/workflows/hex-publish.yml` | ✅ | ✅ green |
| 248-05-01 | 05 | 5 | AUTO-02 | T-248-09,T-248-10 | Only a cancelled Release Please run with matching authoritative repository, workflow, run ID, push/workflow_dispatch event, main branch, and source SHA can create a cancellation receipt carrying source_event. | Stubbed Actions API observer fixtures | `bash scripts/ci/release-observer.test.sh && bash scripts/ci/release-receipt.test.sh` | ✅ | ✅ green |
| 248-05-02 | 05 | 5 | AUTO-01,AUTO-02 | T-248-09,T-248-10,T-248-11 | The trusted default-branch observer covers cancellation from both supported source events; main-only manual evaluation, source identity, permissions, credentials, environment policy, concurrency, receipt ordering, and timeout contracts pass across all release workflows. | ExUnit workflow contracts + all hermetic fixtures + `actionlint -shellcheck=0` | `bash scripts/ci/release-observer.test.sh && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-candidate-preflight.test.sh && bash scripts/ci/release-environment-preflight.test.sh && bash scripts/ci/release-exact-source.test.sh && bash scripts/ci/wait-for-ci-gate.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs test/sigra/planning/phase_248_release_observer_contract_test.exs && actionlint -shellcheck=0 .github/workflows/ci.yml .github/workflows/release-please.yml .github/workflows/release-pr-automerge.yml .github/workflows/release-run-observer.yml .github/workflows/hex-publish.yml` | ✅ | ✅ green |

Each newly introduced fixture test is the first source created in its task and is run red before helper or workflow implementation. The Wave 0 source files are `scripts/ci/release-exact-source.test.sh`, `scripts/ci/release-candidate-preflight.test.sh`, `scripts/ci/release-environment-preflight.test.sh`, `test/sigra/planning/phase_248_release_gate_contract_test.exs`, `scripts/ci/release-receipt.test.sh`, `scripts/ci/release-observer.test.sh`, and `test/sigra/planning/phase_248_release_observer_contract_test.exs`; the plan wave column records each dependent implementation wave.

## Wave 0 Requirements

- [x] Add `scripts/ci/release-candidate-preflight.test.sh` fixtures for wrong branch/title/base/label, multiple candidates, stranded `Unreleased`, duplicate entries, missing source-backed notes, and a changed head.
- [x] Add `scripts/ci/release-exact-source.test.sh` and `scripts/ci/wait-for-ci-gate.test.sh` fixtures for tag/SHA/HEAD equality, successful gate run head SHA, mismatch failure, and the existing timeout contract.
- [x] Add `scripts/ci/release-environment-preflight.test.sh` fixtures for exact `main` deployment policy, missing environment policy, extra branch policy, and broader branch policy rejection.
- [x] Add `scripts/ci/release-receipt.test.sh` fixtures for success, stage failures, dry-run, cancellation, malformed identity, retry idempotency, and notifier failure.
- [x] Add `test/sigra/planning/phase_248_release_gate_contract_test.exs` and `test/sigra/planning/phase_248_release_observer_contract_test.exs` plus `actionlint` coverage for permissions, required release token, exact-main environment attachment and policy preflight, boolean-only secret-name presence, main-only manual Release Please evaluation, exact-head event flow, non-cancelling concurrency, Hex key scope, trusted observer validation for push and workflow_dispatch cancellations on main, source_event preservation, and pinned actions.
- [x] Confirm through a real Actions run that push-triggered ci-gate reports the exact Release Please PR head SHA; no PR synthetic merge SHA is accepted. Run `37881153003` (`push`, branch `release-please--branches--main`) reports head `a0eedb0e7e5c72b03cdf6c5c1730ed2878cb08c0` and successful `ci-gate`; this matches the Release Please candidate head recorded in `249-PREFLIGHT.json`.

## Hosted Evidence Confirmed 2026-10-10

- **Environment setup:** `release-automation` contains `RELEASE_PLEASE_TOKEN`; `hex-publish` contains `HEX_API_KEY` and `HEX_DRY_RUN_API_KEY`; no repository-level secrets are configured. `release-environment-preflight.sh` reports both environment deployment policies as exactly `main`. Secret values were never read.
- **Exact-head candidate gate:** push run `37881153003` on `release-please--branches--main` reports head SHA `a0eedb0e7e5c72b03cdf6c5c1730ed2878cb08c0`; its `ci-gate` job succeeded. The SHA matches the candidate head recorded in Phase 249's preflight evidence.
- **Published-source gate and receipt:** release run `37875238705`, attempt 3, and CI run `37875238741`, attempt 2, both identify source SHA `9e80cb78d6374b1ed4074d5fef6b613fee879dca`; the `ci-gate` succeeded. Artifact `release-result-1.6.0-37875238705` (artifact ID `11594782728`) was retrieved and its JSON records the gate as pass and publish outcome as published. The artifact is retained until 2027-01-07. Phase 249's committed release receipt preserves this identity.
- **Remaining hosted probe:** no eligible terminal failed or cancelled Release Please run with a retained release receipt was found. Failed main-branch runs `37993629242` and `38003573382` have only documentation artifacts; no cancelled Release Please run appeared in the 100-run query. Cancelled candidate `ci.yml` runs are not evidence for the Release Please `workflow_run` observer.

## Hosted Evidence Confirmed 2026-10-11

- **Bounded no-publish canary:** controller run `38137539834` used source SHA `84ebcea60024c9e8caee405d55cad1c76b0e858a`. It failed during its final ZIP download because the script supplied an unsupported `gh api --output` flag. No retry or additional dispatch occurred. The controller failure is retained as a diagnostic; it is not counted as a successful controller run.
- **Hosted failure receipt:** source run `38137550871`, attempt 1, concluded `failure`. Artifact `11701436633` (`release-canary-failure-38137550871-1-de77060c49e441abb00148a9e17518b0`) expires 2026-11-10. The independently downloaded ZIP digest is `94cc44aaa38388e89bb4790e504328ff70c0a163d90ed6301be7a8e912c5565e`; the receipt JSON SHA-256 is `d3c09829c42dd4dbe55a10e16a1a75432cdf04e7077afd0b6948f1283dd28d6d`.
- **Hosted cancellation receipt:** source run `38137614523`, attempt 1, concluded `cancelled`. Trusted observer run `38137756922` succeeded and uploaded artifact `11702216188` (`release-canary-cancellation-38137614523-1`), retained until 2027-01-09. The independently downloaded ZIP digest is `57d3d1667a61483edbe85182fee995697fdb3c502de2c5f97ab464cc24529707`; the receipt JSON SHA-256 is `ed5adb5ac6d1b0a0b12cf7a328c8789d9b99951badeb0aabd71e1791ea7840c3`.
- **Source-bound reconciliation:** the failure and cancellation receipts identify the same repository, main-branch source SHA, canary workflow, source event, and their exact run IDs/outcomes. The receipt-pair validator passes. Phase 250's owner verifier tests pass 12/12 and its report check confirms AUTO-01/AUTO-02 satisfied with zero blockers. Aggregate proof SHA-256: `6eb5fb2e373d2bca6efd3dc9161793e4a3ca0f260bfcf4f6a208aa3c40952289`; source snapshot SHA-256: `87e5681a5ae24a3cce32ef4d0a7e8e3e14c66b07ee871762f68bab2e789ea223`.
- **Validator compatibility note:** the generic `release-canary.sh --validate-proof` in this checkout rejects the historical aggregate proof because it requires the observer event to be `workflow_run`. The canary's exact source SHA has an explicit `workflow_dispatch` observer route, and the owner verifier joins that actual event and observer identity to the recorded source and artifact metadata. The source-specific owner verifier and receipt-pair checks pass; keep the generic validator mismatch visible without treating the failed controller download as success.

## Manual-Only Verifications

No manual-only verifications remain. The hosted failure and cancellation path was exercised by the bounded no-publish canary above; the actual release lane was not interrupted.

**Baseline note:** The required default `actionlint` command reports six pre-existing embedded ShellCheck warnings in the inherited `ci.yml`; the same warnings reproduce against committed baseline. Workflow syntax passes with `actionlint -shellcheck=0`, and the other four release workflows pass default `actionlint`. The inherited `ci.yml` was preserved.

## Validation Sign-Off

- [x] Every final plan task has an automated `<verify>` or an explicit external-secret prerequisite.
- [x] Sampling continuity: no three consecutive tasks without automated verification.
- [x] All Wave 0 fixture validators are present and green; the live exact-head candidate gate and retained release-success receipt are verified.
- [x] No watch-mode flags.
- [x] Record observed feedback latency without claiming a guaranteed bound.
- [x] Retained success, failure, and cancellation artifacts are proven by the Phase 249 release receipt and the Phase 250 no-publish hosted canary.

**Validation result:** complete — all 11 local task checks pass, the exact-head gate and retained release-success receipt are proven, and the hosted canary failure/cancellation receipts are retrieved and source-bound. The canary controller's download failure remains recorded separately; no production release was interrupted.

## Validation Audit 2026-10-08

| Metric | Count |
|---|---|
| Gaps found | 0 |
| Resolved | 11 |
| Escalated | 0 |
| Remote edge probes pending | 1 |

## Validation Audit 2026-10-08

| Metric | Count |
|---|---|
| Gaps found | 0 |
| Resolved | 11 |
| Escalated | 0 |
| External prerequisites pending | 2 |

## Validation Audit 2026-10-10

| Metric | Count |
|---|---|
| Gaps found | 1 |
| Resolved | 2 |
| Escalated | 1 |
| Hosted probes closed | 2 |
| Hosted probes remaining | 1 |
| Local automated checks | 11 |

## Validation Audit 2026-10-11

| Metric | Count |
|---|---|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |
