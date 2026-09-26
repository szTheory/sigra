---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
verified: 2026-09-25T17:10:52Z
status: passed
score: 43/43 must-haves verified
covered_files:
  - .github/actions/example-playwright-boot/action.yml
  - .github/ci-skip-manifest.tsv
  - .github/workflows/ci.yml
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/STATE.md
  - .planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-02-EVIDENCE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-02-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-02-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-03-EVIDENCE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-03-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-03-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-04-EVIDENCE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-04-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-04-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-05-EVIDENCE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-05-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-05-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-06-EVIDENCE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-06-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-06-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-07-EVIDENCE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-07-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-07-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-08-PLAN.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-08-SUMMARY.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-CONTEXT.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/COVERAGE.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-UAT.md
  - MAINTAINING.md
  - mix.exs
  - scripts/ci/capture-phase-241-final-head.sh
  - scripts/ci/capture-phase-241-final-head.test.sh
  - scripts/ci/prohibitions/_p18-lib.mjs
  - scripts/ci/prohibitions/p18-allowlist.tsv
  - scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs
  - scripts/ci/prohibitions/p18-doc-range.test.mjs
  - scripts/ci/prohibitions/p18-planning-paths.test.mjs
  - scripts/ci/prohibitions/p18-ratchet-baseline.tsv
  - scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs
  - scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs
  - test/fixtures/prohibitions/p10-manifest-stale-entry.tsv
  - test/fixtures/prohibitions/p18-doc-range-delimited-sigils.ex
  - test/fixtures/prohibitions/p18-doc-range-leak.ex
  - test/fixtures/prohibitions/p18-doc-range-lowercase-sigil.ex
  - test/fixtures/prohibitions/p18-doc-range-parity.tsv
  - test/fixtures/prohibitions/p18-doc-range-python-language.ex
  - test/fixtures/prohibitions/p18-planning-path-leak.ex
  - test/fixtures/prohibitions/p18-ratchet-r1-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r2-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r3-exceeded.tsv
  - test/fixtures/prohibitions/p18-template-allowlist-shadow.ex
  - test/fixtures/prohibitions/p18-template-bookkeeping.ex
  - test/fixtures/prohibitions/p21-maintaining-stale-topology.md
  - test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-flow-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-quoted-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-space-before-colon-uses.yml
  - test/fixtures/prohibitions/phase241-library-economics-two-owners.yml
  - test/fixtures/prohibitions/phase241-nested-composite-unpinned/release/bootstrap/action.yml
  - test/fixtures/prohibitions/phase241-release-workflow-external-composite/release-workflow.yml
  - test/fixtures/prohibitions/phase241-release-workflow-external-composite/release/bootstrap/action.yml
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/sigra/planning/phase_234_action_pinning_contract_test.exs
covered_digest: "v1:sha256:476aabf197c09c0ee7bdc9a56ff2da03bb7383ff6b205cd4eb759e0e228f5832"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 43/43
  gaps_closed: []
  gaps_remaining: []
  regressions: []
advisory: []
decision_coverage:
  honored: 30
  total: 30
  not_honored: []
---

# Phase 241: Retire v1.47's Dishonest Debt + Adopter-Leakage Guard — Verification Report

**Phase Goal:** Every guard in the repo that currently asserts nothing either asserts something real or is gone — and new adopter-visible leakage cannot land.
**Verified:** 2026-09-25T17:10:52Z
**Status:** passed
**Re-verification:** Yes — refresh after shared milestone metadata changes; the prior gap-closure report passed 43/43.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | ADR-backed formatter retirement leaves the `mix ci` topology unchanged and green. | ✓ VERIFIED | ADR 004 exists; both formatter paths are absent; the phase diff leaves `mix.exs` and `ci.yml` untouched. GitHub run `35466064602` at final SHA `782328e…` completed successfully and its `Library tests shard` / `Run contributor CI gate` executed `MIX_ENV=test mix ci` successfully. |
| 2 | The replacement library-suite invariant is RED on a committed two-owner workflow and GREEN on the real workflow. | ✓ VERIFIED | Real-source contract: 5/5 green. Injected committed `phase241-library-economics-two-owners.yml` exits 2 and reports both `library_tests` and `library_tests-canary_2` as owners. |
| 3 | The honest-skip guard predates the documentation correction, rejects a committed stale subject, and protects real documentation without workflow edits. | ✓ VERIFIED | The committed p21 suite is 3/3 green; injected stale fixture exits 1 with `retired_skip_lane`; phase history keeps guard commit `ffc23579` before documentation correction `f1e3563b`. |
| 4 | Composite-action pins, including bare `uses:`, are visible in failure and success directions. | ✓ VERIFIED | `phase_234_action_pinning_contract_test.exs` is 13/13 green and includes actual bare, dashed, quoted, block, flow, and nested committed fixture assertions plus the real composite inventory. |
| 5 | P18 blocks new planning leakage and independently ratchets R1/R2/R3 without workflow or `mix ci` topology changes. | ✓ VERIFIED | The existing `ci.yml` glob executes the suite; current run `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` passes 112/112 tests. Output confirms independent counters `R1=337`, `R2=220`, and `R3=58`, each equal to its own decrease-or-equal baseline. No Phase 241 diff touches `ci.yml` or `mix.exs`. |
| 6 | The JS R1 scanner is a faithful bounded Phase-237 scanner port, as D-30 requires. | ✓ VERIFIED | Direct oracle sweep: real `lib/` Python/JS/R1 = `337/337/337`; fixture totals are leak `1/1`, lowercase `0/0`, delimited `0/0`, accepted language `4/4`. The permanent Node suite is 4/4 green. |

**Score:** 43/43 must-haves verified (0 present but behavior-unverified)

The earlier gap-closure pass closed both failed truths. This refresh follows Phase 242's completion transition and current shared lifecycle-record reconciliation. The roadmap and requirements edits are confined to later phases/requirements; Phase 241's goal, criteria, requirements, implementation, and evidence remain unchanged. The API-coverage pre-gate initially flagged the phase's GitHub evidence collector; the new phase matrix enumerates all six real collector capabilities and passed the seal-time validator. Re-ran the complete prohibition suite: 112 tests passed, including the p18 counters and negative controls. UAT is complete at 18/18 passing machine-evidenced checks with no issues, pending items, skips, or human checkpoints. The existing roadmap plan-count discrepancy (6 listed versus 8 completed plans) remains non-blocking and is recorded below.

### Advisory (New Scope, Unevidenced)

None. The re-verification anti-pattern scan found no new-scope concern needing advisory treatment.

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| ADR 004 and retired formatter paths | Supersession record and two deletions | ✓ VERIFIED | ADR exists; `test/support/ci/ex_unit_timing_formatter.ex` and `_test.exs` are absent. |
| Phase-233 contract and fixture | Non-vacuous single-owner guarantee | ✓ VERIFIED | Runtime subject selection exists; real test is green and committed two-owner input fails for the asserted reason. |
| P21 and stale-doc fixture | Offline MAINTAINING/manifest parity guard | ✓ VERIFIED | Substantive three-test suite reads committed manifest/p10 inputs; stale fixture failure was re-executed. |
| Phase-234 contract and composite fixtures | Composite action pin inventory | ✓ VERIFIED | 13 active ExUnit cases exercise real inputs and controlled unpinned forms. |
| P18 planning/template/doc guards and baselines | Three hard-fail classes and three independent ratchets | ✓ VERIFIED | Node test glob is wired in `ci.yml:408`, has 112 active passing cases in the current run, and reports non-vacuity/instrument-failure checks. |
| `_p18-lib.mjs` and parity corpus | Exact D-30 scanner state machine | ✓ VERIFIED | The bounded `(~S)?` opener regex matches the Phase-237 Python grammar; Python and JS totals agree on every committed corpus subject. |
| Final-head collector and hermetic test | Fail-closed receipt collector | ✓ VERIFIED | `capture-phase-241-final-head.test.sh`: 58 assertions, including identity, pagination, duplicate/missing job, failed-step, and rate-limit failure paths. |
| Final evidence contract | Immutable same-SHA PR receipt | ✓ VERIFIED | PR #254's committed head is exactly `782328e…`; its schema `sigra.phase-241-final-head/1` comment was posted after that commit and names that same SHA. |
| External API coverage contract | Complete, valid matrix for the phase's GitHub REST collector | ✓ VERIFIED | `COVERAGE.md` enumerates rate-limit, run, paginated jobs, required jobs/steps, and PR comment capabilities; seal-time validator reports 6 capabilities, 6 integrated, 0 opt-outs. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| ADR 004 | Phase-233 contract | Single `MIX_ENV=test mix ci` owner | ✓ WIRED | The contract derives library job bodies and counts invocations rather than restating HEAD. |
| P21 | `ci.yml` guard pickup | Existing `*.test.mjs` glob | ✓ WIRED | `ci.yml:408` executes the prohibition glob; the full local suite passes. |
| Phase-234 inventory | Composite `action.yml` files | Explicit recursive composite universe | ✓ WIRED | Active ExUnit tests enumerate the real `.github/actions/**/action.yml` universe and fixtures. |
| Phase-237 Python scanner | P18 JS scanner | Literal bounded state-machine port | ✓ WIRED | The direct four-fixture oracle sweep and real-tree equality prove behavioral parity, not merely symbol presence. |
| Parity TSV and R1 baseline | `p18-doc-range.test.mjs` | Loaded expectations and baseline reader | ✓ WIRED | Permanent test reads both files; 4/4 tests pass. |
| P18 doc-range test | `ci.yml` fast checks | `scripts/ci/prohibitions/*.test.mjs` glob | ✓ WIRED | `ci.yml:398-408` contains named step and glob; final run's named step succeeded. |
| Collector | PR #254 JSON receipt | Fixed repository/run/job/step selectors | ✓ WIRED | Hermetic collector test passes and receipt comment `5744971752` matches direct GitHub API run/job data. |

## Data-Flow Trace (Level 4)

No rendered-data artifacts are in scope. Guards consume tracked repository files, committed fixtures, TSV baselines, and immutable GitHub Actions metadata; no mock/static API-return path is used as evidence.

## Behavioral Spot-Checks

| Behavior | Command / source | Result | Status |
| --- | --- | --- | --- |
| Fresh Threadline build | `MIX_ENV=test mix clean && MIX_ENV=test mix test test/sigra/audit/forwarders/threadline_test.exs` | Compiled 177 files; 6 tests, 0 failures | ✓ PASS |
| Final contributor CI | GitHub run `35466064602`, PR #254, SHA `782328e…` | `pull_request`, `completed`, `success`; named library job and step successful | ✓ PASS |
| Final P18 CI pickup | Same run's Fast checks / `Phase 230 prohibition guards` | Job and named step both `success` | ✓ PASS |
| Collector failure handling | `bash scripts/ci/capture-phase-241-final-head.test.sh` | Fresh run: 58 assertions passed, 0 failed. | ✓ PASS |
| API coverage seal gate | `gsd_run check api-coverage.verify-pre "$PHASE_DIR" --raw` | Matrix present; 6 capabilities, 6 integrated, 0 opt-outs. | ✓ PASS |
| Current prohibition regression suite | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | Fresh run: 112 passed, 0 failed, 0 skipped. | ✓ PASS |
| Current Phase 233/234 contract regressions | `MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs` | 18 pass, 0 fail; local Postgres connection log noise did not affect either contract file | ✓ PASS |
| D-30 permanent parity | `node --test --test-reporter=tap scripts/ci/prohibitions/p18-doc-range.test.mjs` | Fresh run: 4 passed, 0 failed. | ✓ PASS |
| D-30 Python comparison | Direct temporary-directory oracle sweep | Fresh run: real `lib/` Python/JS/baseline `337/337/337`; leak `1/1`, lowercase `0/0`, delimited `0/0`, accepted-language `4/4`. | ✓ PASS |
| DEBT-02 real and known-bad | Focused ExUnit plus injected committed fixture | Real 5/5 green; known-bad exit 2 with two-owner diagnostic | ✓ PASS / RED PROVEN |
| DEBT-03 real and known-bad | P21 suite plus injected stale fixture | Real 3/3 green; stale fixture exit 1 with `retired_skip_lane` | ✓ PASS / RED PROVEN |
| DEBT-04 real contract | `mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs` | 13 pass, 0 fail | ✓ PASS |
| SURF-04 full guard set | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | 112 pass, 0 fail, 0 skipped | ✓ PASS |

## Probe Execution

SKIPPED — no plan declares a `probe-*.sh` artifact and the repository has no conventional phase probe path.

## Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
| --- | --- | --- | --- |
| DEBT-01 | 241-01, 241-08 | ✓ SATISFIED | ADR/deletions and unchanged topology are present; final-SHA Actions evidence proves exact `mix ci` green without a waived Threadline test. |
| DEBT-02 | 241-02 | ✓ SATISFIED | Real invariant passes; committed two-owner fixture deterministically fails with the expected ownership diagnostic. |
| DEBT-03 | 241-03 | ✓ SATISFIED | P21 is wired into the existing glob, active on real inputs, and stale documentation deterministically fails. |
| DEBT-04 | 241-04 | ✓ SATISFIED | The 13-case contract verifies the real composite universe and controlled bare/dashed/quoted/nested bad inputs. |
| SURF-04 | 241-05, 241-06, 241-07, 241-08 | ✓ SATISFIED | All P18 guards and independent ratchets pass locally and in final-SHA Fast checks; D-30 parity is directly confirmed against the Phase-237 oracle. |

### Planning Metadata Reconciliation

The Phase 241 roadmap entry still says “6 plans” and lists 241-01 through 241-06, while the phase directory contains eight plans. Plans 241-07 and 241-08 are gap-closure plans and are included in this verification's 43 must-haves and covered-file fingerprint. The roadmap goal, five success criteria, and five mapped requirements are unchanged; this plan-count discrepancy does not change the phase verdict.

## Test Quality Audit

| Test files | Linked requirements | Active | Skipped | Circular | Assertion level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `phase_233_*`, `phase_234_*` | DEBT-01/02/04 | 18 | 0 | No | Behavioral fixture and value assertions | ✓ Sufficient |
| `p21-*` | DEBT-03 | 3 | 0 | No | Behavioral parity assertions | ✓ Sufficient |
| `p18-*` | SURF-04 | 112 glob total | 0 | No | Independent value/behavioral RED-GREEN assertions | ✓ Sufficient |
| `capture-phase-241-final-head.test.sh` | DEBT-01, SURF-04 | 58 assertions | 0 | No | Identity, pagination, negative-path, and job/step assertions | ✓ Sufficient |

No requirement-linked test contains a disabled-test marker. No test generates its expected fixture by importing the system under test; committed fixtures and the Phase-237 Python scanner are independent oracles.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `_p18-lib.mjs` / `p18-doc-range.test.mjs` | token literals and `return null` override default | Parser vocabulary and an explicit no-override default | ℹ️ Info | Not a stub: real tracked tier files are selected when no controlled test subject is injected. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt marker exists in the phase implementation. No empty handler, hardcoded rendered data, or console-only implementation exists.

## Decision Coverage

All 30 trackable CONTEXT decisions are honored by shipped artifacts (`check.decision-coverage-verify`: 30/30). This is a non-blocking gate and has no adverse finding.

## Human Verification Required

N/A — this is an infrastructure/foundation phase. Every acceptance criterion, including the external CI condition, has deterministic automated evidence.

## Gaps Summary

None. The prior final-head-CI and scanner-parity gaps are closed. The frozen evidence branch, PR #254 receipt, and direct Actions API all identify the same immutable final SHA `782328e65c134dc4b1f9bba522190838366bf08d`.

---

_Verified: 2026-09-25T17:10:52Z_
_Verifier: the agent (gsd-verifier)_
