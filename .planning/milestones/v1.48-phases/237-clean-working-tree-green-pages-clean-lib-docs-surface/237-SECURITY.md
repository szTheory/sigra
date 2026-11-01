---
phase: "237"
slug: clean-working-tree-green-pages-clean-lib-docs-surface
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-19"
---

# Phase 237 — Security

> ASVS L1 verification of the threat registers authored in all six plans.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Local tree → public repository | Ignore rules and committed artifacts control accidental disclosure | logs, screenshots, local paths, planning evidence |
| Repository → public Pages site | Pages source selects what becomes publicly served | generated report site versus repository internals |
| Local Git objects → remote/maintenance | Worktree and stash operations can disclose or destroy recoverability | stash commits, refs, reflogs |
| Source prose → public documentation | Documentation edits can leak dead paths or erase security rationale | module docs, upgrade guides, rationale comments |
| Evidence ledger → future reviewer | Green claims must remain reproducible and non-vacuous | commands, controls, commit identity |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Evidence | Status |
|-----------|----------|-----------|----------|-------------|---------------------|--------|
| T-237-01-01 | Information Disclosure | agent scratch directory | high | mitigate | Root-anchored ignore rule plus ignore/status controls | closed |
| T-237-01-02 | Repudiation | ignore negation | medium | mitigate | Reachable glob form with negative and positive controls | closed |
| T-237-01-03 | Denial of recoverability | tracked docs index | medium | mitigate | Fresh-clone tracked-file and idempotence checks | closed |
| T-237-01-04 | Tampering | package installs | low | accept | No dependency manifest or lockfile change | closed |
| T-237-02-01 | Information Disclosure | Pages source | critical | mitigate | Live source is `gh-pages`; root `.nojekyll` remains absent | closed |
| T-237-02-02 | Denial of recoverability | Pages setting mutation | high | mitigate | Pre-change payload and literal revert command committed before mutation | closed |
| T-237-02-03 | Spoofing | green Pages claim | high | mitigate | Independent API status/build and HTTP 200 with 404 control | closed |
| T-237-02-04 | Tampering | package installs | low | accept | No registry package installed by this plan | closed |
| T-237-03-01 | Information Disclosure | public stash push | critical | mitigate | D-09 prohibits the push; no archive refs exist on origin | closed |
| T-237-03-02 | Information Disclosure | home path in snapshot | high | mitigate | Negative scan with positive control; snapshot remains sanitized | closed |
| T-237-03-03 | Denial of recoverability | unarchived stashes | high | mitigate | Exact six-SHA comparison and standing gc/reflog/prune prohibition | closed |
| T-237-03-04 | Denial of recoverability | worktree prune | low | accept | Git-native scope documented; all stash SHAs remain resolvable | closed |
| T-237-03-05 | Repudiation | undocumented removal | medium | mitigate | Pre-operation snapshot remains tracked | closed |
| T-237-03-06 | Tampering | package installs | low | accept | No registry package installed by this plan | closed |
| T-237-04-01 | Repudiation / knowledge loss | rationale comments | high | mitigate | Regex-class guard demonstrated RED against committed fixture | closed |
| T-237-04-02 | Spoofing | non-firing guard | critical | mitigate | Trip/tolerate fixtures and empty-input fail-closed proof | closed |
| T-237-04-03 | Information Disclosure | dead internal doc paths | low | mitigate | Named references absent with populated-file controls | closed |
| T-237-04-04 | Information Disclosure | public fixtures | medium | mitigate | Synthetic fixtures contain no identities or local paths | closed |
| T-237-04-05 | Tampering | package installs | low | accept | No registry package installed by this plan | closed |
| T-237-05-01 | Spoofing | suppression prune | high | mitigate | Remove-and-retest plus warnings-as-errors proof | closed |
| T-237-05-02 | Tampering | temporary build-file edit | high | mitigate | Byte-identical restore and clean diff recorded | closed |
| T-237-05-03 | Repudiation | misleading config comment | medium | mitigate | False phrase removed and replacement describes live behavior | closed |
| T-237-05-04 | Information Disclosure | dead guide links | low | mitigate | Dead targets absent with prose-survival controls | closed |
| T-237-05-05 | Tampering | package installs | low | accept | No registry package installed by this plan | closed |
| T-237-06-01 | Spoofing | pre-commit/dirty evidence | high | mitigate | Observation commit is ancestry-bound; fingerprint is fresh | closed |
| T-237-06-02 | Spoofing | control-free absence claim | high | mitigate | Absence checks carry positive controls and failure-direction fixtures | closed |
| T-237-06-03 | Spoofing | wrong ledger validator | medium | mitigate | Evidence slots are parsed directly against the Phase 237 ledger | closed |
| T-237-06-04 | Information Disclosure | published planning artifacts | medium | mitigate | Local-path scan and sanitized snapshot; no secret values introduced | closed |
| T-237-06-05 | Tampering | package installs | low | accept | Only documented local tool pin was restored; no tracked dependency change | closed |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-237-01 | T-237-01-04, T-237-02-04, T-237-03-06, T-237-04-05, T-237-05-05, T-237-06-05 | These plans added no registry dependency; package-supply-chain risk was not introduced. | phase plans | 2026-09-16 |
| AR-237-02 | T-237-03-04 | Git worktree pruning cannot delete `refs/stash`; exact stash SHAs were rechecked after retirement and on 2026-09-19. | phase plan D-09 | 2026-09-16 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-19 | 29 | 29 | 0 | Codex automation-first verification |

## Sign-Off

- [x] All plan-time threats have a disposition.
- [x] Accepted risks are documented.
- [x] Critical/high mitigations are backed by current automated evidence.
- [x] `threats_open: 0` confirmed at ASVS L1.
- [x] `status: verified` set in frontmatter.

**Approval:** verified 2026-09-19
