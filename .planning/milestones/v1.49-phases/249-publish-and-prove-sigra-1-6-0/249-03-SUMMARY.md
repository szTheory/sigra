---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 03
subsystem: infra
tags: [github-actions, release-please, github-cli, ci, shell]
requires:
  - phase: 249-02
    provides: required full-file ExDoc index drift gate in CI
provides:
  - trusted-main Release Please candidate identity capture with stable two-read verification
  - unprivileged candidate docs build and data-only index artifact
  - narrow non-force writer with identity, artifact, race, and fresh-CI checks
  - shell fixtures and ExUnit contracts for the refresh workflow and existing merge guard
affects: [249-05, release-automation]
actuals:
  tokens: 15555
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - run candidate code with read-only access and pass only a validated artifact to the writer
    - bind every candidate mutation and CI lookup to full source SHAs
    - report readiness only after the ordinary push CI run is registered for the new SHA
key-files:
  created:
    - scripts/ci/refresh-release-docs.sh
    - scripts/ci/refresh-release-docs.test.sh
    - test/sigra/planning/phase_249_release_docs_contract_test.exs
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-03-TASK-1-RED.json
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-03-TASK-2-RED.json
  modified:
    - .github/workflows/release-please.yml
key-decisions:
  - "Capture one same-repository pending Release Please PR on the fixed branch and require its full identity to remain stable across reads."
  - "Keep candidate documentation builds outside the release-automation environment with persisted checkout credentials disabled."
  - "Give the release token only to the final writer step; reject artifacts outside the single UTF-8 doc/llms.txt path, above 5 MB, or containing symlinks or extra members."
  - "Use a non-force push and require a registered ordinary CI push run for the exact new head; leave merge decisions to the existing exact-head workflow."
requirements-completed: [REL-02]
coverage:
  - id: D1
    description: "Refresh the generated index for one eligible Release Please candidate using a credential-free docs build."
    requirement: REL-02
    verification:
      - kind: unit
        ref: "bash scripts/ci/refresh-release-docs.test.sh#eligible candidate and explicit no-op"
        status: pass
    human_judgment: false
  - id: D2
    description: "Reject candidate identity drift, hostile artifact content, missing credentials, and non-fast-forward races."
    requirement: REL-02
    verification:
      - kind: unit
        ref: "bash scripts/ci/refresh-release-docs.test.sh#race and artifact matrix"
        status: pass
      - kind: unit
        ref: "scripts/ci/refresh-release-docs.test.sh#oversized generated docs"
        status: pass
    human_judgment: false
  - id: D3
    description: "Preserve the ordinary CI event chain and exact-head merge authority."
    requirement: REL-02
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_249_release_docs_contract_test.exs test/sigra/planning/phase_248_release_gate_contract_test.exs"
        status: pass
      - kind: integration
        ref: "actionlint .github/workflows/release-please.yml .github/workflows/release-pr-automerge.yml .github/workflows/ci.yml"
        status: pass
    human_judgment: false
metrics:
  duration: 16min
  completed: 2026-10-09
  status: complete
---

# Phase 249 Plan 03: Automatic Release Candidate Docs Refresh

**Release Please candidates now get a credential-free ExDoc build and a single-file, exact-head docs refresh before ordinary CI and the existing guarded merger.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-10-09T13:56:00Z
- **Completed:** 2026-10-09T14:12:42Z
- **Tasks:** 2
- **Files changed:** 6

## Accomplishments

- Added trusted-main candidate selection that accepts exactly one open, same-repository PR with the fixed branch, main base, pending label, coherent release title, and stable full head SHA. No candidate produces an explicit no-op.
- Added a separate docs build job with read-only permissions and disabled persisted checkout credentials. It checks out the captured candidate SHA, runs `mix docs --warnings-as-errors`, and packages only `doc/llms.txt` plus the identity JSON.
- Added a release-environment writer that rechecks the current main and candidate before mutation, rejects stale or malformed identity and artifact data, stages only `doc/llms.txt`, and pushes without force. It records a link only after ordinary push CI is registered for the exact new SHA.
- Preserved the existing exact-head merge authority and the two timestamp-normalization fixes observed on trusted current main.

## TDD Evidence and Task Commits

1. **Task 1 tests:** `4913599bc` — `test(249-03): add candidate docs refresh fixtures`
2. **Task 1 implementation:** `6e7c838fe` — `feat(249-03): refresh release candidate docs safely`
3. **Task 2 tests:** `567a304c9` — `test(249-03): cover refresh races and trust boundaries`
4. **Task 2 implementation:** `08f929d7a` — `feat(249-03): bound generated release docs artifact`

Task 1 RED evidence is recorded in `249-03-TASK-1-RED.json` and classified `RED_EVIDENCE_OK`; the target candidate-capture assertion failed because the behavior was absent. Task 2 RED evidence is recorded in `249-03-TASK-2-RED.json` and classified `RED_EVIDENCE_OK`; the fixture showed a 6 MB index passed packaging. Both behaviors pass after implementation. No refactor commit was needed.

## Verification

- `bash scripts/ci/refresh-release-docs.test.sh` — 12 passed.
- `bash scripts/ci/release-candidate-preflight.test.sh` — 26 passed.
- `mix test test/sigra/planning/phase_249_release_docs_contract_test.exs test/sigra/planning/phase_248_release_gate_contract_test.exs` — 15 passed.
- `actionlint .github/workflows/release-please.yml .github/workflows/release-pr-automerge.yml .github/workflows/ci.yml` — passed.
- `shellcheck scripts/ci/refresh-release-docs.sh scripts/ci/refresh-release-docs.test.sh` — passed.

## Decisions and Deviations

The writer checks both the artifact producer’s output and the downloaded artifact because the trust boundary includes the artifact transport. A 5 MB UTF-8 limit bounds the only allowed file while leaving substantial room above the current generated index. The writer confirms that a fresh CI push run exists and records its URL; only the unchanged `workflow_run` merger can decide whether successful `ci-gate` evidence permits a squash merge.

No live candidate write or workflow dispatch was performed. The implementation and its race/event behavior were verified locally; the automatic path runs after this workflow reaches trusted `main`. This plan did not require a one-time external candidate mutation.

**Total deviations:** 1 security hardening within the planned artifact-validation boundary (UTF-8 and 5 MB bound). **Impact:** reduces untrusted artifact resource risk without changing the user-visible release flow.

## Next Phase Readiness

Plan 249-03 is complete. Plans 249-05 and 249-06 remain in the active phase route; Plan 249-05 depends on Plan 249-04 and must preserve the inherited-work inventory before any clean-closeout claim.

---
*Phase: 249-publish-and-prove-sigra-1-6-0*
*Completed: 2026-10-09*
