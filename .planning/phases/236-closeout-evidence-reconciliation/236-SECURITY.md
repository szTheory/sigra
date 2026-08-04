---
phase: 236
slug: closeout-evidence-reconciliation
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-04
---

# Phase 236 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Historical evidence | Immutable verification, validation, receipt, and snapshot artifacts are reconciled from Git history. | SHA-256 digests, Git blobs, planning evidence |
| Validator and audit workflows | Installed GSD validators and the v1.47 audit create canonical lifecycle and audit claims. | Workflow output and lifecycle metadata |
| Scope fence | Git ranges and the current worktree are constrained to a fixed allowlist. | Changed, tracked, and untracked paths |
| Snapshot verifier | Caller inputs are checked against fixed Git-object bytes before JSON decoding. | Snapshot JSON and audit report bytes |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-236-01 | Tampering | SUMMARY declarations and REQUIREMENTS traceability | high | mitigate | Exact ownership, cardinality, and adverse-mutation contract | closed |
| T-236-02 | Tampering | Protected verification and receipt inputs | high | mitigate | Pinned SHA-256 digest contract | closed |
| T-236-03 | Repudiation | Historical proof provenance | medium | mitigate | Byte-preserved narratives linked to independent verification | closed |
| T-236-04 | Elevation of privilege | Checkbox-only completion claim | high | mitigate | Checked requirement plus independent verification and contract | closed |
| T-236-05 | Tampering | 230/231/232/234 validation lifecycle | high | mitigate | Validator-owned lifecycle transitions with postconditions | closed |
| T-236-06 | Repudiation | Validator failure diagnostics | high | mitigate | Fail-fast, exact artifact diagnostics | closed |
| T-236-07 | Tampering | 233/235 validation and 230–235 proof | high | mitigate | Phase digest contract pins out-of-scope artifacts | closed |
| T-236-08 | Denial of service | Optional GitHub evidence lookup | medium | mitigate | Bounded one-watcher/rate-limit hard-stop policy | closed |
| T-236-09 | Tampering | Generated milestone scores and classifications | high | mitigate | Canonical v1.47 audit with exact-field assertions | closed |
| T-236-10 | Repudiation | Noncompliant audit diagnostics | high | mitigate | Preserve fresh report and stop; no waiver | closed |
| T-236-11 | Elevation of privilege | Debt classification gate | medium | mitigate | Audit-owned classification and gap-array assertions | closed |
| T-236-12 | Denial of service | External audit observation | low | accept | One bounded canonical invocation; no CI watcher | closed |
| T-236-13 | Tampering | Existing Phase 231 boundary | high | mitigate | Pinned parent, exact diff, lifecycle and blob assertions | closed |
| T-236-14 | Repudiation | Validator provenance | high | mitigate | Recorded installed-skill result; bounded repository-only claims | closed |
| T-236-15 | Elevation of privilege | Manual lifecycle promotion | high | mitigate | Installed validator plus canonical-delta checks | closed |
| T-236-16 | Tampering | Config, readiness, state, and D-04 evidence | high | mitigate | Pinned blobs/digests and phase-only validator scope | closed |
| T-236-17 | Denial of service | Failed or broad validator transition | medium | mitigate | Preserve diagnostics/state and stop recovery chain | closed |
| T-236-18 (P04) | Tampering | Interposed commits | high | mitigate | Pinned predecessor/direct-child and range-diff checks | closed |
| T-236-19 (P04) | Repudiation | Failure diagnostics | high | mitigate | Schema-validated recovery-result artifact only | closed |
| T-236-18 (P05) | Tampering | Audit input selection | high | mitigate | Source inventory and mutation/omission/reordering rejection | closed |
| T-236-19 (P05) | Tampering | Config or Nyquist/checker state | high | mitigate | Before/after source and resolution snapshot | closed |
| T-236-20 | Repudiation | Audit invocation | high | mitigate | Explicit orchestration record with bounded claims | closed |
| T-236-21 (P05) | Elevation of privilege | Hand-edited green terminal report | high | mitigate | Independent source-to-report adversarial contract | closed |
| T-236-22 (P05) | Information disclosure | Resolver/config capture | medium | mitigate | Paths/digests only; no environment values or credentials | closed |
| T-236-23 (P05) | Denial of service | Audit or checker failure | medium | mitigate | Preserve diagnostics and stop; no duplicate watcher/waiver | closed |
| T-236-21 (P06) | Tampering | Phase 231 protected mixed-commit blobs | high | mitigate | Exact blob, scope, and parent assertions | closed |
| T-236-22 (P06) | Tampering | Input/output audit snapshots | high | mitigate | Recomputed manifest, hashes, ancestry, linkage, and audit digest | closed |
| T-236-23 (P06) | Repudiation | Audit/validator provenance | high | mitigate | Bounded claim-limit text; no identity-authentication claim | closed |
| T-236-24 | Elevation of privilege | Scope expansion | high | mitigate | Identical fail-closed allowlist for committed/tracked/untracked paths | closed |
| T-236-25 | Denial of service | Mutable metadata invalidating frozen audit | medium | mitigate | Historical freeze-to-output comparison | closed |
| T-236-SC (P06) | Tampering | Package installation surface | high | accept | No package installation occurs | closed |
| T-236-26 | Tampering | `historical_verify!/4` documents | critical | mitigate | Fixed Git blobs, byte equality before decode, forged-pair rejection | closed |
| T-236-27 | Spoofing | Caller snapshot paths and manifests | high | mitigate | Fixed repository paths/Git objects are authoritative | closed |
| T-236-28 | Tampering | Rebased Plan 06 scope boundary | high | mitigate | Pinned amendment/completion ancestry and exact range | closed |
| T-236-29 | Repudiation | Plan 07 pre-implementation baseline | high | mitigate | Pinned introduction commit with exact scope/ancestry | closed |
| T-236-30 | Elevation of privilege | Scope expansion into protected artifacts | high | mitigate | One five-path allowlist for all collections | closed |
| T-236-31 | Denial of service | Git collection failure | medium | mitigate | Command-status enforcement and pipeline failure propagation | closed |
| T-236-SC (P07) | Tampering | Package installation surface | high | accept | No package installation occurs | closed |
| T-236-32 | Tampering | `changed_paths_between!/2` | critical | mitigate | Per-commit `rev-list`/`diff-tree` collection; restored-path regression | closed |
| T-236-33 | Repudiation | Git collection failures | high | mitigate | Contextual diagnostics and invalid/mid-collection failure tests | closed |
| T-236-34 | Elevation of privilege | Scope allowlist drift | high | mitigate | Byte-stable shared `@scope_allowlist` | closed |
| T-236-35 | Tampering | Historical Plan 07 range | medium | mitigate | Pinned committed completion SHA | closed |
| T-236-SC (P08) | Tampering | Package installation surface | high | accept | No package installation occurs | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-236-01 | T-236-12 | Canonical audit invocation is bounded and performs no CI watching. | Phase plan | 2026-08-04 |
| AR-236-02 | T-236-SC (P06/P07/P08) | Plan scope installs no packages and uses only repository Git and existing Elixir tooling. | Phase plan | 2026-08-04 |

---

## Security Audit 2026-08-04

| Metric | Count |
|--------|-------|
| Threats found | 43 |
| Closed | 43 |
| Open | 0 |

### Evidence

- `MIX_ENV=test mix test test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` passed: 9 tests, 0 failures.
- `236-VERIFICATION.md` records 10/10 must-haves verified, including immutable evidence digests, fixed-blob snapshot verification, forged-pair rejection, and fail-closed range scope tests.
- All eight PLAN threat models were parsed; all eight SUMMARY files contained no `Threat Flags` section or entries.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-04 | 43 | 43 | 0 | Codex / gsd-secure-phase |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-04
