---
created: 2026-09-26
status: pending
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

## Follow-up

In a separately scoped task, determine whether the retired workflow should be removed or whether the Phase 242 absence contract should reflect the current workflow lifecycle. Run `mix ci` after the change before resuming the Phase 244 evidence push.
