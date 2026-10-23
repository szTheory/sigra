---
phase: "253"
slug: fix-flaky-ci-and-preserve-required-checks
status: verified
threats_open: 0
asvs_level: 1
created: "2026-10-23"
---

# Phase 253 — Security

The security auditor checked 622 threat declarations across 182 authored threat models: 441 distinct IDs, 353 high and 88 medium. All are mitigated at ASVS Level 1. No accepted risk or transfer was invented. Full per-plan IDs, original categories, severities and mitigation text are retained in `.planning/execution/253-final-gates/security-audit.json`.

## Trust boundaries and mitigation evidence

| Boundary / threat family | Closed IDs | Current mitigation evidence |
|---|---|---|
| Archived logs to diagnosis | T-253-01–02 | `scripts/ci/ci_metrics_security.py:22,645` verifies hashes/identities and sanitizes selected context. |
| Native CI results to required gate | T-253-05–08,11–12 | `scripts/ci/honest-skip-verdict.sh:109`, `.github/workflows/ci.yml:1886`, p10/p21 contracts retain lane parity and reject missing results. |
| Downloaded browser artifacts to aggregate | T-253-09–10 | `scripts/ci/ci-browser-records.mjs:15,97` rejects unsafe paths, checks exact producers, hashes and reports. |
| Account uniqueness to public error | T-253-111–112 | `lib/sigra/auth.ex:169,1851` masks duplicate-email errors; `test/sigra/auth_test.exs:130,154` covers them. |
| Native controls and source/budget/log input | 69 IDs in audit record | `scripts/ci/ci-registration-recovery.mjs:860,1258,2823,4435,6683,6930`; `registrationControls.mjs:16`; `failure-jsonl.mjs:11` enforce source identity, owned state, sanitation, approvals, trace/control union and bounded records. |
| History and completion claims | 67 IDs in audit record | `scripts/ci/ci-hosted-gate-verify.py:1893`; `253-LOAD-RECOVERY-reconcile.mjs:2347,2387,2426` reopen bytes and reject synthetic acceptance/halted owners; destinations use exclusive creation. |
| Local recovery captures | T-253-407–442 | `253-RECOVERY-SUCCESSOR.py:532,641,1179,1281,2123`; `253-RECOVERY-BRIDGE-V3.py:57,89` check captured bytes, process output, single-use attempts, permission/source receipts and literal historical statuses. |
| Remote HTTP/publication to evidence | 256 IDs in audit record | `scripts/ci/ci-hosted-transport.py:600,825,1014`; `ci-git-publication.py:647,694,989,1344`; `ci-hosted-gate-verify.py:613,792,1718,1802`; `ci-shape-probe.py:246,465` enforce origin/redirect/token restrictions, charged limits, approvals, create-only refs, receipt identities and safe archive intake. |
| Dependencies/actions to execution | T-253-SC | `ci-registration-recovery.mjs:651,3251` checks installed/locked Playwright identity/integrity; CI actions remain SHA pinned. |

The exact distinct set is T-253-01 through T-253-442 except 405/406, plus T-253-SC. Shared SC occurs in all 182 threat models. Plan172 has no threat block. All 110 summaries were inspected; 35 explicit Threat Flags sections contain no new unregistered threat. The T-253-204a cross-reference resolves to the same control registered as T-253-204 in Plan101.

## Preserved history

The auditor reopened all 73 retired plans from their declared Git commits and checked blob/SHA-256, current plan hash, superseded status, replacement paths and absence of invented summaries: zero mismatches. The 81 implementations, 29 halts and 73 unused retired recipes remain distinct. A current mitigation does not relabel a historical attempt successful.

## Accepted risks

None.

## Security Audit

| Date | Distinct threats | Closed | Open | Depth |
|---|---:|---:|---:|---|
| 2026-10-23 | 441 | 441 | 0 | ASVS1 source verification |

No browser, app, database, CI or GitHub operation was run. This result does not re-prove historical acceptance, claim end-to-end bypass resistance, or complete CIREL-01/Phase253.
