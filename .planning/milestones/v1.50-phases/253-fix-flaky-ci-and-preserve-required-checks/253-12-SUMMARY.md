---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 12
subsystem: testing
tags: [github-actions, ci, canary, recovery]
requires:
  - phase: 253-11
    provides: sealed recovery fixture and bounded canary contract
provides:
  - Fixed frozen-candidate startup and recovery receipt initialization in the canary runner
  - Added preflight-only and create-only scoped-ref checks with charged request records
  - Preserved the live preflight responses that stopped the hosted run
affects: [phase-253, ci-gate-canary, hosted-gate-verification]
actuals:
  tokens: 20295
  tasks: 0
  commits: 5
tech-stack:
  added: []
  patterns: [content-addressed planning write-ahead refs, charged API transaction ledger]
key-files:
  created:
    - scripts/ci/ci-gate-canary.test.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-12-PRELAUNCH-REVISION-02.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-12-RAW-EFFECTIVE-RULES.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-12-RAW-RATE-LIMIT.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-12-RAW-REGISTERED-WORKFLOW.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-EVIDENCE.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-REQUESTS.json
  modified:
    - scripts/ci/ci-gate-canary.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json
key-decisions:
  - "Stop after the fresh effective-check preflight returned no required-check contexts; do not dispatch from a contract that cannot be verified."
  - "Keep the recovery request ceiling and original failed-run records unchanged."
patterns-established:
  - "Canary preflight responses are counted in the same immutable request ledger as dispatches and polling."
requirements-completed: []
coverage:
  - id: D1
    description: "Local canary startup, write-ahead preservation, and create-only ref paths are regression-tested."
    verification:
      - kind: unit
        ref: "bash scripts/ci/ci-gate-canary.test.sh"
        status: pass
    human_judgment: true
    rationale: "The hosted source outcomes and independent verifier were not run because live preflight did not establish the required-check contract."
  - id: D2
    description: "Fresh hosted fixture outcomes and independent verifier results."
    verification:
      - kind: integration
        ref: "253-RECOVERY-CANARY-EVIDENCE.json; 253-RECOVERY-CANARY-REQUESTS.json"
        status: fail
    human_judgment: true
    rationale: "The live preflight halted before fixture ref publication or workflow dispatch."
duration: 31min
completed: 2026-10-13
status: halted
plan_head_before: 0f6bca460e3c95d1ca2f6fc0411890e0e4b18585
plan_head_after: 962ddb3d8f9e4c5d646fa18603e13697495b4da2
commits: 5
---

# Phase 253 Plan 12: Hosted recovery canary summary

**The canary runner’s frozen-candidate startup and receipt handling are repaired, but hosted verification halted because GitHub returned no effective required-check contexts.**

## Performance

- **Duration:** 31 minutes
- **Started:** 2026-10-13T16:16:37Z
- **Stopped:** 2026-10-13T16:47:37Z
- **Tasks fully completed:** 0 of 2; Task 1 stopped during required preflight, so Task 2 did not start.
- **Files modified or created:** 11, including three raw API replies and two live canary ledgers.
- **Hosted budget at halt:** 3 of 120 requests; 0 of 45 actual jobs; 34 seconds of the 60-minute ceiling. The immutable start epoch is `1791909792`.

## Accomplishments

- Fixed canary startup when a valid frozen candidate exists but the new evidence file is absent. Added actual-shell regression coverage for that path and the pre-existing original fixture ref/snapshot conditions.
- Added recovery-specific preflight receipts, charged read-only API transactions, scoped planning write-ahead revisions, and create-only remote fixture-ref verification. Local regression tests cover the new paths.
- Sealed candidate `a740517229ffa2d7573d23af76f9e98fadd27f84` with fixture commit `f15eb9af5668a14995416d8c1ae053c0ec876c62` and workflow blob `a09297bc6be68ad412d1ed0e31724e1b707e7e60`. The runner halted before publishing that ref remotely or dispatching a workflow.
- Preserved exact live replies in `253-12-RAW-RATE-LIMIT.json`, `253-12-RAW-EFFECTIVE-RULES.json`, and `253-12-RAW-REGISTERED-WORKFLOW.json`. The rules response contained only active `main` and `tag-namespace` rulesets, with no `required_status_checks` contexts; the registered workflow response identified active workflow ID `259268962` at `.github/workflows/ci.yml`.

## Verification

- `bash scripts/ci/ci-gate-canary.test.sh` — passed, including startup with sealed candidate and absent new evidence, fresh preflight accounting, and create-only ref checks.
- `python3 scripts/ci/ci-hosted-gate-verify.test.py` — passed, 16 tests.
- `bash -n scripts/ci/ci-gate-canary.sh scripts/ci/ci-gate-canary.test.sh` — passed.
- `git diff --check` — passed.
- Recovery freeze `--check-only` validation — passed; the original scenario set, bounds, required names, and failed-run identities were unchanged.
- Live preflight — stopped after three HTTP 200 GETs: rate limit, effective rulesets, and registered workflow. The missing required-check contexts failed the frozen five-name comparison. Evidence is in `253-RECOVERY-CANARY-EVIDENCE.json` and `253-RECOVERY-CANARY-REQUESTS.json`.
- Not run: remote fixture ref creation, full-pass dispatch, the remaining five source scenarios, independent hosted verifier, and Plan Task 2 matrix verification. No hosted source result exists for this candidate.

## Task Commits

1. **Task 1 local regression (RED)** — `0d5d94f7e` (test).
2. **Task 1 startup and receipt repair** — `92ae6cb50` (fix).
3. **Task 1 resealed local repair candidate** — `91c1f688d` (docs).
4. **Task 1 create-only scoped ref path** — `a74051722` (fix).
5. **Task 1 final reseal before live preflight** — `962ddb3d8` (docs).

The five commits above are measured from `plan_head_before`. The summary/evidence closeout commit follows this plan work.

## Files Created or Modified

- `scripts/ci/ci-gate-canary.sh` — initializes recovery receipts independently from candidate identity, supports preflight-only mode, charges preflight traffic, and checks remote refs create-only.
- `scripts/ci/ci-gate-canary.test.sh` — exercises real shell startup and the bounded preflight/ref paths with a controlled API fixture.
- `253-RECOVERY-CANARY-FREEZE.json` — final sealed candidate and fixture identities; the original contract bounds and scenarios remain unchanged.
- `253-12-PRELAUNCH-REVISION-02.json` — identifies the source reseal and preserved earlier planning revisions.
- `253-RECOVERY-CANARY-EVIDENCE.json` and `253-RECOVERY-CANARY-REQUESTS.json` — durable halted run state and all three charged GET transactions.
- `253-12-RAW-*.json` — exact bodies of the three live preflight responses, with SHA-256 values recorded in the execution record.

## Decisions Made

- Stop before fixture-ref publication or dispatch when the live required-check response does not prove the sealed five-name contract.
- Do not reset the started request/time budget or retry the halted preflight. A later attempt requires a new reviewed source/freeze revision and a new authorized budget.
- Preserve the earlier Plan11 freeze and workflow bytes under `refs/gsd/phase253-12-prior-freeze` and `refs/gsd/phase253-12-prior-workflow`. The prior recovery revisions and the original failed run/ref remain untouched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed recovery startup and write-ahead receipt handling**
- **Found during:** Task 1 local regression work.
- **Issue:** With a sealed candidate and no new ledger, the runner skipped initialization, could target original preflight paths, and could mutate finish/failure receipts without preserving exact bytes first.
- **Fix:** Decoupled candidate identity from recovery evidence initialization, introduced recovery-specific paths, and preserved exact dirty bytes in content-addressed scoped refs before each ledger/evidence mutation.
- **Files modified:** `scripts/ci/ci-gate-canary.sh`, `scripts/ci/ci-gate-canary.test.sh`.
- **Verification:** Shell regression suite passed; prior bytes were read back from scoped refs.
- **Committed in:** `92ae6cb50`.

**2. [Rule 2 - Missing critical functionality] Added a create-only remote fixture-ref check**
- **Found during:** Task 1 local tests.
- **Issue:** The sealed fixture path did not explicitly prove remote absence/create/readback before dispatch.
- **Fix:** Added charged GET, create-only POST, and exact readback with mismatch refusal, plus regression coverage.
- **Files modified:** `scripts/ci/ci-gate-canary.sh`, `scripts/ci/ci-gate-canary.test.sh`.
- **Verification:** Shell regression suite passed with simulated absent and existing refs.
- **Committed in:** `a74051722`.

**3. [Rule 3 - Blocking issue] Halted on missing live required-check contexts**
- **Found during:** Task 1 hosted preflight.
- **Issue:** The fresh rules response had no required-check contexts, so it could not establish the frozen five-check contract.
- **Action:** Preserved the response and halted before ref mutation or dispatch; no code change can make this specific live response satisfy the sealed contract.
- **Files:** `253-RECOVERY-CANARY-EVIDENCE.json`, `253-RECOVERY-CANARY-REQUESTS.json`, and the three `253-12-RAW-*.json` replies.
- **Verification:** Exact request ledger shows three GETs, all HTTP 200; zero jobs or dispatches.

**Total deviations:** 3 (two local fixes and one safe preflight halt).
**Impact on plan:** Local runner repairs are tested. Hosted acceptance remains unproven, and CIREL-02 remains open.

## Issues Encountered

The current GitHub rulesets API response included no effective required-check contexts. The runner correctly failed closed. The raw replies and halted ledger are retained; the scenario matrix and independent verifier were not run. The original failed run `38347679431` and its ref remain unchanged.

The shared `.planning/config.json` has an unrelated pre-existing edit from the parent execution context and was not staged or modified by this plan. The shell suite run directly in that checkout correctly refused to reuse the terminal halted ledger; the final shell and Python suites passed in an isolated clone after seeding only the already-sealed local fixture ref.

Before each self-check edit, the exact prior summary bytes were preserved and read back at `refs/gsd/phase253-12-summary/d1a6c68af706e1e7d36268cce702722311513cff`, `refs/gsd/phase253-12-summary/526aa2c71ac33842c9df877e491ce4a4f626dd0a`, `refs/gsd/phase253-12-summary/acf24a8d4bcc706e99c47951cc01aa497cc232be`, `refs/gsd/phase253-12-summary/d1daca0a6dac01e89ece56c1501c98717501a0c4`, `refs/gsd/phase253-12-summary/4d4b569c5ee12c246e98da29a5f6771429c918e5`, and `refs/gsd/phase253-12-summary/6702829e808b662d882062b91c195db50e5507b7`.

Raw reply SHA-256: effective rules `3b1045cb27790758298466498a42780dbc4d985f23eff1bea74bc0017f910aa9`; rate limit `ae404a52273333e9e857fe3042b9fa77f46a029ddd94d047efad127e2e8e87ae`; registered workflow `963957343ba110ce175bd31d6551e7a8ce3f11d2fbfec453a7922d268c9726cd`.

## Next Phase Readiness

Plan12 is **halted** and cannot establish CIREL-02. Keep Plan13 unstarted. Resolve how to obtain and verify the effective five required-check names from GitHub without weakening the frozen contract, then create a new reviewed freeze/revision and authorized budget before another hosted attempt. Phase253 verification has not started.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Stopped: 2026-10-13*

## Self-Check: PASSED

- All five plan commits exist in history after `plan_head_before`.
- The summary, frozen evidence, request ledger, and three raw preflight response files exist.
- The recorded hashes of the three raw API responses match the saved files.
- In an isolated clone, the shell regression suite, 16 Python tests, shell syntax checks, and `git diff --check` passed after the final source changes; no source changes were made after those checks.
