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
| 251-01-01 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | First output proves exact baseline/blob identity, trusted sources, full source windows, boundaries, producers, and independent trust. It separately records candidate tuple `0e773d3614a242e4fbcdd34c418ecb8a307703d6` / `d135cbce343947499a0810736c500ef5f1cb5c32` / `a494f3ee3878da93aab4f70712ffddeefd77a802` and published tag source `v1.6.0` / `9e80cb78d6374b1ed4074d5fef6b613fee879dca`, with metadata, manifest/config, changelog, tag, HexDocs source-ref, README, guide, shipped changes, compatibility, generated-host action/no-action, and `~> 1.6.0` update/check results. Missing/mismatched items are READY-01 findings and do not block a ready READY-02 slice. | read-only per-requirement feasibility contract | `node --input-type=module -e 'import fs from "node:fs"; import assert from "node:assert/strict"; const p=JSON.parse(fs.readFileSync(".planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-FEASIBILITY.json","utf8")); const a=p.requirements.READY01; assert.deepEqual(a.candidate_tuple,{candidate_sha:"0e773d3614a242e4fbcdd34c418ecb8a307703d6",reviewed_base_sha:"d135cbce343947499a0810736c500ef5f1cb5c32",protected_main_sha:"a494f3ee3878da93aab4f70712ffddeefd77a802"}); assert.deepEqual(a.published_release_source,{tag:"v1.6.0",commit_sha:"9e80cb78d6374b1ed4074d5fef6b613fee879dca"}); const q=a.package_adopter; const paths=[".release-please-manifest.json","release-please-config.json","mix.exs","CHANGELOG.md","README.md","guides/introduction/upgrading-to-v1.6.md","test/example/priv/playwright/tests/organizations.spec.ts","lib/sigra.ex"]; for(const x of paths){assert(q.source_paths.includes(x));assert(p.source_blobs.some(b=>b.path===x&&b.source_identity));} for(const k of ["package_metadata","release_manifest","changelog","tag","hexdocs_source_reference","adopter_shipped_changes","adopter_compatibility","generated_host_action","version_requirement","update_check_path"])assert(Object.hasOwn(q.checks,k)); assert.equal(p.status==="ready",a.capture_allowed||p.requirements.READY02.capture_allowed); if(a.history_complete&&a.approval_event==="absent")assert.equal(a.verdict,"authorization_pending");'` | Yes; first execution artifact | pending |
| 251-01-02 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | Each still-current capture-ready slice unlocks only its evaluator branch. Regression fixtures cover each missing/mismatched package/adopter path and field, require READY-01 unsatisfied, and prove READY-02 remains captureable; unavailable READY-01 history does not gate it. | contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | Yes; extend after 251-01-01 returns ready | pending |
| 251-01-03 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | Packet and Phase 247 report refresh from all capture-ready slices and retain exact candidate/tag identities, every package/adopter source path/blob digest and structured guidance result. A READY-01 mismatch or authorization finding does not block READY-02 inventory capture, and Phase 250 bytes remain unchanged. | evidence contract | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-251 && node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | New packet/check mode from 251-01-02 | pending |
| 251-02-01 | 02 | 2 | READY-01, READY-02 | T-251-05, T-251-06, T-251-07 | Historical Phase 250 exception remains phase-only; current READY outcomes derive independently from the refreshed Phase 247 owner report after a ready feasibility result. | audit contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` | Yes; extend; requires 251-01-01 ready and Task 3 packet/report | pending |
| 251-02-02 | 02 | 2 | READY-01, READY-02 | T-251-06, T-251-07 | Requirement rows and strict milestone audit agree with each refreshed original-owner verdict, including independent pending/unsatisfied outcomes. | source-derived audit | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md` | Yes; extend; requires 251-01-01 ready and 251-01-03 outputs | pending |

## Wave 0 Requirements

- First produce only the read-only feasibility JSON. If neither requirement slice is capture-ready, stop with no further artifacts. A ready slice permits code/test changes only for that branch; complete trusted approval history with no exact event stays `authorization_pending` and does not block READY-02 inventory refresh or truthful owner evidence. Package/adopter mismatch fixtures cover the candidate and published-source identities, metadata, manifest/config, changelog, tag, HexDocs source reference, README-to-guide link, shipped changes, compatibility, generated-host action/no-action, version constraint and update/check path; each failure leaves READY-01 unsatisfied and preserves an independently ready READY-02 capture.
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
