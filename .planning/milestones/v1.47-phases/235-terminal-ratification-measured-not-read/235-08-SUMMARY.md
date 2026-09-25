---
phase: 235-terminal-ratification-measured-not-read
plan: 08
subsystem: CI evidence ratification
tags: [github-actions, sigstore, attestation, verification]
status: complete
requires: [235-07]
provides: [offline-protected-receipt-verification, gate-05-ratification]
affects: [FAST-01, GATE-05]
tech-stack: [gh, sigstore, sandbox-exec, ExUnit]
key-files:
  created:
    - scripts/ci/verify-terminal-ratification-attestation-offline.sh
    - .planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.json
    - .planning/phases/235-terminal-ratification-measured-not-read/235-PROTECTED-RECEIPTS.attestation.jsonl
    - .planning/phases/235-terminal-ratification-measured-not-read/235-TRUSTED-ROOT.jsonl
  modified:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
    - .planning/REQUIREMENTS.md
decisions:
  - Combined Sigstore Public Good and GitHub trusted roots are retained so the accepted sigstore.dev bundle verifies offline.
  - GATE-05 closes from the 93-row protected-receipt proof while FAST-01 remains an open 772-second p50 miss.
metrics:
  tasks_completed: 3
  tests: 112
---

# Phase 235 Plan 08: Protected terminal ratification summary

The accepted protected run `30782184713` now cryptographically authenticates the retained complete receipt offline; its 93 ownership rows close GATE-05 without misrepresenting the 772-second FAST-01 miss.

## Completed work

- Retained the 3.5 MB protected receipts subject, its GitHub/Sigstore bundle, and a combined 34,634-byte trusted-root JSONL.
- Added a fail-closed `sandbox-exec` verifier that uses an empty HOME and denies networking for the positive check plus receipt, bundle, root, signer, and source-ref adversarial cases.
- Recorded protected provenance in the terminal ledger, added a RED→GREEN ExUnit contract, and changed only GATE-05 to Complete; FAST-01 remains unchecked and `Gaps Found`.

## Verification

- `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh`
- `bash scripts/ci/correlate-terminal-ratification-dispatch.sh --self-test`
- `bash scripts/ci/capture-terminal-ratification-evidence.test.sh`
- `bash scripts/ci/ci-run-metrics.test.sh`
- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_198_contributor_dx_contract_test.exs`
- `MIX_ENV=test mix test test/sigra/planning/` — 112 tests, 0 failures, 12 skipped.

## TDD Gate Compliance

- RED: `75c6689c` adds a failing protected-provenance contract.
- GREEN: `0a59cae9` supplies the ledger provenance and reconciles requirement status.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 3 - Blocking provenance retrieval] The default trusted-root endpoint stalled and the accepted bundle was issued by `sigstore.dev`. A signed local loopback TUF mirror generated the Public Good root, which was combined with GitHub's trusted root before offline verification.

## Self-Check: PASSED
