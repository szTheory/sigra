---
phase: 236
slug: closeout-evidence-reconciliation
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-04
---

# Phase 236 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (existing project planning contracts) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/sigra/planning/` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~300 seconds |

---

## Sampling Rate

- **After every task commit:** Run the focused metadata-reconciliation contract selected or added by Wave 0.
- **After every plan wave:** Run the next phase-scoped `$gsd-validate-phase` command or the fresh `$gsd-audit-milestone v1.47` command, as applicable.
- **Before `$gsd-verify-work`:** The fresh v1.47 audit must report all requirements satisfied and Nyquist-compliant.
- **Max feedback latency:** 300 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Behavior | Test Type | Automated Command | Test File | Status |
|---------|------|------|----------|-----------|-------------------|-----------|--------|
| 236-01-01 | 01 | 1 | Exact SUMMARY ownership and immutable-evidence digests | ExUnit contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs --only summary_reconciliation` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-01-02 | 01 | 1 | Exact three-source traceability reconciliation | ExUnit contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-02-01 | 02 | 2 | Phases 230/231 lifecycle replay preserves validated transitions | ExUnit historical replay | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-02-02 | 02 | 2 | Phases 232/234 lifecycle replay preserves isolated transitions | ExUnit historical replay | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs --only validation_replay_recovery` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-03-01 | 03 | 3 | Source-bound v1.47 audit result and empty gap sets | ExUnit audit-boundary contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-04-01 | 04 | 4 | Mixed Phase 231 recovery boundary is preserved and declared honestly | ExUnit Git-history contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs --only validation_replay_recovery` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-04-02 | 04 | 4 | Phase 232 canonical transition has exact parent, scope, and retained body | ExUnit Git-history contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs --only validation_replay_recovery` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-04-03 | 04 | 4 | Phase 234 canonical transition has exact parent, scope, and retained body | ExUnit Git-history contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs --only validation_replay_recovery` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-05-01 | 05 | 5 | Audit-input snapshot inventories and detects source mutation | ExUnit script contract | `elixir scripts/planning/phase-236-audit-snapshot-test.exs` | `scripts/planning/phase-236-audit-snapshot-test.exs` | ✅ green |
| 236-05-02 | 05 | 5 | Audit output remains bound to the committed input boundary | ExUnit historical verifier | `elixir scripts/planning/phase-236-audit-snapshot.exs historical-verify .planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-INPUT-SNAPSHOT.json .planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-OUTPUT-SNAPSHOT.json 22dfd088 a523575d` | `scripts/planning/phase-236-audit-snapshot-test.exs` | ✅ green |
| 236-06-01 | 06 | 6 | Historical validation and audit snapshots reject altered boundaries | ExUnit contracts | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs && elixir scripts/planning/phase-236-audit-snapshot-test.exs` | phase contract + snapshot test | ✅ green |
| 236-06-02 | 06 | 6 | Formatter-clean closeout gate and scope fence | ExUnit contract + formatter | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs && mix format --check-formatted test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs scripts/planning/phase-236-audit-snapshot.exs scripts/planning/phase-236-audit-snapshot-test.exs` | phase contract + snapshot test | ✅ green |
| 236-07-01 | 07 | 7 | Historical verifier authenticates committed snapshot blobs | ExUnit script contract | `elixir scripts/planning/phase-236-audit-snapshot-test.exs` | `scripts/planning/phase-236-audit-snapshot-test.exs` | ✅ green |
| 236-07-02 | 07 | 7 | Rewritten Plan 06 and Plan 07 scope fence reject drift | ExUnit Git-history contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |
| 236-08-01 | 08 | 8 | Committed-range fence catches restored and merge-resolution forbidden paths | ExUnit scope-fence contract | `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs --only scope_fence` | `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add a narrow deterministic contract or command that rejects wrong SUMMARY ownership, extra completion IDs, unbacked traceability `Complete` rows, and protected-receipt edits before metadata is changed.
- [ ] Do not add CI evidence-collection tests; retained evidence is an input, not phase output.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

The original live `compare` command for the Plan 05 input snapshot is intentionally not used as a current-state gate: later closeout documentation changes make it report drift. The committed historical verifier above authenticates the exact freeze and audit boundaries and passes; the snapshot test separately proves live-drift detection.

---

## Validation Sign-Off

- [x] All tasks have automated verification
- [x] Sampling continuity: no 3 consecutive tasks without automated verification
- [x] Wave 0 covers all previously pending references
- [x] No watch-mode flags
- [x] Feedback latency < 300s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** automated audit complete, 2026-08-04

## Validation Audit 2026-08-04

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

The audit reconstructed the complete 15-task map from Plans 01–08 and their summaries. The existing test coverage was complete; this update reconciles the stale draft validation record with the green deterministic evidence.
