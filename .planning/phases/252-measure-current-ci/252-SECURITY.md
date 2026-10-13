---
phase: "252"
slug: measure-current-ci
status: blocked
threats_open: 3
threats_total: 20
threats_closed: 17
all_open: 3
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: "2026-10-12"
---

# Phase 252 — Security

The independent re-audit verified seventeen controls and found three blocking gaps. No risks were accepted. Automated repair remains in scope; phase verification is pending.

## Trust Boundaries

GitHub responses enter retained source files; artifact archives enter offline analysis; comparison families enter statistics; retained diagnostic text enters a shareable Markdown report.

## Threat Register

| Threat ID | Severity | Status | Evidence and remaining control |
|---|---|---|---|
| T-252-01 | high | open blocking | scripts/ci/ci-run-metrics.sh:922-931,1196-1209,1217-1259; scripts/ci/ci_metrics_security.py:179-213. Standalone family replay validates filtered checks but publishes wait from all required-name checks and aggregated jobs; collection overwrites API identity fields. Offline probe confirmed. |
| T-252-02 | high | closed | scripts/ci/ci_metrics_security.py:22-176; scripts/ci/ci-run-metrics.sh:1333-1337. Retained populations, requests, source files, changed paths, ZIPs and members hash-verified. |
| T-252-03 | medium | closed | scripts/ci/ci-run-metrics.sh:329,345,409-413. Ledger excludes bearer headers and signed redirect URLs. |
| T-252-04 | high | closed | scripts/ci/ci-run-metrics.sh:194-203,761-766. Artifact API ID/digest/run/head SHA checked before ZIP acceptance. |
| T-252-05 | high | closed | scripts/ci/ci-run-metrics.sh:206-253. ZIP bounds and traversal/absolute/symlink/duplicate rejection present. |
| T-252-06 | high | closed | scripts/ci/ci-run-metrics.sh:335-400,408-415; scripts/ci/ci_metrics_security.py:340-370. Counted HTTPS redirects, ledgers omit signed URLs, bounded redacted logs. |
| T-252-07 | medium | closed | scripts/ci/ci-run-metrics.sh:322-328,370-379,438-445. Every request debits budgets; rate-limit hard stop and bounded transient retry. |
| T-252-08 | medium | closed | scripts/ci/exunit_timing_contract.py:35-84. Atomic producer; consumer rejects empty, malformed and inconsistent reports. |
| T-252-09 | medium | closed | test/support/ci_timing_formatter.ex:43-68,119-134. Output contains identity/result/duration, no assertions/environment. |
| T-252-10 | medium | closed | scripts/ci/ci-playwright-report.mjs:71-97,122-170,209-215. Playwright shape/identity/results/timing/summary checked. |
| T-252-11 | high | closed | scripts/ci/ci-playwright-report.mjs:260-293. Explicit CLI destinations; report is data. |
| T-252-12 | high | open blocking | scripts/ci/ci-run-metrics.sh:1605-1637,1710; scripts/ci/ci-run-metrics.test.sh:360-379. Generic replay publishes cache, runner and runtime-version metadata before API producer-upload/attempt binding. |
| T-252-13 | high | open blocking | scripts/ci/ci-run-metrics.sh:667-673,1582-1604; scripts/ci/ci_metrics_security.py:291-302. Ranking validator prefers locally injected source identity over conflicting API run/attempt/head fields. Offline probe confirmed. |
| T-252-14 | medium | closed | scripts/ci/ci-run-metrics.sh:1633-1665. Literal outcomes and run/attempt/log references retained. |
| T-252-15 | high | closed | scripts/ci/ci-run-metrics.sh:262-273,733-739; scripts/ci/ci_metrics_security.py:340-370. Capped downloads and sanitized retained excerpts. |
| T-252-16 | high | closed | scripts/ci/ci_metrics_security.py:216-288; scripts/ci/ci-run-metrics.sh:1513-1533. Selected evidence checks owner/run/head/upload, merge parents, commit-tree-workflow blob and hashes. |
| T-252-17 | high | closed | scripts/ci/ci_metrics_security.py:437-572; scripts/ci/ci-run-metrics.sh:1820-1849. Contract actual archive digest, retained hashed queued responses, identity/chained reservation/window checked. |
| T-252-18 | medium | closed | scripts/ci/ci-measure-report.sh:58-65,86-88,115. Ranking/failure references and literal outcomes retained. |
| T-252-19 | high | closed | scripts/ci/ci_metrics_security.py:305-314,340-396; scripts/ci/ci-run-metrics.sh:1665-1686; scripts/ci/ci-measure-report.sh:24-43. Canonical contained log/hash verification; redacted escaped prose and restricted links. |
| T-252-SC | high | closed | scripts/ci/sigra-dep-off.sh:29; .github/workflows/ci.yml:448. No manifest/lock change; existing locked dependencies used. |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Total | Closed | Open | Blocking | Auditor |
|---|---|---|---|---|---|
| 2026-10-12 | 20 | 9 | 11 | 9 | gsd-security-auditor |
| 2026-10-12T23:49:35.370798+00:00 | 20 | 10 | 10 | 9 | gsd-security-auditor |

| 2026-10-13T00:13:14.371408+00:00 | 20 | 17 | 3 | 3 | gsd-security-auditor |

Prior report bytes are preserved and verified in Git at 61b85304365c3ca06e3c7b45efbccfc436441892; exact identities are recorded in 252-SECURITY-AUDIT.json.

## Sign-Off

- [x] Planned threats have a disposition.
- [x] No risk was waived or accepted.
- [ ] All planned mitigations verified.
- [ ] threats_open: 0.

Approval remains pending automated repair and independent re-audit.
