# Phase 258 Scope: Re-anchor CISPEED proof under a fresh source scope

## Objective

Give CISPEED-01/02 a valid path to proof after Phase257 halted, its one-shot claim was consumed, and the controller source bound to that attempt became unavailable. Reuse the still-verified Phase256 candidate/control source pair, fix the Phase258 local verifier defect, and continue under a fresh source-bound proposal. The user's existing project authorization covers this bounded phase; routine local checks and CI do not require another approval prompt.

## Local checks and `act`

`act` can run compatible workflow jobs locally and catch deterministic failures before spending a hosted workload. The recorded preflight ran against the pinned candidate commit and completed 40 steps; the final offline attestation step stopped because the local runner image lacks the required `gh` command. It made zero GitHub API requests and started no hosted workflow. Local `act` output does not establish current branch protection, PR state, GitHub cache state, or hosted runner timing, so it cannot replace those live checks or the required performance observations.

The Phase258 preparation ceiling is a maximum, not a target. Use local checks to catch source and workflow defects first; the actual request count may be lower. The live metadata requests are needed only to confirm mutable GitHub state. The 40-family measurement still needs hosted runners because `act` cannot reproduce GitHub runner timing or cache conditions.

## Fixed requirements

- Preserve the approved 20 paired observations across the original 40 families, seed, ordering, treatment semantics, cost rules, statistical method, and acceptance thresholds.
- Keep CISPEED-01 and CISPEED-02 open until the fixed comparison passes and independent phase verification passes.
- Do not reuse the missing Phase257 controller hash, its consumed one-shot claim, authorization, or execution.
- Revalidate the Phase256 candidate/control commits through the production source verifier before reuse. They remain pinned at `5effabe754c74fcd3086128ae9ce2e01ae07ab79` and `37f1b551d0cfb990a49e6b1b21e6cecaf538dfe0`; the fresh Phase258 source receipt binds them to the current controller code.
- Preserve the unknown predecessor workload as one possible prior workload and reserve its 280 runner timeout-job minutes.
- No merge, release, branch-rule change, treatment change, sample-count change, or threshold change.

## Predecessor accounting

The production Phase257 predecessor verifier records the Phase256/Phase257 source-bound requests and preserves the unknown Phase257 workload. Earlier Phase258 generations and read-only diagnostics remain included in the previously reconciled lifetime total. Before recovery07 began, lifetime usage was 190 GETs. Recovery07 then spent ten readiness GETs before its verifier crashed on a missing `StageController.now`; one separate `/rate_limit` diagnostic also used one GET. Lifetime usage is therefore 201 GETs. Recovery07 made no branch update, workload, runner-time use, or measurement sample, and its claim is consumed. The local clock fix and focused regression are recorded in `phase258-local-validation-15`; recovery07 cannot be retried or reused.

Recovery08 starts from all 201 spent GETs and may use at most 457 additional preparation GETs across readiness and the one preparation workload. This is a maximum, not an expected count. The proposal retains one branch update, one workload, and at most 280 preparation runner timeout-job minutes. It keeps the fixed 24,000 comparison GETs, 82 measurement mutations plus one candidate-publication mutation, and up to 41 measurement workflows (40 families plus the existing one infrastructure retry). Lifetime ceilings remain 24,658 GETs, 83 mutations, 43 workloads, and 12,040 runner timeout-job minutes. These are the previously authorized experiment limits and fixed deadline.

Recovery08 has a 45-minute preparation window starting at its first persisted request reservation, one invocation, zero retries, zero reruns, zero renewals, zero alternate transports, and a 2,700-second hard outer timeout. It cannot move the absolute deadline `2026-11-09T14:12:29.966558Z`. Recovery05, recovery06, and recovery07 remain immutable and cannot be resumed.

## Phase boundary

- **Plan258-01 — local source and budget receipts:** re-read the preserved source pair and every predecessor receipt. No proposal, claim, request, mutation, or workload.
- **Plan258-02 — local production support:** implement and test the Phase258 proposal, exact-consent authorizer, one-use claim, bounded execution wrapper, and independent readers. Produce a complete proposal marked `ready_for_consent`, without authorization/claim files or network access.
- **Plan258-03 — recovery08 continuation:** reconcile recovery07's ten GETs and the separate diagnostic GET, keep its consumed claim closed, verify the supplied-clock fix locally, and build a distinct proposal under `.planning/execution/258/generations/phase258-recovery-08/`.
- **Standing authorization and execution:** bind the exact recovery08 proposal through the production standing-CI authorizer. Create one claim, run preparation once, and start the unchanged comparison only if independent preparation verification passes. Do not ask for another approval within the existing bounded authorization. Stop at any cap or failed proof.

## Reusable evidence

- `.planning/execution/256/PREP-CONTRACT.json`
- `.planning/execution/256/PREP-LEDGER.json`
- `.planning/execution/256/source-recovery-01/SOURCE-CHECK.json`
- `.planning/execution/256/objects.git/`
- `.planning/execution/257/PREP-CONTRACT.json`
- `.planning/execution/257/PREP-PROPOSAL.json`
- `.planning/execution/257/PREPARE-INVOCATION-CLAIM.json`
- `.planning/execution/257/PREP-LEDGER.json`
- `.planning/execution/257/preparation/OUTER-PROCESS.json`
- `.planning/execution/257/local-recovery-18/COUNTER-RECONCILIATION.json`
- `.planning/execution/257/generations/02/PREDECESSOR-RECONCILIATION.json`
- `.planning/debug/phase257-local/CLOCK-ANCHOR-MAINTENANCE-20261105.json`
- `.planning/recovery/opengsd-health-20261106/phase258-act-preflight-01/ACT-PREFLIGHT.json`
- `.planning/recovery/opengsd-health-20261106/phase258-local-validation-15/LOCAL-CHECKS.json`
- `.planning/recovery/opengsd-health-20261106/phase258-preparation-attempt-06-reconciliation/PREPARATION-ATTEMPT-06-RECONCILIATION.json`
