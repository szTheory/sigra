---
status: resolved
trigger: "Resolve the four failures blocking the Phase 246 clean-source MIX_ENV=test mix ci gate."
created: 2026-10-06
updated: 2026-10-06
---

## Symptoms

- **Expected behavior:** A clean checkout of the Phase 246 tested source passes `MIX_ENV=test mix ci`, allowing the required CI evidence to be captured and Phase 246 to resume.
- **Actual behavior:** The gate exits 2 after 33 doctests, 3 properties, and 2623 tests, with four failures in older planning contracts; the dependency-off guard passes 65 tests.
- **Error messages:**
  1. `Phase232PlaywrightEconomicsTest` expects two `playwright-chromium-1.62.1-v3` cache-key matches but finds zero in the committed workflow.
  2. `Phase236EvidenceProvenanceGuardTest` reads a missing live path `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md`; the evidence exists under `.planning/milestones/v1.48-phases/236-flake-root-cause-reproduce-name-fix/`.
  3. `Phase242ShiftLeftContractTest` reports `README.md lacks the supported tuple`; the tested committed README contains `{:sigra, "~> 1.4.0"}` while the contract expects the maintained line now in dirty Phase 244 work.
  4. `Phase242ShiftLeftContractTest` reads a missing live path `.planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md`; the closeout exists under `.planning/milestones/v1.48-phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/`.
- **Timeline:** Detected during the Phase 246-03 final clean-source CI run on tested source `fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a`, 2026-10-06. The working tree already had separate dirty Phase 244 Playwright and documentation updates; preserve them.
- **Reproduction:** On a clean checkout of the tested source, run `mix clean` followed by `MIX_ENV=test mix ci`. Full retained run: `/private/tmp/sigra-phase-246-final-ci.log`; machine-readable failures: `.planning/phases/246-generated-confirmation-recovery/246-MIX-CI-FAILURES.json`.

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

bug_class: Bohrbug (deterministic contract failures)
hypothesis: "All four Phase 246 clean-source failures are resolved by the scoped 13-file candidate."
test: "The isolated fd75cad baseline plus its 13-file patch passed the focused suite and full unsandboxed MIX_ENV=test mix ci after mix clean."
expecting: "Integrating the exact tested patch and its machine-readable evidence preserves the green result; dirty Phase 244 workflow and Playwright changes stay separate."
next_action: "Resume Phase 246 verification from integrated fix commit 4df425a62 and .planning/debug/phase246-four-ci-repair-evidence.json."
reasoning_checkpoint:
  hypothesis: "The four failures arise because two ExUnit tests read pre-archive paths, one ExUnit test hardcodes Playwright 1.62.1 despite a 1.59.1 lockfile/workflow pair, and the clean committed public docs still state 1.4.0 despite the 1.5.0 package and Phase 242 safety contract."
  confirming_evidence:
    - "The unchanged fd75cad clean worktree reproduces exactly four failures in 14 focused tests."
    - "The archived evidence files exist, and P12's archive-aware Node guard passes all 12 ledger checks on the same clean source."
    - "HEAD's workflow cache keys and lockfile both resolve to 1.59.1; the ExUnit contract alone expects 1.62.1."
    - "mix.exs declares 1.5.0 and Phase 242 closeout requires 1.5.0 installation snippets, while HEAD's README and guides still use 1.4.0."
  falsification_test: "If the original focused suite still fails after reading canonical archive paths, deriving expected cache versions from the lockfile, and applying the 1.5.0 doc corrections to a clean source snapshot, the diagnosis is incomplete."
  fix_rationale: "Canonical archive reads preserve immutable evidence checks; lockfile-derived assertions preserve exact 2/3 shard count while testing the source's current version; 1.5.0 doc changes make the shipped instructions satisfy the release safeguard."
  blind_spots: "A missing file masked a second Phase 242 assertion failure; the full mix ci gate may reveal further masked or seed-sensitive failures after the focused suite clears."
  candidate_causes:
    - "code: static ExUnit file paths and cache-key literal drifted from source ownership"
    - "data: committed public documentation retained stale install tuples"
    - "environment: a missing checkout file could indicate incomplete export, but git paths show the files were intentionally archived"
  and_gate: "Yes for the full gate: independent code-contract and documentation defects must all be repaired; no single one explains every failure."

## Eliminated
<!-- APPEND only -->

## Evidence
<!-- APPEND only -->

- timestamp: 2026-10-06
  checked: "The retained fd75cad clean worktree and current HEAD source against the four failing contracts"
  found: "The clean worktree is unchanged at the tested SHA. Current HEAD still has 1.59.1-v3 cache keys matching its 1.59.1 Playwright lockfile, README still says ~> 1.4.0 while mix.exs is 1.5.0, and both historical evidence files exist in the v1.48 archive. The main tree's Phase 244 workflow and install docs are separately dirty."
  implication: "The two version mismatches have different causes: the cache assertion hardcodes a future lock version, whereas the public install documents violate the maintained release contract. Historical file reads use pre-archive paths."

- timestamp: 2026-10-06
  checked: "Pre-fix focused ExUnit suite in the untouched fd75cad worktree"
  found: "14 tests, exactly four failures matching the retained full CI report: Phase 232 cache literal, Phase 236 missing live path, and Phase 242 README and closeout path."
  implication: "The four failures are reproducible without Phase 244 working-tree changes."

- timestamp: 2026-10-06
  checked: "P12 Node guard and public installation snippet diff"
  found: "P12 passes 12 tests by resolving the Phase 236 ledger through archiveAwareRelPath; all ten main-tree public snippets already have the 1.5.0 tuple as dirty Phase 244 changes, while HEAD has 1.4.0."
  implication: "The Phase 236 Node guard can retain its public live-path declaration; only the ExUnit historical read needs the archive path. The clean test snapshot must carry the already-written doc corrections, without touching the dirty main-tree files."

- timestamp: 2026-10-06
  checked: "Focused suite after the first three structural fixes and clean-snapshot documentation corrections"
  found: "13 of 14 tests pass; the newly reached Phase 242 assertion reads live v1.49 REQUIREMENTS.md and expects old v1.48 text. Archived v1.48 requirements exist and now mark REL-03/04 complete from later public evidence, REL-05 partial, and REL-06 unsatisfied."
  implication: "The original missing closeout path masked a second stale dependency; the contract must check the archived milestone's current record without erasing later outcomes."

- timestamp: 2026-10-06
  checked: "Focused suite after updating Phase 242 to the archived v1.48 requirements and its later recorded dispositions"
  found: "All 14 focused ExUnit tests pass; mix format --check-formatted passes on the three changed test files."
  implication: "The direct failure reproductions clear with evidence and shard-count assertions retained. The full clean-source gate remains the acceptance check."

- timestamp: 2026-10-06
  checked: "First full mix ci after mix clean in the isolated source snapshot"
  found: "33 doctests, 3 properties, 2623 tests, 2 failures, 12 skipped; all four originally reported contract failures cleared. Both remaining failures are Phase 235 nested sandbox-exec calls returning Operation not permitted (exit 71) under the enclosing tool sandbox. The dependency-off guard passed 65 tests. Log: /private/tmp/sigra-phase-246-repaired-ci.log."
  implication: "The source fixes are effective. Full-gate acceptance needs the same unsandboxed process condition used by the retained original CI run."

- timestamp: 2026-10-06
  checked: "Full MIX_ENV=test mix ci after mix clean, outside the enclosing process sandbox"
  found: "Exit 0: 33 doctests, 3 properties, 2623 tests, 0 failures, 12 skipped (22 excluded); dependency-off guard 65 tests, 0 failures. Log /private/tmp/sigra-phase-246-repaired-ci-unsandboxed.log has SHA-256 affec5f7b976c07c2916d00f4047d223c9696d837f2d18bce693906bc60d268b."
  implication: "All reported failures and adjacent suite checks pass in the required clean-source environment."

- timestamp: 2026-10-06
  checked: "Exact isolated candidate diff and machine-readable evidence"
  found: "The candidate changes only three planning tests and ten public install docs; git diff --check passes. Patch /private/tmp/sigra-phase-246-repair.patch has SHA-256 1ac0077ec056b9fe166bbc95e682b2b3eb42276676b362b94cc310345d029e42; .planning/debug/phase246-four-ci-repair-evidence.json records source and gate hashes."
  implication: "The tested source is reviewable and reproducible without absorbing other dirty Phase 244 files."

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: "Four independent deterministic source/contract mismatches: two historical ExUnit reads use retired live paths; the Phase 232 test hardcodes a future Playwright version; committed public install docs lag the 1.5.0 release contract."
fix: "Phase 232 now derives cache-key version from the Playwright lockfile while checking 2 Chromium and 3 Chromium-WebKit shard keys; Phase 236 reads its archived evidence while P12 retains archive-aware provenance coverage; Phase 242 reads archived closeout and requirements, checking the later recorded dispositions. The isolated clean-source candidate includes the existing dirty Phase 244 1.5.0 public-install doc corrections."
oracle_type: "derived (lockfile/workflow consistency) and specified (archived evidence and release-install contract)"
verification:
  target_test: {result: pass, detail: "14 focused ExUnit tests, 0 failures"}
  mutation_check: {result: skipped, reason_if_skipped: "Stryker is not configured for Elixir planning contracts"}
  no_op_deletion: {result: pass, deletion_justified_by_rca: false, detail: "No behavior deletion; historical assertions now address canonical evidence and preserve exact counts"}
  adjacent_tests: {result: pass, suites_run: ["full unsandboxed MIX_ENV=test mix ci: 2623 tests and 65 dependency-off tests, zero failures"]}
  revert_and_reconfirm: {result: pass, bug_returned_on_revert: true, fixed_on_reapply: true, detail: "The unchanged fd75cad worktree yielded the exact four failures; the same worktree with the scoped patch yielded zero focused and full-gate failures"}
  guardrail_verdict: accepted
files_changed:
  - test/sigra/planning/phase_232_playwright_economics_test.exs
  - test/sigra/planning/phase_236_evidence_provenance_guard_test.exs
  - test/sigra/planning/phase_242_shift_left_contract_test.exs
  - README.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/introduction/first-hour.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/introduction/getting-started.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/introduction/installation.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/recipes/companion-libs/accrue.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/recipes/companion-libs/lockspire.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/recipes/companion-libs/mailglass.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/recipes/companion-libs/relyra.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/recipes/companion-libs/rulestead.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)
  - guides/recipes/companion-libs/threadline.md (pre-existing dirty Phase 244 correction, mirrored into isolated candidate)

## Blameless Postmortem

why_not_caught: "The full clean-source gate ran after milestone archiving and release-document updates had drifted from historical test literals; no earlier gate exercised all four contracts together on the tested source."
guard: "Keep the Phase 232 version assertion derived from the Playwright lockfile, read retained milestone evidence at its archived path, and retain the Phase 242 public 1.5.0 install contract. The focused 14-test suite and full clean-source mix ci result are recorded in phase246-four-ci-repair-evidence.json."
integrated_commit: "4df425a62"
