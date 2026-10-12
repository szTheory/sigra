---
phase: "252"
slug: measure-current-ci
status: blocked
threats_open: 9
threats_total: 20
threats_closed: 10
all_open: 10
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: "2026-10-12"
---

# Phase 252 — Security

The independent re-audit verified ten controls and found nine blocking and one medium gap. No risks were accepted. Automated repair remains in scope; phase verification is pending.

## Trust Boundaries

GitHub responses enter retained source files; artifact archives enter offline analysis; comparison families enter statistics; retained diagnostic text enters a shareable Markdown report.

## Threat Register

| Threat ID | Severity | Status | Evidence and remaining control |
|---|---|---|---|
| T-252-01 | high | open blocking | scripts/ci/ci-run-metrics.sh:1215-1224; scripts/ci/ci_metrics_security.py:129-154. Family replay omits job run, attempt and repository bindings. |
| T-252-02 | high | open blocking | scripts/ci/ci-run-metrics.sh:686; scripts/ci/ci_metrics_security.py:48-72. Retained changed-path API pages have no response hashes. |
| T-252-03 | medium | closed | scripts/ci/ci-run-metrics.sh:329,345,409-413. Ledger excludes bearer headers and signed redirect URLs. |
| T-252-04 | high | closed | scripts/ci/ci-run-metrics.sh:194-203,761-766. Artifact API ID/digest/run/head SHA checked before ZIP acceptance. |
| T-252-05 | high | closed | scripts/ci/ci-run-metrics.sh:206-253. ZIP bounds and traversal/absolute/symlink/duplicate rejection present. |
| T-252-06 | high | open blocking | scripts/ci/ci_metrics_security.py:252-270; scripts/ci/ci-run-metrics.sh:729-733. Shell-traced environment assignments survive redaction; reproduced offline. |
| T-252-07 | medium | closed | scripts/ci/ci-run-metrics.sh:322-328,370-379,438-445. Every request debits budgets; rate-limit hard stop and bounded transient retry. |
| T-252-08 | medium | open non blocking | scripts/ci/exunit_timing_contract.py:46-84; scripts/ci/ci-run-metrics.sh:1611-1627. General ExUnit reader accepts empty complete reports and unchecked counts/results. |
| T-252-09 | medium | closed | test/support/ci_timing_formatter.ex:43-68,119-134. Output contains identity/result/duration, no assertions/environment. |
| T-252-10 | medium | closed | scripts/ci/ci-playwright-report.mjs:71-97,122-170,209-215. Playwright shape/identity/results/timing/summary checked. |
| T-252-11 | high | closed | scripts/ci/ci-playwright-report.mjs:260-293. Explicit CLI destinations; report is data. |
| T-252-12 | high | open blocking | scripts/ci/ci-run-metrics.sh:1581-1608; scripts/ci/ci_metrics_security.py:157-202. General timing reader lacks API artifact-owner and producer-upload binding. |
| T-252-13 | high | open blocking | scripts/ci/ci-run-metrics.sh:1559-1573,1365. General rankings omit job run, attempt and head SHA checks. |
| T-252-14 | medium | closed | scripts/ci/ci-run-metrics.sh:1633-1665. Literal outcomes and run/attempt/log references retained. |
| T-252-15 | high | open blocking | scripts/ci/ci_metrics_security.py:252-278; scripts/ci/ci-run-metrics.sh:729-733. Bounded logs still retain shell-traced environment secrets. |
| T-252-16 | high | open blocking | scripts/ci/ci_metrics_security.py:205-226; scripts/ci/ci-run-metrics.sh:1492-1509. Replay does not bind tree.sha to commit.commit.tree.sha; reproduced offline. |
| T-252-17 | high | open blocking | .planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json:10; scripts/ci/ci-run-metrics.sh:1792-1802,1084-1102; scripts/ci/ci_metrics_security.py:439. Contract retains old bundle SHA without evaluator equality check. Queued API response discarded; recorded digest only syntax checked. |
| T-252-18 | medium | closed | scripts/ci/ci-measure-report.sh:58-65,86-88,115. Ranking/failure references and literal outcomes retained. |
| T-252-19 | high | open blocking | scripts/ci/ci-run-metrics.sh:1642-1656; scripts/ci/ci-measure-report.sh:21-26,88. Log reference path not contained or bound to hash-verified log; Markdown allows non-HTTP link syntax. |
| T-252-SC | high | closed | scripts/ci/sigra-dep-off.sh:29; .github/workflows/ci.yml:448. No manifest/lock change; existing locked dependencies used. |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Total | Closed | Open | Blocking | Auditor |
|---|---|---|---|---|---|
| 2026-10-12 | 20 | 9 | 11 | 9 | gsd-security-auditor |
| 2026-10-12T23:49:35.370798+00:00 | 20 | 10 | 10 | 9 | gsd-security-auditor |

Prior report bytes are preserved and verified in Git at 5af2854a863c1081b54fe3ff71a965c1e64b4f12; exact identities are recorded in 252-SECURITY-AUDIT.json.

## Sign-Off

- [x] Planned threats have a disposition.
- [x] No risk was waived or accepted.
- [ ] All planned mitigations verified.
- [ ] threats_open: 0.

Approval remains pending automated repair and independent re-audit.
