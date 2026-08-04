---
phase: 236
slug: closeout-evidence-reconciliation
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 236-01-01 | 01 | 1 | Evidence reconciliation | T-236-01 | Reject unbacked SUMMARY declarations, traceability claims, and protected-receipt edits | focused contract | `mix test test/sigra/planning/` | ❌ W0 | ⬜ pending |
| 236-02-01 | 02 | 2 | Nyquist lifecycle | T-236-02 | Canonical validator changes lifecycle only on passing coverage | workflow audit | `$gsd-validate-phase 230 && $gsd-validate-phase 231 && $gsd-validate-phase 232 && $gsd-validate-phase 234` | ✅ existing artifacts | ⬜ pending |
| 236-03-01 | 03 | 3 | Honest milestone closeout | T-236-03 | Audit preserves exact diagnostics unless all criteria pass | end-to-end audit | `$gsd-audit-milestone v1.47` | ✅ existing workflow | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add a narrow deterministic contract or command that rejects wrong SUMMARY ownership, extra completion IDs, unbacked traceability `Complete` rows, and protected-receipt edits before metadata is changed.
- [ ] Do not add CI evidence-collection tests; retained evidence is an input, not phase output.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
