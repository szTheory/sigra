---
phase: "235"
slug: terminal-ratification-measured-not-read
status: verified
threats_open: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: "2026-09-09"
---

# Phase 235 — Security

> ASVS L1 verification of the STRIDE registers authored in all thirteen Phase 235 plans.

## Trust Boundaries

| Boundary | Description | Data crossing |
|---|---|---|
| GitHub APIs → retained evidence | Mutable authenticated run, job, step, and pagination responses enter signed artifacts. | Public workflow metadata and cryptographic provenance |
| Signed subject → measured verdict | Instrument output is authoritative; raw signed pages provide an independent exact-agreement replay. | Run timestamps, conclusions, stable order, p50, and poles |
| Evidence branch → protected main | Evidence producers must land through required checks before dispatch. | Tested workflow, collector, verifier, and contract blobs |
| FAST-01 → GATE-05 | Performance reconciliation must not alter the completed ownership proof. | Requirement state and immutable 93-row ownership ledger |
| Evidence → closeout records | REQUIREMENTS, residual, SEED-005, and CI-PERF must cite one identical authenticated result. | Public evidence tuple and historical measurements |

## Threat Register

Category, component, and mitigation text remain canonical in each referenced `235-*-PLAN.md` threat register. Evidence keys below identify the verified implementation controls.

| Threat ID | Severity | Disposition | Evidence | Status |
|---|---|---|---|---|
| T-235-01-01 | high | mitigate | E1 | closed |
| T-235-01-02 | high | mitigate | E1, E3 | closed |
| T-235-01-03 | high | mitigate | E1 | closed |
| T-235-01-04 | medium | mitigate | E8 | closed |
| T-235-02-01 | high | mitigate | E1, E2 | closed |
| T-235-02-02 | high | mitigate | E1, E2 | closed |
| T-235-02-03 | high | mitigate | E1, E4 | closed |
| T-235-02-04 | high | mitigate | E4 | closed |
| T-235-03-01 | high | mitigate | E1, E3 | closed |
| T-235-03-02 | high | mitigate | E1, E7 | closed |
| T-235-03-03 | high | mitigate | E1, E7 | closed |
| T-235-03-04 | medium | mitigate | E8 | closed |
| T-235-04-01 | high | mitigate | E1, E2 | closed |
| T-235-04-02 | high | mitigate | E1, E3 | closed |
| T-235-04-03 | high | mitigate | E1, E3 | closed |
| T-235-04-04 | low | accept | E9 | accepted |
| T-235-04-05 | low | mitigate | E8 | closed |
| T-235-05-01 | high | mitigate | E4 | closed |
| T-235-05-02 | high | mitigate | E1, E4 | closed |
| T-235-05-03 | high | mitigate | E1, E4 | closed |
| T-235-05-04 | high | mitigate | E1, E3 | closed |
| T-235-05-05 | high | mitigate | E1, E3 | closed |
| T-235-05-06 | low | accept | E9 | accepted |
| T-235-05-07 | low | mitigate | E4, E8 | closed |
| T-235-06-01 | high | mitigate | E1, E4 | closed |
| T-235-06-02 | high | mitigate | E1, E4 | closed |
| T-235-06-03 | high | mitigate | E1, E2 | closed |
| T-235-06-04 | high | mitigate | E1, E3 | closed |
| T-235-06-05 | medium | mitigate | E1, E4 | closed |
| T-235-06-06 | low | accept | E9 | accepted |
| T-235-06-07 | low | mitigate | E4 | closed |
| T-235-07-01 | high | mitigate | E4 | closed |
| T-235-07-02 | high | mitigate | E4 | closed |
| T-235-07-03 | high | mitigate | E4 | closed |
| T-235-07-04 | high | mitigate | E1, E4 | closed |
| T-235-07-05 | medium | mitigate | E4 | closed |
| T-235-07-SC | high | mitigate | E4 | closed |
| T-235-08-01 | high | mitigate | E4, E5 | closed |
| T-235-08-02 | high | mitigate | E4, E5 | closed |
| T-235-08-03 | high | mitigate | E1, E4 | closed |
| T-235-08-04 | high | mitigate | E1, E7 | closed |
| T-235-08-05 | high | mitigate | E1, E4 | closed |
| T-235-08-06 | medium | mitigate | E4 | closed |
| T-235-08-07 | high | mitigate | E4 | closed |
| T-235-15-01 | high | mitigate | E4, E5 | closed |
| T-235-15-02 | high | mitigate | E5 | closed |
| T-235-15-03 | high | mitigate | E5, E6 | closed |
| T-235-15-04 | high | mitigate | E5, E7 | closed |
| T-235-15-05 | high | mitigate | E1, E5 | closed |
| T-235-15-06 | medium | mitigate | E4, E5 | closed |
| T-235-15-07 | low | accept | E9 | accepted |
| T-235-16-01 | high | mitigate | E2, E6 | closed |
| T-235-16-02 | high | mitigate | E2, E6 | closed |
| T-235-16-03 | high | mitigate | E6 | closed |
| T-235-16-04 | high | mitigate | E6 | closed |
| T-235-16-05 | medium | mitigate | E4, E6 | closed |
| T-235-16-06 | low | accept | E9 | accepted |
| T-235-16-07 | high | mitigate | E1, E6 | closed |
| T-235-17-01 | high | mitigate | E4, E6 | closed |
| T-235-17-02 | high | mitigate | E6 | closed |
| T-235-17-03 | high | mitigate | E6 | closed |
| T-235-17-04 | high | mitigate | E6, E7 | closed |
| T-235-17-05 | high | mitigate | E1, E6 | closed |
| T-235-17-06 | medium | mitigate | E4, E6 | closed |
| T-235-17-07 | low | accept | E9 | accepted |
| T-235-18-01 | high | mitigate | E6, E7 | closed |
| T-235-18-02 | high | mitigate | E2, E6, E7 | closed |
| T-235-18-03 | high | mitigate | E1, E7 | closed |
| T-235-18-04 | high | mitigate | E1, E6, E7 | closed |
| T-235-18-05 | low | accept | E9 | accepted |
| T-235-18-06 | low | mitigate | E8 | closed |
| T-235-19-01 | medium | mitigate | E2, E6, E7 | closed |
| T-235-19-02 | medium | mitigate | E6, E8 | closed |
| T-235-19-03 | medium | mitigate | E6, E7 | closed |
| T-235-19-04 | medium | mitigate | E1, E7 | closed |
| T-235-19-SC | low | accept | E9 | accepted |

### Evidence Key

- **E1:** `235-TERMINAL-RATIFICATION.json` and `phase_235_terminal_ratification_contract_test.exs` fail closed on malformed, contradictory, unowned, or receiptless evidence.
- **E2:** `scripts/ci/ci-run-metrics.sh` and its self-test own source retention, wall duration, ordering, threshold, and empty-population behavior.
- **E3:** Phase 198/233/234 inventory, contributor, library-economics, and ownership contracts preserve topology and no-drop assertions.
- **E4:** bounded collectors, correlation scripts, pinned workflows, offline verifier, pagination/exhaustion controls, rate-limit gate, and exact singleton dispatch binding.
- **E5:** retained Plan 15 subject/bundle/root and its gap-closure contract preserve the rejected derived-only candidate and mutation checks.
- **E6:** source-complete subject/bundle/root, sealed dispatch receipt, fixed-path verifier, and source-complete contract authenticate and replay Plan 17.
- **E7:** `235-VALIDATION.md`, Plans 17–18 summaries, remeasurement/terminal contracts, and cross-record reconciliation checks.
- **E8:** bounded deterministic local checks with no sleeps or network dependency.
- **E9:** explicit low-severity accepted risks limited to public repository/run/planning metadata; credentials and authenticated state are excluded.

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---|---|---|---|---|
| AR-235-01 | T-235-04-04 | Public aggregate planning evidence only; no credentials or authenticated payloads. | Plan-time register | 2026-09-09 |
| AR-235-02 | T-235-05-06 | Public repository evidence only; secrets and raw authenticated state excluded. | Plan-time register | 2026-09-09 |
| AR-235-03 | T-235-06-06 | Public run metadata retained without tokens, headers, cookies, or proxies. | Plan-time register | 2026-09-09 |
| AR-235-04 | T-235-15-07 | Public protected-run facts and cryptographic materials only. | Plan-time register | 2026-09-09 |
| AR-235-05 | T-235-16-06 | Source-complete subject contains public workflow metadata only. | Plan-time register | 2026-09-09 |
| AR-235-06 | T-235-17-07 | Correlation and evidence receipts expose no credentials or private API state. | Plan-time register | 2026-09-09 |
| AR-235-07 | T-235-18-05 | Closeout records cite public run metadata and repository proof paths only. | Plan-time register | 2026-09-09 |
| AR-235-08 | T-235-19-SC | No package manager, dependency resolution, or package installation occurs in the verifier-only gap closure. | Plan-time register | 2026-09-09 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Accepted | Open | Run By |
|---|---:|---:|---:|---:|---|
| 2026-09-09 | 71 | 64 | 7 | 0 | gsd-security-auditor |
| 2026-09-09 | 76 | 68 | 8 | 0 | execute-phase ASVS-L1 short-circuit |
| 2026-09-09 | 76 | 68 | 8 | 0 | verify-work ASVS-L1 short-circuit |

## Sign-Off

- [x] All threats have a disposition.
- [x] Accepted risks are documented.
- [x] `threats_open: 0` confirmed at ASVS L1 with `block_on: high`.
- [x] `status: verified` set in frontmatter.

**Approval:** verified 2026-09-09
