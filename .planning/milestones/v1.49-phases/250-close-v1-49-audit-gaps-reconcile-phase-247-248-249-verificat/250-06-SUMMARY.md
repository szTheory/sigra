---
phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
plan: 06
subsystem: release-canary
tags: [github-actions, receipts, release-safety, gap-closure]
dependency-graph:
  requires: [250-01, release-receipt-canary workflow, shared release receipt sanitizer]
  provides: [exact canary dispatch correlation, scenario-bound failure receipts, guarded cancellation, protected-main repair]
  affects: [scripts/ci/release-canary.sh, scripts/ci/release-canary.test.sh, .github/workflows/release-receipt-canary.yml]
tech-stack:
  added: []
  patterns: [authoritative Actions run identity checks, mocked 204 dispatch-to-artifact integration]
key-files:
  created: [.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-06-SUMMARY.md]
  modified: [scripts/ci/release-canary.sh, scripts/ci/release-canary.test.sh, .github/workflows/release-receipt-canary.yml, test/sigra/planning/phase_250_canary_contract_test.exs]
decisions:
  - Keep the historical blocked canary attempts as blocked evidence; no hosted canary dispatch or cancellation was authorized for this plan.
  - Deliver only the reviewed repair through PR #318 and verify the merged source blobs against the successful exact-head CI run.
metrics:
  duration: 4h25m
  completed: 2026-10-10
  commits: 5
  plan_head_before: 0ba7d83c3e62832adeb868fba44ecef04a096ffa
  plan_head_after: ce0688aa0d5e78c827370bfecb655da936a5f0ec
status: complete
actuals:
  tokens: 9284
  tasks: 2
  commits: 5
requirements-completed: []
---

# Phase 250 Plan 06: Canary Dispatch and Receipt Repair Summary

The canary controller now binds each probe to one authoritative dispatched run, propagates the selected failure scenario into the receipt builder, verifies the paired cancellation identity, and exercises exact receipt artifact retrieval in a mocked end-to-end fixture. The repair is active on protected `main` after PR #318 and its exact-head CI passed; no hosted canary was dispatched.

## Completed Tasks

| Task | Result | Commits |
| --- | --- | --- |
| 1. Repair failure dispatch through exact receipt construction | Reproduced the source-SHA correlation failure and missing scenario input; added strict run identity matching, scenario propagation, and a 204 dispatch-to-retrieved-artifact fixture. | `491880a6b`, `0850d2df3` |
| 2. Prove safe cancellation and roll out the scoped repair | Added cancellation SHA/attempt and receipt-pair attempt checks, negative fixtures, contract assertions, and merged the scoped repair after protected CI. | `ceecaec5d`, `81a91670d`, `ce0688aa0` |

## Verification

- `bash scripts/ci/release-canary.test.sh` — 45 passed, 0 failed, including exact dispatch correlation, cancellation negatives, digest checks, and full artifact retrieval.
- `bash scripts/ci/release-receipt.test.sh` — 15 passed, 0 failed.
- `bash scripts/ci/release-observer.test.sh` — 22 passed, 0 failed.
- `actionlint .github/workflows/release-receipt-canary.yml .github/workflows/release-receipt-canary-controller.yml .github/workflows/release-run-observer.yml` — passed.
- Standalone contract run, `elixir -e 'ExUnit.start(); Code.require_file("test/sigra/planning/phase_250_canary_contract_test.exs")'` — 7 tests, 0 failures.
- `MIX_ENV=test mix test test/sigra/planning/phase_250_canary_contract_test.exs` could not reach test execution because the installed ignored dependency checkout does not match `mix.lock` (Phoenix and other packages differ). No dependency installation or lockfile change was made; standalone ExUnit and the required CI suite provide the available contract evidence.
- PR [#318](https://github.com/szTheory/sigra/pull/318) merged by the repository's supported squash merge. Exact PR head: `06ba5a6563533c0c45258f518246d20ed9c5512c`. Exact-head CI run [38080575187](https://github.com/szTheory/sigra/actions/runs/38080575187) completed successfully, including the required CI gate. The earlier run `38080040202` exposed one formatter issue; it was corrected in the style commit and the full exact-head CI was rerun.
- Protected `main` after merge: `34f7fd8e47c4b356ef97656f3213a2e749017f2a`. The four delivered file blobs on that commit are `scripts/ci/release-canary.sh` `932aac4cc3cdc1fb33d7628c825015a828cdf7d6`, `scripts/ci/release-canary.test.sh` `387e19e30c543bfdb841fd48e6a235c9f8b5a625`, `.github/workflows/release-receipt-canary.yml` `04b3ad78954f075615b3535cf330bf74c11814a9`, and `test/sigra/planning/phase_250_canary_contract_test.exs` `79466affca14af04fede10e9d14f5a9d14a1cad1`.
- The original blocked controller run `38059620443` and source failure run `38059634695` remain blocked historical evidence. This plan dispatched no hosted canary and canceled no hosted run.

## Deviations from Plan

**1. [Rule 3 - Blocking CI] Corrected a formatter failure found by protected CI.**
- **Found during:** Task 2
- **Issue:** The first scoped PR CI run rejected a formatting-only assertion layout in the contract test.
- **Fix:** Ran the repository formatter and committed the formatting correction, then reran CI against the new exact PR head.
- **Files modified:** `test/sigra/planning/phase_250_canary_contract_test.exs`
- **Commit:** `ce0688aa0` on the execution branch; delivered PR-head commit `06ba5a656`.

**2. [Documented validation limit] The local Mix wrapper is blocked by ignored dependency drift.** The plan explicitly preserves this as an independent blocker. The dependency checkout was not mutated; standalone ExUnit passed and the protected PR CI completed successfully.

## Decisions Made

- No hosted canary attempt was started because the prior controller authorization was consumed; this plan's authorization covered deterministic fixtures and scoped code delivery only.
- AUTO-02 remains unmarked complete because hosted release failure/cancellation evidence is still outstanding for its owning phase.

## Threat Surface Scan

No new endpoint, publishing credential, release/tag/PR authority, or trust-boundary schema was introduced. The canary workflow continues to use the shared sanitizer and exact workflow allowlists.

## Self-Check: PASSED

- Summary file exists at the planned phase path.
- All five task commits are ancestors of the execution branch `HEAD`.
- The successful exact-head CI and merged `main` commit/blob identities are recorded above.
