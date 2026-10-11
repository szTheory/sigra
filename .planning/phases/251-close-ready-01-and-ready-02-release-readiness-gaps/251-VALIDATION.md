---
phase: "251"
slug: "close-ready-01-and-ready-02-release-readiness-gaps"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-11"
---

# Phase 251 — Validation Strategy

> Per-phase validation contract for evidence refresh and deterministic owner verification.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node.js built-in `node:test` |
| **Config file** | None |
| **Quick run command** | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs` |
| **Full suite command** | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` |
| **Estimated runtime** | Under 1 second for the current 59-test baseline |

The quick and full commands are local and deterministic. They do not query or mutate GitHub, dispatch workflows, merge, publish, create releases, or change a candidate.

## Sampling Rate

- **After every task commit:** Run the quick readiness verifier suite.
- **After every plan wave:** Run the full suite and source-derived audit checks below.
- **Before `$gsd-verify-work`:** Full suite and current source-derived audit must be green.
- **Max feedback latency:** 1 second for the current local baseline; live read-only evidence capture is measured separately.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 251-01-01 | 01 | 1 | READY-01 | T-251-01, T-251-02 | Exact tuple and contemporaneous approval bind the source artifacts; a missing approval remains blocked. | end-to-end contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs` | Yes; extend | pending |
| 251-01-02 | 01 | 1 | READY-02 | T-251-03, T-251-04 | Complete full-identity populations, dispositions, clean source, and preservation read-back are required. | contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | Yes; extend | pending |
| 251-01-03 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04 | New packet, summary and Phase 247 report agree while Phase 250 packets retain their historical bytes. | evidence contract | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-251` | New packet/check mode from 251-01-01 | pending |
| 251-02-01 | 02 | 2 | READY-01, READY-02 | T-251-05, T-251-06, T-251-07 | Historical Phase 250 exception remains phase-only; current READY outcomes derive from Phase 247. | audit contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` | Yes; extend | pending |
| 251-02-02 | 02 | 2 | READY-01, READY-02 | T-251-06, T-251-07 | Requirement rows and strict milestone audit agree with the refreshed original-owner report. | source-derived audit | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md` | Yes; extend | pending |

## Wave 0 Requirements

- Extend existing tests for full approval-record binding, complete PR head/base identity stability, and non-overwriting Phase 251 evidence output.
- No framework installation or new package is needed; current test infrastructure covers the phase.

## Manual-Only Verifications

All in-scope checks are automated. If a historical approval or live read cannot be recovered, record the exact missing evidence and keep the requirement unsatisfied; no manual judgment can replace the required record.

## Source-Derived Audit Checks

- `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources`
- `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md`

## Validation Sign-Off

- [ ] Every plan task has an automated verify command or a Wave 0 dependency.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all required new regression cases.
- [ ] No watch-mode flags.
- [ ] Feedback latency remains within the local test budget.
- [ ] `nyquist_compliant: true` set after validation is complete.

**Approval:** pending
