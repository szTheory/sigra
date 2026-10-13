---
status: resolved
trigger: 'Phase 253 registration runner setup failure'
created: 2026-10-13T12:16:53Z
updated: 2026-10-13T12:56:14Z
goal: find_and_fix
scope: runner startup only; no registration reproduction budget reset
capture_head: 38a4ecf89424638242e1807900fb8a0b64bc2d43
capture_status: clean
---

## Current Focus

hypothesis: Confirmed: the `/var/folders` versus `/private/var/folders` alias broke Mix's relative JOSE include symlink, and the earlier failure path lost its terminal setup receipt.
test: The committed final setup-only entrypoint completed once in 76 seconds; each of three projects completed database setup and drop with exit 0 and served HTTP 200, with zero browser invocations. Exact native receipt and 12 raw logs were bound by SHA-256 and committed.
expecting: Scoped startup repair is complete. The historical registration failure still has no surviving raw record, so registration acceptance and Phase 253 verification remain unproven.
next_action: none in this scoped startup debug; parent continues Phase 253 evidence and routing without resetting the original registration freeze
reasoning_checkpoint:
  hypothesis: Mix writes a broken relative JOSE include symlink when the runner supplies an aliased `/var/folders` build path while the dependency source resolves to `/private/var/folders`; JOSE Record.extract then fails with enoent.
  confirming_evidence:
    - The one allowed real entrypoint run failed at `build-admin-eval/lib/jose/include/jose_jwt.hrl` with enoent and retained its raw log.
    - The same JOSE source compiled with canonical `/private/var/folders/...` MIX_BUILD_PATH but failed with aliased `/var/folders/...`; the latter generated a broken relative include symlink.
  falsification_test: If the canonical build path still produced a broken JOSE include link or failed to compile, the alias explanation would be false.
  fix_rationale: Canonicalize each temp root before deriving MIX_BUILD_PATH and checkout paths so Mix computes a valid relative link between the source and build directories.
  blind_spots: The original historical retry lacks its raw log; no additional real Phoenix entrypoint run is allowed under the just-used freeze.
  candidate_causes:
    - code: runner passes noncanonical temp-root path into MIX_BUILD_PATH
    - environment: macOS TMPDIR uses `/var/folders`, an alias of `/private/var/folders`
  and_gate: yes; the broken link requires both the noncanonical path supplied by the runner and the host's aliased temp directory.
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
- timestamp: 2026-10-13T12:44:34Z
  checked: JOSE-only differential compilation using identical source and aliased versus canonical MIX_BUILD_PATH
  found: `os.tmpdir()` returns `/var/folders/...`, whose real path is `/private/var/folders/...`. Aliased build failed with JOSE header enoent and a broken include symlink; canonical build compiled 113 Erlang and 8 Elixir files and its header link resolves. Raw compile logs have SHA-256 cbf06d4bcd3e1c183d6d5b6b7caa982ca17dca53e7cd5ce3ef73e82c9df3a3dd (red) and 1b18d3ea7eda3bc01e9d66e8b141172be0197b55117549b7fb6ddbed7d0be1fa (green).
  implication: Temp-path aliasing, not the independent build itself, caused the reproducible JOSE include failure. Canonicalize temp roots in both entrypoints.
- timestamp: 2026-10-13T12:48:35Z
  checked: Regression test before and after canonical temp-root fix; adjacent runner tests and preserved evidence identities
  found: New symlinked-TMPDIR test failed before the fix on an aliased `MIX_BUILD_PATH`, then passed after `fs.realpathSync` in setup-only mode and `pwd -P` in the original runner. Full scoped suite passed 5/5 fixture tests and verifier checks; shell and Node syntax checks passed. Original freeze/evidence hashes remain 9c9404c08c14d636cacd0ce6b33e5226889eebd53940372ba660bef8717f2994 and b8636858bad7fcd576a235ee365213ee173b308b6470a728ce86736cf18a5a51. Failed-entrypoint receipt remains e91526eea5fb48f11c834b60f3b33da788c094a457d6e93c3eca0369877486bd.
  implication: Local code-level and dependency-only checks support the fix, but setup completion in the actual entrypoint awaits a separately bounded real run.
- timestamp: 2026-10-13T12:56:14Z
  checked: Final separately frozen setup-only actual entrypoint, exact raw evidence binding, owned port cleanup, and fresh scoped regression suite
  found: One invocation exited 0 after 76 seconds at source HEAD 46399bddc; three project setup commands and three database drops exited 0; Phoenix returned HTTP 200 on ports 25311, 25312, and 25313; zero browser invocations and no listeners remained on those ports. Native receipt plus all 12 raw logs are byte-identical to their committed copies at 1592b3c81, and the receipt hashes match every log. Sequential `bash scripts/ci/ci-registration-repro.test.sh` passed all five fixture tests and verifier checks. Existing failed receipt, local differential, original freeze, and registration evidence hashes stayed unchanged.
  implication: The scoped startup repair is verified. This result provides no registration browser result and does not explain the historical registration failure.

## Resolution

root_cause: Confirmed two runner defects: Bash errexit at failed setup lost the project result/raw log; and a `/var/folders` temp-root alias produced a broken relative JOSE include symlink when Mix resolved the source under `/private/var/folders`. The historical retry lacks raw logs, so its exact cause cannot be proven retrospectively.
fix: Added an independent setup-only diagnostic with immediate command receipts and zero browser commands; moved frozen output mutation behind source identity validation; canonicalized temporary roots in both runners before deriving Mix build paths.
verification:
  target_test: {result: pass, command: "bash scripts/ci/ci-registration-repro.test.sh", cases: 5, pre_fix_result: red_for_symlinked_TMPDIR}
  mutation_check: {result: skipped, reason: "No configured Stryker setup for shell/Node runner"}
  no_op_deletion: {result: pass, deletion_justified_by_rca: false, note: "Canonicalization changes only temp path spelling and does not skip setup or startup."}
  adjacent_tests: {result: pass, suites_run: ["bash scripts/ci/ci-registration-repro.test.sh", "bash -n scripts/ci/ci-registration-repro.sh", "node --check scripts/ci/ci-registration-setup-diagnostic.mjs"]}
  revert_and_reconfirm: {result: pass_local, bug_returned_on_pre_fix: true, fixed_on_apply: true, note: "Same symlinked-TMPDIR regression was red before canonicalization and green after; no live rerun was made."}
  final_actual_entrypoint: {result: pass, source_head: 46399bddc62dd3813ea2e0a136a35804a8ffa353, cli_exit: 0, duration_seconds: 76, project_launches: 3, setup_exit_zero: 3, http_200: 3, drop_exit_zero: 3, browser_invocations: 0, evidence_commit: 1592b3c81, receipt_sha256: 0a9140738f3415399773c03577609dd37bafe6f5b596982d899ad25f6e3c30d1}
  evidence_binding: {result: pass, manifest: .planning/debug/phase253-setup-final-20261013T125238Z/manifest.json, raw_logs: 12, byte_exact_readback: true}
  guardrail_verdict: accepted_for_scoped_startup_only
  live_setup_probes: "3/3 clean-clone database setups and Phoenix launches returned HTTP 200 on ports 25311, 25312, 25313 before the code repair; zero browser invocations."
files_changed:
  - scripts/ci/ci-registration-repro.sh
  - scripts/ci/ci-registration-repro.test.sh
  - scripts/ci/ci-registration-setup-diagnostic.mjs
  - scripts/ci/ci-registration-setup-diagnostic.test.mjs
code_commits: [4ffa9dcb1, c91a85c0d, dd5859dc5]
failed_entrypoint_evidence_commit: e17c1fa4f
local_compile_evidence_commit: f16fd670c
registration_acceptance: unverified; historical registration failure unexplained; Plan 02 remains halted; Phase 253 verification has not started

## Prevention

- Code branch: the setup runner built `MIX_BUILD_PATH` from the spelling returned by `os.tmpdir()`, so Mix used an aliased path while JOSE's dependency source resolved through the canonical path. Mix's relative include link then pointed to a missing file. Both runner entrypoints now canonicalize their temporary root before deriving build and checkout paths.
- Environment branch: on this macOS host, `/var/folders` resolves to `/private/var/folders`. The failure required that alias together with the runner's noncanonical path; the JOSE-only red/green differential isolated that interaction.
- Evidence branch: shell `errexit` stopped the old setup runner before it wrote a project result or retained the failing command log. The setup-only diagnostic now writes command results and raw logs as each step completes, including failures.
- Why not caught: no existing runner test exercised a symlinked `TMPDIR` or asserted a retained nonzero setup receipt. The frozen browser workflow could not diagnose setup because it never reached a browser.
- Recurrence guard: `scripts/ci/ci-registration-setup-diagnostic.test.mjs` tests both a symlinked `TMPDIR` with a resolvable JOSE include path and retention of a failed setup command without a browser launch. The five fixture tests and final real entrypoint check passed.
