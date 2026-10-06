# Phase 246 Plan 03: Local CI Gate Blocker

`MIX_ENV=test mix ci` was run from a clean detached checkout at source SHA `78f973a43e24b0813029b0dec2285dd3f5f54a8b` on 2026-10-06. It exited 2 in the full ExUnit stage with 2,623 tests, 17 failures, 12 skips, and 22 exclusions. The subsequent focused threadline guard stage passed 65 tests with 0 failures.

The full-suite failures are outside Plan 246-03's product and test files. The run exposed existing cross-phase contract gaps in the committed source tree:

- `Sigra.Planning.Phase242ShiftLeftContractTest`: README lacks the supported install tuple; `.planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md` is absent.
- `Sigra.Planning.Phase236EvidenceProvenanceGuardTest`: `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md` is absent.
- `Sigra.Planning.Phase234PlaywrightInventoryContractTest`: inventory validation and live-spec reconciliation fail against the committed inventory/lane state.
- `Sigra.Planning.Phase235Fast01SourceCompleteContractTest`: source-completion and authenticated strict-pass reconciliation contracts fail against the committed phase artifacts.
- Additional failures include the Phase 232 Playwright cache-key contract and Threadline forwarder tests; these predate Plan 246-03 and are not included in its implementation scope.

The phase 242 formatter-only prerequisite repair was completed as authorized, but it did not supply the missing phase artifact or README content. The plan did not change unrelated cross-phase behavior to force this gate green. No GitHub workflow was pushed or dispatched after the mandatory local gate failed, so `install_smoke`, `generated_admin_playwright_smoke`, and `ci-gate` have no current-SHA workflow conclusions. The generated-host local acceptance smoke and the three-test CI route contract both passed at the recorded SHA.

The run's full output was captured at `/private/tmp/sigra-phase-246-03-mix-ci.log`; the failure categories and outcome needed for follow-up are retained here and in `246-CI-EVIDENCE.json`.
