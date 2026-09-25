---
phase: 233
slug: library-suite-economics
status: verified
# Count of OPEN threats at or above workflow.security_block_on severity.
threats_open: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: 2026-07-31
verified: 2026-07-31
---

# Phase 233 — Security

> Per-phase security contract for the library-suite CI economics work. This ASVS L1 audit verifies the plan-time STRIDE mitigations through implementation inspection, executable contracts, and committed CI evidence.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| GitHub matrix/context → shell | Workflow-controlled values select a shard and fixed timing file. | Partition identity and CI paths |
| ExUnit events → retained artifact | Runtime events become durable timing receipts. | Test identity, outcome, and duration |
| GitHub API/artifacts → repository evidence | External CI observations support completion and performance claims. | Run metadata, job results, receipts, and digests |
| Test tags → CI selection | Classification determines whether expensive correctness coverage executes. | Test module tags and selected paths |
| Worker results → protected status context | Dependency results determine merge eligibility. | GitHub job result strings |
| Measured evidence → committed selection | Historical timing data determines the ordinary shard assignment. | Repository-relative test paths and costs |
| Manifest → shell argv | Validated paths become `mix test` arguments. | Repository-relative test paths |
| GitHub run/log/artifact data → completion claim | A specific external run supports requirement closure. | Event, SHA, attempt, jobs, and artifacts |
| Evidence JSON → human-readable ledger | Machine facts are summarized without changing meaning. | Structured CI evidence |
| Historical receipt → merge-blocking selection | Stale measurements control current test ownership until refreshed. | Measured costs and explicit path ownership |
| Repository filesystem/config → manifest validation | The current Mix-filtered universe defines required ownership. | Test paths and load filters |

---

## Threat Register

The Plan 06 artifact reuses `T-233-13` through `T-233-15` for different threats already assigned in Plan 05. Source-plan suffixes below preserve both plan-time records without rewriting their original identifiers.

| Threat ID | Category | Component | Severity | Disposition | Mitigation and evidence | Status |
|-----------|----------|-----------|----------|-------------|-------------------------|--------|
| T-233-01 | Tampering | `library_tests_shard` shell | high | mitigate | CI maps the partition through `env:`, uses quoted array argv and `set -euo pipefail`; the phase contract asserts one guarded invocation. | closed |
| T-233-02 | Tampering | Timing output path | high | mitigate | `ExUnitTimingFormatter` allowlists exactly three CI-owned `/tmp` paths and revalidates before atomic write; rejection paths are unit-tested. | closed |
| T-233-03 | Repudiation | Timing receipt | medium | mitigate | Formatter emits a stable schema and deterministic ordering; the same shard job uploads the receipt with missing-file failure. | closed |
| T-233-04 | Spoofing | Timing-probe run selection | high | mitigate | `233-EVIDENCE.json` records exact workflow, PR event, PR number, head SHA, run ID, attempt, and the matching query. | closed |
| T-233-05 | Repudiation | Evidence ledger | high | mitigate | JSON and Markdown ledgers preserve run/job IDs, commands, excerpts, artifact identities, SHA-256 digests, and requirement dispositions. | closed |
| T-233-06 | Tampering | Timing aggregation | medium | mitigate | The ledger records fail-closed schema, non-empty, integer/non-negative, duplicate-identity, repository-path, and stable-sort validation. | closed |
| T-233-07 | Tampering | Scaffold selection | high | mitigate | Workflow uses direct `--only scaffold`; the executable contract enforces the exact six tagged modules and excludes template-render. | closed |
| T-233-08 | Elevation of Privilege | `Library tests` aggregator | high | mitigate | The unchanged required context runs with `if: always()` and rejects both shard and scaffold results unless each is exactly `success`. | closed |
| T-233-09 | Tampering | Workflow shell | high | mitigate | Dependency results cross through `env:`, are quoted, and are evaluated under strict shell failure; executable contracts cover the boundary. | closed |
| T-233-10 | Tampering | Partition manifest | high | mitigate | Partition construction validates non-empty, exact-once, scaffold-free ownership and exact equality with the live Mix-filtered test universe. | closed |
| T-233-11 | Denial of Service | Shard imbalance | medium | mitigate | Stable measured greedy assignment is implemented; final evidence records a 1-second after-gap versus the 192-second baseline gap. | closed |
| T-233-12 | Tampering | Manifest shell expansion | high | mitigate | Only repository-relative validated paths are emitted; shell captures selector status, rejects empty output/argv, and passes a quoted array to `mix test`. | closed |
| T-233-13 (P05) | Spoofing | Final run selection | high | mitigate | Final evidence identifies retry-free PR run `30668911851`, exact event, workflow/head SHA, attempt, successful jobs, and required check. | closed |
| T-233-14 (P05) | Repudiation | Before/after claim | high | mitigate | JSON and Markdown ledgers preserve the run/job IDs, commands, receipt digests, and machine-computed 192-second/1-second gaps. | closed |
| T-233-15 (P05) | Tampering | Coverage disposition | high | mitigate | Final evidence records named receiver files, all receipt digests, exact `Library tests` success, and completed TEST-01/02/03 dispositions; contracts are executable. | closed |
| T-233-13 (P06) | Tampering | Live manifest and selector transport | high | mitigate | `build_partitions!/1` reconciles disjoint exact ownership against live discovery; CI preserves selector failure and rejects empty output/argv before `mix test`. | closed |
| T-233-14 (P06) | Repudiation | Manifest drift diagnostics | medium | mitigate | Validation reports sorted missing and stale lists; deterministic contracts cover missing, stale, duplicate, and scaffold-leak directions. | closed |
| T-233-15 (P06) | Denial of Service | Newly added unmeasured ordinary test | low | accept | Deliberate fail-closed CI interruption prevents silent coverage loss and requires timing evidence refresh before the new test can run in an ordinary shard. | closed |
| T-233-16 | Elevation of Privilege | Test-root injection seam | medium | mitigate | Production callers use zero-argument defaults; `root:` and `costs:` are explicit test seams, and discovered paths are normalized relative to the supplied root before comparison. | closed |

*Status: open · closed · open — below high threshold (non-blocking). Only open threats at or above the configured high threshold count toward `threats_open`.*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-233-01 | T-233-15 (P06) | A new unmeasured ordinary test intentionally blocks CI until measured evidence is refreshed. This low-severity availability cost is preferable to silently omitting correctness coverage. | Phase 233 Plan 06 | 2026-07-31 |

---

## Verification Evidence

- Implementation inspected: `.github/workflows/ci.yml`, `test/support/ci/ex_unit_timing_formatter.ex`, and `test/support/ci/library_test_partitions.exs`.
- Executable controls: `test/support/ci/ex_unit_timing_formatter_test.exs` and `test/sigra/planning/phase_233_library_economics_contract_test.exs`.
- Durable external-run evidence: `233-EVIDENCE.json` and `233-EVIDENCE.md`.
- Deterministic verification on 2026-07-31: `mix test test/support/ci/ex_unit_timing_formatter_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` — 19 tests, 0 failures.
- Formatting verification: `mix format --check-formatted test/support/ci/library_test_partitions.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` — passed.
- Expected local PostgreSQL connection-refused logs occurred during test-helper startup; the focused security contracts require no database and completed without failures or skipped assertions.

---

## Security Audit 2026-07-31

| Metric | Count |
|--------|-------|
| Threats found | 19 |
| Closed | 19 |
| Open | 0 |

The plan-time register was complete and preliminary L1 verification found no open threats. Per the secure-phase ASVS L1 short-circuit rule, no deeper auditor pass was required.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-31 | 19 | 19 | 0 | Codex secure-phase orchestration |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-31
