---
phase: "247"
slug: "release-candidate-and-repository-readiness"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-10-07"
---

# Phase 247 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Reviewed source and CI → adopter claims | Compatibility or migration claims must reflect the reviewed candidate and required evidence. | Source diffs, test receipts, guide/changelog text |
| Candidate checkout → Hex/ExDoc output | Package and docs output must correspond to the recorded candidate SHA. | Candidate source, package metadata, docs build output |
| Live GitHub/Git observations → readiness ledger | PRs, refs, and inherited paths may change between observations. | PR heads/bases, main SHA, commit/path populations, worktree status |
| Inherited checkout → release candidate | Unrelated changes must remain preserved and excluded from the package source. | Committed and dirty paths, candidate worktree identity |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-247-01 | Tampering | Source inventory and selection | high | mitigate | Final readiness capture rechecks refs and full commit/path/PR populations; it rejects incomplete dispositions. The latest capture has only the separate Hex dry-run diagnostic after the dirty-planning-path classification fix. | closed |
| T-247-02 | Repudiation | Open PR dispositions | medium | mitigate | The ledger records each current open PR, its identity, disposition, reason, source, and preservation location; final validation compares the recorded population to live GitHub. | closed |
| T-247-03 | Tampering | Candidate metadata and source reference | high | mitigate | Candidate SHA, PR/base/main identity, manifest, versioned changelog, configured source tag, and ExDoc reference are checked together; exact-head CI is recorded. | closed |
| T-247-04 | Repudiation | Public release notes | high | mitigate | Candidate claims map to reviewed source and exact-head CI evidence; unsupported Phase 246 claims remain rejected by the ledger validator. | closed |
| T-247-05 | Tampering | Upgrade guide claims | high | mitigate | README → v1.6 guide → versioned changelog links and adopter claims are checked against source and warning-free docs CI at the exact candidate head. | closed |
| T-247-06 | Repudiation | Candidate package/docs result | medium | mitigate | Exact candidate SHA and command outcomes are recorded. The Hex publish dry run is explicitly unproven; final validation remains blocked and does not present it as success. | open — below high threshold (non-blocking) |
| T-247-SC | Tampering | Package-manager installation boundary | high | mitigate | No dependency installation was performed in the clean candidate. Missing exact locked dependencies remain a blocker; no install was used to manufacture a dry-run pass. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*  
*Severity: critical > high > medium > low — only open threats at or above the configured high threshold count toward `threats_open`.*

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-10-07 | 7 | 6 | 1 | Codex — ASVS L1 plan/register and evidence check |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed (no open high-or-higher threat)
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-10-07
