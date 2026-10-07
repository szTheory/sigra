---
phase: "248"
slug: "exact-source-release-gate"
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| **Estimated runtime** | Not measured; record actual focused-test and CI durations during execution |

## Sampling Rate

- **After every task commit:** Run the hermetic test for each changed script and the focused workflow contract test; run `git diff --check`.
- **After every plan wave:** Run all Phase 248 fixture tests and `actionlint` on every changed workflow.
- **Before `$gsd-verify-work`:** Run the full relevant test suite, `actionlint`, the exact-source gate against its immutable tag/SHA, and deterministic receipt/cancellation fixture checks. Preserve machine-readable run receipts; missing live evidence remains blocked.
- **Max feedback latency:** Not measured; keep local fixture checks focused and record observed durations.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 248-01-01 | 01 | 1 | AUTO-01 | T-248-01 | Release tag commit, Release Please SHA, and checked-out HEAD must agree before package setup. | Temporary Git fixture + workflow order contract | `bash scripts/ci/release-exact-source.test.sh` | ❌ W0 | ⬜ pending |
| 248-01-02 | 01 | 1 | AUTO-01 | T-248-02 | The successful `ci-gate` run head SHA must equal the requested release SHA; run identity and the approved timeout ceiling remain observable. | Existing poller fixtures extended with wrong-head and JSON cases | `bash scripts/ci/wait-for-ci-gate.test.sh` | ❌ W0 | ⬜ pending |
| 248-02-01 | 02 | 2 | AUTO-01 | T-248-03 | Only a push-triggered CI run on the Release Please branch with head SHA equal to the current PR head can be considered. | Candidate and workflow-run fixtures + `actionlint` | `bash scripts/ci/release-candidate-preflight.test.sh && actionlint .github/workflows/ci.yml .github/workflows/release-pr-automerge.yml` | ❌ W0 | ⬜ pending |
| 248-02-02 | 02 | 2 | AUTO-01 | T-248-04 | The one candidate passes metadata, exact-head CI, Unreleased, duplicate-note, and source-backed adopter-content checks before a final reread and merge. | Candidate-content fixtures + `actionlint` | `bash scripts/ci/release-candidate-preflight.test.sh && actionlint .github/workflows/release-pr-automerge.yml` | ❌ W0 | ⬜ pending |
| 248-03-01 | 03 | 3 | AUTO-01 | T-248-05,T-248-06 | Release and merge token use is scoped to release-automation, manual Release Please dispatch retains its main guard, candidate CI has no release secrets, each evaluation has unique non-cancelling concurrency, and the 120-attempt/75-minute ceiling remains. | Phase 222-style ExUnit workflow contract + `actionlint` | `mix test test/sigra/planning/phase_248_release_gate_contract_test.exs && actionlint .github/workflows/release-please.yml .github/workflows/hex-publish.yml .github/workflows/release-pr-automerge.yml .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 248-03-02 | 03 | 3 | AUTO-01 | T-248-11 | The live policy preflight accepts only environments with exactly one selected deployment branch policy named main; a missing or broader policy fails before Release Please event operations. | Hermetic policy fixtures + primary workflow contract | `bash scripts/ci/release-environment-preflight.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs` | ❌ W0 | ⬜ pending |
| 248-03-03 | 03 | 3 | AUTO-01 | T-248-05,T-248-11 | Each privileged job references its matching main-only environment; required secret names are checked as booleans, dry-run receives only the read-only key, final publish receives only the write key, and manual dry-run cannot publish. | ExUnit environment and secret-scope contract + `actionlint` | `bash scripts/ci/release-environment-preflight.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs && actionlint .github/workflows/release-please.yml .github/workflows/release-pr-automerge.yml .github/workflows/hex-publish.yml` | ❌ W0 | ⬜ pending |
| 248-04-01 | 04 | 4 | AUTO-02 | T-248-07,T-248-08 | Receipt schema rejects incomplete identity and keeps success, failed stages, dry-run, cancellation, source_event, timestamps, and retry state distinct. | JSON receipt fixtures | `bash scripts/ci/release-receipt.test.sh` | ❌ W0 | ⬜ pending |
| 248-04-02 | 04 | 4 | AUTO-02 | T-248-07,T-248-08 | Terminal receipt upload runs before issue/label notification, preserves source_event including workflow_dispatch, and covers both primary and manual release workflows. | Receipt fixtures + ExUnit workflow contract + `actionlint` | `bash scripts/ci/release-receipt.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs && actionlint .github/workflows/release-please.yml .github/workflows/hex-publish.yml` | ❌ W0 | ⬜ pending |
| 248-05-01 | 05 | 5 | AUTO-02 | T-248-09,T-248-10 | Only a cancelled Release Please run with matching authoritative repository, workflow, run ID, push/workflow_dispatch event, main branch, and source SHA can create a cancellation receipt carrying source_event. | Stubbed Actions API observer fixtures | `bash scripts/ci/release-observer.test.sh && bash scripts/ci/release-receipt.test.sh` | ❌ W0 | ⬜ pending |
| 248-05-02 | 05 | 5 | AUTO-01,AUTO-02 | T-248-09,T-248-10 | The trusted default-branch observer covers cancellation from both supported source events; main-only manual evaluation, source identity, permissions, credentials, concurrency, receipt ordering, and timeout contracts pass across all release workflows. | ExUnit workflow contracts + all hermetic fixtures + `actionlint` | `bash scripts/ci/release-observer.test.sh && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-candidate-preflight.test.sh && bash scripts/ci/release-exact-source.test.sh && bash scripts/ci/wait-for-ci-gate.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs test/sigra/planning/phase_248_release_observer_contract_test.exs && actionlint .github/workflows/ci.yml .github/workflows/release-please.yml .github/workflows/release-pr-automerge.yml .github/workflows/release-run-observer.yml .github/workflows/hex-publish.yml` | ❌ W0 | ⬜ pending |

Each newly introduced fixture test is the first source created in its task and is run red before helper or workflow implementation. The Wave 0 source files are `scripts/ci/release-exact-source.test.sh`, `scripts/ci/release-candidate-preflight.test.sh`, `scripts/ci/release-environment-preflight.test.sh`, `test/sigra/planning/phase_248_release_gate_contract_test.exs`, `scripts/ci/release-receipt.test.sh`, `scripts/ci/release-observer.test.sh`, and `test/sigra/planning/phase_248_release_observer_contract_test.exs`; the plan wave column records each dependent implementation wave.

## Wave 0 Requirements

- [ ] Add `scripts/ci/release-candidate-preflight.test.sh` fixtures for wrong branch/title/base/label, multiple candidates, stranded `Unreleased`, duplicate entries, missing source-backed notes, and a changed head.
- [ ] Add `scripts/ci/release-exact-source.test.sh` and `scripts/ci/wait-for-ci-gate.test.sh` fixtures for tag/SHA/HEAD equality, successful gate run head SHA, mismatch failure, and the existing timeout contract.
- [ ] Add `scripts/ci/release-environment-preflight.test.sh` fixtures for exact `main` deployment policy, missing environment policy, extra branch policy, and broader branch policy rejection.
- [ ] Add `scripts/ci/release-receipt.test.sh` fixtures for success, stage failures, dry-run, cancellation, malformed identity, retry idempotency, and notifier failure.
- [ ] Add `test/sigra/planning/phase_248_release_gate_contract_test.exs` and `test/sigra/planning/phase_248_release_observer_contract_test.exs` plus `actionlint` coverage for permissions, required release token, exact-main environment attachment and policy preflight, boolean-only secret-name presence, main-only manual Release Please evaluation, exact-head event flow, non-cancelling concurrency, Hex key scope, trusted observer validation for push and workflow_dispatch cancellations on main, source_event preservation, and pinned actions.
- [ ] Confirm through a real Actions run that push-triggered ci-gate reports the exact Release Please PR head SHA; no PR synthetic merge SHA is accepted.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Create `release-automation` with only `RELEASE_PLEASE_TOKEN` and `hex-publish` with only `HEX_DRY_RUN_API_KEY` plus `HEX_API_KEY`; configure each environment's selected-branch deployment policy to exactly `main`, move the existing repository-level tokens into those environments, remove their repository-level copies, and require no human reviewer approval. | AUTO-01 | Environment creation, secret migration, and deployment branch policy are one-time GitHub repository settings. Secret values remain unavailable to the test harness and must not be read or emitted. | The authorized maintainer performs this setup once. The release workflow then checks each required secret name using a boolean-only comparison and checks both live environment policies; actual Hex authentication is proven by the immutable-source dry-run. No per-release approval is part of the setup. |

## Validation Sign-Off

- [ ] Every final plan task has an automated `<verify>` or an explicit external-secret prerequisite.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing validators and source-identity prerequisites.
- [ ] No watch-mode flags.
- [ ] Record feedback latency from execution evidence; do not claim a bound before measurement.
- [ ] Set `nyquist_compliant: true` only after the final validation map and required evidence are complete.

**Approval:** pending
