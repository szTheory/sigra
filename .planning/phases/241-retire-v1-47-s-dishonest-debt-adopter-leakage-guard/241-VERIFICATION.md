---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
verified: 2026-09-19T17:29:03Z
status: gaps_found
score: 41/43 must-haves verified
covered_files:
  - .github/ci-skip-manifest.tsv
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/.continue-here.md
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
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-CONTEXT.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-RESEARCH.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-REVIEW-FIX.md
  - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-REVIEW.md
  - MAINTAINING.md
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
  - test/fixtures/prohibitions/p18-planning-path-leak.ex
  - test/fixtures/prohibitions/p18-ratchet-r1-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r2-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r3-exceeded.tsv
  - test/fixtures/prohibitions/p18-template-allowlist-shadow.ex
  - test/fixtures/prohibitions/p18-template-bookkeeping.ex
  - test/fixtures/prohibitions/p21-maintaining-stale-topology.md
  - test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-block-uses.yml
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
covered_digest: "v1:sha256:48c9779e40cb6b1417a9dfa961b17bfff9b2b5c6a126d6ee18f36c4c4c05ba7b"
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 30
  total: 30
  not_honored: []
gaps:
  - truth: "The phase's `mix ci` success criterion is green at final HEAD."
    status: failed
    reason: "`MIX_ENV=test mix ci` reached its test leg with 2,607 tests and 6 Threadline failures; the command then timed out in a later alias leg. `gh run list --commit 6c79afd…` returned no runs, and HEAD is 40 commits ahead of origin/main, so no final-head CI success exists to satisfy the CI-only claim."
    artifacts:
      - path: "test/sigra/audit/forwarders/threadline_test.exs"
        issue: "Six `Sigra.Audit.Forwarders.ThreadlineTest` cases call undefined `Sigra.Audit.Forwarders.Threadline.attach/1` during the exact alias run."
    missing:
      - "A successful final-HEAD CI run (or a fix for the six failures) proving the exact `mix ci` criterion."
  - truth: "R1's JavaScript doc-range scanner faithfully preserves the locked Phase-237 Python scanner surface (D-30 and the final CR-03 decline)."
    status: failed
    reason: "The JS scanner added lowercase, pipe, and paired string-sigil recognition after the original port. The committed Phase-237 scanner intentionally recognizes only heredocs and one-line quoted attributes. On the committed `p18-doc-range-delimited-sigils.ex` fixture, the Python scanner returns `total_hits=0` while JS returns `totalHits=2`; the real-tree 337/337 equality is therefore coincidental and does not establish behavioral parity."
    artifacts:
      - path: "scripts/ci/prohibitions/_p18-lib.mjs"
        issue: "`docRangeOpening()` and `SIGIL_CLOSING_DELIMITERS` broaden the locked scanner language, contradicting the documented rejection of generalized sigil parsing."
      - path: "scripts/ci/prohibitions/p18-doc-range.test.mjs"
        issue: "Tests assert the broadened sigil behavior rather than equivalence with the Phase-237 scanner."
    missing:
      - "Remove the generalized-sigil extension and its tests to restore D-30 parity, or explicitly authorize a scanner-spec revision with a full parity contract and deliberate re-baselining in a separate phase."
---

# Phase 241: Retire v1.47's Dishonest Debt + Adopter-Leakage Guard — Verification Report

**Phase Goal:** Every guard in the repo that currently asserts nothing either asserts something real or is gone — and new adopter-visible leakage cannot land.
**Verified:** 2026-09-19T17:29:03Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | ADR-backed formatter retirement leaves the `mix ci` topology unchanged and green. | ✗ FAILED | ADR 004 exists, both formatter files are absent, the alias contract test passes, but final-head `MIX_ENV=test mix ci` has six failures and no final-head CI run exists. |
| 2 | The replacement library-suite invariant is demonstrably RED on a committed two-owner workflow and GREEN on the real workflow. | ✓ VERIFIED | Targeted ExUnit test: 5/5 GREEN; fixture exits 2 with `more than one owner of the full library suite` and both parsed job ids. |
| 3 | The honest-skip guard was authored before the documentation correction, rejects a committed stale subject, and protects the real documentation without workflow edits. | ✓ VERIFIED | Commit order is `ffc23579` (guard) then `f1e3563b` (doc correction); `p21` is GREEN on real inputs and its fixture exits 1 with an attributable stale-id diagnostic. |
| 4 | Composite-action pins, including bare `uses:`, are visible in both failure and success directions. | ✓ VERIFIED | Phase-234 test: 13/13 GREEN; bare and dashed fixtures each exit 2 with their path and `non-immutable action ref`; live inventory has a 16-entry floor. |
| 5 | P18 blocks new planning leakage and independently ratchets R1/R2/R3 without workflow or `mix ci` topology changes. | ✓ VERIFIED | 106 prohibition tests GREEN; planning/template/doc fixtures and each one-counter baseline fixture RED with their own diagnostic; `ci.yml` glob includes `p18-*.test.mjs` and phase diff does not edit it or `mix.exs`. |
| 6 | The JS R1 scanner is a faithful Phase-237 scanner port, as D-30 and the final review disposition require. | ✗ FAILED | Real-tree totals coincide (337/337), but the committed delimited-sigil fixture yields Python 0 vs JS 2, proving broadened and non-equivalent behavior. |

**Score:** 41/43 must-haves verified (0 present but behavior-unverified)

The score covers all 42 PLAN-frontmatter truths plus the roadmap-only final-head `mix ci` success criterion. The two failures above are blocking gaps; no override applies.

### Required Artifacts

| Artifact group | Expected | Status | Details |
| --- | --- | --- | --- |
| ADR 004 and formatter deletion | Recorded supersession; exactly two formatter files retired | ✓ VERIFIED | ADR sections include the replacement guarantee and ten affected refs; filtered source sweep is empty; deleted paths are absent. |
| Phase-233 contract and two-owner fixture | Runtime-selected, non-vacuous derived invariant | ✓ VERIFIED | `subject_path/0` reads `SIGRA_CONTRACT_SUBJECT` at call time; job grammar includes hyphen/digit suffixes; real and known-bad directions were executed. |
| P21 and stale-doc fixture | Offline MAINTAINING/manifest parity guard | ✓ VERIFIED | Reads committed files only; is picked up by existing glob; retains p10 ownership checks rather than duplicating them. |
| Phase-234 pin contract and bare/dashed fixtures | Composite universe plus relaxed inventory parser | ✓ VERIFIED | Separate recursive composite universe, non-vacuity and numeric floor; external-local paths and unsupported flow/block YAML forms fail closed. |
| P18 helper, three hard-fail guards, allowlist, baselines and fixtures | Detect leakage and ratchet it independently | ⚠️ PARTIAL | All operational guards and RED/GREEN evidence work, but the doc-range helper exceeds the locked Python scanner specification. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| ADR 004 | Phase-233 contract | `exactly one owner` replacement guarantee | ✓ WIRED | The contract counts `MIX_ENV=test mix ci` across derived `library_tests*` bodies. |
| Phase-233 fixture | Phase-233 contract | `SIGRA_CONTRACT_SUBJECT` | ✓ WIRED | Fixture produces the contract's own ownership failure text, not a compile-only failure. |
| P21 | existing CI guard pickup | `scripts/ci/prohibitions/*.test.mjs` | ✓ WIRED | Existing `ci.yml:408` glob discovers the filename; no workflow edit is required. |
| Phase-234 inventory | composite actions | `Path.wildcard(".github/actions/**/action.yml")` | ✓ WIRED | Live `action.yml` is scanned; bare and dashed fixtures exercise separate required surfaces. |
| P18 files | existing CI guard pickup | same `ci.yml:408` glob | ✓ WIRED | Full glob ran 106 tests successfully. |
| Phase-237 Python scanner | P18 JS R1 scanner | claimed faithful port / parity cross-check | ✗ NOT_WIRED AS PARITY | Current-tree numeric equality is insufficient; the committed sigil fixture exposes different scanner semantics. |

### Data-Flow Trace (Level 4)

No rendered-data artifacts are in scope. The guards consume tracked repository files, environment-selected committed fixtures, and committed TSV baselines; no mock/static API return path exists.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Full prohibition suite | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | 106 pass, 0 fail, 0 skipped | ✓ PASS |
| Library owner contract, real source | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | 5 tests, 0 failures | ✓ PASS |
| Library owner contract, known bad | `SIGRA_CONTRACT_SUBJECT=…two-owners.yml mix test …phase_233…` | exit 2; `more than one owner of the full library suite` | ✓ RED PROVEN |
| Action-pinning contract, real source | `mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs` | 13 tests, 0 failures | ✓ PASS |
| Action pin bare/dashed known-bad fixtures | `SIGRA_CONTRACT_SUBJECT=…fixture mix test …phase_234…` | each exit 2; own path and `non-immutable action ref` | ✓ RED PROVEN |
| P21 stale document | `GSD_PROHIB_SUBJECT=…p21-maintaining-stale-topology.md node --test …p21…` | exit 1; stale `retired_skip_lane` identified | ✓ RED PROVEN |
| P18 hard-fail fixtures | subject-injected `p18-{planning,templates,doc-range}` tests | each exit 1 with `P18 DIRTY SURFACE` | ✓ RED PROVEN |
| P18 ratchet fixtures | `GSD_P18_BASELINE=…r{1,2,3}-exceeded.tsv node --test …ratchet…` | each exits 1 with only matching `P18 RATCHET REGRESSION Rn` | ✓ RED PROVEN |
| Current-tree Phase-237/JS count | Python scanner and `docRangeTotal("lib")` | Python 337; JS 337 | ✓ PASS, insufficient for semantic parity |
| Scanner parity counterexample | Python fixture scan vs JS subject-injected fixture scan | Python 0; JS 2 for `p18-doc-range-delimited-sigils.ex` | ✗ FAIL |
| Final CI alias | `MIX_ENV=test mix ci` | test leg: 2,607 tests, 6 failures; later timed out | ✗ FAIL |

### Probe Execution

SKIPPED — Phase plans declare no `probe-*.sh` paths and the repository has no conventional probe scripts.

### Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
| --- | --- | --- | --- |
| DEBT-01 | 241-01 | ✓ SATISFIED | ADR, exact deletions, zero filtered-reference sweep, strict compile, and phase-233 alias test all hold. The broader roadmap CI-green criterion remains a separate blocking gap. |
| DEBT-02 | 241-02 | ✓ SATISFIED | Function-resolved fixture RED and real-workflow GREEN prove the derived owner guarantee; archived remediation JSON remains present. |
| DEBT-03 | 241-03 | ✓ SATISFIED | Guard-before-doc-correction history, stale-fixture RED, real-source GREEN, and manifest citations were directly checked. |
| DEBT-04 | 241-04 | ✓ SATISFIED | Composite universe, bare/dashed RED directions, and live inventory floor are exercised by active ExUnit tests. |
| SURF-04 | 241-05, 241-06 | ✗ BLOCKED | The operational guard suite passes, but its R1 implementation violates the locked scanner-surface contract; its claimed parity is not true beyond the current corpus. |

### Test Quality Audit

| Test files | Linked requirements | Active | Skipped | Circular | Assertion level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `phase_233_*`, `phase_234_*` | DEBT-01/02/04 | 18 | 0 | No | Value and behavioral fixture assertions | ✓ Sufficient |
| `p21-*` | DEBT-03 | 3 | 0 | No | Behavioral parity assertions | ✓ Sufficient |
| `p18-*` | SURF-04 | 10 directly in p18 suite; 106 total glob | 0 | No | Value and behavioral RED/GREEN assertions | ⚠️ Parity assertion insufficient: current-tree count only |

No linked test is disabled. No test writes expected fixtures or imports the system under test to generate expected values. The known-bad fixtures are committed independent inputs. The one test-quality finding is the semantic parity blind spot recorded as the second gap.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `241-04-EVIDENCE.md` | 3 | trailing whitespace | ⚠️ Warning | Documentation hygiene only; does not change guard behavior. |
| `241-REVIEW-FIX.md` | several | trailing whitespace | ⚠️ Warning | Documentation hygiene only; does not change guard behavior. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt marker was added by phase commits. Empty-array/null matches are guarded parser defaults or explicit non-vacuity assertions, not output stubs.

### Decision Coverage

All 30 trackable CONTEXT decisions are represented in phase artifacts (`check.decision-coverage-verify`: 30/30). This non-blocking gate does not override the deterministic failures above.

### Human Verification Required

N/A — this is an infrastructure/foundation phase. Every relevant truth has a deterministic command; the two unresolved items are automated blockers, not manual-UAT questions.

### Gaps Summary

1. The required final-head CI green result does not exist. The local exact alias run is red in its test leg (six failures), while the final HEAD is unpushed and has no GitHub Actions run to establish the CI-only claim.
2. The R1 scanner is not the faithfully bounded Phase-237 port the phase explicitly chose. The implementation and tests added exactly the generalized sigil behavior that the final review declined. Matching the current `lib/` total is coincidental; the committed fixture demonstrates a 0-versus-2 semantic mismatch.

No later roadmap phase explicitly owns either gap, so neither is deferred.

---

_Verified: 2026-09-19T17:29:03Z_
_Verifier: the agent (gsd-verifier)_
