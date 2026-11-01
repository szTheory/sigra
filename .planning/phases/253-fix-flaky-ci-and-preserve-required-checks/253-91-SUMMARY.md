---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "91"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, canary, publication, r6, approval-gates]
requires:
  - phase: 253
    provides: "253-89 Jon-approved not_reproduced target disposition and runner --require-target-disposition predicate"
  - phase: 253
    provides: "253-90 dispositioned completion mode and the R6 reconciliation contract"
provides:
  - "actual-github publication origin verified from measured ledger responses; hermetic origin rejected at live acceptance"
  - "registered ci.yml fixture child plus the six-scenario dispatch-only fixture with a no-API compact-receipt verifier"
  - "per-section committed approval enforced in code for every live canary mode, --publish-docs and every live ci-pr-proof.sh --family mode"
  - "253-LOAD-RECOVERY-CANARY-FREEZE.json, -PUBLICATION.json: final source, packed object graph, expired reruns, native_target binding, two-section outward_actions"
affects: [253-92, 253-93, 253-94]
actuals:
  tokens: 64000
  tasks: 3
  commits: 9
plan_head_before: 8940ac645413625263ea43131cdcca373c17ae8d
plan_head_after: f0c52071783bafc03174aa5040096332fe627bf4
tech-stack:
  added: []
  patterns:
    - "one shared check_section_approval rule (tracked, in HEAD, byte-equal, approve, section name, section digest) reused by canary, publisher and PR collector"
    - "action_approval {path, sha256, section, section_sha256, commit, window_wall_start_epoch} written to the evidence/receipt before the first transaction"
    - "publication receipts pin their own ledger transactions so a shared ledger can keep growing"
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-FREEZE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-PUBLICATION.json
  modified:
    - scripts/ci/ci-git-publication.py
    - scripts/ci/ci-git-publication.test.py
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-gate-canary.test.sh
    - scripts/ci/ci-pr-proof.sh
    - scripts/ci/ci-pr-proof.test.sh
    - scripts/ci/ci-hosted-gate-verify.test.py
key-decisions:
  - "Freeze builder and strict checker live in ci-git-publication.py; ci-gate-canary.sh --check-only --revision-freeze delegates the policy (expired reruns, native_target re-hash, bounds, categories) to it"
  - "Legacy recovery freezes are retired for live execution; --check-only keeps their original retry policy"
  - "A hermetic publication never marks the fixture ref verified; a live allocation is verified with --require-live-origin"
  - "The two reserved reruns (canary retry category 13 requests/6 jobs, PR rerun category 21) are frozen expired; --rerun, --retry-infrastructure and --rerun-failed are refused"
requirements-completed: []
coverage:
  - id: D1
    description: "Strict actual-github origin verified from measured live ledger responses; hermetic and legacy origins rejected at live acceptance; receipts survive later shared-ledger requests"
    requirement: "CIREL-02"
    verification:
      - kind: integration
        ref: "scripts/ci/ci-git-publication.test.py#RegisteredPublicationTests,ReviewRemediationTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every live canary mode, --publish-docs and every live ci-pr-proof.sh --family mode refuse before any request without a committed approval bound to their own section digest, and record action_approval before the first transaction"
    requirement: "CIREL-02"
    verification:
      - kind: integration
        ref: "scripts/ci/ci-git-publication.test.py#LiveModeApprovalTests; scripts/ci/ci-pr-proof.test.sh#SectionApprovalTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "Registered-path fixture, bounded compact matrix and ZIP intake, separate no-API verifier"
    requirement: "CIREL-01"
    verification:
      - kind: unit
        ref: "scripts/ci/ci-hosted-gate-verify.test.py#RegisteredFixtureTests"
        status: pass
    human_judgment: false
  - id: D4
    description: "Final freeze and publication graph from the committed reviewed source: expired reruns, native_target re-hash, two separately hashed outward_actions sections"
    requirement: "CIREL-01"
    verification:
      - kind: other
        ref: "bash scripts/ci/ci-gate-canary.sh --check-only --revision-freeze 253-LOAD-RECOVERY-CANARY-FREEZE.json && python3 scripts/ci/ci-git-publication.py --check-manifest 253-LOAD-RECOVERY-CANARY-PUBLICATION.json"
        status: pass
    human_judgment: false
  - id: D5
    description: "Hosted behavior of the six canary scenarios and the PR collector against real GitHub"
    verification: []
    human_judgment: true
    rationale: "Offline tests are implementation checks; hosted proof belongs to 253-92 and 253-93 after Jon re-confirms each outward-action section."
duration: 75min
completed: 2026-10-15
status: complete
---

# Phase 253 Plan 91: Registered-path canary, publication origin and final freeze Summary

**Per-section committed-approval gates now guard every live canary, docs-publication and PR-collector mode, an actual-github publication origin is verifiable from measured ledger responses, and the registered ci.yml fixture, packed 17-request object graph and two-section outward-action freeze are committed from source 24e17c011 with zero GitHub requests.**

## Performance

- **Duration:** about 75 min
- **Started:** 2026-10-14T23:45Z (approx)
- **Completed:** 2026-10-15T01:00Z
- **Tasks:** 3 (Task 1 tracer and Task 2 TDD, Task 3 freeze with no code change)
- **Files modified:** 10 (3 created, 7 modified)

## Task outcomes

- **Disposition predicate:** `node scripts/ci/ci-registration-recovery.mjs --verify-load-acceptance ... --require-target-disposition` exited 0 at start and again before the freeze; route printed `disposition (human-approved not_reproduced; CIREL-01 partial)`.
- **Task 1 (tracer):** registered `ci.yml` fixture child (`--fixture-file`, `--workflow-path`), `validateFrozenProductSource` (ancestor plus whole product path/mode/blob tree, planning-only movement allowed), origin derived from the measured ledger (`actual-github` only for a live allocation whose every transaction went to api.github.com and whose identities appear in server responses), category predebit (publication 24, docs_publication 14), `--publish-docs`, and `ci-gate-canary.sh --publish-only` driving the publisher end to end on local HTTPS.
- **Task 2:** per-section approval refusal in the canary (all five live modes), in `--publish-docs` and in `ci-pr-proof.sh --family` (normal and docs-only); `require_listed` mutation guard; strict `--check-only --revision-freeze` (retry 0 / expired, native_target re-hash, bounds, categories, history); registered-path fixture with a compact gzip receipt verifier; bounded matrix and ZIP intake; two review passes with all verified findings fixed.
- **Task 3:** `--prepare` against server parent `84ebcea60` (the locally recorded origin/main head) gave `ready-local-proposal`: 1473 product files, B=0, N=4 tree writes, 17 projected requests (<= 24), largest body 2,083,078 bytes (<= 2,097,152). The freeze was derived from a clean committed tree and verified.

## Freeze and manifest

| Item | Value |
|------|-------|
| frozen source commit | `24e17c01186dae9b69a67dd59c9c2292acb5983b` (product tree `5901b49c754b2f251420cace6cfc3f8f96fa8c5d`) |
| 253-LOAD-RECOVERY-CANARY-FREEZE.json sha256 | `726adae60e936dbda12c21f5e379a96a87ef8f2a10f61d6e35db029d468e51a9` |
| 253-LOAD-RECOVERY-CANARY-PUBLICATION.json sha256 | `bd9f5efaf1c2135f756531737592955cedccf0aee4f96e77fc3cd2bec35117cc` |
| canary section sha256 | `678e2576b2aec98434410aeb6b1ed9ab257fce850ade6737277c6287b902a071` |
| docs_and_prs section sha256 | `5d15af53e2c0f4fff002b436fa80a0f872815f818172880f951282f7ff337138` |
| candidate / fixture commits | `1351b066c087d04ba3bf3996394df0080ae9d818` / `f9b7422480a6770604a61345a77ce0303eea6740` (fixture blob `f4c9e2f23be6af58af3ae257579ca6d935251b56`) |
| docs base / head commits | `774621af624c1120e29a8d890b67bafb8a2c67fd` / `45fe14028395a2dad6911535ceb12e37d2129efe` |

**outward_actions (in order).** Canary section (253-92): publish git objects (<= 24 requests); create refs `gsd/253-replan-candidate` and `gsd/253-replan-fixture` at their frozen SHAs; six workflow_dispatch calls on `gsd/253-replan-fixture` (full-pass, docs-only, actual-failure, missing-seam, unexpected-skip, cancelled); one cancellation of the identified cancelled run; one verifier dispatch. docs_and_prs section (253-93): publish docs base/head objects (14 requests, refs `gsd/253-replan-docs-base` and `-docs-head`); two draft PR creates (`gsd/253-replan-candidate` to `main`, `gsd/253-replan-docs-head` to `gsd/253-replan-docs-base`). Both sections: zero reruns, merges, pushes, force updates, ref deletions, rule changes, releases or tags.

**Allocation.** 117 new measured requests plus 3 historical command allocations (120 accounted; historical actual HTTP stays unproven), 45 jobs, 60 minutes, clock starting before the first preflight or publication request. Both reserved reruns are expired with reason "no implemented rerun route; an infrastructure fault halts" (canary 13 requests / 6 jobs unused; PR rerun category 21). native_target route `not_reproduced_disposition` re-hashes the unchanged acceptance evidence, the 253-89 disposition and its approval.

## Task Commits

1. **Task 1** RED `1030f64b9`, GREEN `42e003cd5`
2. **Task 2** RED `f2f91c658`, GREEN `d29e27c09`, categories `5ca51e9ec`, review remediation `8c7661d35` and `24e17c011`
3. **Task 3** publication manifest `94e4521e0`, freeze `f0c520717`

## Deviations from Plan

**1. [Rule 3 - Blocking] Scenario dispatch is not driven against a simulated GitHub Actions server**
- **Found during:** Task 2
- **Issue:** the transport routes only git-object and production-collector routes to a hermetic origin; a canary-kind allocation cannot reach rate_limit, runs, jobs or artifact routes locally, and the transport is outside this plan's declared files.
- **Fix:** the six scenarios are covered at the seams that can run offline: the fixture verdict script for the five native scenarios with real helpers, the cancellation topology, the compact matrix through the real separate-verifier step (wrong ref, blob, source, event, job count, missing scenario and malformed payloads rejected), and the live-mode gate up to the first transaction with a credential-less stub (no network). End-to-end hosted behavior remains for 253-92.
- **Files modified:** scripts/ci/ci-hosted-gate-verify.test.py, scripts/ci/ci-git-publication.test.py

**2. [Rule 2 - Missing critical] Hardening beyond the listed behaviors**
- legacy recovery freezes refused for live execution; `fail()` no longer rewrites already halted evidence; every canary request is charged to its frozen category; rg-based guards replaced by fail-closed grep; relative paths anchored at the invocation directory; bytecode writing disabled so the frozen product tree stays clean.

**3. [Rule 3 - Blocking] Freeze builder and checker placed in ci-git-publication.py**
- the declared files have no other home; `ci-gate-canary.sh --check-only --revision-freeze` delegates to it, so retry policy and native_target re-hash are reachable through the canary script as planned.

**4. Manifest and freeze committed in two commits**
- the builder requires a clean committed tree, so the manifest is committed first and the freeze second. Nothing was published and no request was made between them.

**Total deviations:** 4 (1 blocking-test-scope, 1 missing-critical bundle, 2 structural). **Impact:** no scope creep beyond the declared files; hosted behavior is unchanged from the plan's intent.

## Code review (Task 2 final step)

Two `/code-review high` passes over every R6 product change in this plan. Fixed: receipts invalidated by later shared-ledger requests; hermetic receipt accepted as live; fail-open rg guards; window start moved by retries or disagreeing between receipt and evidence; PR collector and --publish-docs not applying the full freeze policy; evidence overwrite; docs reuse accepting any 14 ledger rows; dispatch input matching not exact; relative path handling; duplicate pinned transactions; docs origin computed over the whole ledger.

**Deferred (recorded, not fixed):**
- A committed approval has no consumed marker: a second window with fresh evidence and ledger paths could reuse it. Mitigation today: evidence bound to one approval digest, halted evidence refusal, terminal ledgers. Needs a decision on one-shot approvals before 253-92 if stricter replay protection is wanted.
- `require_listed` matches exact dispatch inputs and listed refs but does not count uses per action; use is bounded by the per-scenario receipt guard and the category budgets.
- A PR collection interrupted after its start stub must be continued with a new `--evidence` path (the earlier file is deliberately preserved).
- Publication-category rows added later (the fixture ref read in the dispatch flow) are not required to be pinned in the receipt.

## Issues Encountered

An index-based splice briefly corrupted `ci-git-publication.py` mid-Task 2; the uncommitted file was reverted with `git checkout -- <file>` and the edit redone. No committed work was affected.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint or trust boundary was added; the changes tighten existing ones (T-253-178, T-253-179).

## Next Phase Readiness

253-92 may run `--publish-only`, `--preflight-only` and the scenarios only after Jon re-confirms the canary section (digest above) and an approval record is committed; 253-93 likewise for docs_and_prs. Full Phase 253 verification stays not_started.

## Self-Check: PASSED

- Created files present: workflow fixture, freeze, publication manifest, SUMMARY.
- All nine task commits are ancestors of HEAD.
- config.json sha256 prefix `8e312f6ccd34` unchanged; state.json still 70229 bytes; STATE.md, ROADMAP.md, REQUIREMENTS.md untouched.
- Offline suites: ci-gate-canary.test.sh, ci-pr-proof.test.sh (33), ci-gate-canary-recovery.test.py (5), ci-git-publication.test.py (53), ci-hosted-gate-verify.test.py (65) all green; zero GitHub requests, no push, no ref creation, no dispatch.
