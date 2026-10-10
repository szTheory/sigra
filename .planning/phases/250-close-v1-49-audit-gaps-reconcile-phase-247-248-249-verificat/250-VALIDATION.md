---
phase: "250"
slug: "close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-10"
---

# Phase 250 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash fixture tests, ExUnit workflow contract tests, Node.js closeout validator, `actionlint` |
| **Config file** | `.github/workflows/*.yml`, `mix.exs`, phase-local closeout validators |
| **Quick run command** | `bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh` |
| **Full suite command** | `bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs test/sigra/planning/phase_248_release_observer_contract_test.exs && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` |
| **Estimated runtime** | ~2 minutes locally; hosted canary duration is bounded by the source workflow timeout |

## Sampling Rate

- **After every task commit:** Run the focused check owned by that task; receipt and observer changes use the quick run command above.
- **After every plan wave:** Run the full suite command and `actionlint` for every changed workflow.
- **Before `$gsd-verify-work`:** Re-run all focused contract tests, the strict owner-verification/milestone validators, and the hosted canary retrieval check.
- **Max feedback latency:** 120 seconds locally; hosted run waits use one watcher per run at 60-second intervals.

## Per-Task Verification Map

The task IDs below are plan/task coordinates (`250-{plan}-{task}`); every status is **pending** because Phase 250 execution has not begun. A command is not evidence of a pass until it is run against the task's produced artifacts. Commands are copied from each plan task's `<automated>` verifier.

| Task ID and name | Plan | Wave | Original owner requirement(s) | Threat ref / secure behavior | Automated command | Current status |
|------------------|------|------|-------------------------------|-----------------------------|-------------------|----------------|
| 250-01-01 — Task 1: Wire one complete dual-outcome canary tracer | 01 | 1 | AUTO-02 | T-250-01–04, T-250-SC — trusted observer uses exact workflow allowlists and never runs source artifacts; cancellation is exact-run-only; receipts bind full source/artifact identity and omit credentials. | `bash scripts/ci/release-canary.sh --self-test && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh && actionlint .github/workflows/release-receipt-canary.yml .github/workflows/release-receipt-canary-controller.yml .github/workflows/release-run-observer.yml` | ⬜ Pending; not run; canary/controller artifacts are planned outputs. |
| 250-01-02 — Task 2: Lock down canary identity and cancellation boundaries with fixtures | 01 | 1 | AUTO-02 | T-250-01–04, T-250-SC — reject malformed or misbound canary receipts, production/canary namespace crossover, and cancellation of any non-canary or non-waiting run; keep production identity matching unchanged. | `bash scripts/ci/release-canary.test.sh && mix test test/sigra/planning/phase_250_canary_contract_test.exs` | ⬜ Pending; not run; fixture and contract-test files are planned outputs. |
| 250-01-03 — Task 3: Capture the exact hosted proof and fail closed on unavailable Actions evidence | 01 | 1 | AUTO-02 | T-250-02–04, T-250-SC — read-only preflight; exact run/artifact IDs and digests; never expose credentials; missing hosted evidence remains blocked. | `bash scripts/ci/release-canary.test.sh && bash scripts/ci/release-canary.sh --validate-proof .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-PROOF.json` | ⬜ Pending; not run; hosted proof is absent and must be produced by the task. |
| 250-02-01 — Task 1: Reconcile authorization and one immutable candidate tuple | 02 | 2 | READY-01, READY-02 | T-250-05, T-250-06, T-250-SC — require immutable approval of the exact tuple; independently bind full SHAs, source blobs, CI attempt and dry-run; absent approval stays blocked. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs && node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | ⬜ Pending; not run; Phase 250 verifier and regression test are planned outputs. |
| 250-02-02 — Task 2: Write the canonical Phase 247 verifier from the captured join | 02 | 2 | READY-01, READY-02 | T-250-06, T-250-07, T-250-SC — retain exact evidence identities and captured time; report missing joins as unsatisfied rather than inheriting claims from a summary. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-report .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md` | ⬜ Pending; not run; Phase 250 verifier and regression test are planned outputs. |
| 250-03-01 — Task 1: Re-query Phase 248's exact environment, source and receipt identities | 03 | 2 | AUTO-01, AUTO-02 | T-250-08, T-250-09, T-250-SC — query secret names and policy only; validate exact run/attempt/SHA/workflow/artifact/observer identity and both hosted outcomes. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.test.mjs && bash scripts/ci/release-environment-preflight.test.sh` | ⬜ Pending; not run; Phase 250 verifier and regression test are planned outputs. |
| 250-03-02 — Task 2: Refresh the canonical Phase 248 report without hiding historical gaps | 03 | 2 | AUTO-01, AUTO-02 | T-250-09, T-250-10, T-250-SC — bind a fresh report to captured identities, retain the prior result as history, and leave either owner requirement unsatisfied if current evidence fails. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs --check-report .planning/phases/248-exact-source-release-gate/248-VERIFICATION.md && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh` | ⬜ Pending; not run; Phase 250 verifier is a planned output. |
| 250-04-01 — Task 1: Independently join public, historical terminal and post-canary main evidence | 04 | 3 | REL-01, REL-02 | T-250-11, T-250-12, T-250-SC — verify package/source and historical-main identities separately from current post-canary main and inventory. | `bash scripts/ci/release-public-proof.test.sh && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs && node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs` | ⬜ Pending; not run; Phase 250 verifier and regression test are planned outputs. |
| 250-04-02 — Task 2: Refresh Phase 249 verification and retain the accepted-loss record | 04 | 3 | REL-01, REL-02 | T-250-12, T-250-13, T-250-SC — independently capture package, historical-main and current-main evidence; describe the authorized HANDOFF loss as accepted-with-recorded-loss, never recovered or preserved. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs --check-report .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` | ⬜ Pending; not run; Phase 250 verifier is a planned output. |
| 250-05-01 — Task 1: Reconcile original owner summaries and requirement rows | 05 | 4 | READY-01, READY-02, AUTO-01, AUTO-02, REL-01, REL-02 | T-250-14, T-250-16, T-250-SC — retain original requirement ownership; update statuses only when canonical owner verifiers pass; preserve accepted-loss and all three distinct source identities. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-report .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs --check-report .planning/phases/248-exact-source-release-gate/248-VERIFICATION.md && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs --check-report .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md` | ⬜ Pending; not run; Phase 250 verifier scripts are planned outputs. |
| 250-05-02 — Task 2: Add a narrow cross-owner freshness and contradiction gate | 05 | 4 | READY-01, READY-02, AUTO-01, AUTO-02, REL-01, REL-02 | T-250-14, T-250-15, T-250-SC — reject duplicate/orphaned ownership, stale refs, contradictory outcomes, and accepted-loss language that claims recovery. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources` | ⬜ Pending; not run; traceability validator and regression tests are planned outputs. |
| 250-05-03 — Task 3: Run the strict milestone audit as the final acceptance gate | 05 | 4 | READY-01, READY-02, AUTO-01, AUTO-02, REL-01, REL-02 | T-250-14–16, T-250-SC — generate the audit from passing owner evidence, reject hand-edited/stale 9/9, and persist only sanitized identities. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md && test -z "$(git status --porcelain=v1 --untracked-files=all)"` | ⬜ Pending; not run; final owner evidence and audit execution are future task outputs. |

## Wave 0 Requirements

- [ ] Add focused controller/canary fixtures for exact workflow identity, event/ref, unique probe ID, run ID/attempt/SHA binding, artifact naming/digest, credential-key rejection, wrong-run retrieval, and refusal to cancel non-canary runs.
- [ ] Add a negative regression proving production receipt validation rejects canary envelopes while the production Release Please observer match remains unchanged.
- [ ] Confirm the live artifact-retention limit and exact cross-run artifact-download permissions through a read-only preflight; retain a machine-readable blocked diagnostic if either is unavailable.
- [ ] Produce the hosted proof record only after the real GitHub canary completes and both artifacts are retrieved and validated; local fixtures cannot satisfy AUTO-02.

## Manual-Only Verifications

All phase behaviors have automated verification. Hosted permission or settings gaps produce an explicit blocked result; they are never accepted through human UAT.

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s locally
- [ ] `nyquist_compliant: true` set in frontmatter after execution validation

**Approval:** pending
