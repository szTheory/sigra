---
phase: "250"
slug: "close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-10-10"
---

# Phase 250 — Security

> L1 mitigation-presence audit of the authored Phase 250 threat register. This records control presence and test evidence; it does not assert the missing hosted release/canary outcomes.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|-----------|-------------|---------------|
| Canary source to trusted observer/controller | Workflow metadata and artifacts are treated as untrusted data and joined against exact GitHub identities. | Event/ref, run and attempt IDs, SHA, artifact metadata and sanitized receipt fields. |
| GitHub and release evidence to owner verifiers | Mutable refs and inventory are re-read; historical source identities remain distinct. | Public release facts, run/job metadata, PR tuples, raw status hashes and accepted-loss identity. |
| Phase reports to traceability audit | Only original owner reports and their source-bound outcomes determine requirement status. | Sanitized source identities, verdicts and blockers; no credential values. |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-250-01 | Elevation of privilege | workflow_run observer | high | mitigate | Exact workflow identity allowlist and authoritative source re-query are present in `scripts/ci/release-observer.sh`; observer fixtures reject wrong workflow IDs and malformed event identity. | closed |
| T-250-02 | Denial of service | controller cancellation | high | mitigate | `scripts/ci/release-canary.sh` and the controller workflow bind cancellation to the exact canary run; canary fixtures exercise refusal of non-canary and ambiguous run identities. | closed |
| T-250-03 | Spoofing/Tampering | retrieved receipts | high | mitigate | `scripts/ci/release-receipt.sh` validates source/run/attempt identity; receipt and observer fixtures reject mismatches and cover idempotent identity binding. | closed |
| T-250-04 | Information disclosure | receipt builder and workflows | high | mitigate | Receipt builder uses a sanitized field contract; receipt tests reject credential-shaped fields and verify the supplied sentinel value is not persisted. Workflows do not grant the canary publishing credentials. | closed |
| T-250-05 | Spoofing | candidate approval/tuple | high | mitigate | `verify-247-readiness.mjs` requires immutable tuple approval; its tests confirm pending authorization blocks candidate approval. | closed |
| T-250-06 | Tampering | readiness/CI/dry-run join | high | mitigate | `verify-247-readiness.mjs` now routes candidate source, diff digest, readiness commit, exact-head receipt, authoritative run, and capture-race blockers into requirement verdicts. Its 14-test suite covers source-blob drift, stale CI attempt/SHA, malformed receipt, race changes, and verdict blocking. Fixes: `da7d33053`, `e806ccf07`. | closed |
| T-250-07 | Repudiation | owner verification | medium | mitigate | Phase 247 reconciliation and report record captured time, identities, and structured blockers; report-integrity fixture requires those identities. | closed |
| T-250-08 | Information disclosure | environment preflight | high | mitigate | Phase 248 verifier records environment/secret names and policy only; preflight tests reject widened scopes and repository-level copies without persisting values. | closed |
| T-250-09 | Spoofing | AUTO-02 report | high | mitigate | Phase 248 now consumes the actual top-level producer receipt schema, captures each terminal artifact against its authoritative run/listing and downloaded digest, then validates full source/observer identities through evaluation and report checks. The 10-test suite runs the real serializer for both local terminal fixtures; the independent third recheck found no mismatch. Fixes: `13d11e69a`, `27ddb4ea1`, `866dfd735`, `d9c74aac0`. | closed |
| T-250-10 | Repudiation | stale verifier | medium | mitigate | Refreshed Phase 248 report binds a current snapshot and retains the previous report as history; report-check fixture verifies status and identity consistency. | closed |
| T-250-11 | Spoofing | public release/source identity | high | mitigate | `verify-249-release.mjs` joins package source, public tag/docs/checksum, historical acceptance and receipt; fixtures reject source and acceptance-ref drift. | closed |
| T-250-12 | Tampering | current main and inventory | high | mitigate | Phase 249 verifier re-reads exact current-main CI, raw worktree status and live PR identities, and checks unchanged receipt identity; fixtures reject failed CI, dirty status, receipt drift and stale dispositions. | closed |
| T-250-13 | Repudiation | accepted historical loss | medium | mitigate | Verifier and report bind the exact HANDOFF loss hash and authorization, assert bytes were neither recovered nor preserved, and reject changed or overstated loss records. | closed |
| T-250-14 | Repudiation | requirement/audit rows | high | mitigate | Traceability recomputes Phase 248/249 owner verdicts from source snapshots, runs report integrity checks, and rejects embedded marker drift. The 10-test suite covers forged satisfied markers against unsatisfied owner outcomes; current source audit retains the genuine 5/9 gaps. Fix: `698f5d6cc`. | closed |
| T-250-15 | Tampering | audit score | high | mitigate | Strict audit status is computed from owner evidence; a hostile fixture rejects hand-edited passing scores and stale 9/9 claims. | closed |
| T-250-16 | Information disclosure | audit evidence | medium | mitigate | Traceability output stores sanitized run/artifact identifiers and secret names; source predicates reject credential-value fields. | closed |
| T-250-SC | Tampering | package installation | low | accept | No package-manager install was used; existing repository tools and pinned actions were reused. | closed |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-250-SC | T-250-SC | No package installation is in scope; existing tools and pinned actions are used. | Phase 250 plan disposition | 2026-10-10 |

## Separate Owner-Proof Gaps

The initial L1 review recorded three open mitigation gaps: T-250-06, T-250-09, and T-250-14. They were repaired in `da7d33053`, `e806ccf07`, `13d11e69a`, `27ddb4ea1`, `866dfd735`, `d9c74aac0`, and `698f5d6cc`; focused tests and the independent iteration-3 source recheck now support closure. Security mitigation closure does not close product/release acceptance requirements. AUTO-02 remains blocked because the authorized canary produced neither hosted failure nor cancellation receipts. READY-01/02 remain unsatisfied in Phase 247. REL-02 remains unsatisfied because the current-main workflow failed and five live PR identities lack matching dispositions. No missing hosted proof is treated as satisfied by these local controls or fixtures.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-10-10 | 16 mitigations + 1 accepted low risk | 14 | 3 | Initial Codex L1 review |

## Sign-Off

- [x] All threats have a disposition.
- [x] Accepted risk is documented in the Accepted Risks Log.
- [x] `threats_open: 0` — all 16 authored mitigations are now supported by current predicates and negative-test evidence.
- [x] `status: verified` set after source/test re-audit.

**Outcome:** verified 2026-10-10 at ASVS L1. The initial three mitigation gaps were fixed and rechecked; no additional risk was accepted.

## Security Audit 2026-10-10

| Metric | Count |
|---|---|
| Threats found | 17 |
| Closed | 17 |
| Open | 0 |
