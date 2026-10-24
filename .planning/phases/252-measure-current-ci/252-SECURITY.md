---
phase: "252"
slug: measure-current-ci
status: secured
threats_open: 0
threats_total: 20
threats_closed: 20
all_open: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: "2026-10-12"
---

# Phase 252 — Security

The independent re-audit verified all twenty planned controls. No risks were accepted. Phase goal verification remains pending.

## Trust Boundaries

GitHub responses enter retained source files; artifact archives enter offline analysis; comparison families enter statistics; retained diagnostic text enters a shareable Markdown report.

## Threat Register

| Threat ID | Severity | Status | Evidence |
|---|---|---|---|
| T-252-01 | high | closed | scripts/ci/ci-run-metrics.sh:922-931,1197-1223,1239-1274; scripts/ci/ci_metrics_security.py:297-366. Native API jobs preserved; every required check bound to verified attempt jobs before endpoint/cost publication; conflicts rejected. |
| T-252-02 | high | closed | scripts/ci/ci_metrics_security.py:22-176; scripts/ci/ci-run-metrics.sh:1330-1333. All retained populations, requests, changed paths, ZIPs/members/extracted bytes hash-checked. |
| T-252-03 | medium | closed | scripts/ci/ci-run-metrics.sh:408-415,426-450. Ledgers omit bearer headers and signed redirects. |
| T-252-04 | high | closed | scripts/ci/ci-run-metrics.sh:196-205,715-721,761-770. API artifact ID, digest, producing run and head checked. |
| T-252-05 | high | closed | scripts/ci/ci-run-metrics.sh:208-255. ZIP path, type, count and byte limits enforced. |
| T-252-06 | high | closed | scripts/ci/ci-run-metrics.sh:335-400,408-415; scripts/ci/ci_metrics_security.py:405-435. Validated counted HTTPS hops; retained logs bounded/redacted. |
| T-252-07 | medium | closed | scripts/ci/ci-run-metrics.sh:322-330,372-379,435-449. Request/time/core budgets enforced before calls; rate limits stop; retries counted. |
| T-252-08 | medium | closed | test/support/ci_timing_formatter.ex:119-134,174-186; scripts/ci/exunit_timing_contract.py:35-84. Atomic producer; consumers reject empty, malformed or inconsistent reports. |
| T-252-09 | medium | closed | test/support/ci_timing_formatter.ex:43-68,119-134. Timing rows exclude assertion and environment values. |
| T-252-10 | medium | closed | scripts/ci/ci-playwright-report.mjs:71-97,121-175,209-223. Native report shape, identity, results, timing and counts validated. |
| T-252-11 | high | closed | scripts/ci/ci-playwright-report.mjs:260-299. Explicit CLI destinations and atomic output; report paths treated as data. |
| T-252-12 | high | closed | scripts/ci/ci-run-metrics.sh:1354-1530,1602-1610,1663-1675; scripts/ci/ci_metrics_security.py:192-237. All metadata claims require complete artifact/upload-job/attempt/source proof. |
| T-252-13 | high | closed | scripts/ci/ci-run-metrics.sh:667-673,1577-1600; scripts/ci/ci_metrics_security.py:267-294. Native job conflicts rejected before ranking; local labels cannot override API identity. |
| T-252-14 | medium | closed | scripts/ci/ci-run-metrics.sh:1611-1649. Literal failures and verified source references retained; missing evidence unknown. |
| T-252-15 | high | closed | scripts/ci/ci-run-metrics.sh:262-273,733-739; scripts/ci/ci_metrics_security.py:405-435. Only bounded redacted failed-log excerpts retained. |
| T-252-16 | high | closed | scripts/ci/ci_metrics_security.py:192-264; scripts/ci/ci-run-metrics.sh:1509-1527. Artifact owner/run/head/upload, merge parents, commit/tree/workflow blob and hashes bound. |
| T-252-17 | high | closed | scripts/ci/ci_metrics_security.py:502-637; scripts/ci/ci-run-metrics.sh:1776-1801. Actual archive digest and frozen contract checked; retained queued API bytes, chained registration, reservations/window validated. |
| T-252-18 | medium | closed | scripts/ci/ci-run-metrics.sh:1611-1651; scripts/ci/ci-measure-report.sh:59-69,89-100. Rankings and signatures retain run/attempt references and literal outcomes. |
| T-252-19 | high | closed | scripts/ci/ci_metrics_security.py:370-379,405-461; scripts/ci/ci-run-metrics.sh:1618-1639; scripts/ci/ci-measure-report.sh:24-43. Canonical contained hashed logs; escaped redacted prose with restricted links. |
| T-252-SC | high | closed | git diff --name-only 282091eaa^ HEAD; scripts/ci/sigra-dep-off.sh:29. No new dependency manifests, lockfiles or install changes. |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Total | Closed | Open | Blocking | Auditor |
|---|---|---|---|---|---|
| 2026-10-12 | 20 | 9 | 11 | 9 | gsd-security-auditor |
| 2026-10-12T23:49:35.370798+00:00 | 20 | 10 | 10 | 9 | gsd-security-auditor |

| 2026-10-13T00:13:14.371408+00:00 | 20 | 17 | 3 | 3 | gsd-security-auditor |

| 2026-10-13T00:31:51.644825+00:00 | 20 | 20 | 0 | 0 | gsd-security-auditor |

Prior report bytes are preserved and verified in Git at 05d4bf293d5e0277ad0c1b1e5acc164609033fc1; exact identities are recorded in 252-SECURITY-AUDIT.json.

## Sign-Off

- [x] Planned threats have a disposition.
- [x] No risk was waived or accepted.
- [x] All planned mitigations verified.
- [x] threats_open: 0.

Independent security verification is complete; phase goal verification remains pending.
