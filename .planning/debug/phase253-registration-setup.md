---
status: verifying
trigger: 'Phase 253 registration runner setup failure'
created: 2026-10-13T12:16:53Z
updated: 2026-10-13T12:41:24Z
goal: find_and_fix
scope: runner startup only; no registration reproduction budget reset
capture_head: 38a4ecf89424638242e1807900fb8a0b64bc2d43
capture_status: clean
---

## Current Focus

hypothesis: The setup-only entrypoint's external MIX_BUILD_PATH differs from the three earlier successful probes and causes JOSE include files to be absent from its compiled dependency path.
test: Compare the failed receipt and log against the prior successful probe configuration, then reproduce only the dependency compile with local build-path variants; do not launch Phoenix or rerun the frozen entrypoint.
expecting: The external path fails with a missing build/lib/jose/include header while an in-project build path retains it, or evidence disproves the path hypothesis.
next_action: inspect the prior probe build paths and JOSE/Mix include layout, then run a bounded dependency-only differential check if needed
reasoning_checkpoint:
  hypothesis: A nonzero setup command exits the current runner before its evidence writer because Bash errexit is active.
  confirming_evidence:
    - The script begins with `set -Eeuo pipefail` and runs `mix ecto.setup` as a bare command on line 119.
    - The project evidence JSON writer is after ecto.setup, Phoenix readiness, and Playwright; the retained attempt recorded a compile failure with zero browser invocations and no raw compiler log.
  falsification_test: A failure-injected setup command that exits nonzero but still writes the current runner's project evidence would disprove the early-abort explanation.
  fix_rationale: A separate setup-only path records command outcomes immediately and never reaches Playwright, preserving an exact startup diagnostic without altering the exhausted frozen run.
  blind_spots: The historical JOSE raw compiler error is unavailable and all three current real startup probes passed; the original compile root cause remains unknown.
  candidate_causes:
    - code: shell errexit before evidence write and output mutation before source validation
    - environment: an earlier compile/include failure triggered the early-exit path, but its specific cause is not retained
  and_gate: The evidence-loss symptom requires a setup command to fail and the code to exit before recording it; the original compile cause remains unresolved.
bug_class: Bohrbug candidate (build/config startup failure)
candidate_causes:
  - code: runner sets MIX_BUILD_PATH independently for each project after deps.get
  - config: PORT is read at Mix config compilation and could be stale in a shared build
  - environment: local OTP/Hex dependency source or Postgres could differ from the retained attempt
and_gate: unknown until compile and startup results distinguish build from environment

## Symptoms

expected: The isolated runner restores locked dependencies, creates a fresh project database, starts the real Phoenix app, and reaches HTTP readiness before running the selected registration test.
actual: Setup fails before the app is HTTP-ready. All three registration projects remain not_run and browser invocations remain zero.
errors: The final allowed infrastructure retry failed during dependency compilation because the per-project Mix build path omitted a JOSE include artifact. Earlier attempts hit read-only Hex cache, a closed output pipe, and lost launcher ownership/shared compilation for another port.
timeline: Phase 253 Plan 02 execution on 2026-10-13; retained summary records the one infrastructure retry as exhausted.
reproduction: scripts/ci/ci-registration-repro.sh --run-frozen using 253-REPRO-FREEZE.json; do not rerun that exhausted freeze. Use a separate bounded setup-only diagnostic with no browser invocation.
source: Symptoms are already established in the preceding session and committed phase records; no missing user report is needed.

## Required Reading

- AGENTS.md
- scripts/ci/ci-registration-repro.sh
- scripts/ci/ci-registration-repro.test.sh
- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPRO-FREEZE.json
- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REGISTRATION-EVIDENCE.json
- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-02-SUMMARY.md
- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-POSTEXEC-DISPOSITION.md

## Boundaries

- Repair and verify startup only. Do not reset the original freeze, retry allowance, or terminal evidence. Do not invoke registration browser tests in this debug task.
- A setup-only integration check must have a new explicit record, at most three project launches and twenty minutes total, no automatic retry. Preserve all nonzero results.
- Leave registration acceptance fail closed, CIREL-01/CIREL-02 open, Plans 02/07 halted and 08 blocked until their separate proof work completes.
- Do not change product registration helpers, Playwright selections, retry behavior, lockfiles, required check names, hosted canary records, or Phase 252 paths.
- No GitHub calls or hosted runs are needed for this startup repair.
- Preserve exact dirty planning bytes before replacements, including this session checkpoint. Commit specific paths only; verify read-back before mutation. Initial checkpoint is preserved before delegation.
- Code ownership: scripts/ci/ci-registration-repro.sh and its scoped setup tests/support module; debug-session evidence only under .planning/debug/. Parent owns shared state/handoff and phase summaries.

## Eliminated

- hypothesis: A fresh MIX_BUILD_PATH by itself causes JOSE to miss an include artifact.
  evidence: JOSE compiled successfully from installed dependency sources in a new build path: 113 Erlang and 8 Elixir files, exit 0.
  timestamp: 2026-10-13T12:22:02Z
- hypothesis: Clean-clone dependency restoration plus fresh MIX_BUILD_PATH causes JOSE to miss an include artifact.
  evidence: deps.get --check-locked and a forced JOSE compile both exited 0 in a clean clone with scoped HEX_HOME and MIX_BUILD_PATH; eight JOSE .hrl include files exist there.
  timestamp: 2026-10-13T12:22:38Z
- hypothesis: Full app compilation invoked by ecto.setup produces the reported JOSE include failure.
  evidence: Clean-clone ecto.setup completed with exit 0, created/migrated/seeding sigra_253_setup_debug_121 on port 25311 configuration, using the fresh scoped build.
  timestamp: 2026-10-13T12:24:00Z

## Evidence

- timestamp: 2026-10-13T12:16:53Z
  checked: Initial git status and retained registration evidence
  found: Working tree clean at 38a4ecf89424638242e1807900fb8a0b64bc2d43; zero browser runs and exhausted infrastructure retry recorded.
  implication: Repair setup independently; do not classify the historical registration failure from startup results.
- timestamp: 2026-10-13T12:20:33Z
  checked: Runner, app config, JOSE source, database readiness, project skill discovery, and knowledge base
  found: Runner exports a fresh per-project MIX_BUILD_PATH before ecto.setup; JOSE include files exist in deps/jose/include; dev.exs reads PORT during config compilation; PostgreSQL accepts connections at 127.0.0.1:58624; no matching prior debug pattern or project skill was found. No raw JOSE error log is retained.
  implication: The previous summary does not prove which include was missing; a scoped compile experiment must distinguish build-path failure from another cause.
- timestamp: 2026-10-13T12:22:02Z
  checked: Bounded JOSE-only compile with fresh MIX_BUILD_PATH and HEX_HOME
  found: Exit 0; 113 .erl and 8 .ex files compiled; log /private/tmp/sigra-253-jose.Zs4CQD/compile.log has SHA-256 d1a9e25db1be1368fc28445f4b44125d8747405bfa4d9ce73b0c4273282b1721.
  implication: Per-project build isolation is not a sufficient cause; fresh dependency restoration must be checked separately.
- timestamp: 2026-10-13T12:22:38Z
  checked: Fresh clone dependency restoration and isolated JOSE compilation
  found: git clone/checkout, locked deps.get, and JOSE compile all exited 0; deps log /private/tmp/sigra-253-clean.ZKJQW5/deps.log SHA-256 ee40e9ae3f91d46a4dab2c178493d639c5b57342800cc4438e5b89c45cfb434a; compile log has the same successful SHA-256 as the first experiment.
  implication: Neither clean dependency restore nor independent JOSE compilation reproduces the summarized historical failure; next test full app compilation.
- timestamp: 2026-10-13T12:24:00Z
  checked: Full ecto.setup in fresh clone with scoped build and database
  found: Exit 0, database sigra_253_setup_debug_121 migrated and seeded; output log SHA-256 8dfe7f41cc51af794b6d33d5dbe0f238c5c42958b80144f9707e58d1ad935ec2.
  implication: Current clean-clone setup reaches database readiness; test owned Phoenix launch and HTTP next.
- timestamp: 2026-10-13T12:25:16Z
  checked: First clean-clone Phoenix launch and HTTP probe
  found: Owned PID 37873 stayed alive, bound 127.0.0.1:25311, served HTTP 200 twice, and shut down on SIGTERM; app log SHA-256 555dda006991ccacdcd57b58d863110c8722a4d24acbc7c766eb2141e7d5e3a1.
  implication: Current launcher works for admin-eval; distinct port/build projects remain untested.
- timestamp: 2026-10-13T12:26:40Z
  checked: Second clean-clone build, database setup, Phoenix launch and HTTP probe
  found: Fresh build and ecto.setup exited 0; owned PID 41233 stayed alive, bound 127.0.0.1:25312, served HTTP 200 twice, and shut down on SIGTERM. Database log SHA-256 7ffb0fae4a4475eec9f9ff030a96cce2face4c23a364c6a30f4d51188f393476; app log SHA-256 fafa8587c914499f1ea0c375a0d4fa7fe25f788724076bcc821c53906dbc2240.
  implication: The second project's distinct build did not reproduce stale PORT or missing JOSE include.
- timestamp: 2026-10-13T12:28:37Z
  checked: Third clean-clone build, database setup, Phoenix launch, HTTP probe, and frozen evidence identities
  found: Fresh build and ecto.setup exited 0; owned PID 42696 stayed alive, bound 127.0.0.1:25313, served HTTP 200 twice, and shut down on SIGTERM. Database log SHA-256 841a1e4aa7f80949bf0c2d3c4a9ef166d6459d2d3f120076539b8dd334761f4e; app log SHA-256 42efae226887df85f9bbc67648419604e6425c65168b6f9bbd2d50b9cd3de968. Original freeze/evidence SHA-256 remain 9c9404c08c14d636cacd0ce6b33e5226889eebd53940372ba660bef8717f2994 and b8636858bad7fcd576a235ee365213ee173b308b6470a728ce86736cf18a5a51.
  implication: All three allowed app launches reached HTTP readiness; the historical JOSE failure remains unconfirmed because its raw log was not retained. No more live launches are permitted in this diagnostic.
- timestamp: 2026-10-13T12:31:22Z
  checked: Runner failure paths and temporary database cleanup
  found: `set -e` can abort at ecto.setup before project evidence is written; the setup-only mode is absent; all three temporary databases dropped successfully with exit 0.
  implication: Repair the independently demonstrable evidence-loss path without claiming the historical JOSE root cause.
- timestamp: 2026-10-13T12:41:24Z
  checked: Single frozen setup-only entrypoint run and exact preservation of final receipt/raw logs
  found: Entry 3e23c7cbd invoked once and stopped after admin-eval ecto.setup exited 1; zero Phoenix launches and zero browser invocations. Raw log reports missing external-build `lib/jose/include/jose_jwt.hrl`; cleanup reports missing `jose_jwk.hrl`. Receipt and five raw logs were copied byte-identically and committed at e17c1fa4f under `.planning/debug/phase253-setup-entrypoint-20261013T124016Z/`; receipt SHA-256 e91526eea5fb48f11c834b60f3b33da788c094a457d6e93c3eca0369877486bd.
  implication: Evidence retention works, but real startup remains failed; investigate the external build path without another live run.

## Resolution

root_cause: Confirmed harness defect: Bash errexit at a failed setup command could stop the frozen runner before writing the project result or raw compiler log; output mutation also preceded source identity checks. The exact historical JOSE compile cause is unconfirmed.
fix: Added an independent setup-only diagnostic runner with immediate command receipts, bounded 20-minute/three-project execution, owned server cleanup, and zero browser commands; moved frozen output mutation behind source identity validation.
verification:
  target_test: {result: pass, command: "bash scripts/ci/ci-registration-repro.test.sh", cases: 4}
  mutation_check: {result: skipped, reason: "No configured Stryker setup for shell/Node runner"}
  no_op_deletion: {result: pass, deletion_justified_by_rca: false, note: "The change adds a diagnostic path and moves identity validation before output mutation; it does not short-circuit startup."}
  adjacent_tests: {result: pass, suites_run: ["bash scripts/ci/ci-registration-repro.test.sh", "bash -n scripts/ci/ci-registration-repro.sh", "node --check scripts/ci/ci-registration-setup-diagnostic.mjs"]}
  revert_and_reconfirm: {result: failed, reason: "The one allowed real entrypoint invocation reproduced a missing JOSE include under its external build path; no live retry is permitted."}
  guardrail_verdict: rejected_pending_local_diagnosis
  live_setup_probes: "3/3 clean-clone database setups and Phoenix launches returned HTTP 200 on ports 25311, 25312, 25313 before the code repair; zero browser invocations."
files_changed:
  - scripts/ci/ci-registration-repro.sh
  - scripts/ci/ci-registration-repro.test.sh
  - scripts/ci/ci-registration-setup-diagnostic.mjs
  - scripts/ci/ci-registration-setup-diagnostic.test.mjs
code_commit: 4ffa9dcb1
registration_acceptance: unverified; Plan 02 remains halted
