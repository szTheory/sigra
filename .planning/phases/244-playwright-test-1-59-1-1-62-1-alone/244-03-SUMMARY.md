---
phase: 244-playwright-test-1-59-1-1-62-1-alone
plan: 03
subsystem: testing
tags: [playwright, screenshots, ci, evidence]
requires:
  - phase: 244
    provides: pinned candidate and exact screenshot comparator from plans 01–02
provides:
  - Complete paired Playwright measurement receipt with verified package/browser provenance and recorded drift
  - Same-SHA fast_checks and cache guard proof for the measurement candidate
  - Durable diagnostics for historical inconclusive runs and the initial push-after-failed-gate incident
affects: [phase-244 verification, Playwright CI evidence]
actuals:
  tokens: 96228
  tasks: 2
  commits: 37
tech-stack:
  added: []
  patterns: ["Keep failed or inconclusive measurement receipts with immutable run identity."]
key-files:
  created:
    - .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json
    - .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-03-MIX-CI-LOG.txt
    - .planning/todos/pending/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md
  modified:
    - .github/workflows/phase-244-playwright-measure.yml
    - scripts/ci/measure-playwright-drift.mjs
    - scripts/ci/measure-playwright-drift.test.mjs
    - scripts/ci/run-playwright-drift.sh
key-decisions:
  - "Keep failed and inconclusive prior runs as immutable diagnostics; use the complete 115-image run as the current paired measurement."
  - "Record the measured pixel drift without waiving it; merge eligibility remains false and Plan 04 owns final PR disposition."
  - "Keep the admin_behavior assertion failure outside Plan 03 scope; fast_checks and both cache guards passed on the candidate SHA."
requirements-completed: []
plan_head_before: 4123cbaafd3c21c357011424731380b0bdb80973
duration: not recorded
completed: 2026-09-26
status: complete
---

# Phase 244 Plan 03: Paired Playwright Measurement Summary

**A complete same-runner paired capture produced a verified 115-image drift receipt on candidate SHA `980812c`, with zero missing or extra paths and 30 changed images totaling 380,825 changed pixels.**

## Accomplishments

- Fixed the baseline lockfile transform so render A resolves `@playwright/test`, `playwright`, and `playwright-core` to `1.59.1`; render B resolves all three to `1.62.1`.
- Added and locally verified a dependency preflight that installs the operating-system requirements for both Playwright versions before either capture, then runs both passes in the same runner environment.
- Ran the corrected full measurement as workflow [36262576391](https://github.com/szTheory/sigra/actions/runs/36262576391) on source SHA `980812cba598781b0b95a763562aaafbd093afb8`. The workflow is red because the recorded measurement verdict is **drift**, as intended by the fail-closed harness.
- Downloaded and verified the artifact. The 115 expected image paths are complete, both package trios and both tagged browser manifests verified, and the receipt records 30 changed images / 380,825 changed pixels. The manifest verifier accepts the recorded drift and reports `merge_eligible: false`. Render trees and browser manifest artifacts are retained at `/private/tmp/sigra-phase244-run-36262576391/phase-244-playwright-measurement-36262576391`.
- Refreshed PR #213 as closed and unmerged, with head `9f5150bd…`; its August 8 failed run remains stale historical cache-key evidence and is not visual proof. Current `main` is `5a00b90d…`; latest CI run `36220498815` and Playwright smoke checks passed on that SHA.
- Refreshed evidence PR #283 as open/draft at candidate SHA `980812c`. Run `36262573493` passed `fast_checks` and both cache guards on that exact SHA. Its overall CI is red only because the unrelated `tests/admin-audit.spec.ts:77` URL assertion fails in `admin_behavior`, so `ci-gate` fails. That assertion remains out of scope.
- Exact `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` passed at clean HEAD `980812c` under the authorized host-permission retry (2,614 tests, zero failures; Threadline guard 65/0). The earlier initial push of `73858d81` after a failed gate remains explicitly disclosed in the evidence; later branch pushes were gated by passing exact-head CI.

## Verification

- `node --test scripts/ci/measure-playwright-drift.test.mjs` — 15 passed.
- `bash -n scripts/ci/run-playwright-drift.sh`, `node --check` on the measurement runner and test, and `git diff --check` passed after the dependency-preflight change.
- `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` — exit 0 at `980812cba598781b0b95a763562aaafbd093afb8`.
- Measurement workflow `36262576391` — complete paired capture, 115/115 inventory, verified package and browser identities, verdict `drift`; workflow exit 1 is the expected fail-closed verdict result.
- `node scripts/ci/measure-playwright-drift.mjs verify --manifest .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json --source-sha 980812cba598781b0b95a763562aaafbd093afb8 --validate-recorded-outcome` — valid; 115 paths, verdict `drift`, merge eligibility false.
- PR CI run `36262573493` — same-SHA `fast_checks` success and both cache guards passed; unrelated admin audit assertion failure keeps full `ci-gate` red.

## Task Commits

- `73858d81` — initial measurement workflow and harness; initial push followed a failed `mix ci` gate and remains disclosed.
- `629f7f53` — merge refreshed `main` into the disposable measurement branch.
- `ab24b285` — pin the baseline Playwright package trio.
- `e0f58a1f`, `257a5cda`, `f520af74`, `06abd539` — preserve prior measurement diagnostics and resumable gate state.
- `1d21497a` — resume bookkeeping after the exact gate passed.
- `980812cb` — install both browser system-dependency sets before capture and record contract coverage.

## Disposition

Plan 03 is complete: it produced and committed a complete, internally consistent measurement receipt and same-SHA `fast_checks` proof. The measured result is real pixel drift, so it is not merge eligible. Plan 04 must assess the drift and decide the PR disposition; do not interpret the green targeted job as full CI approval. The separate admin audit failure remains outside this plan.

The phase summary, evidence JSON, and gate log are maintained in the disposable clone. The earlier initial push incident, historical inconclusive runs, and stale August 8 result remain in the durable evidence record.

## Self-Check: PASSED

- Evidence JSON and CI diagnostic log exist in the phase directory.
- Source, test, and workflow changes are committed through `980812cb`; final evidence and summary are ready for the exact-head gate.
- The phase evidence verifier accepted run `36262576391` at source SHA `980812cba598781b0b95a763562aaafbd093afb8`.
