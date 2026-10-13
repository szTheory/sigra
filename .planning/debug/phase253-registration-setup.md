---
status: investigating
trigger: 'Phase 253 registration runner setup failure'
created: 2026-10-13T12:16:53Z
updated: 2026-10-13T12:26:40Z
goal: find_and_fix
scope: runner startup only; no registration reproduction budget reset
capture_head: 38a4ecf89424638242e1807900fb8a0b64bc2d43
capture_status: clean
---

## Current Focus

hypothesis: The third project may expose a compile or port-binding failure not seen in the first two isolated builds.
test: Set up an independent database under a fresh admin-eval-dark build path, launch Phoenix on port 25313, probe HTTP, and stop the owned process.
expecting: A nonzero compile/setup or no HTTP 200 would localize the third-project failure; success would mean the original startup failure is not currently reproduced across any project.
next_action: run admin-eval-dark database setup and the third, final bounded Phoenix launch on port 25313, with no browser invocation
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

## Resolution

root_cause:
fix:
verification:
files_changed:
