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
| 251-01-01 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | First output proves exact baseline/blob identity, trusted sources, full source windows, boundaries, producers, and independent trust per requirement; an absent approval event is a finding, not a blocker. | read-only per-requirement feasibility contract | `node --input-type=module -e 'import fs from "node:fs"; import assert from "node:assert/strict"; const p=JSON.parse(fs.readFileSync(".planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-FEASIBILITY.json","utf8")); const a=p.requirements?.READY01, b=p.requirements?.READY02; assert(["ready","blocked"].includes(p.status)); assert(p.active_checkout?.head && p.baseline?.commit && Array.isArray(p.source_blobs) && p.source_blobs.length>0 && Array.isArray(p.checks) && p.checks.length>0 && Array.isArray(p.blockers) && p.trusted_sources?.github_api === "https://api.github.com/repos/szTheory/sigra"); assert(a && b && ["ready","blocked"].includes(a.source_feasibility) && ["ready","blocked"].includes(b.source_feasibility) && typeof a.capture_allowed==="boolean" && typeof b.capture_allowed==="boolean" && Array.isArray(a.sources) && Array.isArray(a.source_checks) && Array.isArray(a.evidence_producers) && Array.isArray(a.independent_trust) && Array.isArray(b.sources) && Array.isArray(b.source_checks) && Array.isArray(b.evidence_producers) && Array.isArray(b.independent_trust) && typeof a.history_complete==="boolean" && a.time_window && Object.hasOwn(a.time_window,"start") && Object.hasOwn(a.time_window,"end") && typeof a.time_window.complete==="boolean" && Object.hasOwn(a.time_window,"start_boundary") && Object.hasOwn(a.time_window,"end_boundary") && ["found","absent","not_searchable"].includes(a.approval_event) && Array.isArray(a.blockers) && Array.isArray(a.findings) && Array.isArray(b.blockers) && Array.isArray(b.findings)); assert.equal(a.capture_allowed,a.source_feasibility==="ready"); assert.equal(b.capture_allowed,b.source_feasibility==="ready"); assert.equal(p.status==="ready",a.capture_allowed||b.capture_allowed); if(a.history_complete && a.approval_event==="absent") assert.equal(a.verdict,"authorization_pending"); if(p.status==="ready") assert.equal(p.blockers.length,0); else { assert(p.blockers.length>0); assert.notEqual(a.verdict,"satisfied"); assert.notEqual(b.verdict,"satisfied"); }'` | Yes; first execution artifact | pending |
| 251-01-02 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | Each still-current capture-ready slice unlocks only its evaluator branch; an unavailable READY-01 history does not gate a source-ready READY-02. | contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | Yes; extend after 251-01-01 returns ready | pending |
| 251-01-03 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | Packet and Phase 247 report refresh from all capture-ready slices; a READY-01 authorization finding does not block READY-02 inventory capture, and Phase 250 bytes remain unchanged. | evidence contract | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-251 && node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | New packet/check mode from 251-01-02 | pending |
| 251-02-01 | 02 | 2 | READY-01, READY-02 | T-251-05, T-251-06, T-251-07 | Historical Phase 250 exception remains phase-only; current READY outcomes derive independently from the refreshed Phase 247 owner report after a ready feasibility result. | audit contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` | Yes; extend; requires 251-01-01 ready and Task 3 packet/report | pending |
| 251-02-02 | 02 | 2 | READY-01, READY-02 | T-251-06, T-251-07 | Requirement rows and strict milestone audit agree with each refreshed original-owner verdict, including independent pending/unsatisfied outcomes. | source-derived audit | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md` | Yes; extend; requires 251-01-01 ready and 251-01-03 outputs | pending |

## Wave 0 Requirements

- First produce only the read-only feasibility JSON. If neither requirement slice is capture-ready, stop with no further artifacts. A ready slice permits code/test changes only for that branch; complete trusted approval history with no exact event stays `authorization_pending` and does not block READY-02 inventory refresh or truthful owner evidence.
- No framework installation or new package is needed; current test infrastructure covers the phase.

## Manual-Only Verifications

All in-scope checks are automated. If a trusted complete historical source contains no exact approval event, record `authorization_pending` and keep READY-01 unsatisfied while continuing any source-ready READY-02 refresh. If a source/window/trust check is unavailable, block only that requirement slice; no manual judgment or later approval can replace historical evidence.

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
