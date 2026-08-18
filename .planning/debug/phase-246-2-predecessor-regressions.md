---
status: blocked
trigger: "Fix Phase 246.2 predecessor regression inventory: 55 unique test files, 774 tests, 27 failures."
created: 2026-08-18T00:00:00-04:00
updated: 2026-08-18T00:30:00-04:00
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

bug_class: bohrbug
reasoning_checkpoint:
  hypothesis: "Historical evidence tests fail because phase artifacts moved intact to .planning/milestones, while several source-contract tests still assert superseded shapes; the optional Threadline test runs without its dependency."
  confirming_evidence:
    - "All requested Phase 239, 240, and 240.3 artifacts exist byte-for-byte under .planning/milestones/v1.48-phases."
    - "The password-reset template forwards user_token_schema, but the legacy generator test expects the pre-alias/pre-normalization call literal."
    - "Threadline source intentionally defines its module only when Code.ensure_loaded?(Threadline), and the focused run reports that module unavailable."
  falsification_test: "After redirecting only verified historical paths and making optional-dependency test selection conditional, each corresponding focused test must pass while its content assertions remain intact."
  fix_rationale: "Redirecting only to retained archival artifacts preserves evidence validation; aligning source contracts with present secure wiring and conditionally skipping absent optional integration prevents false failures without weakening runtime behavior."
  blind_spots: "Some archived contracts may assert obsolete lifecycle text or inventory/workflow ownership that no longer matches active sources; those will be reclassified rather than forced green."
  candidate_causes:
    - "code: stale source-contract literals and documentation excerpt after intentional implementation evolution"
    - "data: archived phase evidence moved from .planning/phases to .planning/milestones"
    - "environment: optional :threadline dependency is absent from this lock/runtime"
  and_gate: "no — each failure cluster has an independent deterministic cause; no single test requires all three conditions."
hypothesis: "The remaining nine failures are not safely repairable by path restoration alone: Phase 234's archive inventory is incomplete for three active specs, Phase 236 asserts a superseded 24-row requirements map and a clean-worktree precondition, and Phase 235 tests use archived identity values as live paths."
test: "Run the remaining four affected modules after the verified repairs and inspect their precise failures."
expecting: "Failures will distinguish real active ownership gaps from stale historical harness assumptions."
next_action: "Report the committed repair and durable blockers to the execute-phase orchestrator; do not fabricate Phase 234 lane ownership or alter historical evidence identities."

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: "The predecessor regression inventory passes all 55 unique test files."
actual: "774 tests run with 27 failures, including architecture walkthrough drift, historical planning/evidence references, installer template drift, and an unavailable optional forwarder module."
errors: "architecture_guides_contract_test; phase_240_3_hosted_crosswake_runtime_test; installer_drift_test; audit/forwarders/threadline_test; additional historical evidence-contract failures."
reproduction: "source tmp/db.env; run the exact 55-file predecessor regression inventory used by the execute-phase gate."
started: "Observed during Phase 246.2 execute-phase predecessor regression gate on 2026-08-18."

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-18T00:00:00-04:00
  checked: "Phase 246.2 verification report"
  found: "The report identifies two independent current phase gaps (direct/refresh limiter isolation and fail-closed provenance identity validation), but the predecessor regression inventory failures are a separate gate with 27 deterministic failures."
  implication: "Do not conflate the known Phase 246.2 security gaps with regression-inventory repair unless a test directly establishes a connection."
- timestamp: 2026-08-18T00:05:00-04:00
  checked: "Phase 244 summary's preserved repository-CI failure inventory"
  found: "All 27 failures are explicitly enumerated: 1 architecture source excerpt, 3 installer generator wiring assertions, 1 installer template forwarding assertion, 6 Threadline forwarder assertions, and 16 historical planning/evidence assertions."
  implication: "The known failure set provides a complete baseline for focused reproduction and classification."
- timestamp: 2026-08-18T00:15:00-04:00
  checked: "Focused 12-module reproduction with isolated PostgreSQL"
  found: "147 tests ran with exactly 27 failures, matching the preserved inventory. Historical artifacts for Phase 239/240/240.3 and Phase 234/235 are retained under .planning/milestones; FAST-01 residual is legitimately deferred; Threadline is intentionally optional and absent."
  implication: "Artifact-path migration is safe only for found retained files; tests must not fabricate absent evidence or enable optional runtime dependencies."
- timestamp: 2026-08-18T00:30:00-04:00
  checked: "Focused repaired-cluster test run"
  found: "96 tests passed with 6 Threadline tests correctly skipped when its optional compiled forwarder module is absent. Commit 0e1ee0d3 records only archival path, exact source-contract, guide, residual-location, and conditional-dependency fixes."
  implication: "The repaired clusters are deterministic and do not require broader runtime changes."
- timestamp: 2026-08-18T00:30:00-04:00
  checked: "Remaining Phase 234/235/236 focused modules"
  found: "Phase 234 inventory lacks three active specs; Phase 235 terminal contract still mixes historical .planning/phases identities with live paths; Phase 236 rejects current untracked workspace files and expects an obsolete 24-row traceability map."
  implication: "The predecessor inventory is not green; these must be migrated as a coherent historical-contract design or the Phase 234 specs need actual CI ownership."

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: "The predecessor regression inventory mixes repairable archived-path/source drift with nine historical evidence-contract failures that require new verified CI ownership or a coherent Phase 234-236 archival-contract migration."
fix: "Commit 0e1ee0d3 repairs only evidence paths that resolve to retained artifacts, current secure generator/template contracts, the walkthrough excerpt, and optional Threadline selection. No evidence or CI ownership was fabricated."
verification: "The repaired clusters pass 96 tests with 0 failures and 6 legitimate optional-Threadline skips. The remaining four historical modules run 51 tests with 9 failures."
files_changed:
  - guides/introduction/code-walkthrough.md
  - test/sigra/audit/forwarders/threadline_test.exs
  - test/sigra/install/generator_wiring_test.exs
  - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
  - test/sigra/planning/phase_239_hosted_session_interop_test.exs
  - test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs
  - test/sigra/planning/phase_240_no_secrets_ci_test.exs
  - test/sigra/templates/installer_drift_test.exs
