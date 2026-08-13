---
phase: 244-pat-and-advanced-jwt-truth-repair
plan: 07
subsystem: installer-contracts
tags: [pat, jwt, installer, templates, ci, tdd]
requires:
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: "Independent PAT browser-management and JWT host-policy generator contracts"
provides:
  - "Exact 56-file core-template inventory and sorted manifest contract"
  - "PAT post-install guidance that names the generated browser/sudo route"
  - "Current focused and repository-wide CI evidence with failure attribution"
affects: [PAT-01, PAT-02, JWT-01, JWT-02, installer-ci]
tech-stack:
  added: []
  patterns:
    - "Template layout is protected by both an exact count and sorted full-manifest equality."
    - "Adopter-facing PAT instructions identify the browser/session management boundary, never a bearer-management path."
key-files:
  created: []
  modified:
    - test/sigra/install/isolation_test.exs
    - test/sigra/install/templates_layout_test.exs
    - lib/sigra/install/features/core.ex
    - test/sigra/install/features/core_post_instructions_test.exs
key-decisions:
  - "The CI inventory remains a 56-entry exact sorted manifest, including the independently shipped JWT and no-LiveView templates."
  - "The --api installer output points to /users/api-tokens, the generated browser/authenticated/sudo PAT surface."
requirements-completed: [PAT-01, PAT-02, JWT-01, JWT-02]
coverage:
  - id: D1
    description: "Core template inventory and sorted layout manifest recognize all 56 shipped templates."
    requirement: JWT-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs test/sigra/install/features/core_post_instructions_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "API post-install guidance names the generated browser PAT management route while JWT guidance remains host-policy-only."
    requirement: PAT-02
    verification:
      - kind: integration
        ref: "test/sigra/install/features/core_post_instructions_test.exs#--api directs adopters to browser PAT management"
        status: pass
    human_judgment: false
metrics:
  duration: 3min
  completed: 2026-08-13
  tasks: 1
  files: 4
status: complete
---

# Phase 244 Plan 07: Template Inventory and PAT Guidance Summary

**The installer now locks its complete 56-template footprint and directs PAT adopters to the generated browser/sudo management route at `/users/api-tokens`.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-12T23:59:19Z
- **Completed:** 2026-08-13T00:02:06Z
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Raised both CI-facing core-template inventory contracts from 52 to exactly 56 files while preserving the isolation scan and flat-directory prohibition.
- Extended the sorted full manifest with `auth_jwt.ex`, `rate_limit.ex`, `registration_controller.ex`, and `settings_controller.ex`, retaining exact directory equality rather than weakening the test to a count or subset check.
- Changed `--api` post-install guidance and its output test to `/users/api-tokens`, matching the generated browser/authenticated/sudo PAT management routes; JWT instructions remain independent and host-policy-only.

## Task Commits

1. **Task 1: Reconcile the shipped template inventory and PAT guidance through CI-facing contracts** — `7b4888b1` (RED), `971364c2` (GREEN)

## Files Created/Modified

- `test/sigra/install/isolation_test.exs` — asserts the intentional 56-file core inventory while retaining forbidden-symbol scanning.
- `test/sigra/install/templates_layout_test.exs` — maintains the explicit sorted 56-entry manifest and physical-layout equality contract.
- `lib/sigra/install/features/core.ex` — tells `--api` adopters about browser PAT management at `/users/api-tokens`.
- `test/sigra/install/features/core_post_instructions_test.exs` — pins the browser route and rejects the stale `/api/tokens` text.

## Decisions Made

- Treat the four templates as shipped core artifacts, not optional omissions: all future additions or removals must update the exact manifest deliberately.
- Describe PAT administration as browser-session management to preserve D-03’s CSRF, authenticated Scope, and recent-sudo boundary.

## TDD Gate Compliance

- RED commit `7b4888b1` made the route contract fail against the stale installer output; the inventory contracts were already redressed by the repository’s physical 56-file layout.
- GREEN commit `971364c2` changed only the installer output and made the focused suite pass.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs test/sigra/install/features/core_post_instructions_test.exs --trace` — passed twice, 20 tests / 0 failures; the second pass is the tracer feedback gate.
- `source tmp/db.env && MIX_ENV=test mix format --check-formatted test/sigra/install/isolation_test.exs test/sigra/install/templates_layout_test.exs lib/sigra/install/features/core.ex test/sigra/install/features/core_post_instructions_test.exs` — passed.
- `source tmp/db.env && MIX_ENV=test mix ci` — exit status 1: 2,625 tests, 27 failures, 12 skipped (26 excluded). No failure came from this plan’s four modified contracts.

### Repository CI Failure Inventory

The CI result is non-passing and is not waived. The 27 failures are outside the four modified contracts:

1. `Sigra.Planning.Phase239HostedSessionInteropTest` — `test/sigra/planning/phase_239_hosted_session_interop_test.exs:25`, missing `239-CROSSWAKE-RELEASE-PROOF.json`.
2. `Sigra.Planning.Phase239HostedSessionInteropTest` — `test/sigra/planning/phase_239_hosted_session_interop_test.exs:91`, missing Phase 239 `COVERAGE.md`.
3. `Sigra.Install.GeneratorWiringTest` — `test/sigra/install/generator_wiring_test.exs:173`, stale reset-password route source assertion.
4. `Sigra.Install.GeneratorWiringTest` — `test/sigra/install/generator_wiring_test.exs:84`, stale `request_password_reset` template assertion.
5. `Sigra.Install.GeneratorWiringTest` — `test/sigra/install/generator_wiring_test.exs:165`, stale confirmation-route source assertion.
6. `Sigra.ArchitectureGuidesContractTest` — `test/sigra/architecture_guides_contract_test.exs:241`, walkthrough source excerpt drift.
7. `Sigra.Planning.Phase2403HostedCrosswakeRuntimeTest` — `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs:256`, missing `240.3-09-PLAN.md`.
8. `Sigra.Planning.Phase2403HostedCrosswakeRuntimeTest` — `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs:383`, missing hosted Crosswake runtime evidence JSON.
9. `Sigra.Planning.Phase2403HostedCrosswakeRuntimeTest` — `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs:282`, missing Phase 240.3 `COVERAGE.md`.
10. `Sigra.Planning.Phase236CloseoutEvidenceReconciliationContractTest` — `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs:364`, scope fence rejects the user-modified `.planning/config.json`.
11. `Sigra.Planning.Phase236CloseoutEvidenceReconciliationContractTest` — `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs:213`, traceability-map mismatch.
12. `Sigra.Planning.Phase235TerminalRatificationContractTest` — `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:667`, missing FAST-01 residual todo artifact.
13. `Sigra.Planning.Phase235TerminalRatificationContractTest` — `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:677`, missing FAST-01 residual todo artifact.
14. `Sigra.Templates.InstallerDriftTest` — `test/sigra/templates/installer_drift_test.exs:370`, missing `user_token_schema` in password-reset template wiring.
15. `Sigra.Planning.Phase235Fast01GapClosureContractTest` — `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs:146`, missing FAST-01 residual todo artifact.
16. `Sigra.Planning.Phase234EvidenceContractTest` — `test/sigra/planning/phase_234_evidence_contract_test.exs:673`, validation-signoff inventory mismatch.
17. `Sigra.Planning.Phase240NoSecretsCiTest` — `test/sigra/planning/phase_240_no_secrets_ci_test.exs:136`, missing Phase 240 `COVERAGE.md`.
18. `Sigra.Planning.Phase234PlaywrightInventoryContractTest` — `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs:75`, missing live Playwright specs.
19. `Sigra.Planning.Phase234PlaywrightInventoryContractTest` — `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs:121`, missing live Playwright specs prevent sibling-marker validation.
20. `Sigra.Planning.Phase234PlaywrightInventoryContractTest` — `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs:136`, missing live Playwright specs prevent exact-harness validation.
21. `Sigra.Planning.Phase234PlaywrightInventoryContractTest` — `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs:47`, inventory does not reconcile three missing live specs.
22. `Sigra.Audit.Forwarders.ThreadlineTest` — `test/sigra/audit/forwarders/threadline_test.exs:145`, Threadline happy-path forwarding contract.
23. `Sigra.Audit.Forwarders.ThreadlineTest` — `test/sigra/audit/forwarders/threadline_test.exs:252`, Threadline thrown-error forwarding contract.
24. `Sigra.Audit.Forwarders.ThreadlineTest` — `test/sigra/audit/forwarders/threadline_test.exs:181`, Threadline handler auto-detach contract.
25. `Sigra.Audit.Forwarders.ThreadlineTest` — `test/sigra/audit/forwarders/threadline_test.exs:279`, Threadline no-audit-rollback contract.
26. `Sigra.Audit.Forwarders.ThreadlineTest` — `test/sigra/audit/forwarders/threadline_test.exs:336`, Threadline forwarding metadata contract.
27. `Sigra.Audit.Forwarders.ThreadlineTest` — `test/sigra/audit/forwarders/threadline_test.exs:227`, Threadline exit-error forwarding contract.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered

- The required repository diagnostic is currently red for the 27 explicit failures above. They remain open repository debt; this plan did not change their files or label the gate as passing.

## User Setup Required

None - the supplied `tmp/db.env` PostgreSQL configuration was sourced for verification.

## Next Phase Readiness

The Phase 244 installer integration gap is closed and its focused contracts are green. Full repository CI remains blocked by the listed non-244-07 failures.

## Self-Check: PASSED

Verified the four declared source/test files exist, the RED and GREEN commits are in git history, the manifest names all four reconciled templates, and the focused 20-test suite passed after the final commit.
