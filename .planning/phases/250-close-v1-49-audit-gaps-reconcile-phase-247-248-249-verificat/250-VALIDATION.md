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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 250-01 | 01 | 1 | READY-01, READY-02 | — | Only one approved immutable candidate tuple can satisfy readiness; missing approval or a mismatched SHA stays blocked. | contract + evidence | Existing readiness validator/tests and exact-source evidence checks; add a focused identity/authorization regression if the current validator does not reject the conflicting tuple. | Existing + possible W0 | ⬜ pending |
| 250-02-01 | 02 | 2 | AUTO-02 | T-250-SC | Canary source has no Hex secret/environment or release authority; production observer and receipt identity remain strict. | unit + workflow contract | `bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs test/sigra/planning/phase_248_release_observer_contract_test.exs && actionlint .github/workflows/*.yml` | Existing tests; canary cases are W0 | ⬜ pending |
| 250-03 | 03 | 3 | AUTO-02 | T-250-SC | Controller dispatches/cancels only the exact allowlisted canary run and validates source-bound failure and cancellation artifacts as data. | hosted integration | Run the on-demand hosted controller; require retrieved failure and cancellation artifacts to pass the receipt validator and bind repo/workflow/event/ref/run ID/attempt/full SHA/artifact/observer/timestamps. | Missing hosted proof; W0 | ⬜ pending |
| 250-04 | 04 | 4 | READY-01, READY-02, AUTO-01, AUTO-02, REL-01, REL-02 | — | Canonical phase reports bind to current immutable source and hosted evidence; stale snapshots cannot pass. | evidence reconciliation | Run each phase verifier against its authoritative readiness, environment, public-release, final-main, inventory, and canary evidence; require explicit blocked outcomes for unresolved joins. | Existing reports; refresh required | ⬜ pending |
| 250-05 | 05 | 5 | All six owner requirements | — | Requirement ownership stays READY→247, AUTO→248, REL→249; accepted historical HANDOFF loss remains explicitly accepted-with-recorded-loss. | traceability + audit | Run requirement/frontmatter consistency checks and `$gsd-audit-milestone` only after all three owner verifications pass. | Audit tool exists; final evidence W0 | ⬜ pending |

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
