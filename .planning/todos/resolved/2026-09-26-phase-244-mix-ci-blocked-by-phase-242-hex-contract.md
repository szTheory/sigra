---
created: 2026-09-26
status: resolved
resolved: 2026-09-27
title: Reconcile the Phase 242 Hex workflow absence contract with the live workflow before the CI gate can pass
area: ci
severity: high
source: phase 244 plan 03 (`MIX_ENV=test mix ci` pre-push gate)
files:
  - test/sigra/planning/phase_242_shift_left_contract_test.exs
  - .github/workflows/hex-remediate-phantom.yml
---

## Problem

During Phase 244 Plan 03, `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` failed in `Sigra.Planning.Phase242ShiftLeftContractTest`: its retired-Hex-automation absence assertion conflicts with `.github/workflows/hex-remediate-phantom.yml`, which is present on the refreshed measurement branch after integrating current `main`.

This is outside Phase 244's scope, but `mix ci` is the required pre-push gate. The measurement branch cannot safely receive the corrected harness or produce same-SHA pull-request checks until the contract and workflow state are reconciled and the gate passes.

## Evidence

- The failure reproduced on the disposable Phase 244 measurement clone after merging current `main` at `5a00b90d2314bc93f27aec4090b5928018743d1b`.
- The failing test and workflow were left unchanged.
- Phase 244's attempted measurement is recorded as inconclusive in `244-PLAYWRIGHT-EVIDENCE.json`; its local harness correction remains unpushed.

## Resolution

The later quick tasks removed the resurfaced workflow and its p22 assets, then repaired the independent Phase 232 cache-key assertion. The exact gate `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` passed with exit 0 before the source commit `ed68e2b9`; details and retained output are in `.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md` and `.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md`.

Phase 244 subsequently completed with its own final-gate evidence. No Phase 244 branch push, PR #283 update, Hex operation, or release action is part of this resolution.
