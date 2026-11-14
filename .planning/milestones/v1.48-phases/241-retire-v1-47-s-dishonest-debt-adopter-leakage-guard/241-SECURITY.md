---
phase: "241"
slug: "retire-v1-47-s-dishonest-debt-adopter-leakage-guard"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-25"
---

# Phase 241 — Security

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Local candidate → GitHub Actions PR run | CI evidence must describe the requested committed source SHA and actual PR head. | Public commit SHA, PR number, run and job metadata. |
| GitHub API → final-head receipt | External API data is untrusted until identity, pagination, job, and step invariants pass. | Public structured Actions and PR metadata. |
| Receipt → planning evidence | CI observations become durable project claims. | Public run IDs, URLs, SHAs, job names, and conclusions. |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-241-G08-01 | Spoofing | PR/run identity | high | mitigate | Check fixed PR endpoint number/base/head before run retrieval and again after collecting run/jobs; stale and advancing-head fixtures reject mismatches. | closed in working tree; follow-up receipt required |
| T-241-G08-02 | Repudiation | required job/step evidence | high | mitigate | Unique required jobs and steps must report successful conclusions; receipt schema validates selected fields. | closed |
| T-241-G08-03 | Repudiation | fast-check evidence | high | mitigate | Fast-check job and named prohibition step must each be unique and successful. | closed |
| T-241-G08-04 | Denial of service | fresh-build ordering | medium | mitigate | Fresh clean/rebuild and exact alias sequence is recorded and validated by phase evidence; collector does not enforce command ordering. | open — below high threshold (non-blocking) |
| T-241-G08-05 | Tampering | job identity | high | mitigate | Job IDs must be unique against the actual ID count; duplicate-ID fixture is rejected. | closed in working tree |
| T-241-G08-06 | Information disclosure | receipt contents | low | accept | Receipt contains bounded public CI metadata only; no credentials, private artifacts, or secret-bearing logs are retrieved. | closed |
| T-241-G08-07 | Denial of service | GitHub polling | medium | mitigate | Rate-limit preflight and 403/429 hard stops are enforced; one-watcher/60-second cadence remains an operator workflow constraint. | open — below high threshold (non-blocking) |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-241-01 | T-241-G08-06 | The receipt intentionally records public run identifiers, URLs, SHA values, job names, and conclusions. No credential or private artifact data is included. | Phase 241 Plan 08 disposition | 2026-09-25 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-25 | 7 | 5 | 2 below blocking threshold | GSD security audit |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` blocking threats confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-25; final-head external receipt for the updated collector remains pending
