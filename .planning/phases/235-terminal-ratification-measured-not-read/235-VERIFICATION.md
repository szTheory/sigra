---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-02T22:47:11Z
status: gaps_found
score: 4/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/8
  gaps_closed:
    - "The three ci_gate_aggregate ledger rows now name ci-gate, the live workflow job."
    - "Closeout validation now composes the supplied CONTRIBUTING.md topology check."
  gaps_remaining:
    - "No canonical gh run-list receipt is retained or validated against the captured population."
    - "Binding-pole receipts do not prove selection, wall_seconds, command, or output_sha256 against the measured median/max evidence."
    - "The 93 ownership rows are not checked against a complete live workflow/receipt semantics map."
  regressions: []
gaps:
  - truth: "The terminal ledger derives the honest FAST-01 result from immutable retained measured evidence."
    status: failed
    reason: "The capture endpoint is pinned as strings, but the raw gh run-list response whose SHA is claimed is neither retained nor consumed. The validator recomputes only self-supplied ledger runs, so a coherent replacement of the source population remains acceptable."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "validate_capture!/1 and validate_captured_ledger!/1 never decode or hash-check a canonical source population receipt."
    missing:
      - "Retain the exact bounded gh run-list bytes, hash them, and reconcile every retained run's identity and provenance fields to those bytes."
  - truth: "Each binding-pole diagnosis authenticates the measured median and maximum evidence."
    status: failed
    reason: "CR-01 is confirmed. validate_binding_pole_receipts!/2 only validates a receipt's chosen job against a retained run. It never derives the expected median/max runs, requires the two selections, compares receipt.wall_seconds, or validates the ci-run-metrics command/output_sha256."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "Lines 790-840 permit forged median/max labels and metric-output metadata while retaining a valid source job receipt."
    missing:
      - "Derive exact median-neighbor and maximum run IDs/durations from the retained PR population; require exactly those receipts and bind command, wall_seconds, and digest to replayed metrics output."
  - truth: "The single ownership artifact proves every family/spec's actual PR, main, and nightly destination."
    status: failed
    reason: "Exact 93-key coverage and the ci-gate spelling are checked, but all other owner/aggregate/receiver/receipt values are accepted as arbitrary nonempty strings. No complete row-semantic map is compared to parsed ci.yml job IDs or evidence receipt contents."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "validate_rows!/1 only semantically constrains ci_gate_aggregate; it does not implement the Plan 05 workflow/receipt mapping contract for the remaining rows."
    missing:
      - "Declare and validate each family/event owner, aggregate, receiver, state, and receipt against parsed workflow jobs and retained evidence."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-08-02T22:47:11Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 05 claimed closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The FAST-01 result is computed using the baseline-compatible wall measurement and strict `< 720` rule. | ✓ VERIFIED | The focused contract recomputes 19 PR runs and obtains p50 772; `strict_fast_01_status/2` rejects 720. |
| 2 | FAST-01 is actually under 12 minutes p50 over at least 10 post-change PR runs. | ✗ FAILED | The committed result is 772 seconds across 19 runs; FAST-01 remains unchecked/Pending in REQUIREMENTS.md. The roadmap expressly requires disclosure of this miss. |
| 3 | An immutable source receipt independently binds every retained run used by the terminal calculation. | ✗ FAILED | No canonical `gh run list` output exists in the ledger and no validator reads `population_sha256` against receipt bytes. |
| 4 | Binding-pole receipts prove the median and maximum diagnoses from the retained PR population. | ✗ FAILED | Confirmed CR-01: receipt selection, `wall_seconds`, metrics command, and `output_sha256` are not compared with the derived poles or output. |
| 5 | One artifact contains the exact before/after PR/push/schedule ownership universe. | ✓ VERIFIED | The hash-pinned Phase 234 inventory plus 11 non-Playwright families form, and the contract enforces, the 93-key cross product. |
| 6 | That artifact accurately identifies the executable owner/aggregate/receiver and receipt for every row. | ✗ FAILED | Only `ci_gate_aggregate` receives semantic checking; arbitrary nonempty values pass for the other 90 rows. |
| 7 | Push and schedule outcomes are recorded using the same window. | ✗ FAILED | The ledger records 1/1 push and 0/2 schedule outcomes, but their source populations have the same unbound-receipt flaw as the PR data. |
| 8 | CONTRIBUTING describes the post-v1.47 topology and local reproduction path that CI actually uses. | ✓ VERIFIED | Contract passes direct job block, aggregate-needs, local `MIX_ENV=test mix ci`, Playwright seam, and non-PR guard checks. |
| 9 | SEED-005 and CI-PERF reconcile the executed 230–235 sequence and ledger-linked FAST-01 residual. | ✓ VERIFIED | Focused closeout test validates the artifact links, 19/772 miss wording, push/schedule outcomes, and sole residual. |
| 10 | Plan 05 hardens existing evidence without altering CI topology or fabricating a pass. | ✓ VERIFIED | Its three commits modify only the ledger and focused contract; the retained result remains the 772-second miss. |

**Score:** 4/10 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-TERMINAL-RATIFICATION.json` | Immutable terminal measurements and before/after ownership ledger | ⚠️ PARTIAL | Substantive 3,042-line ledger, but source-run evidence is self-asserted and ownership semantics are incomplete. |
| `phase_235_terminal_ratification_contract_test.exs` | Fail-closed source, pole, ownership, and closeout contract | ⚠️ PARTIAL | 13 focused tests pass, but they do not exercise the required source-population or pole/row semantic mutations. |
| `CONTRIBUTING.md` | Accurate topology and local reproduction | ✓ VERIFIED | Parsed live-workflow checks pass. |
| `SEED-005...md` / `MILESTONE-ARC.md` | Ledger-backed closeout | ✓ VERIFIED | Current wording is validated against the measured miss. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Phase 234 inventory | Terminal ledger | Hash-pinned exact 93-key cross-product | ✓ WIRED | Validator reads the inventory and enforces exact key equality. |
| GitHub run-list evidence | Terminal ledger | Raw bounded receipt → retained identities → statistics | ✗ NOT WIRED | Endpoint/hash constants have no retained raw population to bind. |
| Retained PR data | Binding-pole diagnosis | Derived median/max → replayed metrics receipt | ✗ PARTIAL | A source job is validated, but the claimed poles and metrics metadata are not bound. |
| Live CI workflow | Ownership ledger | Parsed jobs/needs → each row's semantic mapping | ✗ NOT WIRED | The validator parses workflow blocks only for CONTRIBUTING, not the ownership-row map. |
| CONTRIBUTING | Closeout contract | Supplied contributor content → topology validation | ✓ WIRED | `validate_closeout_records!/5` calls `validate_contributor_topology!/5`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Terminal ledger | `measurements.*.runs` / statistics | Self-contained JSON rows | No independently retained source receipt | ⚠️ SELF-ASSERTED |
| Terminal ledger | `receipts.binding_pole` | Embedded per-run source-job JSON | Individual job identity exists, but not the asserted pole/metric relationship | ⚠️ PARTIAL |
| Ownership ledger | `ownership.rows` | Inventory plus literals | Key set flows; destination semantics do not | ✗ HOLLOW_MAPPING |
| CONTRIBUTING | topology statements | Parsed `ci.yml` blocks | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused Phase 235 contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs --trace` | 13 tests, 0 failures | ✓ PASS |
| Metrics instrument | `bash scripts/ci/ci-run-metrics.test.sh` | 9 passed, 0 failed | ✓ PASS |
| Review CR-01 source inspection | `validate_binding_pole_receipts!/2` at lines 816–841 | No expected-selection, wall-time, command, or output-digest comparisons | ✗ FAIL |

The focused test command emitted PostgreSQL connection-refused diagnostics during test application startup, but all 13 selected contract tests completed successfully; these filesystem-only contract tests do not require a database.

### Probe Execution

Step 7c: SKIPPED — no Phase 235 probe script or declared probe was found.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01 through 235-05 | PR merge verdict under 12m p50 across at least 10 post-change runs | ✗ BLOCKED | The recorded 19-run p50 is 772 seconds (not `< 720`) and the claimed immutable evidence boundary/pole proof is incomplete. |
| GATE-05 | 235-01 through 235-05 | Single before/after PR/main/nightly ownership artifact proving no silent drop | ✗ BLOCKED | Exact coverage keys are proven, but arbitrary ownership destinations and receipts are still accepted. |

All requirements declared in the Phase 235 plans (`FAST-01`, `GATE-05`) are mapped to Phase 235 in REQUIREMENTS.md. No orphaned Phase 235 requirement exists. There is no later milestone phase that specifically defers these gaps.

### Review Finding Re-evaluated

| Finding | Verdict | Effect |
| --- | --- | --- |
| CR-01: binding-pole receipt can accept forged median/max evidence | **Confirmed BLOCKER** | It directly defeats the phase goal's requirement to derive the honest FAST-01 result from retained measured evidence. The passing suite does not test this invariant. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| `phase_235_terminal_ratification_contract_test.exs` | 790–840 | Receipt fields validated only for local consistency, not derived-pole consistency | 🛑 BLOCKER | A forged median/max diagnosis can pass. |
| `phase_235_terminal_ratification_contract_test.exs` | 575–755 | Capture constants and mutable ledger runs, with no raw run-list receipt | 🛑 BLOCKER | A coherent replacement population can pass. |
| `phase_235_terminal_ratification_contract_test.exs` | 673–694 | Almost all ownership values are only nonempty strings | 🛑 BLOCKER | The ownership artifact cannot prove where tests actually landed. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in Phase 235's modified artifacts.

### Gaps Summary

Plan 05 repaired the observed `ci_gate` spelling and made the closeout validator consume CONTRIBUTING. Those fixes are real, but they do not fulfill its central evidence-boundary contract. The ledger still proves only that its own editable rows are internally consistent. It neither anchors the population to a retained GitHub response nor proves that its two binding-pole claims are the median and maximum of that population. Its coverage inventory is exhaustive by key but not trustworthy by executable destination.

This is an **Escalation Gate**. A corrective closure plan must add the missing source and replay receipts, fail-closed pole-selection checks, and exhaustive workflow/receipt ownership semantics. It must retain the honest 772-second FAST-01 miss rather than declare FAST-01 achieved.

---

_Verified: 2026-08-02T22:47:11Z_
_Verifier: the agent (gsd-verifier)_
