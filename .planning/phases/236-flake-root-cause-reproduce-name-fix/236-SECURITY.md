---
phase: "236"
slug: "flake-root-cause-reproduce-name-fix"
status: blocked
threats_open: 2
asvs_level: 1
created: "2026-09-19"
---

# Phase 236 — Security

> Automated security review; open high-severity provenance gaps block phase advancement.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Browser to `AuditIndexLive` | Filter form parameters become a LiveView patch target. | Organization-scoped audit filters |
| Evidence ledger to CI provenance | Recorded GitHub Actions runs support the RED/GREEN claims. | Public run IDs, job conclusions, commit SHA |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-236-01 | Information Disclosure | Evidence docs | medium | mitigate | Secret-value scan | closed |
| T-236-02 | Tampering | Playwright config | medium | mitigate | Retry/trace contract | closed |
| T-236-03 | Repudiation | Evidence provenance | high | mitigate | Phase-236 ledger must pass a provenance guard | open |
| T-236-04 | Denial of Service | Local reproduction | low | accept | Local Postgres/port contention is bounded | open — below high threshold |
| T-236-05 | Tampering | Filter parameters | high | mitigate | `Map.take/2` allowlist | closed |
| T-236-06 | Tampering | Patch target | high | mitigate | Scope-derived local paths only | closed |
| T-236-07 | Information Disclosure | Audit scope | high | mitigate | Organization-scoped query coverage | closed |
| T-236-08 | Denial of Service | Filter query | low | accept | One bounded query per submit | open — below high threshold |
| T-236-09 | Repudiation | Audit loader | low | accept | No new audited action | open — below high threshold |
| T-236-10 | Tampering | Retry guard | high | mitigate | RED fixture plus non-vacuity floors | closed |
| T-236-11 | Repudiation | Guard observation | high | mitigate | Recorded RED/GREEN command evidence | closed |
| T-236-12 | Elevation of Privilege | CI workflow | high | mitigate | One-line retry deletion with contracts | closed |
| T-236-13 | Tampering | Fixture isolation | medium | mitigate | Fixture is non-imported text only | closed |
| T-236-14 | Denial of Service | Fast checks | low | accept | Sub-second runtime addition | open — below high threshold |
| T-236-15 | Repudiation | Five-run GREEN claim | high | mitigate | Phase-236-aware provenance guard | open |
| T-236-16 | Spoofing | GitHub run identity | high | mitigate | Live event/SHA/job verification | closed |
| T-236-17 | Tampering | CI repeat history | medium | mitigate | Completed non-cancelled run verification | closed |
| T-236-18 | Information Disclosure | Merge diff | medium | mitigate | Credential/adopter scan | closed |
| T-236-19 | Elevation of Privilege | Workflow dispatch | high | mitigate | PR-push-only evidence | closed |
| T-236-SC | Tampering | Dependency scope | low | accept | No manifest or lockfile change | open — below high threshold |

## Accepted Risks Log

No accepted risks. The low-severity entries remain documented but are not accepted as a substitute for their stated dispositions.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-19 | 20 | 13 | 7 (2 blocking) | gsd-security-auditor |

## Blocking Findings

`T-236-03` and `T-236-15` share one root cause: the existing `p12-run-id-provenance` test is hard-coded to Phase 230. Phase 236's RED/GREEN ledger is therefore live-verifiable but not covered by the declared mechanical provenance control. The required remediation is a Phase-236-aware or safely generalized guard that makes the ledger pass in CI without weakening the Phase 230 contract.

## Sign-Off

- [x] All threats have a disposition
- [ ] Blocking mitigations verified
- [ ] `threats_open: 0` confirmed
- [ ] `status: verified` set in frontmatter

**Approval:** blocked pending automated provenance-guard remediation
