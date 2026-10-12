---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 09
subsystem: release-proof
tags: [release, docs, github-actions, provenance]
requires:
  - phase: 249-08
    provides: "Live preservation gate with the one exact user-authorized accepted-loss identity"
provides:
  - "A ten-path source-bound candidate on freshly resolved protected main"
  - "The immutable 1.6.0 receipt, current generated docs index, and required build-then-compare CI edge"
affects: [249-10, 249-11, 249-12, REL-02]
actuals:
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns:
    - "Assemble release work only from committed Phase 249 provenance in a clean isolated worktree."
    - "Require docs-only PRs to execute ExDoc and compare the complete generated index before ci-gate."
key-files:
  created:
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-09-CANDIDATE.json
    - scripts/ci/release-public-proof.sh
    - scripts/ci/release-public-proof.test.sh
    - scripts/ci/check-docs-index.sh
    - scripts/ci/check-docs-index.test.sh
  modified:
    - .github/workflows/ci.yml
    - .github/ci-skip-manifest.tsv
    - doc/llms.txt
    - scripts/ci/honest-skip-verdict.sh
    - scripts/ci/honest-skip-verdict.test.sh
requirements-completed: []
coverage:
  - id: D03-D04
    description: "Candidate receipt remains bound to the published package source and its exact successful ci-gate."
    requirement: REL-02
    verification:
      - kind: integration
        ref: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-09-CANDIDATE.json#release_receipt"
        status: pass
    human_judgment: false
  - id: D05-D07
    description: "The full generated docs index matches the candidate build and required CI rejects drift, including docs-only PRs."
    requirement: REL-02
    verification:
      - kind: unit
        ref: "bash scripts/ci/check-docs-index.test.sh"
        status: pass
      - kind: integration
        ref: "mix docs --warnings-as-errors && bash scripts/ci/check-docs-index.sh"
        status: pass
      - kind: workflow
        ref: "actionlint -shellcheck= .github/workflows/ci.yml; scripts/ci/honest-skip-verdict.test.sh"
        status: pass
    human_judgment: false
duration: 10min
completed: 2026-10-09
status: complete
---

# Phase 249 Plan 09: Source-Bound Release and Docs Candidate

**A ten-path local candidate now carries the exact 1.6.0 release receipt and makes the full generated ExDoc index a required CI check for docs-only and other changes.**

## Performance

- **Duration:** 10 minutes
- **Started:** 2026-10-09T19:31:11Z
- **Completed:** 2026-10-09T19:41:24Z
- **Tasks:** 2/2
- **Candidate files:** 10

## Accomplishments

- Revalidated the Plan 08 gate before candidate creation. It returned zero errors/blockers with `accepted-with-recorded-loss` for only `.planning/HANDOFF.json` status ` M`, SHA-256 `00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148`. Those historical bytes remain unrecovered and are not claimed as preserved.
- Resolved protected `main` at `e2fa303017364c7e496c3c620f7b709c8e90c8fb`, fetched that object, and created clean worktree `/private/tmp/sigra-phase-249-09-candidate` on local branch `gsd/phase-249-09-candidate`.
- Restored the public release proof, receipt, and docs-index checker from the exact committed Phase 249 source commits. The receipt remains byte-identical at SHA-256 `c1a58f6a36656194387b0006dac9aab447d8f445cce9b060dcfb638ba6c4fff5`, naming package source and successful source CI head `9e80cb78d6374b1ed4074d5fef6b613fee879dca`.
- Added the required index comparison immediately after `mix docs --warnings-as-errors` in `library_tests_dep_off`, removed its docs-only skip allowance, and updated the complete ExDoc index to the generated 1.6.0 title. The existing `ci-gate` dependency remains intact.
- Committed the two candidate slices as `4974132add64df2a18cf5acfe5e60e93c18419db` and `72fc10449577f63974d068c5aba8c4b3ce99052e`. The candidate changes exactly the ten paths listed in `249-09-CANDIDATE.json`; no inherited work or Phase 249 planning files other than the immutable receipt are included.
- A fresh read-only snapshot after candidate creation observed all six registered worktrees clean and all 14 open PRs represented.

## Verification

- `bash scripts/ci/release-public-proof.test.sh` — 44 passed, 0 failed.
- `bash scripts/ci/check-docs-index.test.sh` — 6 passed, 0 failed.
- `bash scripts/ci/honest-skip-verdict.test.sh` — 20 passed, 0 failed.
- `mix docs --warnings-as-errors` — passed; generated 338 lines / 25,890 bytes.
- `bash scripts/ci/check-docs-index.sh` — passed against the Git-indexed candidate blob.
- `actionlint -shellcheck= .github/workflows/ci.yml` — passed.
- ShellCheck passed with only existing `SC2034`/intentional `SC2016` notices suppressed. Plain `actionlint .github/workflows/ci.yml` reports six ShellCheck warnings already present in the exact protected-main base (`SC2209` twice, `SC2010` twice, `SC2034` twice); a run against the base produced the same warnings. No unrelated cleanup hunks were added to the candidate.
- The host default Bash is 3.2 and lacks `mapfile`; all Bash fixture suites passed under installed Bash 5.2, matching the CI runner capability.

## Deviations and Findings

- The plan's plain `actionlint` invocation cannot pass against current main without unrelated ShellCheck cleanup. To keep the candidate scoped to Phase 249, workflow structure and expression lint ran with ShellCheck integration disabled, while the task-owned shell files were separately checked. The identical six warnings were reproduced on the unmodified base and are recorded in `249-09-CANDIDATE.json`.
- Isolated `mix deps.get` reported OSV advisories for `cloak 1.1.4` and `cloak_ecto 1.3.0`. No dependency or lockfile changes were made in this release-proof slice. Sigra's generated vault uses AES-GCM, and the inspected Sigra source contains no `Cloak.Ecto.PBKDF2` use; track these dependency advisories separately from the candidate review.
- The candidate is local only. No push, hosted PR, merge, or publish action occurred in Plan 09.
- REL-02 phase verification is still open; Plan 10 must finish the candidate review and contributor gate before any PR is created.

## Next Readiness

Plan 249-10 can review the exact candidate head `72fc10449577f63974d068c5aba8c4b3ce99052e` on base `e2fa303017364c7e496c3c620f7b709c8e90c8fb`. Do not open a PR until that plan's complete review and contributor gate pass.

---
*Phase: 249-publish-and-prove-sigra-1-6-0*
*Completed: 2026-10-09*
