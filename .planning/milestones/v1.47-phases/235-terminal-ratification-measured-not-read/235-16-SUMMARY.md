---
phase: 235-terminal-ratification-measured-not-read
plan: 16
subsystem: ci
tags: [github-actions, source-complete-evidence, hackney, hex-audit, protected-main]

requires:
  - phase: 235-08
    provides: protected terminal measurement, 93-row ownership proof, and the honest FAST-01 miss
  - phase: 235-15
    provides: immutable rejected candidate and CR-02 signed-source diagnosis
provides:
  - source-complete FAST-01 collector, authoritative metrics receipt, workflow assertion, and offline verifier contract
  - protected-main landing proof for the exact seven tested evidence-path blobs
  - repository-scoped Hackney 4 security migration clearing the required Library tests audit
affects: [235-17, 235-18, fast-01, protected-evidence, dependency-security]

actuals:
  tokens: 18620
  tasks: 2
  commits: 8

tech-stack:
  added: [hackney-4.7.4, tzdata-1.1.5, h2, quic, webtransport]
  patterns: [source-first signed evidence, authoritative-instrument receipt, protected-main blob equality, repository-only dependency override]

key-files:
  created:
    - scripts/ci/verify-fast-01-source-complete-attestation-offline.sh
    - test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs
  modified:
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-run-metrics.test.sh
    - scripts/ci/capture-fast-01-gap-closure.sh
    - scripts/ci/capture-fast-01-gap-closure.test.sh
    - .github/workflows/fast-01-gap-closure-evidence.yml
    - mix.exs
    - mix.lock

key-decisions:
  - "Retained scripts/ci/ci-run-metrics.sh wall mode as the sole terminal authority; offline source replay is comparison-only."
  - "Used a repository-only dev/test Hackney 4 override because tzdata 1.1.5 accepts Hackney 4 while all published Threadline releases through 0.9 retain an optional 1.x constraint."
  - "Accepted the repository-required squash merge and proved all seven protected-main blobs directly because branch-HEAD ancestry cannot survive a squash-only merge."
  - "Did not dispatch FAST-01 evidence or mark FAST-01 complete; Plan 17 owns the first source-complete measurement."

patterns-established:
  - "Signed derived evidence is non-authoritative until raw page identity, row timestamps, terminal exhaustion, and source/derived equality are independently replayable."
  - "Security advisories blocking required CI are repaired in a separately scoped dependency commit with both local audit and protected-lane proof."

requirements-completed: [GATE-05]

coverage:
  - id: D1
    description: "The source-complete producer retains raw workflow pages and delegates bounded membership, queue-inclusive duration, stable ordering, floor median, pole selection, and verdict to ci-run-metrics.sh wall mode."
    requirement: FAST-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-run-metrics.test.sh#11 passing contracts"
        status: pass
      - kind: integration
        ref: "scripts/ci/capture-fast-01-gap-closure.test.sh#PASS"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "The exact seven tested evidence-path blobs are present on protected main after all five strict required checks passed."
    requirement: FAST-01
    verification:
      - kind: e2e
        ref: "GitHub Actions run 34298307012 on PR #232"
        status: pass
      - kind: other
        ref: "Protected main 158aca14b11de13cbc5ab2fdea1bff790cc7ab29 blob equality against PR head 2e77218678dfc5a0bc57c5e23afbfd46d6c1016d"
        status: pass
    human_judgment: false
  - id: D3
    description: "Hackney 1.25.0 advisories are removed from the repository lock and the required Library tests gate passes with Hackney 4.7.4."
    verification:
      - kind: integration
        ref: "mix hex.audit#No retired or security advisory packages found"
        status: pass
      - kind: e2e
        ref: "GitHub Actions run 34298307012#Library tests"
        status: pass
    human_judgment: false
  - id: D4
    description: "GATE-05 remains Complete and its protected receipts, 93-row ownership proof, and contributor topology remain unchanged."
    requirement: GATE-05
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs#completed ownership proof and contributor topology remain immutable"
        status: pass
    human_judgment: false

duration: 1h 12m
completed: 2026-09-08
status: complete
---

# Phase 235 Plan 16: Source-Complete FAST Evidence Path Summary

**A replayable FAST-01 evidence producer is now on protected main with exact blob proof, while a scoped Hackney 4 migration restored the required security gate without dispatching a measurement.**

## Performance

- **Duration:** 1h 12m
- **Started:** 2026-09-09T00:12:22Z
- **Completed:** 2026-09-09T01:24:29Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- Replaced derived-only FAST evidence with signed raw source pages, explicit pagination/exhaustion, authoritative wall-mode instrument output, independently replayable membership/statistics, and complete miss-pole job/step receipts.
- Passed protected CI run `34298307012` on sole scoped PR #232 and landed the tested path on protected main at `158aca14b11de13cbc5ab2fdea1bff790cc7ab29`.
- Cleared four Hackney 1.25.0 advisories, including the HIGH-severity `CVE-2026-47071`, with `hackney 4.7.4` plus `tzdata 1.1.5`; no required check was waived.
- Preserved the completed GATE-05 proof and performed no FAST-01 evidence dispatch.

## Task Commits

1. **Task 1 RED — source-complete contracts:** `47a88f14` (test)
2. **Task 1 GREEN — source-complete evidence path:** `18a33772` (feat)
3. **Task 2 formatter/protected-contract repair:** `4c46c55f` (fix)
4. **Task 2 protected-CI blocker diagnostics:** `7d43a60a` (docs)
5. **Task 2 historical coverage assertion repair:** `bca5ae2e` (fix)
6. **Task 2 dependency-security migration:** `6b2a7983` (fix)
7. **Task 2 current-main synchronization:** `2e772186` (merge)
8. **Protected-main squash merge:** `158aca14` (PR #232)

## Protected Evidence Path

Protected-main commit: `158aca14b11de13cbc5ab2fdea1bff790cc7ab29`  
Tested PR head: `2e77218678dfc5a0bc57c5e23afbfd46d6c1016d`

| File | Matching blob |
| --- | --- |
| `scripts/ci/ci-run-metrics.sh` | `f8802024614f0e083e511e86cc7b8b8e15da5a41` |
| `scripts/ci/ci-run-metrics.test.sh` | `49418c1735f23d781e0a5192251252daa0945854` |
| `scripts/ci/capture-fast-01-gap-closure.sh` | `92e9fcc71a27123433e252029a3c8c343abcbddc` |
| `scripts/ci/capture-fast-01-gap-closure.test.sh` | `09d33bfef6f8b8cd244c98390b9c78cb2b52cbe1` |
| `.github/workflows/fast-01-gap-closure-evidence.yml` | `159f05efe11d81f5ab48b838ac68369063e0340e` |
| `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` | `bce81c9e9f81f51d0322cd363a1d415a234c4ea2` |
| `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` | `39b11dee71b8e708a4b3e4c744402231ea7130f9` |

The repository rejected merge commits, so PR #232 used its allowed squash method. The plan's literal `git merge-base --is-ancestor HEAD origin/main` check cannot succeed for a squashed PR head; direct equality of every declared protected blob proves the required invariant.

## Verification

- RED contracts failed for the expected missing source-page input and source-complete workflow/verifier semantics before implementation.
- `bash scripts/ci/ci-run-metrics.test.sh`: 11 passed, 0 failed.
- `bash scripts/ci/capture-fast-01-gap-closure.test.sh`: PASS.
- Focused Phase 235 ExUnit contracts: 35 tests, 0 failures.
- Full library suite after a forced local rebuild: 33 doctests, 3 properties, 2548 tests, 0 failures, 12 skipped, 22 excluded.
- `mix hex.audit`: no retired or security advisory packages found.
- Protected CI run `34298307012`: success; all five strict required checks passed.
- No `fast-01-gap-closure-evidence.yml` workflow dispatch occurred after the rejected run `34272746647`; Plan 16 performed no measurement.

## Decisions Made

- Kept the dependency override repository-only (`only: [:dev, :test]`, `runtime: false`) so the security-gate repair does not expand Sigra's runtime package surface.
- Updated tzdata because 1.1.5 is the first retained lock version explicitly accepting Hackney 4; used Mix's top-level override for Threadline's still-stale optional constraint.
- Kept FAST-01 open. This plan establishes safe measurement capability; Plan 17 must populate the capture-specific verifier pins and perform the separately authorized measurement flow.

## Deviations from Plan

### Authorized Scope Exception

**1. Dependency-security migration to restore required CI**
- **Found during:** Task 2 protected CI run `34295647672`.
- **Issue:** Newly published advisories made locked `hackney 1.25.0` fail the required Library tests security audit; one advisory was HIGH severity.
- **Authorization:** The user explicitly authorized the minimal package/constraint migration despite Plan 235-16's original package-change prohibition.
- **Fix:** Added a repository-only Hackney `~> 4.7` override, updated `tzdata` to 1.1.5, locked Hackney 4.7.4 and its new transitive graph, and removed obsolete 1.x-only entries.
- **Files modified:** `mix.exs`, `mix.lock`.
- **Verification:** clean dependency checks, clean `mix hex.audit`, 23 focused Threadline integration tests, full library suite, and protected run `34298307012`.
- **Committed in:** `6b2a7983`.

### Auto-fixed Issues

**2. [Rule 1 - Bug] Repaired stale historical evidence coverage assertion**
- **Found during:** Task 2 exact local `mix ci` gate.
- **Issue:** The historical remeasurement contract required a superseded workflow filename in the current coverage document.
- **Fix:** Asserted the durable `Historical FAST-01 remeasurement` coverage capability instead of a superseded filename.
- **Files modified:** `test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs`.
- **Verification:** Four focused Phase 235 contracts passed 35 tests / 0 failures; full library suite passed.
- **Committed in:** `bca5ae2e`.

**3. [Rule 3 - Blocking] Used direct blob equality after required squash merge**
- **Found during:** Task 2 protected-main verification.
- **Issue:** Repository settings reject merge commits, so a squash-merged PR head is not an ancestor of protected main.
- **Fix:** Compared all seven declared blobs between tested PR head and protected-main merge SHA; every object ID matched exactly.
- **Verification:** seven explicit `MATCH` results plus zero diff for all declared paths.
- **Committed in:** protected-main merge `158aca14` and this summary.

**Total deviations:** 1 explicitly authorized security exception and 2 auto-fixed blockers.  
**Impact on plan:** The exact evidence path landed with stronger byte proof, required CI remained fully enforced, and no measurement or requirement-status expansion occurred.

## Known Stubs

| File | Line | Stub | Reason |
| --- | ---: | --- | --- |
| `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` | 14 | Four `UNSET_PLAN_17_*` capture pins | Intentional fail-closed handoff; Plan 17 installs the subject digest, trusted-root digest, workflow SHA, and endpoint only after the first protected source-complete capture. |

These pins are required by Plan 16's contract and do not prevent the producer from being safely present on protected main; they prevent premature verification or closure.

## Issues Encountered

- The local `.tool-versions` requests Erlang 28.5, which is not installed in this environment. Verification used process-local Erlang 28.4.1 and Elixir 1.19.5 overrides; the user's `.tool-versions` edit was preserved and not committed.
- A prior local dep-off run left conditional modules stale in `_build`; `mix compile --force --warnings-as-errors` rebuilt the intended dependency-present state before the passing full suite. Protected CI used a clean runner and passed without intervention.
- Public Hex metadata queries warned that the local Hex authentication session had expired, but all public package queries and audits completed successfully; no private resource or authentication-dependent action was required.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 17 may now use protected-main SHA `158aca14b11de13cbc5ab2fdea1bff790cc7ab29` as its read-only landing precondition, populate the four capture-specific verifier pins, and request the one source-complete measurement authorization. FAST-01 remains open until that signed source population is verified.

## Self-Check: PASSED

All created artifacts, eight recorded commits/merge SHAs, the protected-main merge identity, and the seven exact blob matches were verified from disk and git history.

---
*Phase: 235-terminal-ratification-measured-not-read*
*Completed: 2026-09-08*
