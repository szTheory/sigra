---
status: investigating
trigger: 'Phase 253 registration runner setup failure'
created: 2026-10-13T12:16:53Z
updated: 2026-10-13T12:20:33Z
goal: find_and_fix
scope: runner startup only; no registration reproduction budget reset
capture_head: 38a4ecf89424638242e1807900fb8a0b64bc2d43
capture_status: clean
---

## Current Focus

hypothesis: An isolated MIX_BUILD_PATH is enough to reproduce the reported JOSE compile failure; if it is not, the retained diagnosis lacks a distinguishing raw error.
test: Compile only JOSE in a fresh scoped build path and capture the full output in a new setup-only diagnostic record.
expecting: A nonzero compile with the same missing include would confirm the build-path cause; success would eliminate it as a sufficient cause.
next_action: run a bounded JOSE-only compile under a fresh MIX_BUILD_PATH, with no Phoenix launch or browser invocation
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

None yet.

## Evidence

- timestamp: 2026-10-13T12:16:53Z
  checked: Initial git status and retained registration evidence
  found: Working tree clean at 38a4ecf89424638242e1807900fb8a0b64bc2d43; zero browser runs and exhausted infrastructure retry recorded.
  implication: Repair setup independently; do not classify the historical registration failure from startup results.
- timestamp: 2026-10-13T12:20:33Z
  checked: Runner, app config, JOSE source, database readiness, project skill discovery, and knowledge base
  found: Runner exports a fresh per-project MIX_BUILD_PATH before ecto.setup; JOSE include files exist in deps/jose/include; dev.exs reads PORT during config compilation; PostgreSQL accepts connections at 127.0.0.1:58624; no matching prior debug pattern or project skill was found. No raw JOSE error log is retained.
  implication: The previous summary does not prove which include was missing; a scoped compile experiment must distinguish build-path failure from another cause.

## Resolution

root_cause:
fix:
verification:
files_changed:
