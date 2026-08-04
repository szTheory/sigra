---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-04T02:13:59Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "FAST-01's protected post-remediation receipt is now accepted only through trusted, hostile-environment-tested staging."
    - "GATE-05's protected 93-row ownership proof is now accepted only through trusted, hostile-environment-tested staging."
  gaps_remaining: []
  regressions: []
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-08-04T02:13:59Z
**Status:** passed
**Re-verification:** Yes — after Plan 14 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | PR wall-clock is under 12 minutes at p50 across at least 10 post-change PR runs, with baseline-compatible wall-time measurement. | ✓ VERIFIED | The protected `sigra.fast-01-gap-closure-remeasurement/v1` receipt contains 15 unique terminal PR runs, all conclusions, `mode: wall`, canonical `{wall_seconds, run_id}` ordering, and recomputes `floor(15/2)` to **486s**. The strict comparator is `< 720`; focused contract mutations prove 719 passes and 720/721 miss. |
| 2 | One committed artifact maps every affected spec/suite to before/after PR, main, and nightly ownership, with a direct receiver for moved work. | ✓ VERIFIED | `235-TERMINAL-RATIFICATION.json` is a substantive 93-row `sigra.terminal-ratification/v1` ledger. The focused terminal contract passed and rejects missing/incorrect receivers, receipts, topology, and expected ownership-key mutations. |
| 3 | Push-to-main and nightly outcomes are retained over the same terminal measurement window. | ✓ VERIFIED | The ledger records the common cutoff `2026-08-01T02:06:30Z` and endpoint `2026-08-02T18:07:04Z`: push `1 success / 1 non-success`; schedule `0 success / 2 non-success`. The contract recomputes these tables from retained runs. |
| 4 | Contributor documentation reflects the shipped CI topology and local reproduction path. | ✓ VERIFIED | The terminal contract exercised the live `ci.yml`, `CONTRIBUTING.md`, `mix.exs`, and Playwright configuration together; it requires `MIX_ENV=test mix ci`, direct owners/aggregates, five named Playwright seams, non-PR signals, and the Playwright reproduction command. |
| 5 | SEED-005 / CI-PERF records are reconciled to the executed 230–235 sequence, preserving the historical measured miss as an evidence-backed record rather than rewriting it. | ✓ VERIFIED | `MILESTONE-ARC.md:269-271` and the SEED addendum state that the Phase 198→203 audit sequence was executed as Phases 230–235, cite the terminal ledger, and retain the historical 772s residual. The terminal contract passed its closeout-record checks. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json` | Protected FAST-01 population and strict result | ✓ VERIFIED | Real retained data: n=15, p50=486s, pass; independently recomputed by the focused contract. |
| `scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | Trusted-staging, network-denied FAST provenance verifier | ✓ VERIFIED | Executable `/bin/bash` entrypoint; fixed-parent work directory, cleared temp overrides, repository/signer/ref/digest checks, and adversarial receipt/bundle/root/signer/ref checks all ran successfully. |
| `235-TERMINAL-RATIFICATION.json` | GATE-05 before/after ownership and outcome ledger | ✓ VERIFIED | 93 ownership rows plus real same-window PR/push/schedule retained measurements. |
| `scripts/ci/verify-terminal-ratification-attestation-offline.sh` | Trusted-staging GATE-05 provenance verifier | ✓ VERIFIED | Executable `/bin/bash` entrypoint; protected receipt/bundle/root pass positive and adverse offline checks after trusted staging. Wired in required `fast_checks` at `ci.yml:312-317`. |
| `CONTRIBUTING.md` and closeout records | Current topology and CI-PERF reconciliation | ✓ VERIFIED | Joint terminal contract validates the text against the live workflow and local execution seams. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| FAST receipt/bundle/root | FAST offline verifier | Trusted staging before copies, then network-denied exact repository/signer/main-ref/digest verification | ✓ WIRED | Direct verifier execution passed; its hostile-PATH/TMPDIR/TMP/TEMP regression reached `offline_fast_01_gap_closure_attestation_verified` with no sentinel execution. |
| FAST receipt | `REQUIREMENTS.md` | Independent recomputation drives FAST-01 | ✓ WIRED | Focused FAST contract recomputed n/p50 and requires the exact run, endpoint, receipt, and GATE-05 non-regression text. |
| Terminal receipt/bundle/root | GATE-05 verifier and CI | Trusted staging, offline verification, and required-CI execution | ✓ WIRED | Direct verifier and checkpoint-reaching hostile regression passed; `ci.yml:312-317` runs both test and verifier. |
| Phase 234 inventory and `ci.yml` | 93-row terminal ledger | Exact ownership/topology reconciliation | ✓ WIRED | Terminal contract passed and rejects wrong receiver, missing receipt, omitted ownership key, and topology substitutions. |
| `ci.yml` | `CONTRIBUTING.md` | Direct owner, aggregate, local command, seams, and non-PR topology documentation | ✓ WIRED | Joint contract passed. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| FAST receipt | `runs`, `eligible_pr_run_count`, `statistics.p50_seconds` | Protected-main attested subject | 15 retained terminal PR rows including failures; p50 recomputes to 486s | ✓ FLOWING |
| Terminal ledger | `measurements.*`, `ownership.rows` | Retained run receipts plus Phase 234 ownership inventory and live workflow topology | 19 PR, 2 push, 2 schedule measurements and 93 ownership rows | ✓ FLOWING |
| CONTRIBUTING / closeout | topology and reconciliation text | Current workflow, `mix.exs`, terminal ledger | Contract reads all sources together and rejects drift | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| FAST hostile caller cannot select tools or temp staging, and verifier reaches complete positive path | `bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.test.sh` | `offline_fast_01_gap_closure_attestation_verified` | ✓ PASS |
| GATE-05 hostile caller cannot select tools or temp staging, and verifier reaches complete positive path | `bash scripts/ci/verify-terminal-ratification-attestation-offline.test.sh` | `offline_attestation_verified` | ✓ PASS |
| FAST retained provenance accepts the exact subject and rejects adverse changes | `bash scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` | Exit 0; expected adverse-case errors emitted, then positive marker | ✓ PASS |
| GATE-05 retained provenance accepts the exact subject and rejects adverse changes | `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh` | Exit 0; expected adverse-case errors emitted, then positive marker | ✓ PASS |
| FAST strict result, staging contract, and GATE-05 ownership/topology mutations | `MIX_ENV=test mix test test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | 27 tests, 0 failures | ✓ PASS |

The focused ExUnit run logged unavailable local PostgreSQL connections during application setup, but all listed planning contracts are filesystem/evidence checks and completed successfully without database access.

### Probe Execution

Step 7c: SKIPPED — no `scripts/*/tests/probe-*.sh` path is declared for this phase. The phase's deterministic runnable evidence consists of the two verifier self-tests, two offline attestation verifiers, and focused contracts above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01 through 235-14 | PR p50 under 12 minutes across at least 10 post-change PR runs | ✓ SATISFIED | Protected run `30865183650` receipt: n=15, canonical wall p50=486s, strict `<720`; actual hardened verifier and its hostile regression passed. |
| GATE-05 | 235-01 through 235-14 | One artifact proves no test was silently dropped across PR/main/nightly | ✓ SATISFIED | Protected run `30782184713`, 93-row ownership ledger, focused mutation-rejection contract, and CI-wired hardened offline verifier all passed. |

All Phase 235 plans declare only `FAST-01` and `GATE-05`; both occur in `REQUIREMENTS.md` and no Phase 235 requirement is orphaned. There are no later milestone phases to which a Phase 235 gap could be deferred.

### Review Disposition

`235-REVIEW.md` reports CR-01 and WR-01 against `scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh`, the historical remeasurement verifier. They do **not** block FAST-01 or GATE-05:

- FAST-01's authoritative, post-remediation n=15/p50=486 subject is verified by `verify-fast-01-gap-closure-attestation-offline.sh`, not the older remeasurement verifier. Its hardened staging and direct hostile-environment test passed above.
- GATE-05 is verified by the separately hardened terminal verifier, which is also CI-wired and passed above.
- The older verifier supports an immutable historical n=13/p50=724 miss. Its reported staging flaw cannot create a false pass for either current requirement and does not participate in the acceptance links above.

The review finding remains useful hardening work for historical-evidence tooling, but it is not an observable failure of the two stated Phase 235 requirements. No override is applied.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `235-REVIEW.md` finding CR-01 | historical remeasurement verifier:63 | Inherited temporary-directory staging; no hostile regression | ℹ️ NON-BLOCKING | Not in FAST-01's authoritative post-remediation path or GATE-05's acceptance path; recorded above for future hardening. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt marker was found in the Phase 235 acceptance verifiers, their hostile-environment tests, or their focused contracts.

---

_Verified: 2026-08-04T02:13:59Z_
_Verifier: the agent (gsd-verifier)_
