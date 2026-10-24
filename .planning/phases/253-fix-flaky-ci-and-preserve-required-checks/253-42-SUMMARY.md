---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "42"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-transport, pr-proof, browser-records, accepted-only]

requires:
  - phase: 253
    provides: measured HTTPS transport (18/19/20), Git object publication, ci-browser-records policy owner
provides:
  - typed canary/production transport allocations (117 vs exactly 120) with frozen category predebits and bound documents
  - typed repository-scoped PR create/read/compare/source-blob/attempt-jobs routes
  - scripts/ci/ci-pr-proof.sh finite real PR collector (prepare, check-only, family, verify)
  - independent verify_pr_family / verify_pr_pair / verify_completion in ci-hosted-gate-verify.py
affects: [253-43, 253-44, 253-45, 253-46, 253-47]

execution_performed: true
execution_scope: offline implementation and synthetic local-HTTPS contracts only
native_execution: 0
github_requests: 0

actuals:
  tokens: 48040
  tasks: 2
  commits: 3
plan_head_before: b0ae538905ba93fb8ebc9f8699d2c6a75560ca69
plan_head_after: df740b901bba964580dbeaff33f69acc8f1cb56e

tech-stack:
  added: []
  patterns:
    - "fail-closed verifier decorator: malformed shapes are VerificationError, never a crash or a pass"
    - "ci-browser-records.mjs copied into a temp root with the retained workflow bytes as the single policy owner"
    - "synthetic evidence is labeled from the allocation origin and refused by live acceptance"

key-files:
  created:
    - scripts/ci/ci-pr-proof.sh
    - scripts/ci/ci-pr-proof.test.sh
  modified:
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py

key-decisions:
  - "allocation_kind canary caps at 117; production is exactly 120 with the frozen 13-category table; no global ceiling increase"
  - "category predebit happens inside the ledger lock before the wire; unknown, missing or exhausted categories stop terminally"
  - "the tested merge commit (PR read) is distinct from the PR head (run/check/artifact head_sha) and is the browser-record source_sha"
  - "completion distinguishes missing links (honest open record, exit 0 without --require-accepted) from forged/failed links (error)"

requirements: [CIREL-01, CIREL-02]
requirements-completed: []

coverage:
  - id: D1
    description: "Typed canary/production allocations, category predebits, bound documents and typed PR routes in the measured transport"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "python3 scripts/ci/ci-hosted-transport.test.py#TypedAllocationWireTests (actual local-HTTPS 117 and 120 boundaries, reset attempts)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Real PR collector subprocess chain over local HTTPS with independent server-journal verification (normal and docs-only)"
    requirement: "CIREL-02"
    verification:
      - kind: integration
        ref: "bash scripts/ci/ci-pr-proof.test.sh#test_complete_synthetic_normal_and_docs_chain_verifies_against_independent_server_receipts"
        status: pass
    human_judgment: false
  - id: D3
    description: "Empty/null/single/duplicate/byte-variant producer inventories, wrong identities and forged ZIP/record inputs reject"
    requirement: "CIREL-02"
    verification:
      - kind: integration
        ref: "bash scripts/ci/ci-pr-proof.test.sh (inventory, ZIP, policy-owner, unicode near-miss, fail-closed field removal contracts)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Accepted-only completion re-opening every linked proof; synthetic, missing, forged or reset evidence is never accepted"
    requirement: "CIREL-01"
    verification:
      - kind: unit
        ref: "python3 scripts/ci/ci-hosted-gate-verify.test.py#CompletionContractTests"
        status: pass
    human_judgment: false
  - id: D5
    description: "Actual hosted/PR behavior of the real GitHub API matches the assumptions encoded in the verifier"
    verification: []
    human_judgment: true
    rationale: "No GitHub request was made this plan; live shapes (merge_commit_sha timing, run.pull_requests linkage, PR-merge workflow_ref) are confirmed only by plan 45/46 execution"

duration: 23min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 42: Real PR collector and accepted-only requirement predicates Summary

**Finite real PR collector (`ci-pr-proof.sh`) over the measured transport with typed canary/production allocations, plus an independent verifier that separates PR head from tested merge from native check app and re-opens every linked proof before CIREL-01/02 could ever be accepted.**

## Performance

- **Duration:** 23 min
- **Started:** 2026-10-14T02:49:29Z
- **Completed:** 2026-10-14T03:12:46Z
- **Tasks:** 2
- **Files modified:** 6 (2 created, 4 modified)
- `execution_performed: true` covers offline implementation and synthetic local-HTTPS contracts only. Native Playwright processes: 0. GitHub requests: 0. No allocation, window, retry or reservation was spent.

## Accomplishments

- **Transport (`ci-hosted-transport.py`)**: `allocation_kind` canary|production (legacy allocations remain canary and keep the 117 ceiling; only production is exactly 120; `Production`, unknown kinds, canary-120 and production-121/117 reject), frozen 13-category `category_limits` (sum 120, copied from the BUDGETS table), `bound_documents` SHA-256 bindings checked before any socket I/O, per-request `category`/`family`, category predebit inside the ledger lock (exhaustion is a terminal stop with no wire request), ledger identity binding so changed limits/window/ceiling cannot continue a ledger. New typed routes `pr_create` (draft-only, exact proof head/base refs), `pr_read`, `compare`, `repo_contents` (two-file allow-list, 40-hex `ref`), `attempt_jobs`; `workflow_runs` accepts `event=pull_request&head_sha=`. Hermetic collector admission is limited to production-kind allocations.
- **Collector (`ci-pr-proof.sh`)**: `--prepare --publication --manifest --output` (verifies the measured publication receipt and manifest, computes local diffs and blobs, freezes with a content digest and document bindings), `--check-only --freeze [--allocation]` (zero requests; rejects drifted documents, non-production or unbound allocations), `--family normal|docs-only` (shared single preflight, 14-request docs base/head object+ref publication, draft PR, run discovery, terminal polls, merge/compare/source reads, attempt-job pages, native checks, artifact metadata, five producer ZIP downloads with 2 hops each; every stop is preserved in evidence), `--verify`.
- **Verifier (`ci-hosted-gate-verify.py`)**: `verify_pr_transport` (separate production allocation, per-category limits, independent server journal for local HTTPS), `verify_pr_family` (PR head vs tested merge vs workflow vs native check app/job/revision, exact five names, classifier job+step, library-test owner, exactly five `browser-execution-<seam>-<run>-<attempt>` artifacts with digest, bounded flat ZIP intake with member inventory equal to the execution record, and `ci-browser-records.mjs` run from a copy rooted at the retained workflow bytes as the single policy owner), `verify_pr_pair` (one non-reset allocation/window, append-only ledgers, distinct PRs/runs, docs base differs from candidate only by the exact `pull_request` branch allowance), `verify_completion` (re-opens and hash-checks Phase252 replay/diagnosis, load controls/acceptance via the strict native checker, publication receipt, hosted canary matrix, both PR families and frozen source links; embedded acceptance claims are ignored/contradicted; synthetic evidence stays open). CLI: `--mode pr --family normal|docs-only|both`, `--mode completion [--require-accepted]`.
- **Tests**: 24 shell/local-HTTPS contracts (real subprocesses against a TLS "GitHub" with a git-backed object store and node-generated producer artifacts), 10 transport wire contracts, 14 verifier/completion contracts. Suites ran: `ci-pr-proof.test.sh` 24 ok, `ci-hosted-transport.test.py` 26 ok, `ci-hosted-gate-verify.test.py` 38 ok, `ci-git-publication.test.py` 28 ok, `ci-gate-canary.test.sh` ok.

## Task Commits

1. **Task 1 (tracer): transport allocations/routes** - `bbbc41a02` (feat) - typed allocations, category predebits, PR routes, wire tests (RED observed first: 3 failures + 7 errors before implementation)
2. **Task 1 (tracer): collector + independent verifier + local-HTTPS contracts** - `8237099e3` (feat)
3. **Task 2: literal limitations and exact UTF-8 near-miss coverage** - `df740b901` (test)

Tasks 1 and 2 share files (verifier, collector tests), so commit boundaries follow dependency order rather than strict file purity; Task 2's docs-topology, completion and accepted-only code landed in `8237099e3` together with the verifier it extends.

## Files Created/Modified

- `scripts/ci/ci-pr-proof.sh` - collector/prepare/check/verify entry point (Python embedded behind a bash launcher)
- `scripts/ci/ci-pr-proof.test.sh` - subprocess and local-HTTPS object-aware contracts (all synthetic)
- `scripts/ci/ci-hosted-transport.py` / `.test.py` - typed allocations, categories, bound documents, PR routes, wire tests
- `scripts/ci/ci-hosted-gate-verify.py` / `.test.py` - PR family/pair and completion verifiers with contracts

## Decisions Made

- Production budgets live in code as the frozen table (sum 120); the BUDGETS document is bound by SHA-256, not parsed.
- The collector never infers acceptance: a stop (refused create, non-terminal run at the poll cap, core floor) is written into the evidence and verification rejects `collection.complete != true`.
- Documentation exemptions are decided only by `ci-browser-records.mjs` given identity derived from API facts (event, classifier job/step, diff), never from record-supplied booleans.
- Pre-merge docs topology: docs base is checked by an extra candidate-to-docs-base compare (counts inside the 8 `pr_identity` requests: normal 3 + docs 5).

## Deviations from Plan

None - plan executed as written, with these documented interpretations:

- **Interpretation (not a rule deviation):** "internal unit owner" / "ordinary mix ci library owner" is enforced as the required `Library tests` check plus at least one successful `Library tests shard*` job in the normal family.
- **Interpretation:** the infrastructure-rerun category (21 requests, shared) is allocated and enforced by the transport but the collector does not implement a rerun route; a rerun is a deliberate later step and no per-family reset is possible.

**Total deviations:** 0 auto-fixed. **Impact:** none on scope.

## Known Stubs / Remaining Gaps

- **Completion checker names are placeholders for plans 39-41.** `verify_completion` invokes `ci-registration-recovery.mjs --verify-load-recovery <evidence> --stage complete` and `--verify-load-acceptance <evidence> --require-target-accepted`; those modes do not exist yet, so a present load link fails closed until plan 41 supplies them (or the argv table `LOAD_CHECKS` is reconciled). Missing links are honest open gaps.
- **Publication receipt verifier** still accepts only `published-local-fixture`; plan 44 owns the live-origin correction, so a live publication link fails closed today.
- **Live-shape assumptions unverified** (no GitHub request made): PR `merge_commit_sha` is read once after the terminal run (distinct from head), run `pull_requests` links the PR, browser-record identity uses `refs/pull/<n>/merge` for `workflow_ref` and the merge SHA for `source_sha`/`workflow_sha`, and artifact `workflow_run.head_sha` equals the PR head. Each is checked strictly, so a mismatch rejects rather than passes; plan 45/46 execution is where they are confirmed or the constants adjusted.
- **Pre-existing unrelated failure:** `scripts/ci/ci-gate-canary-recovery.test.py` fails 2 tests (BSD `mktemp` template with a `.json` suffix colliding with stale `/tmp/253-canary-*` files, and a changed freeze message). It exercises the untouched `ci-gate-canary.sh` and fails identically without this plan's changes; not fixed (out of scope).
- Requirements CIREL-01/CIREL-02 and full Phase253 verification remain open (`phase_verification: not_started`). Nothing here claims acceptance; synthetic evidence is labeled and refused by live acceptance.

## Threat Flags

None beyond the plan threat model (T-253-83 mitigated by independent head/merge/check-app/job/artifact identity matching; T-253-84 by exact-five producer and complete native report inventory; T-253-SC no new dependencies). No new network endpoint was exercised.

## Issues Encountered

- `ci-browser-records.mjs` only runs as main when `argv[1]` equals its real path; on macOS the temp root had to be realpath-resolved or the policy owner silently produced no output (the verifier now rejects empty output and resolves the root).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Collector, verifier and allocation contracts are ready before the hosted freeze (plan 44) and publication/execution (plans 45/46). Blockers to acceptance remain the unexecuted native acceptance (41), canary/publication live-origin work (44) and actual hosted/PR execution (45/46).

## Self-Check: PASSED

All six declared files exist; commits `bbbc41a02`, `8237099e3`, `df740b901` are ancestors of HEAD; no tracked-file deletions; suites listed above pass.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-14*
