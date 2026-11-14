---
phase: 253
plan: 19
subsystem: ci-evidence
tags: [ci, github-checks, evidence, transport, bounded-inputs]
dependency-graph:
  requires: [253-18]
  provides: [measured-hosted-transport-verifier, exact-check-source-verifier, bounded-canary-inputs]
  affects: [scripts/ci/ci-hosted-gate-verify.py, scripts/ci/ci-gate-canary.sh, scripts/ci/ci-hosted-transport.py]
tech-stack:
  added: []
  patterns: [measured-v2-transport-ledger, independent-receipt-reconciliation, bounded-archive-decoding]
key-files:
  created: []
  modified:
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-gate-canary.test.sh
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
decisions:
  - New acceptance modes require measured v2 transport evidence; historical v1 evidence remains available for disclosure only.
  - Dispatch input limits are checked separately as Unicode scalar count and UTF-8 byte count, with exact serialized bytes retained for reconciliation.
  - Canary archives and matrix payloads are decoded under strict size and single-stream rules before evidence is accepted.
metrics:
  duration: 179 minutes
  completed: 2026-10-13
  status: complete
  commits: 4
  plan_head_before: 653ca9e43b42cd36588bea7d6db98c367cf6013c
  plan_head_after: 39bf6fdfdfbe0107e24bb71d115763b111e6f479
actuals:
  tokens: 24971
  tasks: 2
  commits: 4
---

# Phase 253 Plan 19: Measured Hosted Check Evidence Summary

Implemented a measured v2 hosted-transport verifier and hardened the canary adapter so locally generated evidence is reconciled against actual request receipts, complete required-check sources, exact transmitted input bytes, and bounded archive contents.

## Tasks Completed

| Task | Name | Commit |
| --- | --- | --- |
| 1 | Verify measured transport and complete effective check sources | `74dcfb2ed` RED, `334b08274` GREEN |
| 2 | Bind dispatch inputs and artifacts to exact bounded bytes | `5ca5b89ed` RED, `39bf6fdfd` GREEN |

Task 1 adds independent reconciliation of v2 origin, ledger, receipt, and status/header/body digests; explicit page and redirect accounting; complete fresh ruleset and legacy protection reads; and exact verification of the five required check names and native check-run sources. The canary adapter now retains the measured source evidence and uses the new accepted-ref namespace.

Task 2 adds a typed, byte-exact dispatch input serializer with independent Unicode-scalar and UTF-8 byte limits. It also rejects malformed, oversized, concatenated, or trailing ZIP/gzip payloads and accepts only the single bounded regular `canary-result.json` archive member. Signed redirect query strings are redacted from retained receipts while URL digests preserve reconciliation.

## Verification

- `python3 scripts/ci/ci-hosted-gate-verify.test.py` — 24 tests passed.
- `bash scripts/ci/ci-gate-canary.test.sh` — passed with a synthetic fixture repository; no active phase refs or ledgers were used.
- `python3 scripts/ci/ci-hosted-transport.test.py` — 15 tests passed, including real local HTTPS 200/404 responses reconciled into an independent v2 verdict.
- `bash -n scripts/ci/ci-gate-canary.sh scripts/ci/ci-gate-canary.test.sh` — passed.
- `git diff --check` — passed for the six plan files.

These checks prove the local verifier and hermetic fixture behavior. This plan made no GitHub requests and does not prove live repository branch-rule configuration, required-check enforcement, hosted workflow execution, or phase acceptance; those remain for the later hosted verification plans.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the shell adapter's handling of allowed 404 responses.**
- **Found during:** Task 1
- **Issue:** The existing status condition rejected the explicitly permitted 404 response and could treat a different response as allowed.
- **Fix:** Corrected the status comparison and covered the 200/404 behavior with local HTTPS tests.
- **Files modified:** `scripts/ci/ci-gate-canary.sh`, `scripts/ci/ci-hosted-transport.test.py`
- **Commit:** `334b08274`

**2. [Rule 1 - Bug] Prevented signed redirect query strings from being retained in transport evidence.**
- **Found during:** Task 2
- **Issue:** Retaining the full redirected URL could disclose signed query credentials in the evidence ledger.
- **Fix:** Retain a redacted URL and its digest, then verify that signed values do not appear in receipts.
- **Files modified:** `scripts/ci/ci-hosted-transport.py`, `scripts/ci/ci-hosted-transport.test.py`
- **Commit:** `39bf6fdfd`

## Auth Gates

None.

## Self-Check: PASSED

The summary file exists, and all four listed task commits are ancestors of the plan's current HEAD.
