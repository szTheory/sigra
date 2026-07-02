---
phase: 212-v1-42-integration-merge-canary-reconciliation-gate-the-perso
plan: "02"
subsystem: ci-configuration
tags:
  - ci
  - playwright
  - flow-specs
  - FLOW-01
dependency_graph:
  requires:
    - "example app boot + seed (from example_playwright_smoke job context — pre-existing)"
  provides:
    - "FLOW-01 execution-backed: persona-flow specs run in admin_behavior CI step"
    - "admin-flow-platform-admin, admin-flow-support-investigator, admin-flow-org-admin wired to chromium gate"
  affects:
    - "example_playwright_smoke job outcome (adds 3 specs to admin_behavior seam)"
tech_stack:
  added: []
  patterns:
    - "Appended spec paths to existing npx playwright test run block using backslash continuation style"
key_files:
  created: []
  modified:
    - ".github/workflows/ci.yml"
decisions:
  - "D-05: Append to existing admin_behavior step rather than create a new job — reuses booted app + seeded personas at near-zero marginal cost"
  - "D-06: chromium only — specs match ADMIN_BEHAVIOR_SPECS pattern (playwright.config.ts:24-25); mobile testIgnore already excludes ADMIN_BEHAVIOR_SPECS (playwright.config.ts:98-99)"
  - "D-07: No aggregator changes needed — steps.admin_behavior.outcome is already summed at ci.yml:1102-1107"
metrics:
  duration: "<1m"
  completed: "2026-07-02T00:24:02Z"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
status: complete
---

# Phase 212 Plan 02: Wire Persona-Flow Specs into Admin Behavior CI Step Summary

Appended 3 admin-flow-*.spec.ts paths to the admin_behavior chromium run block in ci.yml, making FLOW-01 execution-backed (16 flow-spec tests now gated by CI) via the existing outcome aggregator at zero marginal infrastructure cost.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Append 3 persona-flow specs to admin_behavior chromium step (D-05/D-06) | 7a7da092 | .github/workflows/ci.yml (+6 lines) |

## What Was Built

The `admin_behavior` step in `.github/workflows/ci.yml` (step id: `admin_behavior`, within the `example_playwright_smoke` job) previously listed 4 specs. 3 persona-flow specs were appended before the `--project=chromium` flag:

- `tests/admin-flow-platform-admin.spec.ts` (6 tests — alice platform-admin persona)
- `tests/admin-flow-support-investigator.spec.ts` (5 tests — dave support-investigator persona)
- `tests/admin-flow-org-admin.spec.ts` (5 tests — frank/morgan org-admin persona)

These specs match `ADMIN_BEHAVIOR_SPECS` in `playwright.config.ts:24-25`, so they are routed to chromium only. The mobile project's `testIgnore` at `playwright.config.ts:98-99` already excludes `ADMIN_BEHAVIOR_SPECS`, eliminating any "wired but running nowhere" risk.

The existing outcome aggregator (`ci.yml:1102-1107`) already sums `steps.admin_behavior.outcome`, so a flow-spec failure fails the job fail-closed with no additional wiring.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

Automated verify passed:

```
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" — YAML valid
grep -q 'tests/admin-flow-platform-admin.spec.ts' .github/workflows/ci.yml — FOUND
grep -q 'tests/admin-flow-support-investigator.spec.ts' .github/workflows/ci.yml — FOUND
grep -q 'tests/admin-flow-org-admin.spec.ts' .github/workflows/ci.yml — FOUND
grep -c 'admin-flow-.*mobile|--project=mobile.*admin-flow' .github/workflows/ci.yml — 0 (no mobile wiring)
```

All 4 acceptance criteria met:
- ci.yml parses as valid YAML
- All 3 admin-flow-*.spec.ts paths appear in the admin_behavior step's run block
- The 3 flow specs are NOT wired to a mobile project
- No new CI job was added

## Requirement Closure

- **FLOW-01 CLOSED**: The 3 persona-flow specs (16 tests total) now execute in the `example_playwright_smoke` `admin_behavior` CI step on chromium. The audit ledger's flow-* Tier-2 citations are execution-backed.

## Self-Check: PASSED

- [x] `.github/workflows/ci.yml` modified: confirmed (lines 991-1003)
- [x] Commit `7a7da092` exists: `feat(212-02): wire 3 persona-flow specs into admin_behavior CI step (FLOW-01)`
- [x] YAML parse: valid
- [x] All 3 spec paths present in admin_behavior step
- [x] No mobile project wiring introduced
