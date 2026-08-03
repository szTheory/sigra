---
phase: 235-terminal-ratification-measured-not-read
verified: 2026-08-02T20:43:02-04:00
status: gaps_found
score: 6/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/10
  gaps_closed:
    - "A canonical source-receipt object is now retained and reconciled field-for-field to the ledger population."
    - "Binding-pole selections, wall durations, job source bytes, and metrics replay are now derived deterministically from the retained PR rows."
    - "The 93 ownership rows now have an exhaustive expected-map comparison rather than nonempty-string checks."
  gaps_remaining:
    - "The only retained gh run-list page is exactly the --limit 100 cap, so the bounded population is not proven complete."
    - "Source and job receipt digests remain self-authenticating: their expected value is editable in the same checked-in contract."
    - "Inverted run intervals are accepted and clamped to zero seconds."
    - "Ownership execution validation is a no-op for every event and direct owner."
    - "FAST-01 remains an owned 772-second miss, while REQUIREMENTS.md still marks it Complete."
  regressions:
    - "The prior verification did not detect the capped-capture, self-authentication, inverted-timestamp, or unconditional-execution paths."
gaps:
  - truth: "The terminal ledger derives the honest FAST-01 result from complete, immutable retained measured evidence."
    status: failed
    reason: "The sole gh run-list receipt contains exactly 100 records and the command is hard-capped with --limit 100; no pagination/exhaustion proof exists. Its digest is pinned by an editable module attribute in the same contract, and an inverted in-window interval is converted to zero duration."
    artifacts:
      - path: ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
        issue: "capture_endpoint.source_receipt is a capped first page with no external provenance or exhaustion marker."
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "@population_sha is locally editable; validate_source_receipt!/3 does not establish page exhaustion; wall_seconds!/1 clamps negative intervals."
    missing:
      - "Retain a complete paginated population with explicit exhaustion evidence, bind it to an external/protected provenance source, and reject updated_at earlier than created_at."
  - truth: "The single ownership artifact proves every family/spec's actual PR, main, and nightly destination."
    status: failed
    reason: "The expected-row map checks labels, but event_job_executed?/2 returns true for every event/owner. The contract therefore never proves that an executed owner was enabled by the workflow or present in the corresponding retained receipt."
    artifacts:
      - path: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        issue: "event_job_executed?/2 at lines 821-822 is unconditional."
    missing:
      - "Derive event eligibility from ci.yml guards and require receipt evidence for executed owners; add push/schedule unavailable-owner mutation tests."
  - truth: "Nightly and push-to-main outcomes over the same measurement window are proven from run data."
    status: failed
    reason: "The ledger records the values, but they depend on the same capped, locally self-authenticated population receipt and timestamp-clamping path as the PR measurement."
    artifacts:
      - path: ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
        issue: "push and schedule partitions are derived only from the incomplete source receipt."
    missing:
      - "Use the complete externally anchored source population for every event partition."
  - truth: "FAST-01 is achieved: PR p50 is under 12 minutes across at least 10 post-change runs."
    status: failed
    reason: "The recorded result is 19 PR runs with p50 772 seconds, which is not strictly less than 720 seconds. The owned residual is correct, but REQUIREMENTS.md incorrectly labels FAST-01 Complete."
    artifacts:
      - path: ".planning/REQUIREMENTS.md"
        issue: "FAST-01 is checked and mapped to Phase 235 as Complete despite the ledger and residual stating it remains unmet."
    missing:
      - "Keep the 772-second miss and residual; correct the requirement-status representation rather than presenting FAST-01 as achieved."
---

# Phase 235: Terminal Ratification — Measured, Not Read Verification Report

**Phase Goal:** The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Verified:** 2026-08-02T20:43:02-04:00
**Status:** gaps_found
**Re-verification:** Yes — after Plan 06 claimed closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The terminal calculation uses wall-mode, all retained conclusions, sorted floor(n/2) p50, and strict `< 720` comparison. | ✓ VERIFIED | The focused contract passes; its 19 retained PR rows produce p50 772, and its 720-second mutation is a miss. |
| 2 | FAST-01 is achieved: PR p50 is under 12 minutes across at least 10 post-change PR runs. | ✗ FAILED | The ledger and residual record 19 runs and p50 772 seconds. This is an owned miss, not an achieved requirement. |
| 3 | The source population is complete and independently immutable evidence for every retained terminal run. | ✗ FAILED | `source_command` uses `--limit 100`; the literal receipt decodes to exactly 100 records; neither pagination exhaustion nor an external/protected digest anchor exists. Inverted timestamps can also lower a duration to zero. |
| 4 | The two binding-pole diagnoses are deterministically selected and replayed from the retained PR population. | ✓ VERIFIED | `validate_binding_pole_receipts!/2` derives `median_neighbor` and `maximum_duration`, validates the source/job and metrics receipts, and the focused suite passes. This is internal consistency only; it cannot repair Truth 3's source-boundary failure. |
| 5 | One artifact has the exact before/after PR, push, and schedule ownership key universe. | ✓ VERIFIED | The contract reads the Phase 234 inventory, requires the sorted exact 93-key set, and the focused suite passes. |
| 6 | Every ownership row proves its actual executable owner, aggregate, receiver, and receipt for that event. | ✗ FAILED | `event_job_executed?/2` at lines 821-822 returns `true` for all inputs, so the executed branch has no workflow/receipt execution predicate. |
| 7 | Push and schedule outcomes are proven from the same complete measurement window. | ✗ FAILED | Their recorded 1/1 and 0/2 outcomes are derived from the same capped and self-authenticated source receipt as Truth 3. |
| 8 | CONTRIBUTING describes the current topology and local reproduction path CI actually uses. | ✓ VERIFIED | The contract checks contributor statements against ci.yml job blocks, `MIX_ENV=test mix ci`, and Playwright config/package files; 15 focused tests pass. |
| 9 | SEED-005 and CI-PERF reconcile the delivered audit sequence and link the honest FAST-01 residual. | ✓ VERIFIED | The focused closeout tests validate the 19/772 wording, push/schedule outcome text, and unique residual path. |
| 10 | The closeout preserves the 772-second miss rather than fabricating a pass or expanding unrelated scope. | ✓ VERIFIED | The ledger status is `miss`, the residual is open and owned by CI maintainers, and Plan 06 changed only the ledger and focused contract. |

**Score:** 6/10 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `235-TERMINAL-RATIFICATION.json` | Terminal measurements and ownership source of truth | ⚠️ PARTIAL | Substantive 3,000+ line ledger with 19/2/2 rows and 93 ownership rows; its run population is not proven exhaustive or externally authentic. |
| `phase_235_terminal_ratification_contract_test.exs` | Fail-closed evidence, ownership, and closeout contract | ✗ STUBBED_GUARDS | 15 tests pass, but capped-source, self-authentication, inverted-time, and actual execution predicates remain untested/incorrect. |
| `CONTRIBUTING.md` | Current topology and reproduction guidance | ✓ VERIFIED | Used by `validate_contributor_topology!/5` against live local sources. |
| `SEED-005`, `MILESTONE-ARC`, FAST residual | Honest closeout | ✓ VERIFIED | Reconciled to the preserved 772-second miss. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Phase 234 inventory | Terminal ledger | Hash-pinned exact ownership keys | ✓ WIRED | Exact 93-key reconciliation is executed. |
| GitHub run-list evidence | Terminal ledger | Complete bounded source receipt → run rows → statistics | ✗ NOT WIRED | One 100-record capped response is retained; page exhaustion and external provenance are absent. |
| Retained PR rows | Binding-pole diagnosis | Deterministic sort → source job bytes → metrics replay | ✓ WIRED | Selection and offline replay are validated, conditional on the unproven source population. |
| ci.yml and event job receipts | Ownership ledger | Event eligibility/execution → direct owner and aggregate | ✗ NOT WIRED | The only execution predicate is unconditional `true`. |
| Ledger | Closeout documents | Supplied ledger values and contributor topology | ✓ WIRED | Closeout validator composes contributor validation and document checks. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Terminal ledger | `measurements.*.runs` / statistics | Retained `gh run list` bytes | No — exactly 100 capped rows with no exhaustion/provenance anchor | ✗ INCOMPLETE_SOURCE |
| Binding-pole receipts | selected runs/jobs/metrics output | Retained PR rows and source-job bytes | Yes, internally | ✓ FLOWING (upstream source unproven) |
| Ownership rows | 93 before/after keys and destination labels | Phase 234 inventory, ci.yml, event receipts | Keys flow; actual per-event execution does not | ✗ HOLLOW_EXECUTION_PROOF |
| Contributor topology | documented job/seam statements | ci.yml, Mix, Playwright config/package | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused Phase 235 contract | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs --trace` | 15 tests, 0 failures | ✓ PASS |
| Metrics instrument | `bash scripts/ci/ci-run-metrics.test.sh` | 9 passed, 0 failed | ✓ PASS |
| Ledger current result | `jq -e` assertion for p50/status/row count/source count | 772 / `miss` / 93 rows / 100 source records | ✓ PASS |
| Ownership execution predicate | Source inspection of `event_job_executed?/2` | Both clauses return `true` | ✗ FAIL |
| Source receipt completeness | Decode retained source receipt | 100 records, exactly the command cap | ✗ FAIL |

The focused test prints local PostgreSQL connection-refused diagnostics during application start, but the selected contract tests complete successfully and do not require a database.

### Probe Execution

Step 7c: SKIPPED — no Phase 235 probe script or declared probe was found.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| FAST-01 | 235-01 through 235-06 | Merge verdict under 12m p50 across at least 10 post-change PR runs | ✗ BLOCKED | Current evidence records 772 seconds over 19 runs; it is an owned residual and its claimed source boundary is unproven. `REQUIREMENTS.md` incorrectly shows Complete. |
| GATE-05 | 235-01 through 235-06 | Single before/after PR/main/nightly artifact proving no silent drop | ✗ BLOCKED | Key coverage is exact, but unconditional execution validation cannot prove the declared destination actually ran on each event. |

All requirement IDs declared by every Phase 235 PLAN are `FAST-01` and `GATE-05`, both mapped to Phase 235 in `REQUIREMENTS.md`. No additional Phase 235 requirement is orphaned. `roadmap.analyze` shows no later phase, so none of these gaps is deferred.

### Review Finding Re-evaluation

| Finding | Independent verdict | Effect |
| --- | --- | --- |
| CR-01: no-op ownership execution predicate | **Confirmed BLOCKER** | The two function clauses return `true` for every event/owner. |
| CR-02: capped run-list population | **Confirmed BLOCKER** | The stored source receipt has exactly 100 entries and uses `--limit 100`; there is no exhaustion proof. |
| CR-03: locally self-authenticating digests | **Confirmed BLOCKER** | `@population_sha` is in the same editable test file; receipt digests only prove a checked-in byte string matches its checked-in hash. |
| CR-04: inverted timestamps clamped to zero | **Confirmed BLOCKER** | `wall_seconds!/1` and `recompute_statistics!/2` use `max(DateTime.diff(...), 0)` with no chronological-order rejection. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| `phase_235_terminal_ratification_contract_test.exs` | 821-822 | Unconditional execution predicate | 🛑 BLOCKER | A disabled, skipped, or absent owner can be asserted as executed. |
| `phase_235_terminal_ratification_contract_test.exs` | 623, 840-842, 903-923 | `--limit 100` source capture with no pagination/exhaustion check | 🛑 BLOCKER | Qualifying later-page runs can be omitted, changing p50 and outcomes. |
| `phase_235_terminal_ratification_contract_test.exs` | 16, 906-909, 1016-1019 | Mutable local digest anchors | 🛑 BLOCKER | Coherent replacement evidence can pass local digest checks. |
| `phase_235_terminal_ratification_contract_test.exs` | 1032, 1312-1315 | Negative timestamp intervals clamped to zero | 🛑 BLOCKER | Forged in-window timestamps can lower measured durations. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in the Phase 235 artifacts inspected.

### Gaps Summary

Plan 06 genuinely closed the previous internal-consistency gaps: it retained bytes, derives both poles, and compares a complete ownership map. It did not establish the stronger ratification boundary required by the goal. The measured population can be incomplete or replaced coherently, and the ownership proof does not verify runtime eligibility or execution.

FAST-01 must remain an owned residual: the observed p50 is 772 seconds, not `< 720`. The residual document correctly says this, but the checked `FAST-01` row and `Complete` phase mapping in `REQUIREMENTS.md` conflict with the evidence and must not be treated as achievement.

This is an **Escalation Gate**. A corrective plan must preserve the existing miss and add complete externally anchored run evidence, chronological timestamp rejection, real per-event execution proof, and an accurate requirement status.

---

_Verified: 2026-08-02T20:43:02-04:00_
_Verifier: the agent (gsd-verifier)_
