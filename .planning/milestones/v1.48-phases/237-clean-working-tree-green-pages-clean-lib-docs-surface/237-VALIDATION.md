---
phase: "237"
slug: clean-working-tree-green-pages-clean-lib-docs-surface
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-19"
---

# Phase 237 — Validation Strategy

> Retrospective automation audit of the phase's repository, documentation, Git-object, and Pages seams.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, shell contract tests, phase-local Python scanner, GitHub REST/HTTP read-back |
| **Config file** | `mix.exs`, phase-local fixtures and evidence artifacts |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs` |
| **Full suite command** | Phase 237 automated seam suite recorded in `237-UAT.md` |
| **Estimated runtime** | ~10 seconds locally, excluding a cold dependency build |

## Sampling Rate

- **After docs/index changes:** run the two consumer modules, launch-pack contract, and `mix docs --warnings-as-errors`.
- **After rationale-protection changes:** run both fixtures plus the empty-input failure case.
- **After repository-object changes:** compare worktree count and stash SHAs with the committed snapshot.
- **Before `$gsd-verify-work`:** run the full Phase 237 seam suite, including live Pages read-back.
- **Max observed feedback latency:** under 10 seconds on the 2026-09-19 refresh.

## Requirement Verification Map

| Requirement | Plans | Secure Behavior | Test Type | Automated Evidence | Status |
|-------------|-------|-----------------|-----------|--------------------|--------|
| GREEN-03 | 02, 06 | Publish only the dedicated branch; independently prove green status | external seam | Pages API source/status + latest build + HTTP 200/404 control | ✅ green |
| REPO-01 | 01, 06 | Fresh checkout is clean without deleting scoped evidence | integration | literal local clone, all-untracked status, ignore positive/negative controls | ✅ green |
| REPO-02 | 01, 06 | Tracked docs index survives generation and all consumers | integration | warning-free docs build, byte-clean index, 7 ExUnit tests, launch-pack contract | ✅ green |
| REPO-03 | 03, 06 | One worktree remains; protected local stashes remain byte-identical | state seam | worktree count + exact six-SHA comparison to sanitized snapshot | ✅ green |
| SURF-02 | 04, 05, 06 | Dead planning links are absent without deleting security rationale | unit + integration | RED/GREEN/fail-closed guard, file scans, suppression-list proof, docs gate | ✅ green |

## Wave 0 Requirements

Existing infrastructure and committed phase-local fixtures cover all phase requirements. No Wave 0 additions are required.

## Manual-Only Verifications

All phase behaviors have automated verification. `237-UAT.md` contains 21 machine-resolved checks and zero manual checkpoints.

## Validation Audit 2026-09-19

| Metric | Count |
|--------|-------|
| Requirements audited | 5 |
| Missing automated seams | 0 |
| Manual-only checks | 0 |
| Gaps resolved during audit | 0 |

## Validation Sign-Off

- [x] Every requirement maps to a deterministic command or external read-back.
- [x] Failure direction is proven for absence and prohibition checks.
- [x] No watch-mode flags or sleeps are used.
- [x] API rate budget is read before live GitHub evidence.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** approved 2026-09-19

