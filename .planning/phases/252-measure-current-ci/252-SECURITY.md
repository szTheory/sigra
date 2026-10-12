---
phase: "252"
slug: measure-current-ci
status: blocked
threats_open: 9
threats_total: 20
threats_closed: 9
all_open: 11
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: "2026-10-12"
---

# Phase 252 — Security

The independent audit found nine blocking and two medium mitigation gaps. No risks were accepted. Automated repair remains in scope; phase advancement is pending.

## Trust Boundaries

GitHub responses enter retained source files; artifact archives enter offline analysis; comparison families enter statistics; retained diagnostic text enters a shareable Markdown report.

## Threat Register

| Threat ID | Category | Severity | Disposition | Status | Evidence and remaining control |
|---|---|---|---|---|---|
| T-252-01 | Spoofing | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:1059, scripts/ci/ci-run-metrics.sh:1194. Snapshot replay accepts required checks by name/SHA/app without binding run, attempt and producer job ID. |
| T-252-02 | Tampering | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:783, scripts/ci/ci-run-metrics.sh:1128, scripts/ci/ci-run-metrics.sh:1233. Extracted JSON members are read without member/ZIP equality checks; manual and release population replay hash checks are missing. |
| T-252-03 | Information Disclosure | medium | mitigate | closed | scripts/ci/ci-run-metrics.sh:324, scripts/ci/ci-run-metrics.sh:338, scripts/ci/ci-run-metrics.sh:388. Request ledger does not receive bearer tokens or signed redirect URLs. |
| T-252-04 | Spoofing | high | mitigate | closed | scripts/ci/ci-run-metrics.sh:183, scripts/ci/ci-run-metrics.sh:725, scripts/ci/ci-run-metrics.sh:1222. API artifact ID, producing run, head SHA and digest are checked. |
| T-252-05 | Elevation | high | mitigate | closed | scripts/ci/ci-run-metrics.sh:206, scripts/ci/ci-run-metrics.sh:210, scripts/ci/ci-run-metrics.sh:213, scripts/ci/ci-run-metrics.sh:237. ZIP extractor rejects traversal, absolute paths and symlinks and bounds members and expanded bytes. |
| T-252-06 | Information Disclosure | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:170, scripts/ci/ci-run-metrics.sh:347, scripts/ci/ci-run-metrics.sh:249. Regex redaction does not detect or exclude environment dumps. |
| T-252-07 | Denial of Service | medium | mitigate | open non blocking | scripts/ci/ci-run-metrics.sh:307, scripts/ci/ci-run-metrics.sh:408, scripts/ci/ci-run-metrics.sh:440. Core budget is refreshed every 100 calls without local decrement; a remaining reading of 251 can authorize calls after 250. |
| T-252-08 | Tampering | medium | mitigate | open non blocking | test/support/ci_timing_formatter.ex:133, test/support/ci_timing_formatter.ex:174, scripts/ci/exunit_timing_contract.py:30. Consumer accepts an empty self-declared complete report with zero sum; result values and counts are not reconciled with rows. |
| T-252-09 | Information Disclosure | medium | mitigate | closed | test/support/ci_timing_formatter.ex:53, test/support/ci_timing_formatter.ex:119. Formatter does not serialize assertions or environment data. |
| T-252-10 | Tampering | medium | mitigate | closed | scripts/ci/ci-playwright-report.mjs:71, scripts/ci/ci-playwright-report.mjs:123, scripts/ci/ci-playwright-report.mjs:166, scripts/ci/ci-playwright-report.mjs:209. Playwright normalizer validates shape, identity, duration, results and summary completeness. |
| T-252-11 | Elevation | high | mitigate | closed | scripts/ci/ci-playwright-report.mjs:244, scripts/ci/ci-playwright-report.mjs:266, scripts/ci/ci-playwright-report.mjs:272. Output path comes from explicit CLI; report fields are data only. |
| T-252-12 | Spoofing | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:1242, scripts/ci/ci-run-metrics.sh:1247, .github/workflows/ci.yml:641. Producer attempt/job are self-asserted metadata matched by name, without independent job ID and merge checkout SHA binding. |
| T-252-13 | Tampering | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:1194, scripts/ci/ci-run-metrics.sh:1203, scripts/ci/ci-run-metrics.sh:1208. A same-name/SHA check from a different run or attempt can enter the baseline because producer job IDs are not joined. |
| T-252-14 | Repudiation | medium | mitigate | closed | scripts/ci/ci-run-metrics.sh:1437, scripts/ci/ci-run-metrics.sh:1459, scripts/ci/ci-run-metrics.sh:1463. Failure signatures retain literal outcomes and source run, attempt and log references. |
| T-252-15 | Information Disclosure | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:249, scripts/ci/ci-run-metrics.sh:254, scripts/ci/ci-run-metrics.sh:263, scripts/ci/ci-run-metrics.sh:698. Entire failed-job logs are retained without excerpt or byte bounds and may include environment dumps. |
| T-252-16 | Spoofing | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:1247, scripts/ci/ci-run-metrics.sh:1316, scripts/ci/ci-run-metrics.sh:1559. Producer merge SHA is only format/agreement checked among uploaded metadata, not independently bound to the job. |
| T-252-17 | Tampering | high | mitigate | open blocking | scripts/ci/ci-run-metrics.sh:1600, scripts/ci/ci-run-metrics.sh:1608, scripts/ci/ci-run-metrics.sh:1623. Evaluator lacks frozen family run-ID membership and per-row timestamp window checks; replacement is possible. |
| T-252-18 | Repudiation | medium | mitigate | closed | scripts/ci/ci-measure-report.sh:33, scripts/ci/ci-measure-report.sh:60, scripts/ci/ci-measure-report.sh:130. Report costs, failures and outcomes retain run, attempt and source references. |
| T-252-19 | Information Disclosure | high | mitigate | open blocking | scripts/ci/ci-measure-report.sh:38, scripts/ci/ci-measure-report.sh:60, scripts/ci/ci-measure-report.sh:87. Source URL/diagnostic text is inserted into Markdown without output redaction or destination allowlist. |
| T-252-SC | Tampering | high | mitigate | closed | scripts/ci/sigra-dep-off.sh:29, .github/workflows/ci.yml:448. No new dependency manifest or lockfile change; changed harness uses existing locked dependencies. |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Total | Closed | Open | Blocking | Auditor |
|---|---|---|---|---|---|
| 2026-10-12 | 20 | 9 | 11 | 9 | gsd-security-auditor |

## Sign-Off

- [x] Planned threats have a disposition.
- [x] No risk was waived or accepted.
- [ ] All planned mitigations verified.
- [ ] threats_open: 0.

**Approval:** Pending automated repair and independent re-audit. Details: 252-SECURITY-AUDIT.json.
